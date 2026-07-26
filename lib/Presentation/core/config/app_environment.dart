/// Configuración de entorno para integraciones externas.
///
/// Los valores se inyectan en build-time mediante `--dart-define` para no
/// exponer credenciales sensibles dentro del bundle de assets. Los defaults
/// presentes aquí son únicamente para desarrollo local y deben ser
/// reemplazados en builds de release vía:
///
/// ```
/// flutter build apk \
///   --dart-define=DRIVE_ROOT_FOLDER_ID=xxx \
///   --dart-define=GOOGLE_API_KEY=xxx \
///   --dart-define=GOOGLE_CLIENT_ID=xxx
/// ```
///
/// Nota de seguridad:
/// - GOOGLE_API_KEY y GOOGLE_CLIENT_ID son identificadores públicos por
///   diseño de OAuth 2.0. La protección real se hace en Google Cloud Console
///   restringiendo la API Key por package name + SHA-1 (Android), bundle id
///   (iOS) y HTTP referrer (web).
/// - Los tokens OAuth son administrados internamente por `google_sign_in`
///   usando el almacén seguro nativo del OS (Keystore Android / Keychain iOS).
///   No se persisten en SharedPreferences ni en SQLite.
class AppEnvironment {
  AppEnvironment._();

  static const String _defaultRealtimeDatabaseUrl =
      'https://restaura-a1e34-default-rtdb.firebaseio.com';

  // ── Drive folder id ─────────────────────────────────────────────────────
  static const String _driveRootFolderId = String.fromEnvironment(
    'DRIVE_ROOT_FOLDER_ID',
    defaultValue: '',
  );
  static const String _driveFolderId = String.fromEnvironment(
    'GOOGLE_DRIVE_FOLDER_ID',
    defaultValue: '',
  );
  static const String _legacyDriveRootFolderId = String.fromEnvironment(
    'REACT_APP_GOOGLE_DRIVE_FOLDER_ID',
    defaultValue: '',
  );
  static const String _viteDriveRootFolderId = String.fromEnvironment(
    'VITE_GOOGLE_DRIVE_FOLDER_ID',
    defaultValue: '',
  );
  static const String _nextDriveRootFolderId = String.fromEnvironment(
    'NEXT_PUBLIC_GOOGLE_DRIVE_FOLDER_ID',
    defaultValue: '',
  );

