import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'database_location_service.dart';

/// Servicio para manejar respaldos automáticos de la base de datos
class BackupService {
  static const String _backupFolderName = 'backups';
  static const String _configFileName = 'backup_config.json';

  /// Configuración de respaldo
  static const Map<String, dynamic> _defaultConfig = {
    'autoBackupEnabled': true,
    'backupIntervalHours': 24,
    'maxBackupFiles': 10,
    'backupOnStartup': true,
    'backupOnShutdown': true,
    'lastBackupTime': null,
  };

  /// Crear un respaldo de la base de datos
  static Future<bool> createBackup({String? customName}) async {
    try {
      // Obtener la ruta actual de la base de datos
      final dbPath = await DatabaseLocationService.getDatabasePath();

      if (!await DatabaseLocationService.databaseExists(dbPath)) {
        return false;
      }

      // Crear el directorio de respaldos
      final backupDir = await _getBackupDirectory();
      await _ensureBackupDirectoryExists(backupDir);

      // Generar nombre del respaldo
      final backupName = customName ?? _generateBackupName();
      final backupPath = join(backupDir, '$backupName.db');

      // Copiar la base de datos
      final dbFile = File(dbPath);
      final backupFile = File(backupPath);

      await dbFile.copy(backupPath);

      // Verificar que se copió correctamente
      if (await backupFile.exists()) {
        final originalSize = await dbFile.length();
        final backupSize = await backupFile.length();

        if (originalSize == backupSize) {
          // Actualizar configuración
          await _updateLastBackupTime();

          // Limpiar respaldos antiguos
          await _cleanOldBackups();

          return true;
        } else {
          await backupFile.delete();
          return false;
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Restaurar base de datos desde un respaldo
  static Future<bool> restoreFromBackup(String backupName) async {
    try {
      final backupDir = await _getBackupDirectory();
      final backupPath = join(backupDir, '$backupName.db');

      if (!await File(backupPath).exists()) {
        return false;
      }

      final dbPath = await DatabaseLocationService.getDatabasePath();

      // Crear respaldo de seguridad antes de restaurar
      if (await DatabaseLocationService.databaseExists(dbPath)) {
        final safetyBackup = _generateBackupName(prefix: 'safety_');
        await createBackup(customName: safetyBackup);
      }

      // Restaurar la base de datos
      final backupFile = File(backupPath);
      await backupFile.copy(dbPath);

      // Verificar la restauración
      if (await DatabaseLocationService.databaseExists(dbPath)) {
        await DatabaseLocationService.getDatabaseSize(dbPath);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Listar todos los respaldos disponibles
  static Future<List<Map<String, dynamic>>> listBackups() async {
    try {
      final backupDir = await _getBackupDirectory();

      if (!await Directory(backupDir).exists()) {
        return [];
      }

      final directory = Directory(backupDir);
      final files = await directory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.db'))
          .cast<File>()
          .toList();

      final backups = <Map<String, dynamic>>[];

      for (final file in files) {
        final stat = await file.stat();
        final size = stat.size / (1024 * 1024); // MB
        final name = basenameWithoutExtension(file.path);

        backups.add({
          'name': name,
          'path': file.path,
          'size': size,
          'created': stat.modified,
          'sizeFormatted': '${size.toStringAsFixed(2)} MB',
          'createdFormatted': DateFormat(
            'dd/MM/yyyy HH:mm:ss',
          ).format(stat.modified),
        });
      }

      // Ordenar por fecha de creación (más reciente primero)
      backups.sort(
        (a, b) =>
            (b['created'] as DateTime).compareTo(a['created'] as DateTime),
      );

      return backups;
    } catch (e) {
      return [];
    }
  }

  /// Eliminar un respaldo específico
  static Future<bool> deleteBackup(String backupName) async {
    try {
      final backupDir = await _getBackupDirectory();
      final backupPath = join(backupDir, '$backupName.db');
      final backupFile = File(backupPath);

      if (await backupFile.exists()) {
        await backupFile.delete();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Verificar si es necesario hacer un respaldo automático
  static Future<bool> shouldCreateAutomaticBackup() async {
    try {
      final config = await _getBackupConfig();

      if (!config['autoBackupEnabled']) {
        return false;
      }

      final lastBackupTime = config['lastBackupTime'];
      if (lastBackupTime == null) {
        return true; // Primer respaldo
      }

      final lastBackup = DateTime.parse(lastBackupTime);
      final now = DateTime.now();
      final intervalHours = config['backupIntervalHours'] ?? 24;

      final hoursSinceLastBackup = now.difference(lastBackup).inHours;

      return hoursSinceLastBackup >= intervalHours;
    } catch (e) {
      return true; // En caso de error, es mejor hacer respaldo
    }
  }

  /// Ejecutar respaldo automático si es necesario
  static Future<bool> performAutomaticBackupIfNeeded() async {
    if (await shouldCreateAutomaticBackup()) {
      return await createBackup(
        customName: _generateBackupName(prefix: 'auto_'),
      );
    } else {
      return true;
    }
  }

  /// Obtener la configuración de respaldo
  static Future<Map<String, dynamic>> _getBackupConfig() async {
    try {
      final backupDir = await _getBackupDirectory();
      final configPath = join(backupDir, _configFileName);
      final configFile = File(configPath);

      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final config = json.decode(content) as Map<String, dynamic>;

        // Combinar con configuración por defecto para campos faltantes
        final mergedConfig = Map<String, dynamic>.from(_defaultConfig);
        mergedConfig.addAll(config);

        return mergedConfig;
      } else {
        return Map<String, dynamic>.from(_defaultConfig);
      }
    } catch (e) {
      return Map<String, dynamic>.from(_defaultConfig);
    }
  }

  /// Actualizar la configuración de respaldo
  static Future<void> _updateBackupConfig(Map<String, dynamic> config) async {
    try {
      final backupDir = await _getBackupDirectory();
      await _ensureBackupDirectoryExists(backupDir);

      final configPath = join(backupDir, _configFileName);
      final configFile = File(configPath);

      final jsonContent = const JsonEncoder.withIndent('  ').convert(config);
      await configFile.writeAsString(jsonContent);
    } catch (e) {
      debugPrint('No se pudo guardar la configuración de respaldos: $e');
    }
  }

  /// Actualizar el tiempo del último respaldo
  static Future<void> _updateLastBackupTime() async {
    final config = await _getBackupConfig();
    config['lastBackupTime'] = DateTime.now().toIso8601String();
    await _updateBackupConfig(config);
  }

  /// Obtener el directorio de respaldos
  static Future<String> _getBackupDirectory() async {
    final dbPath = await DatabaseLocationService.getDatabasePath();
    final dbDir = dirname(dbPath);
    return join(dbDir, _backupFolderName);
  }

  /// Asegurar que el directorio de respaldos existe
  static Future<void> _ensureBackupDirectoryExists(String backupDir) async {
    final dir = Directory(backupDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Generar nombre para respaldo
  static String _generateBackupName({String prefix = ''}) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd_HHmmss');
    final timestamp = formatter.format(now);
    return '${prefix}backup_$timestamp';
  }

  /// Limpiar respaldos antiguos según configuración
  static Future<void> _cleanOldBackups() async {
    try {
      final config = await _getBackupConfig();
      final maxBackupFiles = config['maxBackupFiles'] ?? 10;

      final backups = await listBackups();

      if (backups.length > maxBackupFiles) {
        // Excluir respaldos de seguridad de la limpieza
        final autoBackups = backups
            .where((backup) => !backup['name'].toString().startsWith('safety_'))
            .toList();

        if (autoBackups.length > maxBackupFiles) {
          final backupsToDelete = autoBackups.sublist(maxBackupFiles);

          for (final backup in backupsToDelete) {
            await deleteBackup(backup['name']);
          }
        }
      }
    } catch (e) {
      debugPrint('No se pudieron limpiar respaldos antiguos: $e');
    }
  }

  /// Obtener estadísticas de respaldos
  static Future<Map<String, dynamic>> getBackupStats() async {
    try {
      final backups = await listBackups();
      final config = await _getBackupConfig();

      double totalSize = 0;
      for (final backup in backups) {
        totalSize += backup['size'] as double;
      }

      DateTime? lastBackupTime;
      if (config['lastBackupTime'] != null) {
        lastBackupTime = DateTime.parse(config['lastBackupTime']);
      }

      return {
        'totalBackups': backups.length,
        'totalSizeGB': totalSize / 1024,
        'totalSizeMB': totalSize,
        'lastBackupTime': lastBackupTime,
        'autoBackupEnabled': config['autoBackupEnabled'],
        'backupIntervalHours': config['backupIntervalHours'],
        'maxBackupFiles': config['maxBackupFiles'],
        'oldestBackup': backups.isNotEmpty ? backups.last['created'] : null,
        'newestBackup': backups.isNotEmpty ? backups.first['created'] : null,
      };
    } catch (e) {
      return {
        'totalBackups': 0,
        'totalSizeGB': 0.0,
        'totalSizeMB': 0.0,
        'lastBackupTime': null,
        'autoBackupEnabled': false,
        'backupIntervalHours': 24,
        'maxBackupFiles': 10,
      };
    }
  }

  /// Configurar opciones de respaldo
  static Future<void> updateBackupSettings({
    bool? autoBackupEnabled,
    int? backupIntervalHours,
    int? maxBackupFiles,
    bool? backupOnStartup,
    bool? backupOnShutdown,
  }) async {
    final config = await _getBackupConfig();

    if (autoBackupEnabled != null) {
      config['autoBackupEnabled'] = autoBackupEnabled;
    }
    if (backupIntervalHours != null) {
      config['backupIntervalHours'] = backupIntervalHours;
    }
    if (maxBackupFiles != null) config['maxBackupFiles'] = maxBackupFiles;
    if (backupOnStartup != null) config['backupOnStartup'] = backupOnStartup;
    if (backupOnShutdown != null) config['backupOnShutdown'] = backupOnShutdown;

    await _updateBackupConfig(config);
  }
}
