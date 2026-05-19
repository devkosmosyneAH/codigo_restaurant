import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/menu/data/services/drive_menu_connection_service.dart';
import 'package:restaurant_app/features/menu/data/services/menu_sync_diagnostics_service.dart';
import 'package:restaurant_app/features/menu/data/services/menu_realtime_database_service.dart';

class DriveQueueProcessResult {
  final int totalQueued;
  final int processed;
  final int succeeded;
  final int failed;
  final int deferred;

  const DriveQueueProcessResult({
    required this.totalQueued,
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.deferred,
  });
}

enum _DriveQueueOperationOutcome { success, retryLater, drop }

/// Cola local de operaciones Drive para resiliencia offline/transient errors.
///
/// Reutiliza `sync_log` con una tabla lógica local (`_local_drive_ops`) para
/// registrar operaciones de imágenes (subida/borrado) que fallaron y
/// reintentarlas cuando vuelve la conectividad/sesión.
class DriveImageSyncQueueService {
  static const String localQueueTable = '_local_drive_ops';
  static const String _deleteImageKind = 'delete_image';
  static const String _uploadImageKind = 'upload_image';
  static const String _imageTempPathKey = 'image_temp_path';
  static const String _legacyImageBase64Key = 'image_base64';
  static const Duration _autoCleanupMinInterval = Duration(hours: 4);
  static const Duration _autoCleanupMinAge = Duration(hours: 8);
  static const int _autoCleanupMaxDeletes = 25;

  final SyncManager _syncManager;
  final DriveMenuConnectionService _driveService;
  final DatabaseHelper _dbHelper;
  final MenuRealtimeDatabaseService _menuRealtimeDb;
  final TenantContext _tenantContext;
  final MenuSyncDiagnosticsService? _diagnosticsService;

  DateTime? _lastAutoCleanupAt;

  DriveImageSyncQueueService({
    required SyncManager syncManager,
    required DriveMenuConnectionService driveService,
    required DatabaseHelper dbHelper,
    required MenuRealtimeDatabaseService menuRealtimeDb,
    required TenantContext tenantContext,
    MenuSyncDiagnosticsService? diagnosticsService,
  }) : _syncManager = syncManager,
       _driveService = driveService,
       _dbHelper = dbHelper,
       _menuRealtimeDb = menuRealtimeDb,
       _tenantContext = tenantContext,
       _diagnosticsService = diagnosticsService;

  Future<int> countPendingOperations() async {
    final pending = await _syncManager.obtenerPendientesPorTabla(
      localQueueTable,
    );
    final count = pending.length;
    _diagnosticsService?.updatePendingQueueCount(count);
    return count;
  }

  Future<void> enqueueDeleteImage({
    required String restaurantId,
    required String fileId,
  }) async {
    final normalizedFileId = fileId.trim();
    if (normalizedFileId.isEmpty) return;

    final exists = await _syncManager.existePendiente(
      tabla: localQueueTable,
      registroId: normalizedFileId,
    );
    if (exists) return;

    await _syncManager.registrarOperacion(
      tabla: localQueueTable,
      registroId: normalizedFileId,
      operacion: SyncOperation.delete,
      restaurantId: restaurantId,
      datos: {'kind': _deleteImageKind, 'file_id': normalizedFileId},
    );

    await countPendingOperations();
  }

