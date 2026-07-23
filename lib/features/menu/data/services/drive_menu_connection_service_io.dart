import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:restaurant_app/core/config/app_environment.dart';
import 'package:restaurant_app/features/menu/data/datasources/drive_connection_local_datasource.dart';
import 'package:restaurant_app/features/menu/data/models/drive_connection_model.dart';
import 'package:restaurant_app/features/menu/data/services/menu_sync_diagnostics_service.dart';
import 'package:restaurant_app/features/menu/domain/entities/drive_connection.dart';
import 'package:restaurant_app/services/drive_auth_coordinator.dart';

/// Resultado de subida de imagen a Drive.
class DriveUploadResult {
  final String fileId;

  /// URL publica directa que cualquier `<img>` puede consumir sin OAuth.
  final String publicUrl;

  /// Ruta local en disco con la copia cacheada (offline-first).
  final String? localCachePath;

  const DriveUploadResult({
    required this.fileId,
    required this.publicUrl,
    this.localCachePath,
  });
}

class DriveStoredFile {
  final String id;
  final String name;
  final DateTime? createdAt;

  const DriveStoredFile({
    required this.id,
    required this.name,
    required this.createdAt,
  });
}

class DriveCleanupResult {
  final int scanned;
  final int orphanCandidates;
  final int deleted;
  final bool dryRun;
  final bool skipped;
  final String? message;

  const DriveCleanupResult({
    required this.scanned,
    required this.orphanCandidates,
    required this.deleted,
    required this.dryRun,
    this.skipped = false,
    this.message,
  });
}

// Usamos los tipos `DriveAuthResult` y `DriveAuthStatus` definidos
// centralmente en `DriveAuthCoordinator`.

/// Servicio ÚNICO de conexión a Drive para imágenes del menú.
///
/// IMPORTANTE: NO crea su propia instancia de GoogleSignIn.
/// Reutiliza DriveAuthCoordinator para toda la autenticación y la gestión
/// de tokens de Drive.
///
/// Responsabilidades:
/// 1. Crea/recupera una subcarpeta por tenant dentro de [AppEnvironment.driveRootFolderId]
/// 2. Comparte esa subcarpeta como pública (anyone with link, reader)
/// 3. Sube imágenes de productos y retorna URL pública
/// 4. Mantiene cache local para fallback offline
///
/// Seguridad:
/// - No persiste tokens OAuth: DriveAuthCoordinator administra el acceso a Google
///   y el refresco de credenciales.
/// - No expone credenciales: la página pública solo usa URLs públicas
class DriveMenuConnectionService {
  final DriveConnectionLocalDatasource _datasource;
  final MenuSyncDiagnosticsService _diagnosticsService;
  final DriveAuthCoordinator _driveAuthCoordinator;
  final Uuid _uuid;

  DriveMenuConnectionService({
    required DriveConnectionLocalDatasource datasource,
    MenuSyncDiagnosticsService? diagnosticsService,
    DriveAuthCoordinator? driveAuthCoordinator,
    Uuid? uuid,
  }) : _datasource = datasource,
       _diagnosticsService = diagnosticsService ?? MenuSyncDiagnosticsService(),
       _driveAuthCoordinator =
           driveAuthCoordinator ?? DriveAuthCoordinator.instance,
       _uuid = uuid ?? const Uuid();

  String? _lastAuthError;

  bool get isSignedIn => _driveAuthCoordinator.isSignedIn;
  String? get currentEmail => _driveAuthCoordinator.currentEmail;

  Future<bool> signIn() async {
    try {
      final account = await _driveAuthCoordinator.signIn();
      final googleSignedIn = account != null;
      _diagnosticsService.updateDriveStatus(
        connected: googleSignedIn,
        accountEmail: currentEmail,
        error: googleSignedIn
            ? null
            : (_lastAuthError ??
                  'No se pudo autenticar la sesión de Google Drive.'),
      );
      return googleSignedIn;
    } catch (e) {
      _lastAuthError = 'Error en signIn: $e';
      _diagnosticsService.recordError(_lastAuthError!);
      return false;
    }
  }

  Future<bool> restoreSessionSilently() async {
    try {
      final restored =
          await _driveAuthCoordinator.restoreSessionSilently() != null;
      _diagnosticsService.updateDriveStatus(
        connected: restored,
        accountEmail: currentEmail,
        tokenExpiresAt: restored ? await _tryResolveTokenExpiry() : null,
        error: restored ? null : _lastAuthError,
      );
      return restored;
    } catch (e) {
      _lastAuthError = 'Error en restoreSessionSilently: $e';
      _diagnosticsService.recordError(_lastAuthError!);
      return false;
    }
  }

