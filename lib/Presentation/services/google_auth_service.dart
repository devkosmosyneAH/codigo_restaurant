import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:restaurant_app/Presentation/core/config/app_environment.dart';

enum GoogleAuthState {
  notAuthenticated,
  restoring,
  authenticating,
  authenticated,
  error,
}

/// Única fuente de verdad para la identidad de Google, permisos de Drive y
/// access token. Google Sign-In es quien persiste la sesión; este servicio solo
/// refleja el estado que Google devuelve.
class GoogleAuthService extends ChangeNotifier {
  GoogleAuthService._({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? _createDefaultGoogleSignIn() {
    _googleSignIn.onCurrentUserChanged.listen(_synchronizeAccount);
  }

  static GoogleAuthService? _instance;
  static GoogleAuthService get instance => _instance ??= GoogleAuthService._();

  @visibleForTesting
  static void setInstance(GoogleAuthService instance) => _instance = instance;
  @visibleForTesting
  static void reset() => _instance = null;

  /// El único catálogo de scopes OAuth de Drive de la aplicación.
  static const Set<String> driveScopes = <String>{
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.appdata',
  };

  // GIS does not expose `expires_at` through google_sign_in 6.x. A token is
  // valid for at most one hour, so retain a small margin before requiring a
  // new user-initiated authorization round on web.
  static const Duration _webAccessTokenLifetime = Duration(minutes: 55);

  final GoogleSignIn _googleSignIn;
  GoogleSignInAccount? _currentUser;
  GoogleAuthState _state = GoogleAuthState.notAuthenticated;
  final Set<String> _grantedScopes = <String>{};
  String? _accessToken;
  DateTime? _accessTokenValidUntil;
  Future<void>? _initializeFuture;
  Future<GoogleSignInAccount?>? _restoreFuture;
  Future<GoogleSignInAccount?>? _signInFuture;
  Future<String?>? _tokenFuture;
  Future<bool>? _authorizationFuture;

  GoogleSignInAccount? get currentUser => _currentUser;
  String? get currentEmail => _currentUser?.email;
  bool get isAuthenticated => _currentUser != null;
  bool get isSignedIn => isAuthenticated;
  GoogleAuthState get state => _state;
  String? get accessToken => _accessToken;
  DateTime? get accessTokenExpiresAt => _accessTokenValidUntil;
  Set<String> get grantedScopes => Set.unmodifiable(_grantedScopes);
  bool get hasDriveAuthorization => driveScopes.every(_grantedScopes.contains);

  /// google_sign_in 6.x se inicializa al crear su única instancia. Este punto
  /// explícito serializa el arranque y deja preparado el contrato para la UI.
  Future<void> initialize() {
    return _initializeFuture ??= Future<void>.value();
  }

  /// Solo debe invocarse desde main durante el arranque. Nunca abre UI.
  Future<GoogleSignInAccount?> restoreSession() async {
    await initialize();
    if (_restoreFuture != null) return _restoreFuture!;
    if (isAuthenticated) return _currentUser;

    _state = GoogleAuthState.restoring;
    _notify();
    _restoreFuture = _googleSignIn.signInSilently();
    try {
      final account = await _restoreFuture;
      _synchronizeAccount(account);
      if (account == null) _setState(GoogleAuthState.notAuthenticated);
      return account;
    } catch (error) {
      debugPrint('google_auth.restoreSession: $error');
      _clearSession(GoogleAuthState.notAuthenticated);
      return null;
    } finally {
      _restoreFuture = null;
    }
  }

  /// Inicio interactivo; debe ejecutarse únicamente como respuesta del usuario.
  Future<GoogleSignInAccount?> signIn() async {
    await initialize();
    if (_signInFuture != null) return _signInFuture!;
    if (isAuthenticated) return _currentUser;

    _setState(GoogleAuthState.authenticating);
    _signInFuture = _googleSignIn.signIn();
    try {
      final account = await _signInFuture;
      _synchronizeAccount(account);
      if (account == null) _setState(GoogleAuthState.notAuthenticated);
      return account;
    } catch (error) {
      _setState(GoogleAuthState.error);
      rethrow;
    } finally {
      _signInFuture = null;
    }
  }

  /// Autoriza el catálogo central de Drive. En Web puede abrir el diálogo de
  /// consentimiento, por eso [interactive] debe ser true solo desde un gesto.
  Future<bool> ensureDriveAuthorized({required bool interactive}) async {
    if (!isAuthenticated) return false;
    if (_authorizationFuture != null) return _authorizationFuture!;
    _authorizationFuture = _performDriveAuthorization(interactive);
    try {
      return await _authorizationFuture!;
    } finally {
      _authorizationFuture = null;
    }
  }

  Future<bool> _performDriveAuthorization(bool interactive) async {
    if (kIsWeb) {
      final authorized = await _googleSignIn.canAccessScopes(
        driveScopes.toList(),
      );
      if (authorized) {
        _grantedScopes.addAll(driveScopes);
        _notify();
        return true;
      }
      if (!interactive) return false;
      final granted = await _googleSignIn.requestScopes(driveScopes.toList());
      if (granted) {
        _grantedScopes.addAll(driveScopes);
        _invalidateAccessToken();
        _notify();
      }
      return granted;
    }

    // En Android, iOS y macOS los scopes del constructor se conceden junto con
    // la sesión. canAccessScopes no está implementado en google_sign_in 6.x.
    _grantedScopes.addAll(driveScopes);
    _notify();
    return true;
  }

  /// Único administrador del access token. Nunca deriva su vencimiento del ID
  /// token. En nativo la renovación es responsabilidad del SDK; en Web GIS no
  /// hay refresh token y, al caducar, solo una acción del usuario puede volver
  /// a autorizar los scopes.
  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    if (!isAuthenticated || !hasDriveAuthorization) return null;
    if (kIsWeb) {
      if (!forceRefresh && _hasUsableCachedToken) return _accessToken;
      if (_accessToken != null && !_hasUsableCachedToken) return null;
    }
    if (_tokenFuture != null) return _tokenFuture!;

    _tokenFuture = _requestAccessToken();
    try {
      return await _tokenFuture!;
    } finally {
      _tokenFuture = null;
    }
  }

  bool get _hasUsableCachedToken =>
      _accessToken != null &&
      _accessTokenValidUntil != null &&
      DateTime.now().isBefore(_accessTokenValidUntil!);

  Future<String?> _requestAccessToken() async {
    try {
      final token = (await _currentUser!.authentication).accessToken;
      if (token == null || token.isEmpty) return null;
      _accessToken = token;
      // GIS documenta una vida de una hora y no expone `expires_at` en v6.
      // En nativo no se mantiene un TTL inventado: pedir authentication al
      // SDK permite que su almacenamiento/renovación sea la autoridad.
      _accessTokenValidUntil =
          kIsWeb ? DateTime.now().add(_webAccessTokenLifetime) : null;
      _notify();
      return token;
    } catch (error) {
      debugPrint('google_auth.getAccessToken: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } finally {
      _clearSession(GoogleAuthState.notAuthenticated);
    }
  }

  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } finally {
      _clearSession(GoogleAuthState.notAuthenticated);
    }
  }

