import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:restaurant_app/core/config/app_environment.dart';

/// Estado de autenticación con Google.
enum GoogleAuthState { notAuthenticated, authenticating, authenticated, error }

/// Servicio ÚNICO y centralizado para autenticación con Google.
///
/// RESPONSABILIDADES:
/// - Una sola instancia de GoogleSignIn
/// - Manejo thread-safe de login/logout/restore
/// - Protección contra múltiples logins simultáneos
/// - Gestión de scopes y configuración
/// - Válido para Android, iOS, Web, Windows, macOS, Linux
///
/// TODO LO DEMÁS (Firebase, Drive, etc) DEPENDE DE ESTE SERVICIO.
class GoogleAuthService {
  GoogleAuthService._({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? _createDefaultGoogleSignIn();

  static GoogleAuthService? _instance;

  // ── Inicialización ───────────────────────────────────────────────────────

  /// Obtiene la instancia única de GoogleAuthService.
  static GoogleAuthService get instance {
    _instance ??= GoogleAuthService._();
    return _instance!;
  }

  /// Para pruebas: permite inyectar una instancia custom.
  @visibleForTesting
  static void setInstance(GoogleAuthService instance) {
    _instance = instance;
  }

  /// Para pruebas: resetea la instancia.
  @visibleForTesting
  static void reset() {
    _instance = null;
  }

  // ── Implementación ───────────────────────────────────────────────────────

  final GoogleSignIn _googleSignIn;
  GoogleSignInAccount? _currentUser;
  GoogleAuthState _state = GoogleAuthState.notAuthenticated;

  /// Future compartida para evitar múltiples logins concurrentes.
  Future<GoogleSignInAccount?>? _loginFuture;

  /// Future compartida para evitar múltiples restorations concurrentes.
  Future<GoogleSignInAccount?>? _restoreFuture;

  /// Marca si la restauración de sesión silenciosa ya se intentó una vez.
  bool _hasRestoredSession = false;

  String? _cachedAccessToken;
  DateTime? _cachedAccessTokenExpiry;
  Future<String?>? _accessTokenFuture;

  // ── Getters ──────────────────────────────────────────────────────────────

  /// Usuario actualmente autenticado, o null.
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Email del usuario autenticado.
  String? get currentEmail => _currentUser?.email;

  /// ¿Hay un usuario autenticado?
  bool get isSignedIn => _currentUser != null;

  /// Estado actual de autenticación.
  GoogleAuthState get state => _state;

  // ── Autenticación Interactiva ────────────────────────────────────────────

  /// Inicia sesión interactivamente con Google.
  ///
  /// Reutiliza la Future si un login ya está en progreso.
  /// Thread-safe.
  Future<GoogleSignInAccount?> signIn() async {
    if (_loginFuture != null) {
      debugPrint('google_auth.signIn: Reutilizando Future en progreso');
      return _loginFuture;
    }

    _state = GoogleAuthState.authenticating;
    _loginFuture = _performSignIn();

    try {
      final account = await _loginFuture;
      if (account != null) {
        _currentUser = account;
        _state = GoogleAuthState.authenticated;
        debugPrint('google_auth.signIn: Exitoso para ${account.email}');
      } else {
        _state = GoogleAuthState.notAuthenticated;
        debugPrint('google_auth.signIn: Usuario canceló o falló');
      }
      return account;
    } catch (e) {
      _state = GoogleAuthState.error;
      debugPrint('google_auth.signIn: Error $e');
      rethrow;
    } finally {
      _loginFuture = null;
    }
  }

  /// Implementación interna de signIn.
  Future<GoogleSignInAccount?> _performSignIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('google_auth._performSignIn: Error interno $e');
      rethrow;
    }
  }

  // ── Autenticación Silenciosa ─────────────────────────────────────────────

  /// Restaura sesión silenciosamente si existe.
  ///
  /// Intenta usar la sesión guardada sin mostrar UI.
  /// Reutiliza la Future si una restauración ya está en progreso.
  /// Thread-safe.
  Future<GoogleSignInAccount?> signInSilently() async {
    if (isSignedIn) {
      debugPrint('google_auth.signInSilently: Ya hay usuario autenticado');
      return _currentUser;
    }

    if (_hasRestoredSession) {
      debugPrint(
        'google_auth.signInSilently: Restauración ya intentada anteriormente, no se reintentará.',
      );
      return null;
    }

    if (_restoreFuture != null) {
      debugPrint('google_auth.signInSilently: Reutilizando Future en progreso');
      return _restoreFuture;
    }

    _restoreFuture = _performSignInSilently();

    try {
      final account = await _restoreFuture;
      if (account != null) {
        _currentUser = account;
        _state = GoogleAuthState.authenticated;
        _hasRestoredSession = true;
        debugPrint(
          'google_auth.signInSilently: Sesión restaurada para ${account.email}',
        );
      } else {
        _hasRestoredSession = true;
      }
      return account;
    } catch (e) {
      debugPrint('google_auth.signInSilently: Error $e');
      _hasRestoredSession = true;
      return null;
    } finally {
      _restoreFuture = null;
    }
  }