  // â”€â”€ AutenticaciÃ³n centralizada â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Verifica y establece autenticaciÃ³n con Google Drive.
  ///
  /// Pasos:
  /// 1. Intenta restaurar sesiÃ³n silenciosamente (Google Sign-In).
  /// 2. Si [interactive] es `true` y no hay sesiÃ³n, inicia flujo OAuth
  ///    con Google Sign-In interactivo.
  /// 3. Valida acceso real a la Drive API con una llamada de prueba.
  ///
  /// Todos los pasos producen logs con prefijo `drive.auth [io]:`.
  Future<DriveAuthResult> ensureDriveAuthenticated({
    bool interactive = false,
  }) async {
    final result = await _driveAuthCoordinator.ensureDriveAuthenticated(
      interactive: interactive,
      requiredScopes: const [drive.DriveApi.driveFileScope],
    );

    if (result.isConnected) {
      _diagnosticsService.updateDriveStatus(
        connected: true,
        accountEmail: currentEmail,
        tokenExpiresAt: await _tryResolveTokenExpiry(),
      );
    } else {
      _diagnosticsService.updateDriveStatus(
        connected: false,
        accountEmail: currentEmail,
        error: result.message,
      );
    }

    return result;
  }

  /// Valida acceso real a la Drive API con un request mÃ­nimo (list 1 archivo).
  ///
  /// Devuelve `true` si la API responde correctamente, `false` en caso de error.
  Future<bool> validateDriveApiAccess({bool allowInteractive = false}) async {
    try {
      final api = await _driveAuthCoordinator.createDriveApi(
        interactive: allowInteractive,
        requiredScopes: const [drive.DriveApi.driveFileScope],
      );
      await api.files.list(pageSize: 1);
      debugPrint('drive.auth [io]: validación API Drive OK');
      return true;
    } catch (e, st) {
      debugPrint('drive.auth [io]: fallo validación Drive API: $e\n$st');
      _diagnosticsService.recordError('Fallo validación Drive API: $e');
      _diagnosticsService.updateDriveStatus(
        connected: false,
        accountEmail: currentEmail,
        error: 'Validación Drive API fallida: $e',
      );
      return false;
    }
  }

  /// DiagnÃ³stico de configuraciÃ³n GCP visible para el administrador.
  Map<String, String> driveConfigDiagnostic() {
    final clientId = AppEnvironment.googleClientId;
    final folderId = AppEnvironment.driveRootFolderId;
    return {
      'clientId': clientId.isNotEmpty
          ? '${clientId.substring(0, clientId.length.clamp(0, 12))}...'
          : 'VACÃO â€” revisa GOOGLE_CLIENT_ID en dart-define',
      'folderId': folderId.isNotEmpty
          ? '${folderId.substring(0, folderId.length.clamp(0, 8))}...'
          : 'VACÃO â€” revisa GOOGLE_DRIVE_FOLDER_ID en dart-define',
      'isDriveConfigured': AppEnvironment.isDriveConfigured.toString(),
      'scope': drive.DriveApi.driveFileScope,
      'platform': Platform.operatingSystem,
      'sessionActive': isSignedIn.toString(),
      'cuenta': currentEmail ?? 'ninguna',
    };
  }

  Future<void> signOut() async {
    await _driveAuthCoordinator.signOut();
    _diagnosticsService.updateDriveStatus(
      connected: false,
      accountEmail: null,
      tokenExpiresAt: null,
    );
  }

