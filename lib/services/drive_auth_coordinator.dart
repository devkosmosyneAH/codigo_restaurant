import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:restaurant_app/services/google_auth_service.dart';

enum DriveAuthState {
  unauthenticated,
  restoring,
  authenticated,
  expired,
  authorizing,
  failed,
}

/// Resultado de autenticación y autorización de Drive.
class DriveAuthResult {
  final DriveAuthStatus status;
  final String? email;
  final String? message;
  final bool isPopupBlocked;

  const DriveAuthResult._({
    required this.status,
    this.email,
    this.message,
    this.isPopupBlocked = false,
  });

  factory DriveAuthResult.connected({required String email}) =>
      DriveAuthResult._(status: DriveAuthStatus.connected, email: email);

  factory DriveAuthResult.notConnected({String? message}) =>
      DriveAuthResult._(
        status: DriveAuthStatus.notConnected,
        message: message,
      );

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

class DriveAuthCoordinator {
  DriveAuthCoordinator({GoogleAuthService? googleAuthService})
      : _googleAuthService = googleAuthService ?? GoogleAuthService.instance;

  static DriveAuthCoordinator? _instance;

  static DriveAuthCoordinator get instance {
    _instance ??= DriveAuthCoordinator();
    return _instance!;
  }

  @visibleForTesting
  static void setInstance(DriveAuthCoordinator instance) {
    _instance = instance;
  }

  @visibleForTesting
  static void reset() {
    _instance = null;
  }

  final GoogleAuthService _googleAuthService;
  DriveAuthState _state = DriveAuthState.unauthenticated;
  String? _lastError;
  bool _validatedDriveApi = false;
  DateTime? _lastDriveValidationAt;
  DateTime? _lastSilentRestoreAt;
  Future<DriveAuthResult>? _ensureFuture;

  static const Duration _driveValidationCache = Duration(minutes: 10);
  static const Duration _silentRestoreBackoff = Duration(minutes: 10);
  static const List<String> _defaultDriveScopes = [drive.DriveApi.driveFileScope];

  bool get isSignedIn => _googleAuthService.isSignedIn;
  String? get currentEmail => _googleAuthService.currentEmail;
  DriveAuthState get state => _state;
  String? get lastError => _lastError;
  bool get isDriveReady {
    if (_state != DriveAuthState.authenticated) return false;
    if (!_validatedDriveApi) return false;
    final expiry = _lastDriveValidationAt;
    return expiry != null && DateTime.now().difference(expiry) < _driveValidationCache;
  }

  Future<GoogleSignInAccount?> signIn() async {
    _setState(DriveAuthState.authorizing);
    final account = await _googleAuthService.signIn();
    if (account != null) {
      _resetValidation();
      _setState(DriveAuthState.unauthenticated);
    } else {
      _setState(DriveAuthState.unauthenticated,
          'Inicio de sesión de Google cancelado o fallido.');
    }
    return account;
  }

  Future<GoogleSignInAccount?> restoreSessionSilently() async {
    if (isSignedIn) return _googleAuthService.currentUser;

    final now = DateTime.now();
    if (_lastSilentRestoreAt != null &&
        now.difference(_lastSilentRestoreAt!) < _silentRestoreBackoff) {
      return null;
    }
    _lastSilentRestoreAt = now;

    _setState(DriveAuthState.restoring);
    final account = await _googleAuthService.restoreSession();
    if (account != null) {
      _resetValidation();
      _setState(DriveAuthState.unauthenticated);
    } else {
      _setState(DriveAuthState.unauthenticated);
    }
    return account;
  }

  Future<DriveAuthResult> ensureDriveAuthenticated({
    bool interactive = false,
    List<String>? requiredScopes,
  }) {
    if (_ensureFuture != null) {
      return _ensureFuture!;
    }
    _ensureFuture = _performDriveAuthentication(
      interactive,
      requiredScopes: requiredScopes,
    ).whenComplete(() => _ensureFuture = null);
    return _ensureFuture!;
  }

  List<String> _resolveScopes(List<String>? requiredScopes) {
    if (requiredScopes == null || requiredScopes.isEmpty) {
      return _defaultDriveScopes;
    }
    return requiredScopes.toList(growable: false);
  }

