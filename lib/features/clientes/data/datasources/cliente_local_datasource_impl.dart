import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/clientes/data/datasources/cliente_local_datasource.dart';
import 'package:restaurant_app/features/clientes/data/models/cliente_model.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/domain/repositories/cliente_repository.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

/// Implementación SQLite del datasource de Clientes.
class ClienteLocalDataSourceImpl implements ClienteLocalDataSource {
  final DatabaseHelper _db;
  final SyncManager _syncManager;
  final TenantContext _tenantContext;

  ClienteLocalDataSourceImpl({
    required DatabaseHelper dbHelper,
    required SyncManager syncManager,
    required TenantContext tenantContext,
  }) : _db = dbHelper,
       _syncManager = syncManager,
       _tenantContext = tenantContext;

  static const _table = 'clientes';

  String _cleanCedula(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  String _cleanRequiredText(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  String? _cleanOptionalText(String? value) {
    final clean = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    return clean.isEmpty ? null : clean;
  }

  String? _cleanEmail(String? value) =>
      _cleanOptionalText(value)?.toLowerCase();

  String? _cleanPhone(String? value) {
    final clean = value?.replaceAll(RegExp(r'[^0-9+()\-\s]'), '').trim() ?? '';
    return clean.isEmpty ? null : clean;
  }

  ClienteModel _normalized(ClienteModel cliente) {
    return ClienteModel(
      idCliente: cliente.idCliente,
      cedula: _cleanCedula(cliente.cedula),
      restaurantId: _tenantContext.restaurantId,
      nombre: _cleanRequiredText(cliente.nombre),
      apellido: _cleanOptionalText(cliente.apellido),
      telefono: _cleanPhone(cliente.telefono),
      email: _cleanEmail(cliente.email),
      direccion: _cleanOptionalText(cliente.direccion),
      fechaNacimiento: cliente.fechaNacimiento,
      notas: _cleanOptionalText(cliente.notas),
      estado: cliente.estado,
      activo: cliente.activo,
      createdAt: cliente.createdAt,
      updatedAt: cliente.updatedAt,
    );
  }

  Map<String, dynamic> _toSyncPayload(ClienteModel cliente) {
    final data = Map<String, dynamic>.from(cliente.toMap());
    data.remove('id_cliente');
    return data;
  }

  void _validateCliente(ClienteModel cliente, {required bool validateCedula}) {
    if (validateCedula && !Cliente.esCedulaValida(cliente.cedula)) {
      throw const BusinessException(
        message: 'La cédula/RUC ingresada no es válida.',
      );
    }
    if (cliente.nombre.trim().isEmpty) {
      throw const BusinessException(
        message: 'El nombre del cliente es obligatorio.',
      );
    }
    final email = cliente.email;
    if (email != null &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw const BusinessException(message: 'Correo electrónico inválido.');
    }
  }

  Future<ClienteModel?> _getClienteByCedulaForTenant(
    String restaurantId,
    String cedula, {
    bool includeInactive = false,
  }) async {
    final where = StringBuffer('restaurant_id = ? AND cedula = ?');
    if (!includeInactive) {
      where.write(' AND activo = 1 AND estado = 1');
    }

    final rows = await _db.query(
      _table,
      where: where.toString(),
      whereArgs: [restaurantId, _cleanCedula(cedula)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ClienteModel.fromMap(rows.first);
  }

  @override
  Future<List<ClienteModel>> getClientes(String restaurantId) async {
    try {
      final scopedRestaurantId = _tenantContext.restaurantId;
      final rows = await _db.query(
        _table,
        where: 'restaurant_id = ? AND activo = 1 AND estado = 1',
        whereArgs: [scopedRestaurantId],
        orderBy: 'nombres ASC',
      );
      return rows.map(ClienteModel.fromMap).toList();
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener clientes: $e');
    }
  }

  @override
  Future<ClienteModel?> getClienteByCedula(
    String restaurantId,
    String cedula,
  ) async {
    try {
      final scopedRestaurantId = _tenantContext.restaurantId;
      return await _getClienteByCedulaForTenant(scopedRestaurantId, cedula);
    } catch (e) {
      throw DatabaseException(message: 'Error al buscar cliente: $e');
    }
  }

  @override
  Future<List<ClienteModel>> buscarClientes(
    String restaurantId,
    String query,
  ) async {
    try {
      final scopedRestaurantId = _tenantContext.restaurantId;
      final cleanQuery = _cleanRequiredText(query);
      final like = '%$cleanQuery%';
      final digitQuery = _cleanCedula(cleanQuery);
      final digitLike = digitQuery.isEmpty ? like : '%$digitQuery%';
      final rows = await _db.rawQuery(
        '''
        SELECT * FROM $_table
        WHERE restaurant_id = ?
          AND activo = 1
          AND estado = 1
          AND (
            cedula      LIKE ? OR
            nombres     LIKE ? OR
            nombre      LIKE ? OR
            apellido    LIKE ? OR
            email       LIKE ? OR
            telefono    LIKE ? OR
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(telefono, ' ', ''), '-', ''), '(', ''), ')', ''), '+', '') LIKE ?
          )
        ORDER BY nombres ASC
        LIMIT 50
        ''',
        [
          scopedRestaurantId,
          digitLike,
          like,
          like,
          like,
          like,
          like,
          digitLike,
        ],
      );
      return rows.map(ClienteModel.fromMap).toList();
    } catch (e) {
      throw DatabaseException(message: 'Error al buscar clientes: $e');
    }
  }

  @override
  Future<ClienteModel> createCliente(ClienteModel cliente) async {
    try {
      final normalized = _normalized(cliente);
      _validateCliente(normalized, validateCedula: true);

      final existing = await _getClienteByCedulaForTenant(
        normalized.restaurantId,
        normalized.cedula,
        includeInactive: true,
      );
      if (existing != null) {
        if (existing.activo && existing.estado) {
          throw const BusinessException(
            message: 'Ya existe un cliente registrado con esa cédula.',
          );
        }

        final reactivated = ClienteModel(
          idCliente: existing.idCliente,
          cedula: normalized.cedula,
          restaurantId: normalized.restaurantId,
          nombre: normalized.nombre,
          apellido: normalized.apellido,
          telefono: normalized.telefono,
          email: normalized.email,
          direccion: normalized.direccion,
          fechaNacimiento: normalized.fechaNacimiento,
          notas: normalized.notas,
          estado: true,
          activo: true,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        );
        await _db.update(
          _table,
          reactivated.toMap(),
          where: 'restaurant_id = ? AND cedula = ?',
          whereArgs: [reactivated.restaurantId, reactivated.cedula],
        );
        await _syncManager.registrarOperacion(
          tabla: _table,
          registroId: '${reactivated.restaurantId}:${reactivated.cedula}',
          operacion: SyncOperation.update,
          restaurantId: reactivated.restaurantId,
          datos: _toSyncPayload(reactivated),
        );
        return reactivated;
      }

      final idCliente = await _db.insert(
        _table,
        normalized.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      final created = ClienteModel.fromEntity(
        normalized.copyWith(idCliente: normalized.idCliente ?? idCliente),
      );
      await _syncManager.registrarOperacion(
        tabla: _table,
        registroId: '${created.restaurantId}:${created.cedula}',
        operacion: SyncOperation.insert,
        restaurantId: created.restaurantId,
        datos: _toSyncPayload(created),
      );
      return created;
    } on BusinessException {
      rethrow;
    } catch (e) {
      throw DatabaseException(message: 'Error al registrar cliente: $e');
    }
  }

  @override
  Future<ClienteModel> updateCliente(ClienteModel cliente) async {
    try {
      final normalized = _normalized(cliente);
      _validateCliente(normalized, validateCedula: false);
      final updated = ClienteModel.fromMap({
        ...normalized.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      final affected = await _db.update(
        _table,
        updated.toMap(),
        where: 'restaurant_id = ? AND cedula = ?',
        whereArgs: [updated.restaurantId, updated.cedula],
      );
      if (affected == 0) {
        throw const BusinessException(message: 'Cliente no encontrado.');
      }
      await _syncManager.registrarOperacion(
        tabla: _table,
        registroId: '${updated.restaurantId}:${updated.cedula}',
        operacion: SyncOperation.update,
        restaurantId: updated.restaurantId,
        datos: _toSyncPayload(updated),
      );
      return updated;
    } on BusinessException {
      rethrow;
    } catch (e) {
      throw DatabaseException(message: 'Error al actualizar cliente: $e');
    }
  }

  @override
  Future<void> deleteCliente(String restaurantId, String cedula) async {
    try {
      final scopedRestaurantId = _tenantContext.restaurantId;
      final cleanCedula = _cleanCedula(cedula);
      final affected = await _db.update(
        _table,
        {
          'activo': 0,
          'estado': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'restaurant_id = ? AND cedula = ?',
        whereArgs: [scopedRestaurantId, cleanCedula],
      );
      if (affected == 0) {
        throw const BusinessException(message: 'Cliente no encontrado.');
      }
      await _syncManager.registrarOperacion(
        tabla: _table,
        registroId: '$scopedRestaurantId:$cleanCedula',
        operacion: SyncOperation.delete,
        restaurantId: scopedRestaurantId,
      );
    } on BusinessException {
      rethrow;
    } catch (e) {
      throw DatabaseException(message: 'Error al eliminar cliente: $e');
    }
  }

  @override
  Future<ClienteResumen> getResumenCliente(
    String cedula,
    String restaurantId,
  ) async {
    try {
      final scopedRestaurantId = _tenantContext.restaurantId;
      final rows = await _db.rawQuery(
        '''
        SELECT
          COUNT(*)            AS total_visitas,
          COALESCE(SUM(total), 0)  AS total_gastado,
          MIN(created_at)     AS primera_visita,
          MAX(created_at)     AS ultima_visita
        FROM ventas
        WHERE restaurant_id = ?
          AND (
            cliente_identificacion = ?
            OR identificacion_cliente = ?
          )
        ''',
        [scopedRestaurantId, _cleanCedula(cedula), _cleanCedula(cedula)],
      );

      if (rows.isEmpty) {
        return ClienteResumen(
          cedula: cedula,
          totalVisitas: 0,
          totalGastado: 0,
          ticketPromedio: 0,
        );
      }

      final row = rows.first;
      final totalVisitas = (row['total_visitas'] as int?) ?? 0;
      final totalGastado = (row['total_gastado'] as num?)?.toDouble() ?? 0.0;

      return ClienteResumen(
        cedula: cedula,
        totalVisitas: totalVisitas,
        totalGastado: totalGastado,
        ticketPromedio: totalVisitas > 0 ? totalGastado / totalVisitas : 0,
        primeraVisita: row['primera_visita'] != null
            ? DateTime.tryParse(row['primera_visita'] as String)
            : null,
        ultimaVisita: row['ultima_visita'] != null
            ? DateTime.tryParse(row['ultima_visita'] as String)
            : null,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener resumen: $e');
    }
  }
}
