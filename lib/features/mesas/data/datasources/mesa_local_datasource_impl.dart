import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/mesas/data/datasources/mesa_local_datasource.dart';
import 'package:restaurant_app/features/mesas/data/models/mesa_model.dart';

/// Implementación del datasource local de Mesas usando SQLite.
class MesaLocalDataSourceImpl implements MesaLocalDataSource {
  final DatabaseHelper _dbHelper;
  final SyncManager _syncManager;
  final TenantContext _tenantContext;

  MesaLocalDataSourceImpl({
    required DatabaseHelper dbHelper,
    required SyncManager syncManager,
    required TenantContext tenantContext,
  }) : _dbHelper = dbHelper,
       _syncManager = syncManager,
       _tenantContext = tenantContext;

  static const _table = 'mesas';

  @override
  Future<List<MesaModel>> getMesas(String restaurantId) async {
    try {
      final results = await _dbHelper.query(
        _table,
        where: 'restaurant_id = ? AND activo = 1',
        whereArgs: [restaurantId],
        orderBy: 'numero ASC',
      );
      return results.map((row) => MesaModel.fromMap(row)).toList();
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener mesas: $e');
    }
  }

  @override
  Future<MesaModel?> getMesaById(String id) async {
    try {
      final results = await _dbHelper.query(
        _table,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (results.isEmpty) return null;
      return MesaModel.fromMap(results.first);
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener mesa: $e');
    }
  }

  @override
  Future<void> createMesa(MesaModel mesa) async {
    try {
      await _dbHelper.insert(_table, mesa.toMap());
      await _syncManager.registrarOperacion(
        tabla: _table,
        registroId: mesa.id,
        operacion: SyncOperation.insert,
        restaurantId: mesa.restaurantId,
        datos: mesa.toMap(),
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al crear mesa: $e');
    }
  }

  @override
  Future<void> updateMesa(MesaModel mesa) async {
    try {
      final data = mesa.toMap();
      data['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.update(
        _table,
        data,
        where: 'id = ?',
        whereArgs: [mesa.id],
      );
      await _syncManager.registrarOperacion(
        tabla: _table,
        registroId: mesa.id,
        operacion: SyncOperation.update,
        restaurantId: mesa.restaurantId,
        datos: data,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al actualizar mesa: $e');
    }
  }

  @override
  Future<void> deleteMesa(String id) async {
    try {
      await _dbHelper.update(
        _table,
        {'activo': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _syncManager.registrarOperacion(
        tabla: _table,
        registroId: id,
        operacion: SyncOperation.delete,
        restaurantId: _tenantContext.restaurantId,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al eliminar mesa: $e');
    }
  }

  @override
  Future<void> updateEstadoMesa(String id, String estado) async {
    try {
      await _dbHelper.update(
        _table,
        {'estado': estado, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _syncManager.registrarOperacion(
        tabla: _table,
        registroId: id,
        operacion: SyncOperation.update,
        restaurantId: _tenantContext.restaurantId,
        datos: {'estado': estado},
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Error al actualizar estado de mesa: $e',
      );
    }
  }

  @override
  Future<void> unirMesas(List<String> mesaIds, String unionId) async {
    try {
      await _dbHelper.transaction((txn) async {
        for (final mesaId in mesaIds) {
          await txn.update(
            _table,
            {
              'mesa_union_id': unionId,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [mesaId],
          );
        }
      });
    } catch (e) {
      throw DatabaseException(message: 'Error al unir mesas: $e');
    }
  }

  @override
  Future<void> separarMesas(String unionId) async {
    try {
      await _dbHelper.update(
        _table,
        {'mesa_union_id': null, 'updated_at': DateTime.now().toIso8601String()},
        where: 'mesa_union_id = ?',
        whereArgs: [unionId],
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al separar mesas: $e');
    }
  }

  @override
  Future<int> getNextNumeroMesa(String restaurantId) async {
    try {
      final result = await _dbHelper.rawQuery(
        'SELECT COALESCE(MAX(numero), 0) + 1 as next_num '
        'FROM $_table WHERE restaurant_id = ?',
        [restaurantId],
      );
      return (result.first['next_num'] as int?) ?? 1;
    } catch (e) {
      throw DatabaseException(
        message: 'Error al obtener siguiente número de mesa: $e',
      );
    }
  }
}