  // â”€â”€ Conexion por tenant â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Garantiza la existencia de la conexion Drive del tenant.
  ///
  /// Si ya existe en SQLite, la retorna. Si no, genera UUID nuevo, crea la
  /// subcarpeta dentro de [AppEnvironment.driveRootFolderId], la comparte
  /// como publica y la persiste.
  ///
  /// Requiere sesion Google activa. Lanza si Drive no esta configurado.
  Future<DriveConnection> ensureConnectionForTenant({
    required String restaurantId,
    required String userId,
  }) async {
    if (!AppEnvironment.isDriveConfigured) {
      throw StateError(
        'La carpeta raiz de Drive no esta configurada '
        '(DRIVE_ROOT_FOLDER_ID / GOOGLE_DRIVE_FOLDER_ID / '
        'REACT_APP_GOOGLE_DRIVE_FOLDER_ID / VITE_GOOGLE_DRIVE_FOLDER_ID / '
        'NEXT_PUBLIC_GOOGLE_DRIVE_FOLDER_ID).',
      );
    }

    final existing = await _datasource.getByRestaurantId(restaurantId);
    if (existing != null) return existing;

    final api = await _driveAuthCoordinator.createDriveApi(
      interactive: true,
      requiredScopes: const [drive.DriveApi.driveFileScope],
    );
    final newId = _uuid.v4();
    final folderName = 'tenant-$restaurantId-${newId.substring(0, 8)}';

    // 1. Crear subcarpeta dentro de la carpeta raiz.
    final folderMeta = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [AppEnvironment.driveRootFolderId];
    final created = await api.files.create(folderMeta, $fields: 'id');
    final folderId = created.id;
    if (folderId == null) {
      throw StateError('Drive no retorno el id de la carpeta creada.');
    }

    // 2. Compartir publica.
    await _enablePublicShare(api, folderId);

    final now = DateTime.now();
    final connection = DriveConnectionModel(
      id: newId,
      restaurantId: restaurantId,
      folderId: folderId,
      folderName: folderName,
      ownerEmail: currentEmail ?? '',
      publicShareEnabled: true,
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
    );
    await _datasource.upsert(connection);
    return connection;
  }

  /// Revoca el permiso publico de la carpeta del tenant.
  Future<void> revokePublicAccess(String restaurantId) async {
    final connection = await _datasource.getByRestaurantId(restaurantId);
    if (connection == null) return;

    final api = await _driveAuthCoordinator.createDriveApi(
      interactive: true,
      requiredScopes: const [drive.DriveApi.driveFileScope],
    );
    final perms = await api.permissions.list(
      connection.folderId,
      $fields: 'permissions(id,type)',
    );
    for (final perm in perms.permissions ?? const <drive.Permission>[]) {
      if (perm.type == 'anyone' && perm.id != null) {
        await api.permissions.delete(connection.folderId, perm.id!);
      }
    }
    final updated = DriveConnectionModel.fromEntity(
      connection.copyWith(publicShareEnabled: false, updatedAt: DateTime.now()),
    );
    await _datasource.upsert(updated);
  }