  void _synchronizeAccount(GoogleSignInAccount? account) {
    final changed = _currentUser?.id != account?.id;
    _currentUser = account;
    if (account == null) {
      _clearSession(GoogleAuthState.notAuthenticated);
      return;
    }
    if (!kIsWeb) _grantedScopes.addAll(driveScopes);
    _setState(GoogleAuthState.authenticated, notify: changed);
  }

  void _invalidateAccessToken() {
    _accessToken = null;
    _accessTokenValidUntil = null;
  }

  void _clearSession(GoogleAuthState state) {
    _currentUser = null;
    _grantedScopes.clear();
    _invalidateAccessToken();
    _setState(state);
  }

  void _setState(GoogleAuthState state, {bool notify = true}) {
    _state = state;
    if (notify) _notify();
  }

  void _notify() {
    if (!hasListeners) return;
    notifyListeners();
  }

  static GoogleSignIn _createDefaultGoogleSignIn() => GoogleSignIn(
        scopes: driveScopes.toList(),
        clientId: AppEnvironment.googleClientId.isEmpty
            ? null
            : AppEnvironment.googleClientId,
        serverClientId: kIsWeb || AppEnvironment.googleClientId.isEmpty
            ? null
            : AppEnvironment.googleClientId,
      );

  @visibleForTesting
  GoogleSignIn get googleSignInForTesting => _googleSignIn;
}
