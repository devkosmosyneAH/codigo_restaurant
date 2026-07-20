import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/services/google_auth_service.dart';

/// Resultado de una operación de backup o restauración.
class DriveResult {
  final bool success;
  final String message;
  final DateTime? timestamp;

  const DriveResult({
    required this.success,
    required this.message,
    this.timestamp,
  });
}

/// Servicio ÚNICO para respaldar/restaurar la base de datos desde Google Drive.
///
/// IMPORTANTE: NO crea su propia instancia de GoogleSignIn.
/// Reutiliza GoogleAuthService.instance para toda la autenticación.
///
/// Usa OAuth 2.0 con el scope de appdata (aislado por app, el usuario no
/// ve estos archivos en su Drive normal).
class DriveBackupService {
  DriveBackupService._({GoogleAuthService? googleAuthService})
    : _googleAuthService = googleAuthService ?? GoogleAuthService.instance;

  static DriveBackupService? _instance;

  /// Obtiene la instancia única de DriveBackupService.
  static DriveBackupService get instance {
    _instance ??= DriveBackupService._();
    return _instance!;
  }

  /// Para pruebas: permite inyectar una instancia custom.
  @visibleForTesting
  static void setInstance(DriveBackupService instance) {
    _instance = instance;
  }

  /// Para pruebas: resetea la instancia.
  @visibleForTesting
  static void reset() {
    _instance = null;
  }

  static const _backupFileName = 'lapena_backup.db';
  static const _folderName = 'La Peña Backups';

  final GoogleAuthService _googleAuthService;

  // ── Getters ──────────────────────────────────────────────────────────────

  /// Usuario autenticado (del servicio central).
  GoogleSignInAccount? get currentUser => _googleAuthService.currentUser;

  /// Email del usuario autenticado.
  String? get currentEmail => _googleAuthService.currentEmail;

  /// ¿Hay un usuario autenticado?
  bool get isSignedIn => _googleAuthService.isSignedIn;

  // ── Auth ─────────────────────────────────────────────────────────────────

  /// Inicia sesión interactiva con Google.
  ///
  /// Delega a GoogleAuthService (no crea nueva instancia).
  Future<GoogleSignInAccount?> signIn() async {
    final account = await _googleAuthService.signIn();
    debugPrint('drive_backup: signIn resultado=${account?.email ?? 'null'}');
    return account;
  }

  /// Intenta iniciar sesión silenciosamente (sesión previa).
  ///
  /// Delega a GoogleAuthService.
  Future<GoogleSignInAccount?> signInSilently() async {
    final account = await _googleAuthService.restoreSession();
    debugPrint(
      'drive_backup: signInSilently resultado=${account?.email ?? 'null'}',
    );
    return account;
  }

  /// Cierra sesión.
  ///
  /// Delega a GoogleAuthService.
  Future<void> signOut() async {
    await _googleAuthService.signOut();
    debugPrint('drive_backup: signOut completado');
  }

  /// Expone la verificación de permisos para Drive (delegado al servicio
  /// central de GoogleAuthService).
  Future<bool> ensureDriveAuthenticated({bool interactive = false}) =>
      _googleAuthService.ensureDriveAuthenticated(interactive: interactive);

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<drive.DriveApi> _getDriveApi() async {
    const tokenError = 'Drive accessToken inválido. Reautenticación requerida.';

    // Obtener usuario autenticado desde el servicio central
    var account = _googleAuthService.currentUser;
    if (account == null) {
      // Intentar restaurar sesión única silenciosa.
      account = await _googleAuthService.restoreSession();
      if (account != null) {
        debugPrint(
          'drive_backup._getDriveApi: sesión activa por restoreSession '
          'cuenta=${account.email}',
        );
      }
    }

    if (account == null) {
      // Solicitar login interactivo
      debugPrint(
        'drive_backup._getDriveApi: sin sesión silenciosa, '
        'forzando signIn interactivo.',
      );
      account = await _googleAuthService.signIn();
      if (account != null) {
        debugPrint(
          'drive_backup._getDriveApi: sesión activa por signIn '
          'cuenta=${account.email}',
        );
      }
    }

    if (account == null) {
      throw StateError(
        'No hay sesión de Google activa. '
        'El usuario debe iniciar sesión para usar Drive.',
      );
    }

    // Obtener token
    // Verificar que la sesión tenga permisos para Drive sin forzar UI.
    final hasDrive = await _googleAuthService.ensureDriveAuthenticated(
      interactive: false,
    );
    if (!hasDrive) {
      debugPrint(
        'drive_backup._getDriveApi: sesión sin token Drive para ${account.email} (consentimiento faltante)',
      );
      throw StateError(
        'Drive no autorizado: la cuenta está autenticada pero NO tiene un access token para Drive. ' 
        'Debes ejecutar una conexión interactiva una sola vez para otorgar permisos (llama a GoogleAuthService.signIn()).',
      );
    }

    final token = await _googleAuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint(
        'drive_backup._getDriveApi: accessToken null para ${account.email}',
      );
      throw StateError(tokenError);
    }

    final tokenPreview = token.substring(0, token.length.clamp(0, 8));
    debugPrint(
      'drive_backup._getDriveApi: accessToken obtenido '
      '($tokenPreview...) cuenta=${account.email}',
    );

    // Crear API client
    final api = drive.DriveApi(_AuthClient({'Authorization': 'Bearer $token'}));