  Future<DriveAuthResult> _performDriveAuthentication(
    bool interactive, {
    List<String>? requiredScopes,
  }) async {
    final scopes = _resolveScopes(requiredScopes);
    if (isDriveReady && await _googleAuthService.canAccessScopes(scopes)) {
      return DriveAuthResult.connected(email: currentEmail!);
    }

    _setState(DriveAuthState.restoring);
    try {
      if (!isSignedIn) {
        final restored = await _googleAuthService.restoreSession();
        if (restored == null) {
          if (!interactive) {
            _setState(
              DriveAuthState.unauthenticated,
              'No hay sesión de Google activa para Drive.',
            );
            return DriveAuthResult.notConnected(
              message: 'No hay sesión de Google activa para Drive.',
            );
          }
          final signed = await _googleAuthService.signIn();
          if (signed == null) {
            _setState(
              DriveAuthState.unauthenticated,
              'Conexión interactiva con Google cancelada.',
            );
            return DriveAuthResult.notConnected(
              message: 'Conexión interactiva con Google cancelada.',
            );
          }
        }
      }

      final hasScopes = await _googleAuthService.canAccessScopes(scopes);
      if (!hasScopes) {
        if (!interactive) {
          _setState(
            DriveAuthState.unauthenticated,
            'La cuenta no tiene permisos de Drive.',
          );
          return DriveAuthResult.notConnected(
            message: 'La cuenta no tiene permisos de Drive.',
          );
        }

        _setState(DriveAuthState.authorizing);
        final granted = await _googleAuthService.requestScopes(scopes);
        if (!granted) {
          _setState(
            DriveAuthState.failed,
            'Permiso de acceso a Drive no concedido.',
          );
          return DriveAuthResult.notConnected(
            message: 'Permiso de acceso a Drive no concedido.',
          );
        }
      }

      final token = await _googleAuthService.getAccessToken(
        forceRefresh: true,
        requiredScopes: scopes,
      );
      if (token == null || token.isEmpty) {
        _setState(
          DriveAuthState.failed,
          'No se pudo obtener token de acceso para Drive.',
        );
        return DriveAuthResult.error(
          message: 'No se pudo obtener token de acceso para Drive.',
        );
      }

      final valid = await _validateDriveApi(token);
      if (!valid) {
        _setState(
          DriveAuthState.failed,
          'Autenticado pero sin acceso válido a Drive API.',
        );
        return DriveAuthResult.error(
          message: 'Autenticado pero sin acceso válido a Drive API.',
        );
      }

      _setState(DriveAuthState.authenticated);
      _validatedDriveApi = true;
      _lastDriveValidationAt = DateTime.now();
      return DriveAuthResult.connected(email: currentEmail!);
    } catch (e, st) {
      debugPrint('drive_auth_coordinator: error en autenticación Drive $e\n$st');
      _setState(DriveAuthState.failed, e.toString());
      final errorText = e.toString();
      final isPopupBlocked = errorText.contains('popup') ||
          errorText.contains('blocked') ||
          errorText.contains('Blocked');

      // Detectar problemas comunes en web relacionados con GSI / FedCM.
      final isFedCmDisabled = errorText.contains('FedCM') ||
          errorText.contains('Error retrieving a token') ||
          errorText.contains('NetworkError');

      if (isFedCmDisabled) {
        return DriveAuthResult.error(
          message:
              'No se pudo completar la autenticación web. Parece que el inicio de sesión federado (FedCM / Google Identity) está deshabilitado por el navegador. Pide al usuario habilitar el inicio de sesión en el icono a la izquierda de la barra de URL o en la configuración del sitio, o usar el botón "Conectar Drive" para reintentar.',
          isPopupBlocked: isPopupBlocked,
        );
      }

      return DriveAuthResult.error(
        message: 'Error al autenticar con Google Drive: $e',
        isPopupBlocked: isPopupBlocked,
      );
    }
  }

  Future<bool> _validateDriveApi(String accessToken) async {
    final client = _AuthClient({'Authorization': 'Bearer $accessToken'});
    try {
      final api = drive.DriveApi(client);
      await api.files.list(pageSize: 1);
      return true;
    } catch (e) {
      debugPrint('drive_auth_coordinator: validación Drive API falló: $e');
      return false;
    } finally {
      client.close();
    }
  }

  Future<drive.DriveApi> createDriveApi({
    bool interactive = false,
    List<String>? requiredScopes,
  }) async {
    final scopes = _resolveScopes(requiredScopes);
    final result = await ensureDriveAuthenticated(
      interactive: interactive,
      requiredScopes: scopes,
    );
    if (!result.isConnected) {
      throw StateError(result.message ?? 'No se pudo autenticar Drive.');
    }

    final token = await getAccessToken(
      forceRefresh: true,
      requiredScopes: scopes,
    );
    if (token == null || token.isEmpty) {
      throw StateError('Drive accessToken inválido. Reautenticación requerida.');
    }

    final client = _AuthClient({'Authorization': 'Bearer $token'});
    try {
      final api = drive.DriveApi(client);
      await api.files.list(pageSize: 1);
      return api;
    } catch (e) {
      client.close();
      rethrow;
    }
  }

  Future<String?> getAccessToken({
    bool forceRefresh = false,
    List<String>? requiredScopes,
  }) async {
    return _googleAuthService.getAccessToken(
      forceRefresh: forceRefresh,
      requiredScopes: requiredScopes ?? _defaultDriveScopes,
    );
  }

  Future<bool> hasDriveScopes() async {
    return _googleAuthService.canAccessScopes(_defaultDriveScopes);
  }

  Future<Map<String, String>?> getAuthorizationHeaders() async {
    final token = await getAccessToken(forceRefresh: false);
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _googleAuthService.getIdToken(forceRefresh: forceRefresh);
  }

  Future<void> signOut() async {
    await _googleAuthService.signOut();
    _resetValidation();
    _setState(DriveAuthState.unauthenticated);
  }

  void _setState(DriveAuthState state, [String? error]) {
    _state = state;
    _lastError = error;
  }

  void _resetValidation() {
    _validatedDriveApi = false;
    _lastDriveValidationAt = null;
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
}
