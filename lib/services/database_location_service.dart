import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';

/// Servicio para detectar automáticamente la ubicación de la base de datos
/// según el sistema operativo y el contexto de ejecución (desarrollo vs ejecutable)
class DatabaseLocationService {
  static const String _databaseName = AppConstants.databaseName;

  /// Obtener una ruta segura y escribible para la base de datos.
  ///
  /// Para instalaciones reales en Windows/Android/iOS/macOS/Linux usamos
  /// siempre el directorio estándar de `sqflite`, evitando escribir junto al
  /// ejecutable donde suele haber restricciones de permisos.
  static Future<String> getDatabasePath() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'La base de datos SQLite no es compatible con Flutter Web',
      );
    }

    if (Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isAndroid ||
        Platform.isIOS) {
      return join(await getDatabasesPath(), _databaseName);
    }

    throw UnsupportedError(
      'Sistema operativo no soportado: ${Platform.operatingSystem}',
    );
  }

  /// Crear el directorio de la base de datos si no existe
  static Future<void> ensureDatabaseDirectoryExists(String dbPath) async {
    final dir = Directory(dirname(dbPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Obtener información del sistema para debugging
  static Map<String, dynamic> getSystemInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'executable': Platform.resolvedExecutable,
      'isDebugMode': kDebugMode,
      'isProfileMode': kProfileMode,
      'isReleaseMode': kReleaseMode,
    };
  }

  /// Obtener una ruta fallback estándar para la base de datos
  static Future<String> getFallbackPath() async {
    final dbPath = join(await getDatabasesPath(), _databaseName);
    return dbPath;
  }

  /// Verificar si la base de datos existe en la ruta especificada
  static Future<bool> databaseExists(String path) async {
    final exists = await File(path).exists();
    return exists;
  }

  /// Obtener el tamaño de la base de datos
  static Future<double> getDatabaseSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final sizeInBytes = await file.length();
        final sizeInMB = sizeInBytes / (1024 * 1024);
        return sizeInMB;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}
