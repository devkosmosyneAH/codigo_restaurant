import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/features/menu/data/services/drive_menu_connection_service.dart';

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

/// Cola local de operaciones Drive para resiliencia offline/transient errors.
///
/// Reutiliza `sync_log` con una tabla lógica local (`_local_drive_ops`) para
/// registrar operaciones de borrado de imágenes que fallaron y reintentarlas.
class DriveImageSyncQueueService {
  static const String localQueueTable = '_local_drive_ops';
  static const String _deleteImageKind = 'delete_image';

  final SyncManager _syncManager;
  final DriveMenuConnectionService _driveService;

  DriveImageSyncQueueService({
    required SyncManager syncManager,
    required DriveMenuConnectionService driveService,
  }) : _syncManager = syncManager,
       _driveService = driveService;

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
  }

  Future<DriveQueueProcessResult> processPendingDeletes({
    bool allowInteractiveSignIn = false,
    int maxToProcess = 40,
  }) async {
    final pending = await _syncManager.obtenerPendientesPorTabla(
      localQueueTable,
    );
    if (pending.isEmpty) {
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
      final kind = record.datos?['kind']?.toString();
      if (kind != _deleteImageKind) {
        await _syncManager.marcarSincronizado(record.id);
        continue;
      }

      final rawFileId =
          record.datos?['file_id']?.toString() ?? record.registroId;
      final fileId = rawFileId.trim();
      if (fileId.isEmpty) {
        await _syncManager.marcarSincronizado(record.id);
        continue;
      }

      processed++;
      final deleted = await _driveService.tryDeleteProductImage(fileId);
      if (deleted) {
        await _syncManager.marcarSincronizado(record.id);
        succeeded++;
      } else {
        await _syncManager.incrementarIntentos(record.id);
        failed++;
      }
    }

    final deferred = pending.length - processed;
    return DriveQueueProcessResult(
      totalQueued: pending.length,
      processed: processed,
      succeeded: succeeded,
      failed: failed,
      deferred: deferred,
    );
  }
}