  // â”€â”€ Imagenes de producto â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Sube una imagen al folder del tenant y devuelve `fileId` + URL publica.
  ///
  /// Si la conexion del tenant aun no existe, la crea. Mantiene una copia
  /// local en cache para offline.
  Future<DriveUploadResult> uploadProductImage({
    required String restaurantId,
    required String userId,
    required String productoId,
    required List<int> bytes,
    required String mimeType,
    required String fileExtension,
  }) async {
    try {
      final uploadStopwatch = Stopwatch()..start();
      final connection = await ensureConnectionForTenant(
        restaurantId: restaurantId,
        userId: userId,
      );

      final api = await _driveAuthCoordinator.createDriveApi(
        interactive: true,
        requiredScopes: const [drive.DriveApi.driveFileScope],
      );
      final fileName =
          '$productoId-${DateTime.now().millisecondsSinceEpoch}'
          '.$fileExtension';
      final meta = drive.File()
        ..name = fileName
        ..parents = [connection.folderId];
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: mimeType,
      );
      final created = await api.files.create(
        meta,
        uploadMedia: media,
        $fields: 'id',
      );
      final fileId = created.id;
      if (fileId == null) {
        throw StateError('Drive no retorno el id del archivo subido.');
      }

      final publicUrl = buildPublicUrl(fileId);
      final cachePath = await _writeLocalCache(
        restaurantId: restaurantId,
        fileName: fileName,
        bytes: bytes,
      );
      uploadStopwatch.stop();
      debugPrint(
        'drive.io.upload '
        'productoId=$productoId '
        'bytes=${bytes.length} '
        'mime=$mimeType '
        'elapsedMs=${uploadStopwatch.elapsedMilliseconds} '
        'url=$publicUrl',
      );

      _diagnosticsService.recordUploadSuccess(
        fileId: fileId,
        publicUrl: publicUrl,
      );

      return DriveUploadResult(
        fileId: fileId,
        publicUrl: publicUrl,
        localCachePath: cachePath,
      );
    } catch (e, st) {
      _diagnosticsService.recordUploadFailure(e);
      debugPrint('drive.io.upload.error productoId=$productoId error=$e\n$st');
      rethrow;
    }
  }

  /// Elimina un archivo del Drive por su id. Tolerante a errores
  /// (por ejemplo, si ya fue borrado manualmente desde Drive Web).
  Future<bool> tryDeleteProductImage(String fileId) async {
    try {
      final api = await _driveAuthCoordinator.createDriveApi(
        interactive: true,
        requiredScopes: const [drive.DriveApi.driveFileScope],
      );
      await api.files.delete(fileId);
      return true;
    } catch (e) {
      _diagnosticsService.recordError('Error al borrar imagen en Drive: $e');
      // Retorna false para que el caller pueda encolar reintentos.
      return false;
    }
  }

  Future<void> deleteProductImage(String fileId) async {
    await tryDeleteProductImage(fileId);
  }

  /// Construye una URL publica directa servida por la CDN de Google.
  /// No cuenta contra la cuota OAuth y es accesible sin login.
  static String buildPublicUrl(String fileId) {
    return 'https://drive.google.com/uc?export=view&id=$fileId';
  }

  Future<List<DriveStoredFile>> listTenantFiles({
    required String restaurantId,
    required String userId,
  }) async {
    final connection = await ensureConnectionForTenant(
      restaurantId: restaurantId,
      userId: userId,
    );

    final api = await _driveAuthCoordinator.createDriveApi(
      interactive: true,
      requiredScopes: const [drive.DriveApi.driveFileScope],
    );
    final output = <DriveStoredFile>[];
    String? pageToken;

    do {
      final page = await api.files.list(
        q:
            "'${connection.folderId}' in parents and trashed = false and "
            "mimeType != 'application/vnd.google-apps.folder'",
        spaces: 'drive',
        pageSize: 200,
        pageToken: pageToken,
        $fields: 'nextPageToken,files(id,name,createdTime)',
      );

      for (final file in page.files ?? const <drive.File>[]) {
        final id = file.id?.trim();
        if (id == null || id.isEmpty) continue;
        output.add(
          DriveStoredFile(
            id: id,
            name: file.name ?? id,
            createdAt: file.createdTime,
          ),
        );
      }

      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return output;
  }

  Future<DriveCleanupResult> cleanupOrphanedImages({
    required String restaurantId,
    required String userId,
    required Set<String> referencedFileIds,
    Duration minAge = const Duration(hours: 6),
    int maxDeletes = 25,
    bool dryRun = false,
  }) async {
    final normalizedRefs = referencedFileIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();

    final allFiles = await listTenantFiles(
      restaurantId: restaurantId,
      userId: userId,
    );

    final threshold = DateTime.now().subtract(minAge);
    final orphanCandidates = allFiles
        .where((file) {
          if (normalizedRefs.contains(file.id)) return false;
          final createdAt = file.createdAt;
          if (createdAt == null) return false;
          return createdAt.isBefore(threshold);
        })
        .toList(growable: false);

    if (dryRun) {
      return DriveCleanupResult(
        scanned: allFiles.length,
        orphanCandidates: orphanCandidates.length,
        deleted: 0,
        dryRun: true,
      );
    }

    final safeDeleteLimit = maxDeletes < 0 ? 0 : maxDeletes;
    var deleted = 0;
    for (final orphan in orphanCandidates.take(safeDeleteLimit)) {
      final ok = await tryDeleteProductImage(orphan.id);
      if (ok) deleted++;
    }

    return DriveCleanupResult(
      scanned: allFiles.length,
      orphanCandidates: orphanCandidates.length,
      deleted: deleted,
      dryRun: false,
    );
  }

  // â”€â”€ Internals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<DateTime?> _tryResolveTokenExpiry() async {
    if (!isSignedIn) return null;

    try {
      final idToken = await _driveAuthCoordinator.getIdToken();
      return _decodeJwtExpiry(idToken);
    } catch (_) {
      return null;
    }
  }

  DateTime? _decodeJwtExpiry(String? token) {
    if (token == null || token.trim().isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final parsed = jsonDecode(payload);
      if (parsed is! Map<String, dynamic>) return null;
      final expRaw = parsed['exp'];
      final seconds = expRaw is num
          ? expRaw.toInt()
          : int.tryParse(expRaw?.toString() ?? '');
      if (seconds == null || seconds <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    } catch (_) {
      return null;
    }
  }

  Future<void> _enablePublicShare(drive.DriveApi api, String folderId) async {
    final permission = drive.Permission()
      ..type = 'anyone'
      ..role = 'reader';
    await api.permissions.create(
      permission,
      folderId,
      sendNotificationEmail: false,
    );
  }

  Future<String?> _writeLocalCache({
    required String restaurantId,
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'menu_images', restaurantId));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
