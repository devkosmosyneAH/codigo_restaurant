import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Utilidad para hashear y verificar PINs de usuario.
///
/// Esquema actual (v2): `v2:<salt_hex>:<sha256(salt:pin)>`.
///
/// Compatibilidad legacy: soporta validación de hashes antiguos con salt fijo
/// para migrarlos gradualmente al esquema v2 cuando el usuario inicia sesión.
class PinHasher {
  PinHasher._();

  static const String _legacyAppSalt = 'lapena_restaurant_2026_pin_salt';
  static const String _versionPrefix = 'v2';
  static const int _saltLengthBytes = 16;

  static final Random _random = Random.secure();

  /// Retorna un hash v2 con salt aleatorio por usuario.
  static String hash(String pin) {
    final salt = _generateSaltHex();
    final digest = _digestWithSalt(pin, salt);
    return '$_versionPrefix:$salt:$digest';
  }

  /// Verifica si un PIN en texto plano coincide con un hash almacenado
  /// (v2 o legacy).
  static bool verify(String pin, String storedHash) {
    final normalized = storedHash.trim();

    if (isV2Hash(normalized)) {
      final parts = normalized.split(':');
      if (parts.length != 3) return false;
      final salt = parts[1];
      final digest = parts[2];
      return _digestWithSalt(pin, salt) == digest;
    }

    if (isLegacyHash(normalized)) {
      return _legacyHash(pin) == normalized;
    }

    return false;
  }

  /// Retorna true si el hash debe migrarse a v2.
  static bool requiresMigration(String storedHash) {
    return isLegacyHash(storedHash.trim());
  }

  static bool isV2Hash(String value) {
    final parts = value.split(':');
    return parts.length == 3 &&
        parts[0] == _versionPrefix &&
        RegExp(r'^[a-f0-9]{32}$').hasMatch(parts[1]) &&
        RegExp(r'^[a-f0-9]{64}$').hasMatch(parts[2]);
  }

  /// Retorna true si el valor es un hash legacy SHA-256 (64 chars hex).
  static bool isHashed(String value) {
    return isV2Hash(value.trim()) || isLegacyHash(value.trim());
  }

  static bool isLegacyHash(String value) {
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
  }

  static String _legacyHash(String pin) {
    final input = '$_legacyAppSalt:$pin';
    return sha256.convert(utf8.encode(input)).toString();
  }

  static String _digestWithSalt(String pin, String saltHex) {
    final input = '$saltHex:$pin';
    return sha256.convert(utf8.encode(input)).toString();
  }

  static String _generateSaltHex() {
    final bytes = List<int>.generate(
      _saltLengthBytes,
      (_) => _random.nextInt(256),
      growable: false,
    );
    final out = StringBuffer();
    for (final b in bytes) {
      out.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return out.toString();
  }
}
