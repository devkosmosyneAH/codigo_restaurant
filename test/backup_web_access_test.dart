import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/services/backup_access_stub.dart' as web_backup;
import 'package:restaurant_app/services/database_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;
  String? exportedJson;
  String? nextImportedJson;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    exportedJson = null;
    nextImportedJson = null;

    web_backup.setWebBackupJsonHooks(
      exportHook: (fileName, jsonContent) async {
        exportedJson = jsonContent;
        return fileName;
      },
      importHook: () async => nextImportedJson,
    );

    tempDir = await Directory.systemTemp.createTemp('backup_web_access_');
    dbPath = p.join(tempDir.path, 'web_data.db');
    DatabaseLocationService.setDatabasePathOverride(dbPath);

    final db = await DatabaseHelper.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS web_backup_smoke (
        id INTEGER PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.delete('web_backup_smoke');
    await db.insert('web_backup_smoke', {'id': 1, 'value': 'seed'});
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseLocationService.setDatabasePathOverride(null);
    web_backup.setWebBackupJsonHooks();

    try {
      await deleteDatabase(dbPath);
    } catch (_) {
      // Ignorar si ya no existe el archivo.
    }

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('web backup: crea respaldo y aparece en el overview', () async {
    final created = await web_backup.createManualBackup(
      customName: 'web_manual_case',
    );

    expect(created, isTrue);

    final overview = await web_backup.getBackupOverview();
    final backups = (overview['backups'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    expect(overview['supported'], isTrue);
    expect(overview['storageType'], 'browser');
    expect(backups.any((b) => b['name'] == 'web_manual_case'), isTrue);
  });

  test('web backup: restore recupera datos previos', () async {
    final created = await web_backup.createManualBackup(
      customName: 'web_restore_case',
    );
    expect(created, isTrue);

    final db = await DatabaseHelper.instance.database;
    await db.update('web_backup_smoke', {'value': 'mutated'}, where: 'id = 1');

    final restored = await web_backup.restoreBackup('web_restore_case');
    expect(restored, isTrue);

    final rows = await db.query(
      'web_backup_smoke',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    expect(rows, isNotEmpty);
    expect(rows.first['value'], 'seed');
  });

  test('web backup: restore devuelve false si no existe backup', () async {
    final restored = await web_backup.restoreBackup('backup_inexistente');
    expect(restored, isFalse);
  });

  test('web backup: auto backup crea primer respaldo', () async {
    await web_backup.performAutomaticBackupIfNeeded();

    final overview = await web_backup.getBackupOverview();
    final stats = Map<String, dynamic>.from(overview['stats'] as Map);

    expect((stats['totalBackups'] as int?) ?? 0, greaterThanOrEqualTo(1));
  });

  test('web backup: exporta respaldo en JSON', () async {
    final created = await web_backup.createManualBackup(
      customName: 'web_export_case',
    );
    expect(created, isTrue);

    final result = await web_backup.exportBackup('web_export_case');
    expect(result['success'], isTrue);
    expect(exportedJson, isNotNull);

    final decoded = jsonDecode(exportedJson!) as Map<String, dynamic>;
    expect(decoded['format'], 'lapena-web-backup');
    expect(decoded.containsKey('snapshot'), isTrue);
  });

  test('web backup: importa JSON y permite restaurar', () async {
    final created = await web_backup.createManualBackup(
      customName: 'web_import_source',
    );
    expect(created, isTrue);

    final exportResult = await web_backup.exportBackup('web_import_source');
    expect(exportResult['success'], isTrue);
    expect(exportedJson, isNotNull);

    nextImportedJson = exportedJson;

    final importResult = await web_backup.importBackupFile();
    expect(importResult['success'], isTrue);

    final importedBackupName = importResult['backupName']?.toString();
    expect(importedBackupName, isNotNull);

    final db = await DatabaseHelper.instance.database;
    await db.update('web_backup_smoke', {'value': 'mutated'}, where: 'id = 1');

    final restored = await web_backup.restoreBackup(importedBackupName!);
    expect(restored, isTrue);

    final rows = await db.query(
      'web_backup_smoke',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    expect(rows.first['value'], 'seed');
  });

  test('web backup: importación inválida retorna error', () async {
    nextImportedJson = '{"invalid":true}';

    final importResult = await web_backup.importBackupFile();
    expect(importResult['success'], isFalse);
    expect(importResult['cancelled'], isFalse);
  });
}
