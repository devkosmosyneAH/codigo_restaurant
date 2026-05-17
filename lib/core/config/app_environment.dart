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
    return _legacyGoogleClientId;
  }

  /// True si el folder root está configurado y la integración con Drive
  /// puede operar.
  static bool get isDriveConfigured => driveRootFolderId.isNotEmpty;
}
