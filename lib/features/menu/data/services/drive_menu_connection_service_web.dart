import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:restaurant_app/core/config/app_environment.dart';
import 'package:restaurant_app/features/menu/data/datasources/drive_connection_local_datasource.dart';
import 'package:restaurant_app/features/menu/data/models/drive_connection_model.dart';
import 'package:restaurant_app/features/menu/domain/entities/drive_connection.dart';

/// Resultado de subida de imagen a Drive.
class DriveUploadResult {
  final String fileId;

  /// URL publica directa que cualquier `<img>` puede consumir sin OAuth.
  final String publicUrl;

  /// En web no existe ruta de cache local por filesystem.
  final String? localCachePath;

  const DriveUploadResult({
    required this.fileId,
    required this.publicUrl,
    this.localCachePath,
  });
}

/// Servicio de conexion Drive para Flutter Web (menu imagenes).
///
/// Reusa Google Sign-In Web para obtener headers OAuth y consumir Drive API.
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
           GoogleSignIn(
             scopes: const [drive.DriveApi.driveFileScope],
             clientId: AppEnvironment.googleClientId.isEmpty
                 ? null
                 : AppEnvironment.googleClientId,
           ),
       _uuid = uuid ?? const Uuid();

  GoogleSignInAccount? _currentUser;

  bool get isSignedIn => _currentUser != null;
  String? get currentEmail => _currentUser?.email;

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
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // No-op
    }
    _currentUser = null;
  }

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

    final api = await _getDriveApi();
    final newId = _uuid.v4();
    final folderName = 'tenant-$restaurantId-${newId.substring(0, 8)}';

    final folderMeta = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [AppEnvironment.driveRootFolderId];
    final created = await api.files.create(folderMeta, $fields: 'id');

    final folderId = created.id;
    if (folderId == null) {
      throw StateError('Drive no retorno el id de la carpeta creada.');
    }

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
      throw StateError('Drive no retorno el id del archivo subido.');
    }

    final publicUrl = buildPublicUrl(fileId);
    return DriveUploadResult(
      fileId: fileId,
      publicUrl: publicUrl,
      localCachePath: null,
    );
  }

  Future<bool> tryDeleteProductImage(String fileId) async {
    try {
      final api = await _getDriveApi();
      await api.files.delete(fileId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteProductImage(String fileId) async {
    await tryDeleteProductImage(fileId);
  }

  static String buildPublicUrl(String fileId) {
    return 'https://drive.google.com/uc?export=view&id=$fileId';
  }

  Future<drive.DriveApi> _getDriveApi() async {
    final account = _currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) {
      throw StateError(
        'No hay sesion Google activa. El admin debe iniciar sesion antes.',
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