  Future<void> enqueueUploadImage({
    required String restaurantId,
    required String userId,
    required String productoId,
    required List<int> bytes,
    required String mimeType,
    required String fileExtension,
    String? previousDriveFileId,
  }) async {
    final normalizedRestaurantId = restaurantId.trim();
    final normalizedUserId = userId.trim().isEmpty ? 'system' : userId.trim();
    final normalizedProductoId = productoId.trim();

    if (normalizedRestaurantId.isEmpty || normalizedProductoId.isEmpty) {
      return;
    }
    if (bytes.isEmpty) return;

    final normalizedMimeType = mimeType.trim();
    if (normalizedMimeType.isEmpty) return;

    final normalizedExtension = fileExtension.trim().isEmpty
        ? 'jpg'
        : fileExtension.trim().toLowerCase();

    final previousFileId = previousDriveFileId?.trim();
    final queueRecordId = 'upload:$normalizedProductoId';

    final tempImagePath = await _writePendingImageTempFile(
      restaurantId: normalizedRestaurantId,
      productoId: normalizedProductoId,
      fileExtension: normalizedExtension,
      bytes: bytes,
    );
    if (tempImagePath == null || tempImagePath.trim().isEmpty) {
      _diagnosticsService?.recordError(
        'No se pudo crear archivo temporal para cola Drive '
        'de "$normalizedProductoId".',
      );
      return;
    }

    final existing = await _syncManager.obtenerPendiente(
      tabla: localQueueTable,
      registroId: queueRecordId,
    );
    final previousTempPath =
        existing?.datos?[_imageTempPathKey]?.toString().trim() ?? '';
    if (previousTempPath.isNotEmpty && previousTempPath != tempImagePath) {
      await _deleteTempImageFile(previousTempPath);
    }

    await _syncManager.registrarOperacion(
      tabla: localQueueTable,
      registroId: queueRecordId,
      operacion: SyncOperation.update,
      restaurantId: normalizedRestaurantId,
      datos: {
        'kind': _uploadImageKind,
        'restaurant_id': normalizedRestaurantId,
        'user_id': normalizedUserId,
        'producto_id': normalizedProductoId,
        'mime_type': normalizedMimeType,
        'file_extension': normalizedExtension,
        _imageTempPathKey: tempImagePath,
        'previous_drive_file_id':
            (previousFileId == null || previousFileId.isEmpty)
            ? null
            : previousFileId,
      },
    );

    await countPendingOperations();
  }

  Future<DriveQueueProcessResult> processPendingOperations({
    bool allowInteractiveSignIn = false,
    int maxToProcess = 40,
  }) async {
    final pending = await _syncManager.obtenerPendientesPorTabla(
      localQueueTable,
    );
    _diagnosticsService?.updatePendingQueueCount(pending.length);

    if (pending.isEmpty) {
      await _runAutoCleanupIfDue(allowInteractiveSignIn: false);
      return const DriveQueueProcessResult(
        totalQueued: 0,
        processed: 0,
        succeeded: 0,
        failed: 0,
        deferred: 0,
      );
    }

    var signedIn = await _driveService.restoreSessionSilently();
    if (!signedIn && allowInteractiveSignIn) {
      signedIn = await _driveService.signIn();
    }

    if (!signedIn) {
      _diagnosticsService?.updateDriveStatus(
        connected: false,
        accountEmail: _driveService.currentEmail,
      );
      _diagnosticsService?.recordError(
        'No hay sesión Drive activa para procesar la cola '
        '(${pending.length} pendiente(s)).',
      );
      return DriveQueueProcessResult(
        totalQueued: pending.length,
        processed: 0,
        succeeded: 0,
        failed: 0,
        deferred: pending.length,
      );
    }

    var processed = 0;
    var succeeded = 0;
    var failed = 0;

    for (final record in pending.take(maxToProcess)) {
      processed++;
      final kind = record.datos?['kind']?.toString();

      final outcome = switch (kind) {
        _deleteImageKind => await _processDeleteRecord(record),
        _uploadImageKind => await _processUploadRecord(record),
        _ => _DriveQueueOperationOutcome.drop,
      };

      if (outcome == _DriveQueueOperationOutcome.success ||
          outcome == _DriveQueueOperationOutcome.drop) {
        await _syncManager.marcarSincronizado(record.id);
        succeeded++;
      } else {
        await _syncManager.incrementarIntentos(record.id);
        failed++;
      }
    }

    final deferred = pending.length - processed;
    await countPendingOperations();
    await _runAutoCleanupIfDue(allowInteractiveSignIn: allowInteractiveSignIn);

    return DriveQueueProcessResult(
      totalQueued: pending.length,
      processed: processed,
      succeeded: succeeded,
      failed: failed,
      deferred: deferred,
    );
  }

