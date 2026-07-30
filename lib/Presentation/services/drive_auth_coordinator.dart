import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:restaurant_app/Presentation/services/google_auth_service.dart';

/// Estado derivado de [GoogleAuthService]. No mantiene una sesión paralela.
enum DriveAuthState {
  unauthenticated,
  restoring,
  authenticated,
  expired,
  authorizing,
  failed,
}

class DriveAuthResult {
  const DriveAuthResult._({
    required this.status,
    this.email,
    this.message,
    this.isPopupBlocked = false,
  });
  final DriveAuthStatus status;
  final String? email;
  final String? message;
  final bool isPopupBlocked;

  factory DriveAuthResult.connected({required String email}) =>
      DriveAuthResult._(status: DriveAuthStatus.connected, email: email);
  factory DriveAuthResult.notConnected({String? message}) =>
      DriveAuthResult._(status: DriveAuthStatus.notConnected, message: message);
  factory DriveAuthResult.error({
    required String message,
    bool isPopupBlocked = false,
  }) =>
      DriveAuthResult._(
        status: DriveAuthStatus.error,
        message: message,
        isPopupBlocked: isPopupBlocked,
      );
  bool get isConnected => status == DriveAuthStatus.connected;
}

enum DriveAuthStatus { connected, notConnected, error }

/// Adaptador de Drive. La identidad, scopes y token pertenecen exclusivamente
/// a [GoogleAuthService].
class DriveAuthCoordinator {
  DriveAuthCoordinator({GoogleAuthService? googleAuthService})
      : _googleAuthService = googleAuthService ?? GoogleAuthService.instance;

  static DriveAuthCoordinator? _instance;
  static DriveAuthCoordinator get instance =>
      _instance ??= DriveAuthCoordinator();
  @visibleForTesting
  static void setInstance(DriveAuthCoordinator instance) =>
      _instance = instance;
  @visibleForTesting
  static void reset() => _instance = null;

  final GoogleAuthService _googleAuthService;
  Future<DriveAuthResult>? _ensureFuture;

  bool get isSignedIn => _googleAuthService.isAuthenticated;
  String? get currentEmail => _googleAuthService.currentEmail;
  String? get lastError => null;
  DriveAuthState get state {
    switch (_googleAuthService.state) {
      case GoogleAuthState.restoring:
        return DriveAuthState.restoring;
      case GoogleAuthState.authenticating:
        return DriveAuthState.authorizing;
      case GoogleAuthState.authenticated:
        return _googleAuthService.hasDriveAuthorization
            ? DriveAuthState.authenticated
            : DriveAuthState.unauthenticated;
      case GoogleAuthState.error:
        return DriveAuthState.failed;
      case GoogleAuthState.notAuthenticated:
        return DriveAuthState.unauthenticated;
    }
  }

  bool get isDriveReady =>
      _googleAuthService.isAuthenticated &&
      _googleAuthService.hasDriveAuthorization;
  DateTime? get accessTokenExpiresAt => _googleAuthService.accessTokenExpiresAt;

  /// Acción interactiva de "Conectar Drive". Centraliza login y autorización.
  Future<GoogleSignInAccount?> signIn() async {
    final account = await _googleAuthService.signIn();
    if (account == null) return null;
    final authorized = await _googleAuthService.ensureDriveAuthorized(
      interactive: true,
    );
    return authorized ? account : null;
  }

  /// Conservado para compatibilidad de lectura: no restaura, no abre UI y no
  /// consulta Google. La restauración real ocurre una sola vez desde main.
  Future<GoogleSignInAccount?> currentAccount() async =>
      _googleAuthService.currentUser;

  Future<DriveAuthResult> ensureDriveAuthenticated({bool interactive = false}) {
    if (_ensureFuture != null) return _ensureFuture!;
    _ensureFuture = _ensure(
      interactive,
    ).whenComplete(() => _ensureFuture = null);
    return _ensureFuture!;
  }

  Future<DriveAuthResult> _ensure(bool interactive) async {
    if (!isSignedIn) {
      if (!interactive) {
        return DriveAuthResult.notConnected(
          message: 'No hay sesión de Google activa para Drive.',
        );
      }
      final account = await _googleAuthService.signIn();
      if (account == null) {
        return DriveAuthResult.notConnected(
          message: 'Conexión interactiva con Google cancelada.',
        );
      }
    }

    try {
      final authorized = await _googleAuthService.ensureDriveAuthorized(
        interactive: interactive,
      );
      if (!authorized) {
        return DriveAuthResult.notConnected(
          message: 'La cuenta no tiene permisos de Drive.',
        );
      }
      final token = await _googleAuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        return DriveAuthResult.notConnected(
          message: interactive
              ? 'No se pudo obtener un token de Drive. Intenta autorizar nuevamente.'
              : 'No hay token de Drive vigente.',
        );
      }
      return DriveAuthResult.connected(email: currentEmail!);
    } catch (error, stackTrace) {
      debugPrint('drive_auth_coordinator: $error\n$stackTrace');
      final text = error.toString();
      return DriveAuthResult.error(
        message: 'Error al autenticar con Google Drive: $error',
        isPopupBlocked: text.contains('popup') || text.contains('blocked'),
      );
    }
  }

  Future<drive.DriveApi> createDriveApi({bool interactive = false}) async {
    final result = await ensureDriveAuthenticated(interactive: interactive);
    if (!result.isConnected) {
      throw StateError(result.message ?? 'No se pudo autenticar Drive.');
    }
    final token = await _googleAuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Drive accessToken no disponible.');
    }
    return drive.DriveApi(_AuthClient({'Authorization': 'Bearer $token'}));
  }

  Future<String?> getAccessToken({bool forceRefresh = false}) =>
      _googleAuthService.getAccessToken(forceRefresh: forceRefresh);
  Future<bool> hasDriveScopes() async =>
      _googleAuthService.hasDriveAuthorization;
  Future<Map<String, String>?> getAuthorizationHeaders() async {
    final token = await getAccessToken();
    return token == null ? null : {'Authorization': 'Bearer $token'};
  }

  Future<void> signOut() => _googleAuthService.signOut();
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
  void close() => _inner.close();
}
