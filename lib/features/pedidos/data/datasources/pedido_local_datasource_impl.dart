import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/pedidos/data/datasources/pedido_local_datasource.dart';
import 'package:restaurant_app/features/pedidos/data/models/pedido_item_model.dart';
import 'package:restaurant_app/features/pedidos/data/models/pedido_model.dart';

/// Implementación del datasource local de Pedidos usando SQLite.
class PedidoLocalDataSourceImpl implements PedidoLocalDataSource {
  final DatabaseHelper _dbHelper;
  final SyncManager _syncManager;
  final TenantContext _tenantContext;

  PedidoLocalDataSourceImpl({
    required DatabaseHelper dbHelper,
    required SyncManager syncManager,
    required TenantContext tenantContext,
  }) : _dbHelper = dbHelper,
       _syncManager = syncManager,
       _tenantContext = tenantContext;

  static const _tablePedidos = 'pedidos';
  static const _tableItems = 'pedido_items';

  // ── Pedidos ──────────────────────────────────────────────────────

  @override
  Future<List<PedidoModel>> getPedidos(String restaurantId) async {
    try {
      // JOIN con mesas y usuarios para obtener display names
      final results = await _dbHelper.rawQuery(
        '''
        SELECT p.*,
               m.nombre AS mesa_nombre,
               m.numero AS mesa_numero,
               u.nombre AS mesero_nombre
        FROM $_tablePedidos p
        LEFT JOIN mesas m ON p.mesa_id = m.id
        LEFT JOIN usuarios u ON p.mesero_id = u.id
        WHERE p.restaurant_id = ?
        ORDER BY p.created_at DESC
        ''',
        [restaurantId],
      );

      final pedidos = <PedidoModel>[];
      for (final row in results) {
        // Construir mesa_nombre con numero si disponible
        final mesaNombre =
            row['mesa_nombre'] as String? ??
            (row['mesa_numero'] != null ? 'Mesa ${row['mesa_numero']}' : null);

        final map = Map<String, dynamic>.from(row);
        map['mesa_nombre'] = mesaNombre;

        final items = await getItemsByPedido(row['id'] as String);
        pedidos.add(PedidoModel.fromMap(map, items: items));
      }

      return pedidos;
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener pedidos: $e');
    }
  }

  @override
  Future<List<PedidoModel>> getPedidosActivos(String restaurantId) async {
    try {
      final results = await _dbHelper.rawQuery(
        '''
        SELECT p.*,
               m.nombre AS mesa_nombre,
               m.numero AS mesa_numero,
               u.nombre AS mesero_nombre
        FROM $_tablePedidos p
        LEFT JOIN mesas m ON p.mesa_id = m.id
        LEFT JOIN usuarios u ON p.mesero_id = u.id
        WHERE p.restaurant_id = ?
          AND p.estado != 'entregado'
        ORDER BY p.created_at DESC
        ''',
        [restaurantId],
      );

      final pedidos = <PedidoModel>[];
      for (final row in results) {
        final mesaNombre =
            row['mesa_nombre'] as String? ??
            (row['mesa_numero'] != null ? 'Mesa ${row['mesa_numero']}' : null);

        final map = Map<String, dynamic>.from(row);
        map['mesa_nombre'] = mesaNombre;

        final items = await getItemsByPedido(row['id'] as String);
        pedidos.add(PedidoModel.fromMap(map, items: items));
      }

      return pedidos;
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener pedidos activos: $e');
    }
  }

  @override
  Future<List<PedidoModel>> getPedidosByMesa(String mesaId) async {
    try {
      final results = await _dbHelper.rawQuery(
        '''
        SELECT p.*,
               m.nombre AS mesa_nombre,
               m.numero AS mesa_numero,
               u.nombre AS mesero_nombre
        FROM $_tablePedidos p
        LEFT JOIN mesas m ON p.mesa_id = m.id
        LEFT JOIN usuarios u ON p.mesero_id = u.id
        WHERE p.mesa_id = ?
          AND p.estado != 'entregado'
        ORDER BY p.created_at DESC
        ''',
        [mesaId],
      );

      final pedidos = <PedidoModel>[];
      for (final row in results) {
        final mesaNombre =
            row['mesa_nombre'] as String? ??
            (row['mesa_numero'] != null ? 'Mesa ${row['mesa_numero']}' : null);

        final map = Map<String, dynamic>.from(row);
        map['mesa_nombre'] = mesaNombre;

        final items = await getItemsByPedido(row['id'] as String);
        pedidos.add(PedidoModel.fromMap(map, items: items));
      }

      return pedidos;
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener pedidos de mesa: $e');
    }
  }

  @override
  Future<PedidoModel?> getPedidoById(String id) async {
    try {
      final results = await _dbHelper.rawQuery(
        '''
        SELECT p.*,
               m.nombre AS mesa_nombre,
               m.numero AS mesa_numero,
               u.nombre AS mesero_nombre
        FROM $_tablePedidos p
        LEFT JOIN mesas m ON p.mesa_id = m.id
        LEFT JOIN usuarios u ON p.mesero_id = u.id
        WHERE p.id = ?
        ''',
        [id],
      );

      if (results.isEmpty) return null;

      final row = results.first;
      final mesaNombre =
          row['mesa_nombre'] as String? ??
          (row['mesa_numero'] != null ? 'Mesa ${row['mesa_numero']}' : null);

      final map = Map<String, dynamic>.from(row);
      map['mesa_nombre'] = mesaNombre;

      final items = await getItemsByPedido(id);
      return PedidoModel.fromMap(map, items: items);
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener pedido: $e');
    }
  }