  Future<DriveQueueProcessResult> processPendingDeletes({
    bool allowInteractiveSignIn = false,
    int maxToProcess = 40,
  }) {
    // Compatibilidad con llamados existentes: procesa toda la cola.
    return processPendingOperations(
      allowInteractiveSignIn: allowInteractiveSignIn,
      maxToProcess: maxToProcess,
    );
  }

  Future<DriveCleanupResult> cleanupOrphanedDriveImages({
    String? restaurantId,
    String? userId,
    bool dryRun = false,
    bool allowInteractiveSignIn = false,
    int maxDeletes = 25,
    Duration minAge = const Duration(hours: 6),
  }) async {
    final effectiveRestaurantId = (restaurantId?.trim().isNotEmpty ?? false)
        ? restaurantId!.trim()
        : _tenantContext.restaurantId.trim();
    final effectiveUserId = (userId?.trim().isNotEmpty ?? false)
        ? userId!.trim()
        : (_tenantContext.userId ?? 'system');

    if (effectiveRestaurantId.isEmpty) {
      final result = DriveCleanupResult(
        scanned: 0,
        orphanCandidates: 0,
        deleted: 0,
        dryRun: dryRun,
        skipped: true,
        message: 'No hay restaurant_id activo para limpiar huérfanas.',
      );
      _diagnosticsService?.recordCleanup(
        scanned: result.scanned,
        orphanCandidates: result.orphanCandidates,
        deleted: result.deleted,
        dryRun: result.dryRun,
        message: result.message,
      );
      return result;
    }

    var signedIn = await _driveService.restoreSessionSilently();
    if (!signedIn && allowInteractiveSignIn) {
      signedIn = await _driveService.signIn();
    }

    if (!signedIn) {
      final result = DriveCleanupResult(
        scanned: 0,
        orphanCandidates: 0,
        deleted: 0,
        dryRun: dryRun,
        skipped: true,
        message: 'Limpieza pendiente: sesión Drive no disponible.',
      );
      _diagnosticsService?.recordCleanup(
        scanned: result.scanned,
        orphanCandidates: result.orphanCandidates,
        deleted: result.deleted,
        dryRun: result.dryRun,
        message: result.message,
      );
      return result;
    }

    final referencedIds = await _loadReferencedDriveFileIds(
      restaurantId: effectiveRestaurantId,
    );

    final result = await _driveService.cleanupOrphanedImages(
      restaurantId: effectiveRestaurantId,
      userId: effectiveUserId,
      referencedFileIds: referencedIds,
      minAge: minAge,
      maxDeletes: maxDeletes,
      dryRun: dryRun,
    );

    _diagnosticsService?.recordCleanup(
      scanned: result.scanned,
      orphanCandidates: result.orphanCandidates,
      deleted: result.deleted,
      dryRun: result.dryRun,
      message: result.message,
    );

    return result;
  }

  Future<_DriveQueueOperationOutcome> _processDeleteRecord(
    SyncRecord record,
  ) async {
    final rawFileId = record.datos?['file_id']?.toString() ?? record.registroId;
    final fileId = rawFileId.trim();
    if (fileId.isEmpty) {
      return _DriveQueueOperationOutcome.drop;
    }

    final deleted = await _driveService.tryDeleteProductImage(fileId);
    return deleted
        ? _DriveQueueOperationOutcome.success
        : _DriveQueueOperationOutcome.retryLater;
  }

