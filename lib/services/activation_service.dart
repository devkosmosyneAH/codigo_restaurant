import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ActivationMode { none, demo, full }

class ActivationStatus {
  const ActivationStatus({
    required this.mode,
    required this.evaluatedAt,
    this.activatedAt,
    this.expiresAt,
  });

  final ActivationMode mode;
  final DateTime evaluatedAt;
  final DateTime? activatedAt;
  final DateTime? expiresAt;

  factory ActivationStatus.empty({DateTime? now}) {
    return ActivationStatus(
      mode: ActivationMode.none,
      evaluatedAt: now ?? DateTime.now(),
    );
  }

  bool get isDemo => mode == ActivationMode.demo;
  bool get isFull => mode == ActivationMode.full;

  bool get isExpired {
    return isDemo && expiresAt != null && !expiresAt!.isAfter(evaluatedAt);
  }

  bool get canAccessApp => isFull || (isDemo && !isExpired);

  int get remainingDays {
    if (!isDemo || expiresAt == null || isExpired) return 0;

    final remaining = expiresAt!.difference(evaluatedAt);
    final wholeDays = remaining.inDays;
    final hasPartialDay = remaining - Duration(days: wholeDays) > Duration.zero;

    return hasPartialDay ? wholeDays + 1 : wholeDays;
  }

  String get message {
    if (isFull) {
      return 'Licencia fija activa. La app está desbloqueada.';
    }
    if (isDemo && !isExpired) {
      return 'Demo activa. Quedan $remainingDays día(s) para probar la app.';
    }
    if (isDemo && isExpired) {
      return 'La demo de 7 días ya venció. Ingresa el código fijo para continuar.';
    }
    return 'Ingresa un código de activación para habilitar la demo o la licencia fija.';
  }
}

class ActivationService {
  static const String _modeKey = 'activation_mode';
  static const String _activatedAtKey = 'activation_activated_at';
  static const String _expiresAtKey = 'activation_expires_at';
  static const String _lastCodeKey = 'activation_last_code';

  Future<ActivationStatus> getStatus({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final evaluatedAt = now ?? DateTime.now();
    final rawMode = prefs.getString(_modeKey);

    final mode = switch (rawMode) {
      'demo' => ActivationMode.demo,
      'full' => ActivationMode.full,
      _ => ActivationMode.none,
    };

    return ActivationStatus(
      mode: mode,
      evaluatedAt: evaluatedAt,
      activatedAt: _parseDate(prefs.getString(_activatedAtKey)),
      expiresAt: _parseDate(prefs.getString(_expiresAtKey)),
    );
  }

  Future<String?> activateWithCode(String code, {DateTime? now}) async {
    final normalized = code.trim().toUpperCase();
    final current = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    if (normalized == AppConstants.demoActivationCode.toUpperCase()) {
      await prefs.setString(_modeKey, 'demo');
      await prefs.setString(_activatedAtKey, current.toIso8601String());
      await prefs.setString(
        _expiresAtKey,
        current.add(AppConstants.demoActivationDuration).toIso8601String(),
      );
      await prefs.setString(_lastCodeKey, normalized);
      return null;
    }

    if (normalized == AppConstants.fullActivationCode.toUpperCase()) {
      await prefs.setString(_modeKey, 'full');
      await prefs.setString(_activatedAtKey, current.toIso8601String());
      await prefs.remove(_expiresAtKey);
      await prefs.setString(_lastCodeKey, normalized);
      return null;
    }

    return 'Código de activación inválido.';
  }

  Future<void> clearActivation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modeKey);
    await prefs.remove(_activatedAtKey);
    await prefs.remove(_expiresAtKey);
    await prefs.remove(_lastCodeKey);
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
