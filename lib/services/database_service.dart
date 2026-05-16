import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/database/database_helper.dart';
import 'database_location_service.dart';
import 'backup_service.dart';

/// Servicio principal para manejar la conexión con SQLite
/// Actualizado con sistema de ubicación automática y respaldos
class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    try {
      // Usar el nuevo servicio de ubicación automática
      String path = await DatabaseLocationService.getDatabasePath();

      try {
        // Asegurar que el directorio existe
        await DatabaseLocationService.ensureDatabaseDirectoryExists(path);
      } catch (e) {
        // Usar ruta fallback estándar de SQLite
        path = await DatabaseLocationService.getFallbackPath();
        await DatabaseLocationService.ensureDatabaseDirectoryExists(path);
      }

      // Verificar si el archivo existe, si no, copiarlo desde assets
      if (!await DatabaseLocationService.databaseExists(path)) {
        try {
          // Copiar la base de datos desde assets
          ByteData data = await rootBundle.load('assets/database/data.db');
          List<int> bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );

          // Escribir el archivo
          await File(path).writeAsBytes(bytes, flush: true);

          // Verificar que se copió correctamente
          if (!await File(path).exists()) {
            throw Exception(
              'El archivo de base de datos no se creó correctamente',
            );
          }
        } catch (e) {
          throw Exception(
            'No se pudo copiar la base de datos desde assets: $e',
          );
        }
      }

      // Intentar abrir la base de datos
      final db = await openDatabase(
        path,
        version: AppConstants.databaseVersion,
        onUpgrade: _onDatabaseUpgrade,
      );

      // Ejecutar respaldo automático si es necesario
      _performAutomaticBackupIfNeeded();

      return db;
    } catch (e) {
      rethrow;
    }
  }

  /// Aplica migraciones de esquema al actualizar la versión de la BD.
  /// Agregar nuevos `case` aquí cada vez que se modifique el esquema.
  static Future<void> _onDatabaseUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await DatabaseHelper.applyMigrations(db, oldVersion, newVersion);
  }

  /// Ejecutar respaldo automático en segundo plano
  static void _performAutomaticBackupIfNeeded() {
    // Ejecutar en segundo plano sin bloquear la inicialización
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await BackupService.performAutomaticBackupIfNeeded();
      } catch (e) {
        debugPrint('Respaldo automático omitido: $e');
      }
    });
  }

  /// Cerrar la conexión a la base de datos
  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Método helper para ejecutar queries raw
  static Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    final result = await db.rawQuery(sql, arguments);
    return result;
  }

  /// Método helper para ejecutar comandos raw
  static Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    final result = await db.rawInsert(sql, arguments);
    return result;
  }

  /// Método helper para ejecutar updates raw
  static Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }

  /// Método helper para ejecutar deletes raw
  static Future<int> rawDelete(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawDelete(sql, arguments);
  }

  /// Método helper para transacciones
  static Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Obtener información de la base de datos actual
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final path = await DatabaseLocationService.getDatabasePath();
      final exists = await DatabaseLocationService.databaseExists(path);
      final size = exists
          ? await DatabaseLocationService.getDatabaseSize(path)
          : 0.0;

      return {
        'path': path,
        'exists': exists,
        'sizeMB': size,
        'systemInfo': DatabaseLocationService.getSystemInfo(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'path': 'Error obteniendo ruta',
        'exists': false,
        'sizeMB': 0.0,
      };
    }
  }

  /// Crear respaldo manual de la base de datos
  static Future<bool> createManualBackup({String? customName}) async {
    try {
      return await BackupService.createBackup(customName: customName);
    } catch (e) {
      return false;
    }
  }

  /// Restaurar base de datos desde respaldo
  static Future<bool> restoreFromBackup(String backupName) async {
    try {
      // Cerrar la conexión actual antes de restaurar
      await closeDatabase();

      final result = await BackupService.restoreFromBackup(backupName);

      // Reinicializar la base de datos después de restaurar
      if (result) {
        _database = await _initDatabase();
      }

      return result;
    } catch (e) {
      return false;
    }
  }
}