  Future<_DriveQueueOperationOutcome> _processUploadRecord(
    SyncRecord record,
  ) async {
    final data = record.datos ?? const <String, dynamic>{};

    final restaurantId =
        (data['restaurant_id']?.toString().trim().isNotEmpty ?? false)
        ? data['restaurant_id'].toString().trim()
        : record.restaurantId.trim();
    final userId = (data['user_id']?.toString().trim().isNotEmpty ?? false)
        ? data['user_id'].toString().trim()
        : 'system';
    final productoId = data['producto_id']?.toString().trim() ?? '';
    final mimeType = data['mime_type']?.toString().trim() ?? '';
    final fileExtension = (data['file_extension']?.toString().trim() ?? 'jpg')
        .toLowerCase();
    final tempImagePath = data[_imageTempPathKey]?.toString().trim() ?? '';
    final encodedBytes = data[_legacyImageBase64Key]?.toString().trim() ?? '';

    if (restaurantId.isEmpty ||
        productoId.isEmpty ||
        mimeType.isEmpty ||
        (tempImagePath.isEmpty && encodedBytes.isEmpty)) {
      _diagnosticsService?.recordError(
        'Registro de cola de Drive incompleto para producto "$productoId".',
      );
      await _deleteTempImageFile(tempImagePath);
      return _DriveQueueOperationOutcome.drop;
    }

    List<int> bytes;
    if (tempImagePath.isNotEmpty) {
      try {
        final file = File(tempImagePath);
        if (!await file.exists()) {
          _diagnosticsService?.recordError(
            'Archivo temporal no encontrado para cola Drive de "$productoId".',
          );
          return _DriveQueueOperationOutcome.drop;
        }
        bytes = await file.readAsBytes();
      } catch (e, st) {
        _diagnosticsService?.recordError(
          'No se pudo leer archivo temporal de cola Drive para "$productoId": $e',
        );
        debugPrint('Drive queue temp read error for $productoId: $e\n$st');
        return _DriveQueueOperationOutcome.drop;
      }
    } else {
      try {
        bytes = base64Decode(encodedBytes);
      } catch (e, st) {
        _diagnosticsService?.recordError(
          'Payload base64 inválido en cola Drive para "$productoId": $e',
        );
        debugPrint('Drive queue decode error for $productoId: $e\n$st');
        return _DriveQueueOperationOutcome.drop;
      }
    }
    if (bytes.isEmpty) {
      await _deleteTempImageFile(tempImagePath);
      return _DriveQueueOperationOutcome.drop;
    }

    DriveUploadResult upload;
    try {
      upload = await _driveService.uploadProductImage(
        restaurantId: restaurantId,
        userId: userId,
        productoId: productoId,
        bytes: bytes,
        mimeType: mimeType,
        fileExtension: fileExtension,
      );
    } catch (e, st) {
      _diagnosticsService?.recordError(
        'Error subiendo imagen pendiente de "$productoId" a Drive: $e',
      );
      debugPrint('Drive queue upload error for $productoId: $e\n$st');
      return _DriveQueueOperationOutcome.retryLater;
    }

    final previousDriveFileId =
        data['previous_drive_file_id']?.toString().trim() ?? '';
    if (previousDriveFileId.isNotEmpty &&
        previousDriveFileId != upload.fileId) {
      final deleted = await _driveService.tryDeleteProductImage(
        previousDriveFileId,
      );
      if (!deleted) {
        await enqueueDeleteImage(
          restaurantId: restaurantId,
          fileId: previousDriveFileId,
        );
      }
    }

    try {
      final applied = await _applyUploadedImageToLocalProduct(
        restaurantId: restaurantId,
        productoId: productoId,
        upload: upload,
      );

      if (!applied) {
        await _driveService.tryDeleteProductImage(upload.fileId);
        await _deleteTempImageFile(tempImagePath);
        return _DriveQueueOperationOutcome.drop;
      }
      await _deleteTempImageFile(tempImagePath);
      return _DriveQueueOperationOutcome.success;
    } catch (e, st) {
      _diagnosticsService?.recordError(
        'Error aplicando imagen subida al producto "$productoId": $e',
      );
      debugPrint('Drive queue apply error for $productoId: $e\n$st');
      await _driveService.tryDeleteProductImage(upload.fileId);
      return _DriveQueueOperationOutcome.retryLater;
    }
  }