  @override
  Future<void> createPedido(PedidoModel pedido) async {
    try {
      await _dbHelper.insert(_tablePedidos, pedido.toMap());
      await _syncManager.registrarOperacion(
        tabla: _tablePedidos,
        registroId: pedido.id,
        operacion: SyncOperation.insert,
        restaurantId: pedido.restaurantId,
        datos: pedido.toMap(),
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al crear pedido: $e');
    }
  }

  @override
  Future<void> updatePedido(PedidoModel pedido) async {
    try {
      final data = pedido.toMap();
      data['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.update(
        _tablePedidos,
        data,
        where: 'id = ?',
        whereArgs: [pedido.id],
      );
      await _syncManager.registrarOperacion(
        tabla: _tablePedidos,
        registroId: pedido.id,
        operacion: SyncOperation.update,
        restaurantId: pedido.restaurantId,
        datos: data,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al actualizar pedido: $e');
    }
  }

  @override
  Future<void> updateEstadoPedido(String id, String estado) async {
    try {
      await _dbHelper.update(
        _tablePedidos,
        {'estado': estado, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _syncManager.registrarOperacion(
        tabla: _tablePedidos,
        registroId: id,
        operacion: SyncOperation.update,
        restaurantId: _tenantContext.restaurantId,
        datos: {'estado': estado},
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Error al actualizar estado de pedido: $e',
      );
    }
  }

  @override
  Future<void> deletePedido(String id) async {
    try {
      // Eliminar items primero (cascade manual)
      await _dbHelper.delete(
        _tableItems,
        where: 'pedido_id = ?',
        whereArgs: [id],
      );
      // Luego eliminar el pedido
      await _dbHelper.delete(_tablePedidos, where: 'id = ?', whereArgs: [id]);
      await _syncManager.registrarOperacion(
        tabla: _tablePedidos,
        registroId: id,
        operacion: SyncOperation.delete,
        restaurantId: _tenantContext.restaurantId,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al eliminar pedido: $e');
    }
  }

  @override
  Future<void> recalcularTotal(String pedidoId) async {
    try {
      final result = await _dbHelper.rawQuery(
        '''
        SELECT COALESCE(SUM(precio_unitario * cantidad), 0) AS total
        FROM $_tableItems
        WHERE pedido_id = ?
        ''',
        [pedidoId],
      );
      final total = (result.first['total'] as num?)?.toDouble() ?? 0;
      await _dbHelper.update(
        _tablePedidos,
        {'total': total, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [pedidoId],
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al recalcular total: $e');
    }
  }

  // ── Pedido Items ─────────────────────────────────────────────────

  @override
  Future<List<PedidoItemModel>> getItemsByPedido(String pedidoId) async {
    try {
      final results = await _dbHelper.rawQuery(
        '''
        SELECT pi.*,
               pr.nombre AS producto_nombre,
               v.nombre AS variante_nombre
        FROM $_tableItems pi
        LEFT JOIN productos pr ON pi.producto_id = pr.id
        LEFT JOIN variantes v ON pi.variante_id = v.id
        WHERE pi.pedido_id = ?
        ORDER BY pi.created_at ASC
        ''',
        [pedidoId],
      );
      return results.map((row) => PedidoItemModel.fromMap(row)).toList();
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener items del pedido: $e');
    }
  }

  @override
  Future<void> addItem(PedidoItemModel item) async {
    try {
      await _dbHelper.insert(_tableItems, item.toMap());
      // Recalcular total del pedido
      await recalcularTotal(item.pedidoId);
      await _syncManager.registrarOperacion(
        tabla: _tableItems,
        registroId: item.id,
        operacion: SyncOperation.insert,
        restaurantId: _tenantContext.restaurantId,
        datos: item.toMap(),
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al agregar item: $e');
    }
  }

  @override
  Future<void> updateItem(PedidoItemModel item) async {
    try {
      final data = item.toMap();
      data['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.update(
        _tableItems,
        data,
        where: 'id = ?',
        whereArgs: [item.id],
      );
      // Recalcular total del pedido
      await recalcularTotal(item.pedidoId);
      await _syncManager.registrarOperacion(
        tabla: _tableItems,
        registroId: item.id,
        operacion: SyncOperation.update,
        restaurantId: _tenantContext.restaurantId,
        datos: data,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al actualizar item: $e');
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    try {
      // Obtener pedido_id antes de eliminar
      final results = await _dbHelper.query(
        _tableItems,
        where: 'id = ?',
        whereArgs: [itemId],
      );
      final pedidoId = results.isNotEmpty
          ? results.first['pedido_id'] as String
          : null;

      await _dbHelper.delete(_tableItems, where: 'id = ?', whereArgs: [itemId]);

      // Recalcular total si encontramos el pedido
      if (pedidoId != null) {
        await recalcularTotal(pedidoId);
      }
      await _syncManager.registrarOperacion(
        tabla: _tableItems,
        registroId: itemId,
        operacion: SyncOperation.delete,
        restaurantId: _tenantContext.restaurantId,
      );
    } catch (e) {
      throw DatabaseException(message: 'Error al eliminar item: $e');
    }
  }

  @override
  Future<void> updateEstadoItem(String itemId, String estado) async {
    try {
      await _dbHelper.update(
        _tableItems,
        {'estado': estado, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [itemId],
      );
      await _syncManager.registrarOperacion(
        tabla: _tableItems,
        registroId: itemId,
        operacion: SyncOperation.update,
        restaurantId: _tenantContext.restaurantId,
        datos: {'estado': estado},
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Error al actualizar estado del item: $e',
      );
    }
  }
}