  /// Restaura la sesión una sola vez durante la vida de la aplicación.
  ///
  /// Esta llamada es la única que debe ejecutarse desde el arranque del app.
  Future<GoogleSignInAccount?> restoreSession() async {
    if (_hasRestoredSession) {
      debugPrint('google_auth.restoreSession: restauración ya ejecutada');
      return _currentUser;
    }

    return await signInSilently();
  }

  /// Implementación interna de signInSilently.
  Future<GoogleSignInAccount?> _performSignInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('google_auth._performSignInSilently: Error interno $e');
      return null;
    }
  }

  // ── Cierre de Sesión ─────────────────────────────────────────────────────

  /// Cierra la sesión actual.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint(
        'google_auth.signOut: Error al cerrar sesión de GoogleSignIn $e',
      );
    } finally {
      _currentUser = null;
      _state = GoogleAuthState.notAuthenticated;
      _cachedAccessToken = null;
      _cachedAccessTokenExpiry = null;
      _accessTokenFuture = null;
      _hasRestoredSession = false;
      debugPrint('google_auth.signOut: Sesión cerrada');
    }
  }

  /// Desconecta completamente de Google (elimina permisos).
  ///
  /// Más invasivo que signOut(). Úsalo solo cuando sea necesario.
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint('google_auth.disconnect: Error $e');
      rethrow;
    } finally {
      _currentUser = null;
      _state = GoogleAuthState.notAuthenticated;
      _cachedAccessToken = null;
      _cachedAccessTokenExpiry = null;
      _accessTokenFuture = null;
      _hasRestoredSession = false;
      debugPrint('google_auth.disconnect: Desconectado de Google');
    }
  }

  // ── Tokens ───────────────────────────────────────────────────────────────

  /// Obtiene el Access Token del usuario actual.
  ///
  /// Solo funciona si [isSignedIn] es true.
  /// Puede solicitar autorización adicional si es necesario.
  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    final user = _currentUser;
    if (user == null) {
      debugPrint('google_auth.getAccessToken: No hay usuario autenticado');
      return null;
    }

    if (!forceRefresh && _cachedAccessToken != null) {
      final expiry = _cachedAccessTokenExpiry;
      if (expiry != null && DateTime.now().isBefore(expiry)) {
        debugPrint(
          'google_auth.getAccessToken: Reutilizando token cacheado para ${user.email}',
        );
        return _cachedAccessToken;
      }
    }

    if (_accessTokenFuture != null) {
      debugPrint('google_auth.getAccessToken: Reutilizando Future de token');
      return _accessTokenFuture;
    }

    _accessTokenFuture = _requestAccessToken();
    try {
      final token = await _accessTokenFuture;
      return token;
    } finally {
      _accessTokenFuture = null;
    }
  }

  Future<String?> _requestAccessToken() async {
    try {
      final auth = await _currentUser!.authentication;
      final token = auth.accessToken;
      _cachedAccessToken = token;
      _cachedAccessTokenExpiry = _decodeJwtExpiry(auth.idToken);
      if (token == null) {
        debugPrint(
          'google_auth.getAccessToken: Token null para ${_currentUser?.email}',
        );
      } else {
        debugPrint(
          'google_auth.getAccessToken: Token obtenido para ${_currentUser?.email}',
        );
      }
      return token;
    } catch (e) {
      debugPrint('google_auth._requestAccessToken: Error $e');
      return null;
    }
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _currentUser;
    if (user == null) {
      debugPrint('google_auth.getIdToken: No hay usuario autenticado');
      return null;
    }
    try {
      final auth = await user.authentication;
      return auth.idToken;
    } catch (e) {
      debugPrint('google_auth.getIdToken: Error $e');
      return null;
    }
  }

  /// Obtiene los headers Authorization para requests a Google APIs.
  ///
  /// Retorna `{'Authorization': 'Bearer <token>'}` o null si no hay token.
  Future<Map<String, String>?> getAuthorizationHeaders() async {
    final token = await getAccessToken();
    if (token == null) return null;
    return {'Authorization': 'Bearer $token'};
  }

  // ── Helpers Privados ─────────────────────────────────────────────────────

  static GoogleSignIn _createDefaultGoogleSignIn() {
    return GoogleSignIn(
      scopes: [
        // Drive scope (requirido para backup y menú)
        'https://www.googleapis.com/auth/drive',
      ],
      clientId: AppEnvironment.googleClientId.isEmpty
          ? null
          : AppEnvironment.googleClientId,
      serverClientId: kIsWeb
          ? null
          : AppEnvironment.googleClientId.isEmpty
          ? null
          : AppEnvironment.googleClientId,
    );
  }

  // ── Limpieza ─────────────────────────────────────────────────────────────

  /// Para pruebas: permite acceder a la instancia interna de GoogleSignIn.
  @visibleForTesting
  GoogleSignIn get googleSignInForTesting => _googleSignIn;

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
      if (expRaw is num) {
        return DateTime.fromMillisecondsSinceEpoch(expRaw.toInt() * 1000);
      }
      if (expRaw is String) {
        final expSeconds = int.tryParse(expRaw);
        if (expSeconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
