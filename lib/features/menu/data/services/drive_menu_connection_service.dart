import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:restaurant_app/core/config/app_environment.dart';
import 'package:restaurant_app/features/menu/data/datasources/drive_connection_local_datasource.dart';
import 'package:restaurant_app/features/menu/data/models/drive_connection_model.dart';
import 'package:restaurant_app/features/menu/domain/entities/drive_connection.dart';

/// Resultado de subida de imagen a Drive.
class DriveUploadResult {
  final String fileId;

  /// URL pública directa que cualquier `<img>` puede consumir sin OAuth.
  final String publicUrl;

  /// Ruta local en disco con la copia cacheada (offline-first).
  final String? localCachePath;

  const DriveUploadResult({
    required this.fileId,
    required this.publicUrl,
    this.localCachePath,
  });
}

/// Servicio de conexión Drive específico para imágenes del menú.
///
/// A diferencia de `DriveBackupService` (que respalda la BD), este servicio:
/// 1. Crea/recupera una subcarpeta por tenant dentro de la carpeta raíz
///    configurada en [AppEnvironment.driveRootFolderId].
/// 2. Comparte esa subcarpeta como pública (anyone with link, reader) para
///    que las imágenes sean accesibles sin OAuth desde la página pública/QR.
/// 3. Sube imágenes asociadas a productos y retorna URL pública persistible.
/// 4. Mantiene caché local para fallback offline.
///
/// Seguridad:
/// - No persiste tokens OAuth: `google_sign_in` los administra en el
///   almacén nativo seguro del OS.
/// - No expone credenciales: la página pública solo usa URLs `drive.google.com`
///   ya autorizadas como públicas.
class DriveMenuConnectionService {
  final DriveConnectionLocalDatasource _datasource;
  final GoogleSignIn _googleSignIn;
  final Uuid _uuid;

  DriveMenuConnectionService({
    required DriveConnectionLocalDatasource datasource,
    GoogleSignIn? googleSignIn,
    Uuid? uuid,
  }) : _datasource = datasource,
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(scopes: const [drive.DriveApi.driveFileScope]),
       _uuid = uuid ?? const Uuid();

  GoogleSignInAccount? _currentUser;

  bool get isSignedIn => _currentUser != null;
  String? get currentEmail => _currentUser?.email;

  // ── Auth ────────────────────────────────────────────────────────────────

  Future<bool> signIn() async {
    try {
      _currentUser =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> restoreSessionSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  // ── Conexión por tenant ─────────────────────────────────────────────────

  /// Garantiza la existencia de la conexión Drive del tenant.
  ///
  /// Si ya existe en SQLite, la retorna. Si no, genera UUID nuevo, crea la
  /// subcarpeta dentro de [AppEnvironment.driveRootFolderId], la comparte
  /// como pública y la persiste.
  ///
  /// Requiere sesión Google activa. Lanza si Drive no está configurado.
  Future<DriveConnection> ensureConnectionForTenant({
    required String restaurantId,
    required String userId,
  }) async {
    if (!AppEnvironment.isDriveConfigured) {
      throw StateError(
        'La carpeta raíz de Drive no está configurada '
        '(DRIVE_ROOT_FOLDER_ID / GOOGLE_DRIVE_FOLDER_ID / '
        'REACT_APP_GOOGLE_DRIVE_FOLDER_ID / VITE_GOOGLE_DRIVE_FOLDER_ID / '
        'NEXT_PUBLIC_GOOGLE_DRIVE_FOLDER_ID).',
      );
    }

    final existing = await _datasource.getByRestaurantId(restaurantId);
    if (existing != null) return existing;

    final api = await _getDriveApi();
    final newId = _uuid.v4();
    final folderName = 'tenant-$restaurantId-${newId.substring(0, 8)}';

    // 1. Crear subcarpeta dentro de la carpeta raíz.
    final folderMeta = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [AppEnvironment.driveRootFolderId];
    final created = await api.files.create(folderMeta, $fields: 'id');
    final folderId = created.id;
    if (folderId == null) {
      throw StateError('Drive no retornó el id de la carpeta creada.');
    }

    // 2. Compartir pública.
    await _enablePublicShare(api, folderId);

    final now = DateTime.now();
    final connection = DriveConnectionModel(
      id: newId,
      restaurantId: restaurantId,
      folderId: folderId,
      folderName: folderName,
      ownerEmail: _currentUser?.email ?? '',
      publicShareEnabled: true,
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
    );
    await _datasource.upsert(connection);
    return connection;
  }

  /// Revoca el permiso público de la carpeta del tenant.
  Future<void> revokePublicAccess(String restaurantId) async {
    final connection = await _datasource.getByRestaurantId(restaurantId);
    if (connection == null) return;

    final api = await _getDriveApi();
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

  // ── Imágenes de producto ────────────────────────────────────────────────

  /// Sube una imagen al folder del tenant y devuelve `fileId` + URL pública.
  ///
  /// Si la conexión del tenant aún no existe, la crea. Mantiene una copia
  /// local en caché para offline.
  Future<DriveUploadResult> uploadProductImage({
    required String restaurantId,
    required String userId,
    required String productoId,
    required List<int> bytes,
    required String mimeType,
    required String fileExtension,
  }) async {
    final connection = await ensureConnectionForTenant(
      restaurantId: restaurantId,
      userId: userId,
    );

    final api = await _getDriveApi();
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
      throw StateError('Drive no retornó el id del archivo subido.');
    }

    final publicUrl = buildPublicUrl(fileId);
    final cachePath = await _writeLocalCache(
      restaurantId: restaurantId,
      fileName: fileName,
      bytes: bytes,
    );

    return DriveUploadResult(
      fileId: fileId,
      publicUrl: publicUrl,
      localCachePath: cachePath,
    );
  }

  /// Elimina un archivo del Drive por su id. Tolerante a errores
  /// (por ejemplo, si ya fue borrado manualmente desde Drive Web).
  Future<bool> tryDeleteProductImage(String fileId) async {
    try {
      final api = await _getDriveApi();
      await api.files.delete(fileId);
      return true;
    } catch (_) {
      // Retorna false para que el caller pueda encolar reintentos.
      return false;
    }
  }

  Future<void> deleteProductImage(String fileId) async {
    await tryDeleteProductImage(fileId);
  }

  /// Construye una URL pública directa servida por la CDN de Google.
  /// No cuenta contra la cuota OAuth y es accesible sin login.
  static String buildPublicUrl(String fileId) {
    return 'https://drive.google.com/uc?export=view&id=$fileId';
  }

  // ── Internals ───────────────────────────────────────────────────────────

  Future<drive.DriveApi> _getDriveApi() async {
    final account = _currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) {
      throw StateError(
        'No hay sesión Google activa. El admin debe iniciar sesión antes.',
      );
    }
    _currentUser = account;
    final authHeaders = await account.authHeaders;
    return drive.DriveApi(_AuthClient(authHeaders));
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
