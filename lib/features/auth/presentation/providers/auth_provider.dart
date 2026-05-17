import 'package:flutter/foundation.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/auth/presentation/providers/activation_provider.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';
import 'package:restaurant_app/features/usuarios/domain/usecases/usuario_usecases.dart';
import 'package:restaurant_app/services/session_service.dart';

/// Maneja la sesión activa del usuario autenticado.
///
/// Es un [ChangeNotifier] para que [GoRouter] pueda reaccionar a
/// cambios de sesión mediante [refreshListenable].
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier();

  static const int _maxFailedAttempts = 3;
  static const Duration _pinLockDuration = Duration(minutes: 5);

  Usuario? _usuario;

  /// El usuario actualmente autenticado, o null si no hay sesión.
  Usuario? get usuario => _usuario;

  /// Verdadero si hay un usuario autenticado.
  bool get isAuthenticated => _usuario != null;

  String _lockMessage(Duration remaining) {
    final seconds = remaining.inSeconds <= 0 ? 1 : remaining.inSeconds;
    return 'Acceso bloqueado temporalmente. Intenta de nuevo en ${seconds}s.';
  }

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

  /// Autentica al usuario mediante PIN de 4 dígitos.
  ///
  /// Retorna `null` en caso de éxito, o un mensaje de error.
  Future<String?> loginWithPin(String pin) async {
    if (!_canUseActivatedApp()) {
      await _audit('login_blocked_activation');
      return sl<ActivationChangeNotifier>().status.message;
    }

    final now = DateTime.now();
    final lockUntil = await SessionService.getPinLockUntil();

    if (lockUntil != null && lockUntil.isAfter(now)) {
      await _audit(
        'login_blocked_lockout',
        detail: {'remaining_seconds': lockUntil.difference(now).inSeconds},
      );
      return _lockMessage(lockUntil.difference(now));
    }

    final result = await sl<VerificarPin>()(
      AppConstants.defaultRestaurantId,
      pin,
    );

    return result.fold((failure) => failure.message, (usuario) async {
      if (usuario == null || !usuario.activo) {
        final attempts = await SessionService.registerFailedPinAttempt(
          maxAttempts: _maxFailedAttempts,
          lockDuration: _pinLockDuration,
        );
        notifyListeners();

        if (attempts >= _maxFailedAttempts) {
          await _audit('login_lockout_applied', detail: {'attempts': attempts});
          return 'Demasiados intentos fallidos. Acceso bloqueado por 5 minutos.';
        }

        final remaining = _maxFailedAttempts - attempts;
        final intentoLabel = remaining == 1 ? 'intento' : 'intentos';
        await _audit(
          'login_failed_pin',
          detail: {'attempts': attempts, 'remaining': remaining},
        );
        return 'PIN incorrecto. Te quedan $remaining $intentoLabel antes del bloqueo.';
      }

      await SessionService.clearPinSecurityState();
      _usuario = usuario;
      await SessionService.saveUserSession(_toSessionMap(usuario));
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
      notifyListeners();
      return null;
    });
  }

  /// Restaura una sesión previamente guardada si sigue siendo válida.
  Future<void> restoreSession() async {
    if (!_canUseActivatedApp()) {
      await _audit('session_forced_logout_activation');
      await SessionService.logout();
      return;
    }

    final session = await SessionService.getCurrentUserSession();
    if (session == null) return;

    try {
      final usuario = _fromSessionMap(session);
      if (!usuario.activo) {
        await _audit('session_invalid_inactive', userId: usuario.id);
        await SessionService.logout();
        return;
      }

      _usuario = usuario;
      await _audit('session_restored', userId: usuario.id);
      sl<TenantContext>().setFromSession(
        restaurantId: usuario.restaurantId,
        userId: usuario.id,
        rol: usuario.rol.value,
      );
      notifyListeners();
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
    _usuario = null;
    sl<TenantContext>().clear();
    await SessionService.logout();
    notifyListeners();
  }

  Map<String, dynamic> _toSessionMap(Usuario usuario) {
    return {
      'id': usuario.id,
      'restaurantId': usuario.restaurantId,
      'nombre': usuario.nombre,
      'email': usuario.email,
      // PIN no se persiste en sesión por seguridad
      'rol': usuario.rol.value,
      'activo': usuario.activo,
      'createdAt': usuario.createdAt.toIso8601String(),
      'updatedAt': usuario.updatedAt.toIso8601String(),
    };
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