  Future<bool> _applyUploadedImageToLocalProduct({
    required String restaurantId,
    required String productoId,
    required DriveUploadResult upload,
  }) async {
    final rows = await _dbHelper.query(
      'productos',
      where: 'id = ? AND restaurant_id = ?',
      whereArgs: [productoId, restaurantId],
      limit: 1,
    );

    if (rows.isEmpty) return false;

    final nowIso = DateTime.now().toIso8601String();
    final patch = <String, dynamic>{
      'imagen_url': upload.publicUrl,
      'drive_file_id': upload.fileId,
      'drive_public_url': upload.publicUrl,
      'imagen_local_cache_path': upload.localCachePath,
      'updated_at': nowIso,
    };

    await _dbHelper.update(
      'productos',
      patch,
      where: 'id = ? AND restaurant_id = ?',
      whereArgs: [productoId, restaurantId],
    );

    await _syncManager.registrarOperacion(
      tabla: 'productos',
      registroId: productoId,
      operacion: SyncOperation.update,
      restaurantId: restaurantId,
      datos: {'id': productoId, 'restaurant_id': restaurantId, ...patch},
    );

    unawaited(
      _menuRealtimeDb.patchProducto(
        restaurantId: restaurantId,
        productoId: productoId,
        data: patch,
      ),
    );

    return true;
  }

  Future<String?> _writePendingImageTempFile({
    required String restaurantId,
    required String productoId,
    required String fileExtension,
    required List<int> bytes,
  }) async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final queueDir = Directory(
        p.join(tmpDir.path, 'menu_drive_queue', restaurantId),
      );
      if (!await queueDir.exists()) {
        await queueDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        p.join(queueDir.path, '${productoId}_$timestamp.$fileExtension'),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      _diagnosticsService?.recordError(
        'No se pudo escribir archivo temporal de cola Drive: $e',
      );
      debugPrint('Drive queue temp write error: $e\n$st');
      return null;
    }
  }

  Future<void> _deleteTempImageFile(String? path) async {
    final normalized = path?.trim() ?? '';
    if (normalized.isEmpty) return;

    try {
      final file = File(normalized);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, st) {
      debugPrint('Drive queue temp delete warning: $e\n$st');
    }
  }

  Future<void> _runAutoCleanupIfDue({
    required bool allowInteractiveSignIn,
  }) async {
    final now = DateTime.now();
    final lastRun = _lastAutoCleanupAt;
    if (lastRun != null && now.difference(lastRun) < _autoCleanupMinInterval) {
      return;
    }

    _lastAutoCleanupAt = now;
    try {
      await cleanupOrphanedDriveImages(
        allowInteractiveSignIn: allowInteractiveSignIn,
        maxDeletes: _autoCleanupMaxDeletes,
        minAge: _autoCleanupMinAge,
      );
    } catch (e, st) {
      _diagnosticsService?.recordError('Error en auto-cleanup de Drive: $e');
      debugPrint('Drive auto-cleanup error: $e\n$st');
      // No interrumpe el procesamiento de la cola por errores de mantenimiento.
    }
  }

  Future<Set<String>> _loadReferencedDriveFileIds({
    required String restaurantId,
  }) async {
    final rows = await _dbHelper.rawQuery(
      'SELECT DISTINCT drive_file_id '
      'FROM productos '
      'WHERE restaurant_id = ? '
      'AND drive_file_id IS NOT NULL '
      "AND TRIM(drive_file_id) <> ''",
      [restaurantId],
    );

    final ids = <String>{};
    for (final row in rows) {
      final raw = row['drive_file_id']?.toString().trim() ?? '';
      if (raw.isNotEmpty) {
        ids.add(raw);
      }
    }
    return ids;
  }
}
