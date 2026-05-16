import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilidad para hashear y verificar PINs de usuario.
///
/// Usa SHA-256 con un salt fijo por aplicación. Esto protege los PINs
/// en la base de datos SQLite local contra acceso directo al archivo .db.
///
/// NOTA: Para un sistema multi-tenant en la nube se debería usar bcrypt
/// con salt aleatorio por usuario. SHA-256 con salt fijo es apropiado
/// para esta escala (app local, PINs de 4 dígitos, no datos bancarios).
class PinHasher {
  PinHasher._();

  /// Salt de aplicación. Cambiarlo invalida todos los PINs existentes.
  static const String _appSalt = 'lapena_restaurant_2026_pin_salt';

  /// Retorna el hash SHA-256 del PIN combinado con el salt.
  static String hash(String pin) {
    final input = '$_appSalt:$pin';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Verifica si un PIN en texto plano coincide con un hash almacenado.
  static bool verify(String pin, String storedHash) {
    return hash(pin) == storedHash;
  }

  /// Retorna true si el valor ya es un hash SHA-256 (64 chars hex).
  /// Útil durante la migración para no re-hashear valores ya hasheados.
  static bool isHashed(String value) {
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
  }
}
