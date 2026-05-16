import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/sync/sync_cloud_service.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurant_app/features/mesas/data/datasources/mesa_local_datasource_impl.dart';
import 'package:restaurant_app/features/mesas/data/models/mesa_model.dart';
import 'package:restaurant_app/features/sincronizacion/presentation/providers/sync_provider.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';
import 'package:restaurant_app/features/usuarios/domain/repositories/usuario_repository.dart';
import 'package:restaurant_app/features/usuarios/domain/usecases/usuario_usecases.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

class _PinUsuarioRepository implements UsuarioRepository {
  _PinUsuarioRepository(this._usuariosPorPin);

  final Map<String, Usuario> _usuariosPorPin;

  @override
  Future<Either<Failure, Usuario?>> verificarPin(
    String restaurantId,
    String pin,
  ) async {
    return right(_usuariosPorPin[pin]);
  }

  @override
  Future<Either<Failure, Usuario>> createUsuario(Usuario usuario) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteUsuario(String id) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Usuario?>> getUsuarioById(String id) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<Usuario>>> getUsuarios(String restaurantId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<Usuario>>> getUsuariosByRol(
    String restaurantId,
    String rol,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, Usuario>> updateUsuario(Usuario usuario) =>
      throw UnimplementedError();
}

class _InMemorySyncCloudBackend implements SyncCloudBackend {
  final documents = <String, Map<String, dynamic>>{};
  final audits = <String, Map<String, dynamic>>{};
  final setAttemptsByPath = <String, int>{};
  final _setFailuresByPath = <String, int>{};

  @override
  Future<void> ensureAvailable() async {}

  @override
  Future<void> setDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    required bool merge,
  }) async {
    final path = _path(restaurantId, collection, documentId);
    setAttemptsByPath[path] = (setAttemptsByPath[path] ?? 0) + 1;

    final remainingFailures = _setFailuresByPath[path] ?? 0;
    if (remainingFailures > 0) {
      _setFailuresByPath[path] = remainingFailures - 1;
      throw StateError('network disconnected during sync');
    }

    documents[path] = merge
        ? {...?documents[path], ...data}
        : Map<String, dynamic>.from(data);
  }

