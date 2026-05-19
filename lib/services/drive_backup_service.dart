import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/config/app_environment.dart';

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

/// Servicio para subir/descargar la base de datos SQLite desde Google Drive.
///
/// Usa OAuth 2.0 con el scope de appdata (aislado por app, el usuario no
/// ve estos archivos en su Drive normal).  No requiere client_secret en el
/// dispositivo: google_sign_in usa el OAuth nativo de Android/iOS.
class DriveBackupService {
  DriveBackupService._();
  static final DriveBackupService instance = DriveBackupService._();

  static const _backupFileName = 'lapena_backup.db';
  static const _folderName = 'La Peña Backups';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
    clientId: AppEnvironment.googleClientId.isEmpty
        ? null
        : AppEnvironment.googleClientId,
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  // ── Auth ─────────────────────────────────────────────────────────────────

  /// Inicia sesión interactiva con Google.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      return null;
    }
  }

  /// Intenta iniciar sesión silenciosamente (sesión previa).
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Cierra sesión.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<drive.DriveApi> _getDriveApi() async {
    const tokenError = 'Drive accessToken inválido. Reautenticación requerida.';

    Future<void> resetSession() async {
      try {
        await signOut();
      } catch (_) {}
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      _currentUser = null;
    }

    Future<GoogleSignInAccount?> acquireAccount({
      required bool interactive,
    }) async {
      var account = _currentUser;
      if (account == null) {
        account = await signInSilently();
        if (account != null) {
          debugPrint(
            'drive.auth [backup]: sesión activa por signInSilently '
            'cuenta=${account.email}',
          );
        }
      }

      if (account == null && interactive) {
        debugPrint(
          'drive.auth [backup]: sin sesión silenciosa, '
          'forzando signIn interactivo.',
        );
        account = await signIn();
        if (account != null) {
          debugPrint(
            'drive.auth [backup]: sesión activa por signIn '
            'cuenta=${account.email}',
          );
        }
      }

      return account;
    }

    Future<String> resolveAccessToken(GoogleSignInAccount account) async {
      final auth = await account.authentication;
      final token = auth.accessToken;

      if (token == null || token.isEmpty) {
        debugPrint(
          'drive.auth [backup]: accessToken null para ${account.email}',
        );
        await resetSession();

        final relogin = await acquireAccount(interactive: true);
        if (relogin == null) {
          throw StateError(tokenError);
        }

        _currentUser = relogin;
        final retryAuth = await relogin.authentication;
        final retryToken = retryAuth.accessToken;
        if (retryToken == null || retryToken.isEmpty) {
          debugPrint(
            'drive.auth [backup]: accessToken null tras reautenticación '
            'cuenta=${relogin.email}',
          );
          await resetSession();
          throw StateError(tokenError);
        }
        final retryPreview = retryToken.substring(
          0,
          retryToken.length.clamp(0, 8),
        );
        debugPrint(
          'drive.auth [backup]: accessToken reautenticado '
          '($retryPreview...) cuenta=${relogin.email}',
        );
        return retryToken;
      }

      final tokenPreview = token.substring(0, token.length.clamp(0, 8));
      debugPrint(
        'drive.auth [backup]: accessToken obtenido '
        '($tokenPreview...) cuenta=${account.email}',
      );
      return token;
    }

    final account = await acquireAccount(interactive: true);
    if (account == null) {
      throw StateError(
        'No hay sesión de Google activa. '
        'El usuario debe iniciar sesión para usar Drive.',
      );
    }

    _currentUser = account;
    debugPrint(
      'drive.auth [backup]: sesión Google activa cuenta=${account.email}',
    );

    var token = await resolveAccessToken(account);
    var api = drive.DriveApi(_AuthClient({'Authorization': 'Bearer $token'}));

    try {
      await api.files.list(pageSize: 1);
    } catch (e, st) {
      debugPrint(
        'drive.auth [backup]: validación runtime Drive falló: $e\n$st',
      );
      await resetSession();

      final relogin = await acquireAccount(interactive: true);
      if (relogin == null) {
        throw StateError('Autenticado pero sin acceso a Drive API.');
      }

      _currentUser = relogin;
      token = await resolveAccessToken(relogin);
      api = drive.DriveApi(_AuthClient({'Authorization': 'Bearer $token'}));
      await api.files.list(pageSize: 1);
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
