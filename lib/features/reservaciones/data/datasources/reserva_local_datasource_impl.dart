import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/reservaciones/data/datasources/reserva_local_datasource.dart';
import 'package:restaurant_app/features/reservaciones/data/models/reserva_model.dart';

/// Implementacion SQLite del datasource de reservaciones.
class ReservaLocalDataSourceImpl implements ReservaLocalDataSource {
  final DatabaseHelper _dbHelper;
  final SyncManager _syncManager;
  // ignore: unused_field
  final TenantContext _tenantContext;

  ReservaLocalDataSourceImpl({
    required DatabaseHelper dbHelper,
    required SyncManager syncManager,
    required TenantContext tenantContext,
  }) : _dbHelper = dbHelper,
       _syncManager = syncManager,
       _tenantContext = tenantContext;

  static const _table = 'reservaciones';

  @override
  Future<void> createReserva(ReservaModel reserva) async {
    try {
      final data = {...reserva.toMap()};
      data['updated_at'] =
          data['created_at'] ?? DateTime.now().toIso8601String();

      await _dbHelper.insert(_table, data);
      await _syncManager.registrarOperacion(
        tabla: _table,
        registroId: reserva.id,
        operacion: SyncOperation.insert,
        restaurantId: reserva.restaurantId,
        datos: data,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al crear reserva: $e');
    }
  }

  @override
  Future<void> updateReserva(ReservaModel reserva) async {
    try {
      final data = {...reserva.toMap()};
      data['updated_at'] = DateTime.now().toIso8601String();

      final rows = await _dbHelper.update(
        _table,
        data,
        where: 'id = ?',
        whereArgs: [reserva.id],
      );
      if (rows == 0) {
        throw DatabaseException(
          message: 'La reserva no existe o ya fue eliminada',
        );
      }
      await _syncManager.registrarOperacion(
        tabla: _table,
        registroId: reserva.id,
        operacion: SyncOperation.update,
        restaurantId: reserva.restaurantId,
        datos: data,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al actualizar reserva: $e');
    }
  }

  @override
  Future<List<ReservaModel>> getReservasByMonth(
    String restaurantId,
    String startDate,
    String endDate,
  ) async {
    try {
      final results = await _dbHelper.rawQuery(
        '''
        SELECT r.*, m.nombre AS mesa_nombre, m.numero AS mesa_numero
        FROM $_table r
        LEFT JOIN mesas m ON r.mesa_id = m.id
        WHERE r.restaurant_id = ?
          AND r.fecha >= ?
          AND r.fecha <= ?
        ORDER BY r.fecha ASC, r.hora_inicio ASC, r.created_at ASC
        ''',
        [restaurantId, startDate, endDate],
      );

      return results.map((row) {
        final map = Map<String, dynamic>.from(row);
        if (map['mesa_nombre'] == null && map['mesa_numero'] != null) {
          map['mesa_nombre'] = 'Mesa ${map['mesa_numero']}';
        }
        return ReservaModel.fromMap(map);
      }).toList();
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener reservas: $e');
    }
  }

  @override
  Future<List<ReservaModel>> getReservasByDate(
    String restaurantId,
    String date,
  ) async {
    try {
      final results = await _dbHelper.rawQuery(
        '''
        SELECT r.*, m.nombre AS mesa_nombre, m.numero AS mesa_numero
        FROM $_table r
        LEFT JOIN mesas m ON r.mesa_id = m.id
        WHERE r.restaurant_id = ?
          AND r.fecha = ?
        ORDER BY r.hora_inicio ASC, r.created_at ASC
        ''',
        [restaurantId, date],
      );

      return results.map((row) {
        final map = Map<String, dynamic>.from(row);
        if (map['mesa_nombre'] == null && map['mesa_numero'] != null) {
          map['mesa_nombre'] = 'Mesa ${map['mesa_numero']}';
        }
        return ReservaModel.fromMap(map);
      }).toList();
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener reservas: $e');
    }
  }
}
