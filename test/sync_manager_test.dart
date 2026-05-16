import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  group('SyncManager', () {
    late _MockDatabaseHelper dbHelper;
    late SyncManager manager;

    setUp(() {
      dbHelper = _MockDatabaseHelper();
      manager = SyncManager(dbHelper: dbHelper);
    });

    test('registrarOperacion persists restaurant_id in sync_log', () async {
      Map<String, dynamic>? insertedData;
      when(() => dbHelper.insert(any(), any())).thenAnswer((invocation) async {
        insertedData = Map<String, dynamic>.from(
          invocation.positionalArguments[1] as Map,
        );
        return 1;
      });

      await manager.registrarOperacion(
        tabla: 'pedidos',
        registroId: 'pedido_001',
        operacion: SyncOperation.insert,
        restaurantId: 'restaurant_002',
        datos: {'total': 25.5},
      );

      verify(() => dbHelper.insert('sync_log', any())).called(1);
      expect(insertedData, isNotNull);
      expect(insertedData!['tabla'], 'pedidos');
      expect(insertedData!['registro_id'], 'pedido_001');
      expect(insertedData!['operacion'], 'insert');
      expect(insertedData!['restaurant_id'], 'restaurant_002');
      expect(jsonDecode(insertedData!['datos'] as String), {'total': 25.5});
      expect(insertedData!['sincronizado'], 0);
    });

    test('obtenerPendientes maps restaurant_id back to SyncRecord', () async {
      when(
        () => dbHelper.query(
          'sync_log',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            'id': 'sync_001',
            'tabla': 'pedidos',
            'registro_id': 'pedido_001',
            'operacion': 'update',
            'datos': '{"estado":"creado"}',
            'sincronizado': 0,
            'intentos': 0,
            'created_at': '2026-04-30T10:00:00.000',
            'restaurant_id': 'restaurant_002',
          },
        ],
      );

      final records = await manager.obtenerPendientes();

      expect(records, hasLength(1));
      expect(records.single.id, 'sync_001');
      expect(records.single.restaurantId, 'restaurant_002');
      expect(records.single.operacion, SyncOperation.update);
      expect(records.single.datos, {'estado': 'creado'});
      verify(
        () => dbHelper.query(
          'sync_log',
          where: 'sincronizado = ?',
          whereArgs: [0],
          orderBy: 'created_at ASC',
        ),
      ).called(1);
    });
  });
}