  @override
  Future<void> deleteDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
  }) async {
    documents.remove(_path(restaurantId, collection, documentId));
  }

  @override
  Future<void> writeAudit({
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    audits[recordId] = Map<String, dynamic>.from(data);
  }

  @override
  Object serverTimestamp() => 'server_timestamp';

  void failNextSet({
    required String restaurantId,
    required String collection,
    required String documentId,
    int times = 1,
  }) {
    _setFailuresByPath[_path(restaurantId, collection, documentId)] = times;
  }

  String _path(String restaurantId, String collection, String documentId) =>
      'restaurantes/$restaurantId/$collection/$documentId';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('multi-tenant end-to-end flow', () {
    late _MockDatabaseHelper dbHelper;
    late SyncManager syncManager;
    late TenantContext tenantContext;
    late MesaLocalDataSourceImpl mesasDataSource;
    late _InMemorySyncCloudBackend cloudBackend;
    late SyncCloudService cloudService;
    late List<Map<String, dynamic>> syncLog;
    late Map<String, Map<String, dynamic>> mesasTable;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await sl.reset();

      dbHelper = _MockDatabaseHelper();
      syncManager = SyncManager(dbHelper: dbHelper);
      tenantContext = TenantContext();
      mesasDataSource = MesaLocalDataSourceImpl(
        dbHelper: dbHelper,
        syncManager: syncManager,
        tenantContext: tenantContext,
      );
      cloudBackend = _InMemorySyncCloudBackend();
      cloudService = SyncCloudService(backend: cloudBackend);
      syncLog = [];
      mesasTable = {};

      when(() => dbHelper.insert(any(), any())).thenAnswer((invocation) async {
        final table = invocation.positionalArguments[0] as String;
        final data = Map<String, dynamic>.from(
          invocation.positionalArguments[1] as Map,
        );

        if (table == 'sync_log') {
          syncLog.add(data);
        } else if (table == 'mesas') {
          mesasTable[data['id'] as String] = data;
        }

        return 1;
      });

      when(
        () => dbHelper.query(
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((invocation) async {
        final table = invocation.positionalArguments[0] as String;
        if (table != 'sync_log') return [];

        final whereArgs = invocation.namedArguments[#whereArgs] as List?;
        final syncValue = whereArgs != null && whereArgs.isNotEmpty
            ? whereArgs.first as int
            : 0;

        return syncLog
            .where((row) => row['sincronizado'] == syncValue)
            .toList();
      });

      when(
        () => dbHelper.update(
          any(),
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((invocation) async {
        final table = invocation.positionalArguments[0] as String;
        final data = Map<String, dynamic>.from(
          invocation.positionalArguments[1] as Map,
        );
        final whereArgs = invocation.namedArguments[#whereArgs] as List?;

        if (table == 'sync_log' && whereArgs != null && whereArgs.isNotEmpty) {
          final id = whereArgs.first as String;
          final index = syncLog.indexWhere((row) => row['id'] == id);
          if (index != -1) {
            syncLog[index] = {...syncLog[index], ...data};
            return 1;
          }
        }

        return 0;
      });

      when(() => dbHelper.rawQuery(any(), any())).thenAnswer((
        invocation,
      ) async {
        final sql = invocation.positionalArguments[0] as String;
        final args = invocation.positionalArguments.length > 1
            ? invocation.positionalArguments[1] as List?
            : null;

        if (sql.startsWith('UPDATE sync_log SET intentos')) {
          final id = args?.first as String;
          final index = syncLog.indexWhere((row) => row['id'] == id);
          if (index != -1) {
            syncLog[index] = {
              ...syncLog[index],
              'intentos': (syncLog[index]['intentos'] as int? ?? 0) + 1,
            };
          }
          return [];
        }

        if (sql.startsWith('SELECT COUNT(*) as count FROM sync_log')) {
          return [
            {'count': syncLog.where((row) => row['sincronizado'] == 0).length},
          ];
        }

        return [];
      });

      sl.registerLazySingleton<TenantContext>(() => tenantContext);
      sl.registerLazySingleton<VerificarPin>(
        () => VerificarPin(
          _PinUsuarioRepository({
            '1111': _usuario(
              id: 'usr_admin_a',
              restaurantId: 'tenant_a',
              pin: '1111',
            ),
            '2222': _usuario(
              id: 'usr_admin_b',
              restaurantId: 'tenant_b',
              pin: '2222',
            ),
          }),
        ),
      );
    });

    tearDown(() async {
      await sl.reset();
    });

    test(
      'login -> operation -> local sync -> cloud sync keeps each tenant isolated',
      () async {
        final tenantARecord = await _loginCreateAndSyncMesa(
          pin: '1111',
          expectedTenantId: 'tenant_a',
          mesaId: 'mesa_tenant_a_01',
          mesaNumero: 1,
          auth: AuthChangeNotifier(),
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
          syncManager: syncManager,
          cloudService: cloudService,
        );

        expect(
          cloudBackend
              .documents['restaurantes/tenant_a/mesas/mesa_tenant_a_01'],
          containsPair('restaurant_id', 'tenant_a'),
        );
        expect(
          cloudBackend
              .documents['restaurantes/tenant_b/mesas/mesa_tenant_a_01'],
          isNull,
        );
        expect(
          cloudBackend.audits[tenantARecord.id]?['restaurant_id'],
          'tenant_a',
        );

        await AuthChangeNotifier().logout();

        final tenantBRecord = await _loginCreateAndSyncMesa(
          pin: '2222',
          expectedTenantId: 'tenant_b',
          mesaId: 'mesa_tenant_b_01',
          mesaNumero: 2,
          auth: AuthChangeNotifier(),
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
          syncManager: syncManager,
          cloudService: cloudService,
        );

        expect(
          cloudBackend
              .documents['restaurantes/tenant_b/mesas/mesa_tenant_b_01'],
          containsPair('restaurant_id', 'tenant_b'),
        );
        expect(
          cloudBackend
              .documents['restaurantes/tenant_a/mesas/mesa_tenant_b_01'],
          isNull,
        );
        expect(
          cloudBackend.audits[tenantBRecord.id]?['restaurant_id'],
          'tenant_b',
        );

        expect(mesasTable['mesa_tenant_a_01']?['restaurant_id'], 'tenant_a');
        expect(mesasTable['mesa_tenant_b_01']?['restaurant_id'], 'tenant_b');
        expect(
          syncLog.map((row) => row['restaurant_id']),
          containsAllInOrder(['tenant_a', 'tenant_b']),
        );
        expect(syncLog.every((row) => row['sincronizado'] == 1), isTrue);
      },
    );

    test(
      'network outage during sync keeps the row pending and the next retry preserves tenant isolation',
      () async {
        final record = await _loginAndCreateMesa(
          pin: '1111',
          expectedTenantId: 'tenant_a',
          mesaId: 'mesa_network_retry_01',
          mesaNumero: 3,
          auth: AuthChangeNotifier(),
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
          syncManager: syncManager,
        );
        final path = 'restaurantes/tenant_a/mesas/mesa_network_retry_01';
        cloudBackend.failNextSet(
          restaurantId: 'tenant_a',
          collection: 'mesas',
          documentId: 'mesa_network_retry_01',
        );

        final notifier = SyncNotifier(
          syncManager: syncManager,
          cloudService: cloudService,
        );
        addTearDown(notifier.dispose);

        await notifier.loadRegistros();
        await notifier.sincronizarAhora();

        expect(cloudBackend.documents[path], isNull);
        expect(cloudBackend.audits[record.id], isNull);
        expect(_syncRow(syncLog, record.id)['sincronizado'], 0);
        expect(_syncRow(syncLog, record.id)['intentos'], 1);
        expect(notifier.state.totalPendientes, 1);

        await notifier.sincronizarAhora();

        expect(
          cloudBackend.documents[path],
          containsPair('restaurant_id', 'tenant_a'),
        );
        expect(
          cloudBackend
              .documents['restaurantes/tenant_b/mesas/mesa_network_retry_01'],
          isNull,
        );
        expect(cloudBackend.audits[record.id]?['restaurant_id'], 'tenant_a');
        expect(cloudBackend.setAttemptsByPath[path], 2);
        expect(_syncRow(syncLog, record.id)['sincronizado'], 1);
        expect(_syncRow(syncLog, record.id)['intentos'], 1);
      },
    );

    test(
      'duplicate local operations for the same record are idempotent in cloud and stay tenant-scoped',
      () async {
        final firstRecord = await _loginAndCreateMesa(
          pin: '1111',
          expectedTenantId: 'tenant_a',
          mesaId: 'mesa_duplicate_01',
          mesaNumero: 4,
          auth: AuthChangeNotifier(),
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
          syncManager: syncManager,
        );
        final secondRecord = await _createMesaOperation(
          expectedTenantId: 'tenant_a',
          mesaId: 'mesa_duplicate_01',
          mesaNumero: 4,
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
          syncManager: syncManager,
        );
        final path = 'restaurantes/tenant_a/mesas/mesa_duplicate_01';

        final notifier = SyncNotifier(
          syncManager: syncManager,
          cloudService: cloudService,
        );
        addTearDown(notifier.dispose);

        await notifier.loadRegistros();
        await notifier.sincronizarAhora();

        expect(
          cloudBackend.documents[path],
          containsPair('restaurant_id', 'tenant_a'),
        );
        expect(
          cloudBackend
              .documents['restaurantes/tenant_b/mesas/mesa_duplicate_01'],
          isNull,
        );
        expect(cloudBackend.setAttemptsByPath[path], 2);
        expect(
          cloudBackend.audits[firstRecord.id]?['restaurant_id'],
          'tenant_a',
        );
        expect(
          cloudBackend.audits[secondRecord.id]?['restaurant_id'],
          'tenant_a',
        );
        expect(_syncRow(syncLog, firstRecord.id)['sincronizado'], 1);
        expect(_syncRow(syncLog, secondRecord.id)['sincronizado'], 1);
        expect(
          cloudBackend.documents.keys.where(
            (key) => key.endsWith('/mesa_duplicate_01'),
          ),
          [path],
        );
      },
    );

    test(
      'partial sync marks only successful records and retries the failed tenant record without corrupting others',
      () async {
        final tenantARecord = await _loginAndCreateMesa(
          pin: '1111',
          expectedTenantId: 'tenant_a',
          mesaId: 'mesa_partial_a_01',
          mesaNumero: 5,
          auth: AuthChangeNotifier(),
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
          syncManager: syncManager,
        );

        await AuthChangeNotifier().logout();

        final tenantBFailedRecord = await _loginAndCreateMesa(
          pin: '2222',
          expectedTenantId: 'tenant_b',
          mesaId: 'mesa_partial_b_01',
          mesaNumero: 6,
          auth: AuthChangeNotifier(),
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
          syncManager: syncManager,
        );
        final tenantBSuccessfulRecord = await _createMesaOperation(
          expectedTenantId: 'tenant_b',
          mesaId: 'mesa_partial_b_02',
          mesaNumero: 7,
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
          syncManager: syncManager,
        );

        cloudBackend.failNextSet(
          restaurantId: 'tenant_b',
          collection: 'mesas',
          documentId: 'mesa_partial_b_01',
        );

        final notifier = SyncNotifier(
          syncManager: syncManager,
          cloudService: cloudService,
        );
        addTearDown(notifier.dispose);

        await notifier.loadRegistros();
        await notifier.sincronizarAhora();

        expect(
          cloudBackend
              .documents['restaurantes/tenant_a/mesas/mesa_partial_a_01'],
          containsPair('restaurant_id', 'tenant_a'),
        );
        expect(
          cloudBackend
              .documents['restaurantes/tenant_b/mesas/mesa_partial_b_01'],
          isNull,
        );
        expect(
          cloudBackend
              .documents['restaurantes/tenant_b/mesas/mesa_partial_b_02'],
          containsPair('restaurant_id', 'tenant_b'),
        );
        expect(_syncRow(syncLog, tenantARecord.id)['sincronizado'], 1);
        expect(_syncRow(syncLog, tenantBFailedRecord.id)['sincronizado'], 0);
        expect(_syncRow(syncLog, tenantBFailedRecord.id)['intentos'], 1);
        expect(
          _syncRow(syncLog, tenantBSuccessfulRecord.id)['sincronizado'],
          1,
        );
        expect(
          cloudBackend
              .documents['restaurantes/tenant_a/mesas/mesa_partial_b_02'],
          isNull,
        );

        await notifier.sincronizarAhora();

        expect(
          cloudBackend
              .documents['restaurantes/tenant_b/mesas/mesa_partial_b_01'],
          containsPair('restaurant_id', 'tenant_b'),
        );
        expect(_syncRow(syncLog, tenantBFailedRecord.id)['sincronizado'], 1);
        expect(_syncRow(syncLog, tenantBFailedRecord.id)['intentos'], 1);
        expect(notifier.state.totalPendientes, 0);
      },
    );

    test(
      'concurrent sync across tenants keeps every record in its tenant path',
      () async {
        await _loginTenant(
          pin: '1111',
          expectedTenantId: 'tenant_a',
          auth: AuthChangeNotifier(),
          tenantContext: tenantContext,
        );
        await _createMesaBatch(
          expectedTenantId: 'tenant_a',
          prefix: 'mesa_concurrent_a',
          count: 20,
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
        );

        await AuthChangeNotifier().logout();
        await _loginTenant(
          pin: '2222',
          expectedTenantId: 'tenant_b',
          auth: AuthChangeNotifier(),
          tenantContext: tenantContext,
        );
        await _createMesaBatch(
          expectedTenantId: 'tenant_b',
          prefix: 'mesa_concurrent_b',
          count: 20,
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
        );

        final pending = await syncManager.obtenerPendientes();
        expect(pending, hasLength(40));

        await Future.wait(
          pending.map((record) async {
            await cloudService.pushRecord(record);
            await syncManager.marcarSincronizado(record.id);
          }),
        );

        expect(syncLog.every((row) => row['sincronizado'] == 1), isTrue);
        _expectTenantIsolation(
          cloudBackend,
          expectedTenantCounts: {'tenant_a': 20, 'tenant_b': 20},
        );
        expect(
          cloudBackend.documents.keys.any(
            (path) =>
                path.startsWith('restaurantes/tenant_a/') &&
                path.contains('mesa_concurrent_b'),
          ),
          isFalse,
        );
        expect(
          cloudBackend.documents.keys.any(
            (path) =>
                path.startsWith('restaurantes/tenant_b/') &&
                path.contains('mesa_concurrent_a'),
          ),
          isFalse,
        );
      },
    );

    test(
      'stress sync recovers from partial network failures without tenant data corruption',
      () async {
        const operationsPerTenant = 60;

        await _loginTenant(
          pin: '1111',
          expectedTenantId: 'tenant_a',
          auth: AuthChangeNotifier(),
          tenantContext: tenantContext,
        );
        await _createMesaBatch(
          expectedTenantId: 'tenant_a',
          prefix: 'mesa_stress_a',
          count: operationsPerTenant,
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
        );

        await AuthChangeNotifier().logout();
        await _loginTenant(
          pin: '2222',
          expectedTenantId: 'tenant_b',
          auth: AuthChangeNotifier(),
          tenantContext: tenantContext,
        );
        await _createMesaBatch(
          expectedTenantId: 'tenant_b',
          prefix: 'mesa_stress_b',
          count: operationsPerTenant,
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
        );

        await _createDuplicateMesaOperations(
          expectedTenantId: 'tenant_b',
          mesaId: 'mesa_stress_b_duplicate',
          count: 3,
          tenantContext: tenantContext,
          dataSource: mesasDataSource,
        );

        for (final index in [0, 7, 14, 21, 28]) {
          cloudBackend.failNextSet(
            restaurantId: 'tenant_a',
            collection: 'mesas',
            documentId: 'mesa_stress_a_$index',
          );
          cloudBackend.failNextSet(
            restaurantId: 'tenant_b',
            collection: 'mesas',
            documentId: 'mesa_stress_b_$index',
          );
        }

        final notifier = SyncNotifier(
          syncManager: syncManager,
          cloudService: cloudService,
        );
        addTearDown(notifier.dispose);

        await notifier.loadRegistros();
        expect(notifier.state.totalPendientes, 123);

        await notifier.sincronizarAhora();

        final failedRows = syncLog.where((row) => row['sincronizado'] == 0);
        expect(failedRows, hasLength(10));
        expect(failedRows.every((row) => row['intentos'] == 1), isTrue);
        _expectTenantIsolation(
          cloudBackend,
          expectedTenantCounts: {'tenant_a': 55, 'tenant_b': 56},
        );
        expect(
          cloudBackend.documents.keys.any(
            (path) =>
                path.startsWith('restaurantes/tenant_a/') &&
                path.contains('mesa_stress_b'),
          ),
          isFalse,
        );
        expect(
          cloudBackend.documents.keys.any(
            (path) =>
                path.startsWith('restaurantes/tenant_b/') &&
                path.contains('mesa_stress_a'),
          ),
          isFalse,
        );

        await notifier.sincronizarAhora();

        expect(syncLog.every((row) => row['sincronizado'] == 1), isTrue);
        expect(syncLog.where((row) => row['intentos'] == 1), hasLength(10));
        expect(notifier.state.totalPendientes, 0);
        _expectTenantIsolation(
          cloudBackend,
          expectedTenantCounts: {'tenant_a': 60, 'tenant_b': 61},
        );
        expect(
          cloudBackend
              .documents['restaurantes/tenant_b/mesas/mesa_stress_b_duplicate'],
          containsPair('restaurant_id', 'tenant_b'),
        );
        expect(
          cloudBackend
              .setAttemptsByPath['restaurantes/tenant_b/mesas/mesa_stress_b_duplicate'],
          3,
        );
        expect(
          cloudBackend
              .documents['restaurantes/tenant_a/mesas/mesa_stress_b_duplicate'],
          isNull,
        );
      },
    );
  });
}

Future<SyncRecord> _loginCreateAndSyncMesa({
  required String pin,
  required String expectedTenantId,
  required String mesaId,
  required int mesaNumero,
  required AuthChangeNotifier auth,
  required TenantContext tenantContext,
  required MesaLocalDataSourceImpl dataSource,
  required SyncManager syncManager,
  required SyncCloudService cloudService,
}) async {
  final record = await _loginAndCreateMesa(
    pin: pin,
    expectedTenantId: expectedTenantId,
    mesaId: mesaId,
    mesaNumero: mesaNumero,
    auth: auth,
    tenantContext: tenantContext,
    dataSource: dataSource,
    syncManager: syncManager,
  );

  await cloudService.pushRecord(record);
  await syncManager.marcarSincronizado(record.id);

  return record;
}

Future<SyncRecord> _loginAndCreateMesa({
  required String pin,
  required String expectedTenantId,
  required String mesaId,
  required int mesaNumero,
  required AuthChangeNotifier auth,
  required TenantContext tenantContext,
  required MesaLocalDataSourceImpl dataSource,
  required SyncManager syncManager,
}) async {
  final loginError = await auth.loginWithPin(pin);

  expect(loginError, isNull);
  expect(auth.isAuthenticated, isTrue);
  expect(tenantContext.restaurantId, expectedTenantId);

  return _createMesaOperation(
    expectedTenantId: expectedTenantId,
    mesaId: mesaId,
    mesaNumero: mesaNumero,
    tenantContext: tenantContext,
    dataSource: dataSource,
    syncManager: syncManager,
  );
}

Future<void> _loginTenant({
  required String pin,
  required String expectedTenantId,
  required AuthChangeNotifier auth,
  required TenantContext tenantContext,
}) async {
  final loginError = await auth.loginWithPin(pin);

  expect(loginError, isNull);
  expect(auth.isAuthenticated, isTrue);
  expect(tenantContext.restaurantId, expectedTenantId);
}

Future<void> _createMesaBatch({
  required String expectedTenantId,
  required String prefix,
  required int count,
  required TenantContext tenantContext,
  required MesaLocalDataSourceImpl dataSource,
}) async {
  expect(tenantContext.restaurantId, expectedTenantId);

  await Future.wait(
    List.generate(count, (index) async {
      final now = DateTime(2026, 4, 30, 13).add(Duration(minutes: index));
      await dataSource.createMesa(
        MesaModel(
          id: '${prefix}_$index',
          restaurantId: tenantContext.restaurantId,
          numero: index + 1,
          nombre: 'Mesa ${index + 1}',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }),
  );
}

Future<void> _createDuplicateMesaOperations({
  required String expectedTenantId,
  required String mesaId,
  required int count,
  required TenantContext tenantContext,
  required MesaLocalDataSourceImpl dataSource,
}) async {
  expect(tenantContext.restaurantId, expectedTenantId);

  for (var index = 0; index < count; index++) {
    final now = DateTime(2026, 4, 30, 15).add(Duration(minutes: index));
    await dataSource.createMesa(
      MesaModel(
        id: mesaId,
        restaurantId: tenantContext.restaurantId,
        numero: 900 + index,
        nombre: 'Mesa duplicada $index',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

Future<SyncRecord> _createMesaOperation({
  required String expectedTenantId,
  required String mesaId,
  required int mesaNumero,
  required TenantContext tenantContext,
  required MesaLocalDataSourceImpl dataSource,
  required SyncManager syncManager,
}) async {
  expect(tenantContext.restaurantId, expectedTenantId);
  final now = DateTime(2026, 4, 30, 12, mesaNumero);
  await dataSource.createMesa(
    MesaModel(
      id: mesaId,
      restaurantId: tenantContext.restaurantId,
      numero: mesaNumero,
      nombre: 'Mesa $mesaNumero',
      createdAt: now,
      updatedAt: now,
    ),
  );

  final pending = await syncManager.obtenerPendientes();
  final record = pending.lastWhere((item) => item.registroId == mesaId);

  expect(record.restaurantId, expectedTenantId);
  expect(record.datos?['restaurant_id'], expectedTenantId);

  return record;
}

Map<String, dynamic> _syncRow(List<Map<String, dynamic>> syncLog, String id) {
  return syncLog.singleWhere((row) => row['id'] == id);
}

void _expectTenantIsolation(
  _InMemorySyncCloudBackend cloudBackend, {
  required Map<String, int> expectedTenantCounts,
}) {
  final actualCounts = <String, int>{};

  for (final entry in cloudBackend.documents.entries) {
    final pathSegments = entry.key.split('/');
    expect(pathSegments, hasLength(4));
    expect(pathSegments[0], 'restaurantes');

    final tenantId = pathSegments[1];
    actualCounts[tenantId] = (actualCounts[tenantId] ?? 0) + 1;
    expect(entry.value['restaurant_id'], tenantId);
  }

  expect(actualCounts, expectedTenantCounts);

  for (final audit in cloudBackend.audits.values) {
    final tenantId = audit['restaurant_id'] as String;
    expect(expectedTenantCounts.keys, contains(tenantId));
  }
}

Usuario _usuario({
  required String id,
  required String restaurantId,
  required String pin,
}) {
  final now = DateTime(2026, 4, 30, 10);
  return Usuario(
    id: id,
    restaurantId: restaurantId,
    nombre: 'Administrador $restaurantId',
    email: null,
    pin: pin,
    rol: RolUsuario.administrador,
    activo: true,
    createdAt: now,
    updatedAt: now,
  );
}
