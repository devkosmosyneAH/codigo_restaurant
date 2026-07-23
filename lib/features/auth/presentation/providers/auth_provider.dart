import 'package:flutter/foundation.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/auth/presentation/providers/activation_provider.dart';
import 'package:restaurant_app/features/menu/data/services/drive_menu_connection_service.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';
import 'package:restaurant_app/services/firebase_auth_service.dart';
import 'package:restaurant_app/services/session_service.dart';

/// Maneja la sesión activa del usuario autenticado.
///
/// Es un [ChangeNotifier] para que [GoRouter] pueda reaccionar a
/// cambios de sesión mediante [refreshListenable].
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier();

  Usuario? _usuario;

  /// El usuario actualmente autenticado, o null si no hay sesión.
  Usuario? get usuario => _usuario;

  /// Verdadero si hay un usuario autenticado.
  bool get isAuthenticated => _usuario != null;

  bool _canUseActivatedApp() {
    if (!sl.isRegistered<ActivationChangeNotifier>()) return true;

    final activation = sl<ActivationChangeNotifier>();
    if (!activation.isInitialized) return true;

    return activation.canAccessApp;
  }

  Future<void> _audit(
    String eventType, {
    String? userId,
    Map<String, dynamic>? detail,
  }) async {
    await SessionService.logSecurityEvent(
      eventType: eventType,
      userId: userId,
      restaurantId: AppConstants.defaultRestaurantId,
      detail: detail,
    );
  }

  Future<void> _connectDriveAutomatically() async {
    if (!sl.isRegistered<DriveMenuConnectionService>()) return;

    try {
      await sl<DriveMenuConnectionService>().restoreSessionSilently();
    } catch (_) {
      // El login debe seguir aunque Drive no esté disponible en este momento.
    }
  }

  /// Autentica al usuario mediante Firebase Authentication.
  Future<String?> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!_canUseActivatedApp()) {
      await _audit('login_blocked_activation');
      return sl<ActivationChangeNotifier>().status.message;
    }

    final authService = sl<FirebaseAuthService>();
    final error = await authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (error != null) {
      await _audit('login_failed_firebase', detail: {'email': email});
      return error;
    }

    final session = await authService.getCurrentAuthenticatedUser();
    if (session == null) {
      await _audit('login_failed_session');
      return 'No fue posible restaurar la sesión del usuario.';
    }

    await SessionService.clearPinSecurityState();
    final previousUser = _usuario;
    final usuario = Usuario(
      id: session['uid'] as String? ?? 'firebase-user',
      restaurantId:
          session['restaurantId'] as String? ??
          AppConstants.defaultRestaurantId,
      nombre: session['name'] as String? ?? 'Usuario',
      email: session['email'] as String?,
      pin: null,
      rol: RolUsuario.fromString(session['role'] as String? ?? 'administrador'),
      activo: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _usuario = usuario;
    await _audit(
      'login_success',
      userId: usuario.id,
      detail: {'rol': usuario.rol.value},
    );
    sl<TenantContext>().setFromSession(
      restaurantId: usuario.restaurantId,
      userId: usuario.id,
      rol: usuario.rol.value,
    );
    if (previousUser != _usuario) {
      notifyListeners();
    }
    return null;
  }

  /// Compatibilidad con el flujo anterior: utiliza Firebase Auth para validar el acceso.
  Future<String?> loginWithPin(String pin) async {
    if (pin.isEmpty) {
      return 'Ingresa tus credenciales de Firebase.';
    }
    return 'El acceso por PIN fue reemplazado por Firebase Authentication. Usa el formulario de correo y contraseña.';
  }

  /// Restaura una sesión previamente guardada si sigue siendo válida.
  Future<void> restoreSession() async {
    if (!_canUseActivatedApp()) {
      await _audit('session_forced_logout_activation');
      await SessionService.logout();
      return;
    }

    final session = await SessionService.getCurrentUserSession();
    if (session == null) {
      final firebaseSession = await sl<FirebaseAuthService>()
          .restoreSessionFromFirebase();
      if (firebaseSession == null) return;
      return;
    }

    try {
      final usuario = _fromSessionMap(session);
      if (!usuario.activo) {
        await _audit('session_invalid_inactive', userId: usuario.id);
        await SessionService.logout();
        return;
      }

      final previousUser = _usuario;
      _usuario = usuario;
      await _audit('session_restored', userId: usuario.id);
      sl<TenantContext>().setFromSession(
        restaurantId: usuario.restaurantId,
        userId: usuario.id,
        rol: usuario.rol.value,
      );
      if (previousUser != _usuario) {
        notifyListeners();
      }
    } catch (_) {
      await _audit('session_restore_failed');
      await SessionService.logout();
    }
  }

  /// Cierra la sesión actual y limpia la persistencia local.
  Future<void> logout() async {
    final current = _usuario;
    if (current != null) {
      await _audit('logout', userId: current.id);
    }
    final hadUser = _usuario != null;
    _usuario = null;
    sl<TenantContext>().clear();
    if (sl.isRegistered<DriveMenuConnectionService>()) {
      await sl<DriveMenuConnectionService>().signOut();
    }
    await sl<FirebaseAuthService>().signOut();
    if (hadUser) {
      notifyListeners();
    }
  }

  Usuario _fromSessionMap(Map<String, dynamic> session) {
    return Usuario(
      id: session['id'] as String,
      restaurantId: session['restaurantId'] as String,
      nombre: session['nombre'] as String,
      email: session['email'] as String?,
      pin: null, // PIN nunca se lee desde sesión persistida
      rol: RolUsuario.fromString(session['rol'] as String? ?? 'mesero'),
      activo: session['activo'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(session['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(session['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
