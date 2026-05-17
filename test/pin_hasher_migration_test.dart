import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/utils/pin_hasher.dart';
import 'package:restaurant_app/features/usuarios/data/datasources/usuario_local_datasource_impl.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

class _MockSyncManager extends Mock implements SyncManager {}

void main() {
  setUpAll(() {
    registerFallbackValue(SyncOperation.insert);
  });

  group('PinHasher migration', () {
    test('verifies legacy hash and marks it for migration', () {
      const pin = '1234';
      const legacySalt = 'lapena_restaurant_2026_pin_salt';
      final legacyHash = sha256
          .convert(utf8.encode('$legacySalt:$pin'))
          .toString();

      expect(PinHasher.verify(pin, legacyHash), isTrue);
      expect(PinHasher.requiresMigration(legacyHash), isTrue);
    });

    test('generates and verifies v2 hash with per-user salt', () {
      const pin = '1234';
      final v2Hash = PinHasher.hash(pin);

      expect(PinHasher.isV2Hash(v2Hash), isTrue);
      expect(PinHasher.verify(pin, v2Hash), isTrue);
      expect(PinHasher.requiresMigration(v2Hash), isFalse);
    });
  });

  group('UsuarioLocalDataSource PIN migration', () {
    late _MockDatabaseHelper dbHelper;
    late _MockSyncManager syncManager;
    late UsuarioLocalDataSourceImpl dataSource;

    setUp(() {
      dbHelper = _MockDatabaseHelper();
      syncManager = _MockSyncManager();

      dataSource = UsuarioLocalDataSourceImpl(
        dbHelper: dbHelper,
        syncManager: syncManager,
        tenantContext: TenantContext()
          ..setFromSession(
            restaurantId: 'la_pena_001',
            userId: 'usr_admin_01',
            rol: 'administrador',
          ),
      );

      when(
        () => dbHelper.query(
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);

      when(
        () => dbHelper.update(
          any(),
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      when(
        () => syncManager.registrarOperacion(
          tabla: any(named: 'tabla'),
          registroId: any(named: 'registroId'),
          operacion: any(named: 'operacion'),
          restaurantId: any(named: 'restaurantId'),
          datos: any(named: 'datos'),
        ),
      ).thenAnswer((_) async {});
    });

    test('migrates legacy PIN hash after successful login', () async {
      const pin = '1234';
      const legacySalt = 'lapena_restaurant_2026_pin_salt';
      final legacyHash = sha256
          .convert(utf8.encode('$legacySalt:$pin'))
          .toString();

      when(
        () => dbHelper.query(
          'usuarios',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            'id': 'usr_legacy_01',
            'restaurant_id': 'la_pena_001',
            'nombre': 'Admin Legacy',
            'email': 'legacy@test.com',
            'pin': legacyHash,
            'rol': 'administrador',
            'activo': 1,
            'created_at': '2026-01-01T00:00:00.000',
            'updated_at': '2026-01-01T00:00:00.000',
          },
        ],
      );

      Map<String, dynamic>? updatedData;
      when(
        () => dbHelper.update(
          'usuarios',
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((invocation) async {
        updatedData = Map<String, dynamic>.from(
          invocation.positionalArguments[1] as Map,
        );
        return 1;
      });

      final usuario = await dataSource.verificarPin('la_pena_001', pin);

      expect(usuario, isNotNull);
      expect(usuario!.pin, pin);
      expect(updatedData, isNotNull);
      final upgradedHash = updatedData!['pin'] as String;
      expect(PinHasher.isV2Hash(upgradedHash), isTrue);
      expect(PinHasher.verify(pin, upgradedHash), isTrue);

      verify(
        () => syncManager.registrarOperacion(
          tabla: 'usuarios',
          registroId: 'usr_legacy_01',
          operacion: SyncOperation.update,
          restaurantId: 'la_pena_001',
          datos: any(named: 'datos'),
        ),
      ).called(1);
    });

    test('does not rewrite PIN when hash is already v2', () async {
      const pin = '1234';
      final v2Hash = PinHasher.hash(pin);

      when(
        () => dbHelper.query(
          'usuarios',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            'id': 'usr_v2_01',
            'restaurant_id': 'la_pena_001',
            'nombre': 'Admin V2',
            'email': 'v2@test.com',
            'pin': v2Hash,
            'rol': 'administrador',
            'activo': 1,
            'created_at': '2026-01-01T00:00:00.000',
            'updated_at': '2026-01-01T00:00:00.000',
          },
        ],
      );

      final usuario = await dataSource.verificarPin('la_pena_001', pin);

      expect(usuario, isNotNull);
      expect(usuario!.pin, pin);
      verifyNever(
        () => dbHelper.update(
          'usuarios',
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      );
      verifyNever(
        () => syncManager.registrarOperacion(
          tabla: any(named: 'tabla'),
          registroId: any(named: 'registroId'),
          operacion: any(named: 'operacion'),
          restaurantId: any(named: 'restaurantId'),
          datos: any(named: 'datos'),
        ),
      );
    });
  });
}