    // Validar acceso
    try {
      await api.files.list(pageSize: 1);
      debugPrint('drive_backup._getDriveApi: Drive API validado');
    } catch (e, st) {
      debugPrint(
        'drive_backup._getDriveApi: validación runtime Drive falló: $e\n$st',
      );
      throw StateError('Autenticado pero sin acceso a Drive API.');
    }

    return api;
  }

  /// Obtiene o crea la carpeta de backups en Drive.
  Future<String> _getFolderId(drive.DriveApi api) async {
    final query =
        "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final result = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id,name)',
    );
    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }
    // Crear carpeta
    final folder = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    return created.id!;
  }

  Future<String> _getLocalDbPath() async {
    final dbDir = await getDatabasesPath();
    return p.join(dbDir, AppConstants.databaseName);
  }

  // ── Backup ───────────────────────────────────────────────────────────────

  /// Sube la base de datos a Google Drive.
  ///
  /// Si ya existe un archivo previo lo reemplaza (actualiza contenido).
  Future<DriveResult> backup() async {
    try {
      // Intentar asegurar permisos Drive: si no hay token, solicitar
      // interactivamente al usuario una vez (auto-prompt).
      final ready = await _ensureDriveReady(interactiveIfNeeded: true);
      if (!ready) {
        return const DriveResult(
          success: false,
          message:
              'Permisos para Google Drive no concedidos. Se requiere autorización.',
        );
      }

      final api = await _getDriveApi();
      final folderId = await _getFolderId(api);
      final dbPath = await _getLocalDbPath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return const DriveResult(
          success: false,
          message: 'No se encontró la base de datos local.',
        );
      }

      final bytes = await dbFile.readAsBytes();
      final stream = Stream.fromIterable([bytes]);
      final media = drive.Media(
        stream,
        bytes.length,
        contentType: 'application/octet-stream',
      );

      // Buscar si ya existe
      final query =
          "name='$_backupFileName' and '$folderId' in parents and trashed=false";
      final existing = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id)',
      );

      if (existing.files != null && existing.files!.isNotEmpty) {
        // Actualizar contenido (patch sin cambiar metadatos)
        await api.files.update(
          drive.File(),
          existing.files!.first.id!,
          uploadMedia: media,
        );
      } else {
        // Crear archivo nuevo
        final meta = drive.File()
          ..name = _backupFileName
          ..parents = [folderId];
        await api.files.create(meta, uploadMedia: media);
      }

      final now = DateTime.now();
      return DriveResult(
        success: true,
        message: 'Backup subido correctamente.',
        timestamp: now,
      );
    } catch (e) {
      return DriveResult(success: false, message: 'Error al subir: $e');
    }
  }

  // ── Restore ──────────────────────────────────────────────────────────────

  /// Descarga la base de datos desde Drive y reemplaza la local.
  ///
  /// ⚠️ Cierra la BD antes de llamar este método y reinicia la app después.
  Future<DriveResult> restore() async {
    try {
      final ready = await _ensureDriveReady(interactiveIfNeeded: true);
      if (!ready) {
        return const DriveResult(
          success: false,
          message:
              'Permisos para Google Drive no concedidos. Se requiere autorización.',
        );
      }

      final api = await _getDriveApi();
      final folderId = await _getFolderId(api);

      final query =
          "name='$_backupFileName' and '$folderId' in parents and trashed=false";
      final result = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id,modifiedTime)',
      );

      if (result.files == null || result.files!.isEmpty) {
        return const DriveResult(
          success: false,
          message: 'No se encontró ningún backup en Drive.',
        );
      }

      final fileId = result.files!.first.id!;
      final media =
          await api.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      // Guardar en directorio temporal primero, luego mover
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File(p.join(tmpDir.path, _backupFileName));
      final sink = tmpFile.openWrite();
      await media.stream.pipe(sink);
      await sink.close();

      // Reemplazar DB local
      final dbPath = await _getLocalDbPath();
      await tmpFile.copy(dbPath);
      await tmpFile.delete();

      return DriveResult(
        success: true,
        message: 'Base de datos restaurada. Reinicia la aplicación.',
        timestamp: result.files!.first.modifiedTime,
      );
    } catch (e) {
      return DriveResult(success: false, message: 'Error al restaurar: $e');
    }
  }

  // ── Info ─────────────────────────────────────────────────────────────────

  /// Retorna la fecha del último backup en Drive, o null si no existe.
  Future<DateTime?> lastBackupDate() async {
    try {
      final ready = await _ensureDriveReady(interactiveIfNeeded: false);
      if (!ready) return null;

      final api = await _getDriveApi();
      final folderId = await _getFolderId(api);
      final query =
          "name='$_backupFileName' and '$folderId' in parents and trashed=false";
      final result = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(modifiedTime)',
      );
      return result.files?.firstOrNull?.modifiedTime;
    } catch (_) {
      return null;
    }
  }

  /// Intenta asegurar permisos para Drive; si `interactiveIfNeeded` es true
  /// intentará pedir consentimiento interactivo la primera vez.
  Future<bool> _ensureDriveReady({bool interactiveIfNeeded = true}) async {
    try {
      final has = await ensureDriveAuthenticated(interactive: false);
      if (has) return true;
      if (!interactiveIfNeeded) return false;
      final granted = await ensureDriveAuthenticated(interactive: true);
      return granted;
    } catch (e) {
      debugPrint('drive_backup._ensureDriveReady: $e');
      return false;
    }
  }
}

// ── HTTP client que adjunta los headers OAuth ────────────────────────────────
class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
