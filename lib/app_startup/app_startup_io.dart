import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/services/database_service.dart';

Future<void> initializeDesktopWindow() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(null, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await windowManager.setSize(const Size(800, 600));
  await windowManager.setMinimumSize(const Size(400, 300));
  await windowManager.setResizable(true);
  await windowManager.setMinimizable(true);
  await windowManager.setMaximizable(true);
  await windowManager.setClosable(true);
  await windowManager.setTitle('La Peña • Sistema de Gestión');

  if (Platform.isWindows) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await windowManager.restore();
    await windowManager.focus();
  }
}

Future<void> initializePlatformSpecific() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

Future<void> initDatabaseSafely() async {
  try {
    if (Platform.isIOS || Platform.isAndroid) {
      await _initMobileDatabase();
    } else {
      await DatabaseService.database;
    }
  } catch (_) {
    await _safeFallbackDatabaseInit();
  }
}

Future<void> _initMobileDatabase() async {
  final dbPath = join(await getDatabasesPath(), AppConstants.databaseName);
  final dbFile = File(dbPath);

  if (!await dbFile.exists()) {
    final data = await rootBundle.load('assets/database/data.db');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await dbFile.writeAsBytes(bytes, flush: true);
  }

  final db = await openDatabase(
    dbPath,
    version: AppConstants.databaseVersion,
    readOnly: false,
    onUpgrade: _onDatabaseUpgrade,
  );
  await db.close();
}

/// Aplica migraciones de esquema al actualizar la versión de la BD.
/// Agregar nuevos `case` aquí cada vez que se modifique el esquema.
Future<void> _onDatabaseUpgrade(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  await DatabaseHelper.applyMigrations(db, oldVersion, newVersion);
}

Future<void> _safeFallbackDatabaseInit() async {
  try {
    if (Platform.isIOS || Platform.isAndroid) {
      final dbPath = join(await getDatabasesPath(), AppConstants.databaseName);
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        try {
          final db = await openDatabase(dbPath, readOnly: true);
          await db.close();
          return;
        } catch (_) {
          await dbFile.delete();
        }
      }

      final data = await rootBundle.load('assets/database/data.db');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await dbFile.writeAsBytes(bytes, flush: true);
      final db = await openDatabase(
        dbPath,
        version: AppConstants.databaseVersion,
        onUpgrade: _onDatabaseUpgrade,
      );
      await db.close();
    }
  } catch (_) {
    // La app puede continuar con la BD disponible localmente.
  }
}
