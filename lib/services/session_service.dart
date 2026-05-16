import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Servicio para manejar la persistencia de sesión del usuario
class SessionService {
  static const String _sessionKey = 'user_session';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _failedPinAttemptsKey = 'failed_pin_attempts';
  static const String _pinLockUntilKey = 'pin_lock_until';

  /// Guardar sesión del usuario
  static Future<bool> saveUserSession(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar datos del usuario como JSON
      final userJson = jsonEncode(userData);
      await prefs.setString(_sessionKey, userJson);

      // Marcar como loggeado
      await prefs.setBool(_isLoggedInKey, true);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtener sesión del usuario actual
  static Future<Map<String, dynamic>?> getCurrentUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Verificar si está loggeado
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (!isLoggedIn) {
        return null;
      }

      // Obtener datos del usuario
      final userJson = prefs.getString(_sessionKey);

      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        return userData;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Verificar si hay una sesión activa
  static Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (isLoggedIn) {
        // Verificar que también existan los datos
        final userJson = prefs.getString(_sessionKey);
        return userJson != null;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Obtener el número de intentos fallidos recientes de PIN.
  static Future<int> getFailedPinAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_failedPinAttemptsKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Obtiene hasta cuándo está bloqueado temporalmente el acceso por PIN.
  static Future<DateTime?> getPinLockUntil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pinLockUntilKey);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (e) {
      return null;
    }
  }

  /// Registra un intento fallido y aplica bloqueo temporal si se supera el límite.
  static Future<int> registerFailedPinAttempt({
    int maxAttempts = 3,
    Duration lockDuration = const Duration(seconds: 30),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attempts = (prefs.getInt(_failedPinAttemptsKey) ?? 0) + 1;
      await prefs.setInt(_failedPinAttemptsKey, attempts);

      if (attempts >= maxAttempts) {
        final lockUntil = DateTime.now().add(lockDuration).toIso8601String();
        await prefs.setString(_pinLockUntilKey, lockUntil);
      }

      return attempts;
    } catch (e) {
      return maxAttempts;
    }
  }

  /// Limpia el contador de intentos y cualquier bloqueo temporal.
  static Future<bool> clearPinSecurityState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_failedPinAttemptsKey);
      await prefs.remove(_pinLockUntilKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cerrar sesión del usuario
  static Future<bool> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limpiar datos de sesión
      await prefs.remove(_sessionKey);
      await prefs.setBool(_isLoggedInKey, false);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Actualizar datos del usuario en sesión
  static Future<bool> updateUserSession(
    Map<String, dynamic> updatedData,
  ) async {
    try {
      // Verificar que hay sesión activa
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        return false;
      }

      // Guardar datos actualizados
      return await saveUserSession(updatedData);
    } catch (e) {
      return false;
    }
  }

  /// Obtener información específica del usuario actual
  static Future<String?> getCurrentUserId() async {
    final session = await getCurrentUserSession();
    return session?['uid'];
  }

  static Future<String?> getCurrentUserEmail() async {
    final session = await getCurrentUserSession();
    return session?['email'];
  }

  static Future<String?> getCurrentUserName() async {
    final session = await getCurrentUserSession();
    return session?['name'];
  }

  static Future<String?> getCurrentUserRole() async {
    final session = await getCurrentUserSession();
    return session?['role'];
  }

  static Future<String?> getCurrentUserPermission() async {
    final session = await getCurrentUserSession();
    return session?['permission'];
  }

  /// Método para debug - muestra sólo si hay sesión activa, sin datos sensibles
  static Future<void> debugSessionInfo() async {
    assert(() {
      // Solo se ejecuta en debug builds; ignorado completamente en release
      isUserLoggedIn().then((isLoggedIn) {
        debugPrint('[Session] Estado: ${isLoggedIn ? 'activa' : 'inactiva'}');
      });
      return true;
    }());
  }
}
