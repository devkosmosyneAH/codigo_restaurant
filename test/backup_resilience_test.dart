import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:restaurant_app/features/pagina_publica/presentation/providers/drive_backup_provider.dart';
import 'package:restaurant_app/services/backup_service.dart';
import 'package:restaurant_app/services/database_location_service.dart';
import 'package:restaurant_app/services/drive_backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  Future<void> seedDatabase() async {
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE smoke_data (
            id INTEGER PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );

    await db.delete('smoke_data');
    await db.insert('smoke_data', {'id': 1, 'value': 'seed'});
    await db.close();
  }

  Future<String?> readSmokeValue() async {
    final db = await openDatabase(dbPath);
    final rows = await db.query(
      'smoke_data',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    await db.close();
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_resilience_');
    dbPath = p.join(tempDir.path, 'data.db');
    DatabaseLocationService.setDatabasePathOverride(dbPath);

    await seedDatabase();
  });

  tearDown(() async {
    DatabaseLocationService.setDatabasePathOverride(null);

    try {
      await deleteDatabase(dbPath);
    } catch (_) {
      // Ignorar: el archivo puede haber sido eliminado por el propio test.
    }

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('restaurar backup local revierte cambios de datos', () async {
    final backupCreated = await BackupService.createBackup(
      customName: 'manual_restore_case',
    );
    expect(backupCreated, isTrue);

    final db = await openDatabase(dbPath);
    await db.update('smoke_data', {'value': 'mutated'}, where: 'id = 1');
    await db.close();

    expect(await readSmokeValue(), 'mutated');

    final restored = await BackupService.restoreFromBackup(
      'manual_restore_case',
    );
    expect(restored, isTrue);
    expect(await readSmokeValue(), 'seed');
  });

  test('recupera la base cuando el archivo local desaparece', () async {
    final backupCreated = await BackupService.createBackup(
      customName: 'manual_missing_db_case',
    );
    expect(backupCreated, isTrue);

    await File(dbPath).delete();
    expect(await File(dbPath).exists(), isFalse);

    final restored = await BackupService.restoreFromBackup(
      'manual_missing_db_case',
    );

    expect(restored, isTrue);
    expect(await File(dbPath).exists(), isTrue);
    expect(await readSmokeValue(), 'seed');
  });

  test('si SQLite se daña, restaurar backup recupera los datos', () async {
    final backupCreated = await BackupService.createBackup(
      customName: 'manual_corrupt_case',
    );
    expect(backupCreated, isTrue);

    final rng = Random(42);
    final corruptedBytes = List<int>.generate(1024, (_) => rng.nextInt(255));
    await File(dbPath).writeAsBytes(corruptedBytes, flush: true);

    final restored = await BackupService.restoreFromBackup(
      'manual_corrupt_case',
    );

    expect(restored, isTrue);
    expect(await readSmokeValue(), 'seed');
  });

  test('si Drive falla, el estado reporta error sin romper flujo', () async {
    final notifier = DriveBackupNotifier(
      service: _FakeDriveFailingService(),
      autoCheckSignIn: false,
    );

    await notifier.backup();

    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.lastSuccess, isFalse);
    expect(notifier.state.lastMessage, contains('Drive no disponible'));
  });
}

class _FakeDriveFailingService implements DriveBackupService {
  @override
  String? get currentEmail => null;

  @override
  bool get isSignedIn => false;

  @override
  Future<DriveResult> backup() async {
    return const DriveResult(
      success: false,
      message: 'Drive no disponible (error simulado)',
    );
  }

  @override
  Future<DateTime?> lastBackupDate() async => null;

  @override
  Future<DriveResult> restore() async {
    return const DriveResult(
      success: false,
      message: 'Drive no disponible (error simulado)',
    );
  }

  @override
  Future<String?> signIn() async => null;

  @override
  Future<String?> signInSilently() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> ensureDriveAuthenticated({bool interactive = false}) async =>
      false;
}