  // ── API key ─────────────────────────────────────────────────────────────
  static const String _googleApiKey = String.fromEnvironment(
    'GOOGLE_API_KEY',
    defaultValue: '',
  );
  static const String _apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );
  static const String _legacyGoogleApiKey = String.fromEnvironment(
    'REACT_APP_GOOGLE_API_KEY',
    defaultValue: '',
  );
  static const String _viteGoogleApiKey = String.fromEnvironment(
    'VITE_GOOGLE_API_KEY',
    defaultValue: '',
  );
  static const String _nextGoogleApiKey = String.fromEnvironment(
    'NEXT_PUBLIC_GOOGLE_API_KEY',
    defaultValue: '',
  );

  // ── OAuth client id ─────────────────────────────────────────────────────
  static const String _googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
  static const String _clientId = String.fromEnvironment(
    'CLIENT_ID',
    defaultValue: '',
  );
  static const String _legacyGoogleClientId = String.fromEnvironment(
    'REACT_APP_GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
  static const String _viteGoogleClientId = String.fromEnvironment(
    'VITE_GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
  static const String _nextGoogleClientId = String.fromEnvironment(
    'NEXT_PUBLIC_GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  // ── Realtime Database URL ───────────────────────────────────────────────
  static const String _firebaseDatabaseUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue: '',
  );
  static const String _realtimeDatabaseUrl = String.fromEnvironment(
    'REALTIME_DATABASE_URL',
    defaultValue: '',
  );
  static const String _firebaseRtdbUrl = String.fromEnvironment(
    'FIREBASE_RTDB_URL',
    defaultValue: '',
  );
  static const String _legacyFirebaseDatabaseUrl = String.fromEnvironment(
    'REACT_APP_FIREBASE_DATABASE_URL',
    defaultValue: '',
  );
  static const String _viteFirebaseDatabaseUrl = String.fromEnvironment(
    'VITE_FIREBASE_DATABASE_URL',
    defaultValue: '',
  );
  static const String _nextFirebaseDatabaseUrl = String.fromEnvironment(
    'NEXT_PUBLIC_FIREBASE_DATABASE_URL',
    defaultValue: '',
  );

  /// ID de la carpeta raíz en Google Drive donde se crean las subcarpetas
  /// de cada restaurante (tenant).
  static String get driveRootFolderId {
    if (_driveRootFolderId.isNotEmpty) return _driveRootFolderId;
    if (_driveFolderId.isNotEmpty) return _driveFolderId;
    if (_legacyDriveRootFolderId.isNotEmpty) return _legacyDriveRootFolderId;
    if (_viteDriveRootFolderId.isNotEmpty) return _viteDriveRootFolderId;
    if (_nextDriveRootFolderId.isNotEmpty) return _nextDriveRootFolderId;
    return '1xLbiiFfRHkN_3KuUI7zseoXGq9mSyOrR';
  }

  /// API Key pública de Google (con restricciones aplicadas en GCP).
  /// No usada directamente por `google_sign_in` (OAuth nativo); reservada
  /// para llamadas REST que puedan agregarse en el futuro.
  static String get googleApiKey {
    if (_googleApiKey.isNotEmpty) return _googleApiKey;
    if (_apiKey.isNotEmpty) return _apiKey;
    if (_viteGoogleApiKey.isNotEmpty) return _viteGoogleApiKey;
    if (_nextGoogleApiKey.isNotEmpty) return _nextGoogleApiKey;
    return _legacyGoogleApiKey;
  }

  /// Client ID OAuth público (con restricciones aplicadas en GCP).
  static String get googleClientId {
    if (_googleClientId.isNotEmpty) return _googleClientId;
    if (_clientId.isNotEmpty) return _clientId;
    if (_viteGoogleClientId.isNotEmpty) return _viteGoogleClientId;
    if (_nextGoogleClientId.isNotEmpty) return _nextGoogleClientId;
    if (_legacyGoogleClientId.isNotEmpty) return _legacyGoogleClientId;
    return '125358587893-k8t94o1m266010m2mm7kaip8agu8g27j.apps.googleusercontent.com';
  }

  /// URL base de Firebase Realtime Database.
  ///
  /// Acepta varias variables para mantener compatibilidad con distintos
  /// toolchains (.env de Flutter/React/Vite/Next).
  static String get realtimeDatabaseUrl {
    if (_firebaseDatabaseUrl.isNotEmpty) {
      return _normalizeBaseUrl(_firebaseDatabaseUrl);
    }
    if (_realtimeDatabaseUrl.isNotEmpty) {
      return _normalizeBaseUrl(_realtimeDatabaseUrl);
    }
    if (_firebaseRtdbUrl.isNotEmpty) {
      return _normalizeBaseUrl(_firebaseRtdbUrl);
    }
    if (_viteFirebaseDatabaseUrl.isNotEmpty) {
      return _normalizeBaseUrl(_viteFirebaseDatabaseUrl);
    }
    if (_nextFirebaseDatabaseUrl.isNotEmpty) {
      return _normalizeBaseUrl(_nextFirebaseDatabaseUrl);
    }
    if (_legacyFirebaseDatabaseUrl.isNotEmpty) {
      return _normalizeBaseUrl(_legacyFirebaseDatabaseUrl);
    }
    return _defaultRealtimeDatabaseUrl;
  }

  static bool get isRealtimeDatabaseConfigured =>
      realtimeDatabaseUrl.isNotEmpty;

  /// True si el folder root está configurado y la integración con Drive
  /// puede operar.
  static bool get isDriveConfigured => driveRootFolderId.isNotEmpty;

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }
}
