import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/caja/data/datasources/caja_local_datasource.dart';
import 'package:restaurant_app/features/caja/data/models/venta_detalle_model.dart';
import 'package:restaurant_app/features/caja/data/models/venta_model.dart';
import 'package:restaurant_app/features/cotizaciones/data/models/cotizacion_model.dart';
import 'package:restaurant_app/features/cotizaciones/data/models/cotizacion_item_model.dart';
import 'package:restaurant_app/features/pedidos/data/models/pedido_item_model.dart';
import 'package:restaurant_app/features/pedidos/data/models/pedido_model.dart';
import 'package:uuid/uuid.dart';

/// Implementación SQLite del datasource de Caja.
class CajaLocalDataSourceImpl implements CajaLocalDataSource {
  final DatabaseHelper _dbHelper;
  final SyncManager _syncManager;
  // ignore: unused_field
  final TenantContext _tenantContext;

  CajaLocalDataSourceImpl({
    required DatabaseHelper dbHelper,
    required SyncManager syncManager,
    required TenantContext tenantContext,
  }) : _dbHelper = dbHelper,
       _syncManager = syncManager,
       _tenantContext = tenantContext;

  static const _tableVentas = 'ventas';
  static const _tableDetalles = 'venta_detalles';
  static const _tablePedidos = 'pedidos';
  static const _tableMesas = 'mesas';
  static const _tablePedidoItems = 'pedido_items';
  static const _tableCotizaciones = 'cotizaciones';
  static const _tableCotizacionItems = 'cotizacion_items';
  static const _tableReservaciones = 'reservaciones';
  static const _tableSriComprobantes = 'sri_comprobantes';
  static const _tableSriAttempts = 'sri_attempts';

  // ── Registro de venta ─────────────────────────────────────────

  @override
  Future<void> registrarVenta(VentaModel venta, {String? mesaId}) async {
    final nowIso = DateTime.now().toIso8601String();
    final ventaData = {...venta.toMap(), 'updated_at': nowIso};
    final pedidoData = {'estado': 'entregado', 'updated_at': nowIso};
    final mesaData = {'estado': 'libre', 'updated_at': nowIso};
    final cotizacionData = {'estado': 'cobrada', 'updated_at': nowIso};
    final reservaData = {'estado': 'realizada', 'updated_at': nowIso};
    final reservacionesActualizadas = <String>[];

    try {
      await _dbHelper.transaction((txn) async {
        // 1. Insertar venta principal
        await txn.insert(_tableVentas, ventaData);

        if (venta.sriComprobanteId != null) {
          await txn.insert(_tableSriComprobantes, {
            'id': venta.sriComprobanteId,
            'restaurant_id': venta.restaurantId,
            'venta_id': venta.id,
            'tipo': venta.tipoComprobante.value,
            'ambiente': 'pruebas',
            'clave_acceso': venta.sriClaveAcceso ?? '',
            'secuencial': _extractSecuencial(venta.sriClaveAcceso),
            'xml_local_hash': venta.sriXmlHash,
            'estado': venta.estadoSri.value,
            'numero_autorizacion': venta.sriNumeroAutorizacion,
            'fecha_autorizacion': venta.sriFechaAutorizacion?.toIso8601String(),
            'mensaje': venta.sriMensaje,
            'ride_path': venta.sriRidePath,
            'created_at': nowIso,
            'updated_at': nowIso,
          });
          await txn.insert(_tableSriAttempts, {
            'id': const Uuid().v4(),
            'restaurant_id': venta.restaurantId,
            'comprobante_id': venta.sriComprobanteId,
            'tipo_operacion': 'preparacion_local',
            'request_id': null,
            'estado': venta.estadoSri.value,
            'http_status': null,
            'sri_estado': null,
            'mensaje': venta.sriMensaje,
            'retry_count': 0,
            'next_retry_at':
                venta.estadoSri == EstadoComprobanteSri.pendienteEnvio
                ? nowIso
                : null,
            'payload_hash': venta.sriXmlHash,
            'created_at': nowIso,
          });
        }

        // 2. Insertar detalles de la venta
        for (final detalle in venta.detalles) {
          final detalleModel = VentaDetalleModel.fromEntity(detalle);
          await txn.insert(_tableDetalles, detalleModel.toMap());
        }

        // 3. Marcar el pedido como entregado
        await txn.update(
          _tablePedidos,
          pedidoData,
          where: 'id = ?',
          whereArgs: [venta.pedidoId],
        );

        // 4. Liberar la mesa si aplica
        if (mesaId != null) {
          await txn.update(
            _tableMesas,
            mesaData,
            where: 'id = ?',
            whereArgs: [mesaId],
          );
        }

        // 5. Marcar la cotización como cobrada si aplica
        if (venta.sourceCotizacionId != null) {
          final reservaRows = await txn.query(
            _tableReservaciones,
            columns: ['id'],
            where: 'cotizacion_id = ?',
            whereArgs: [venta.sourceCotizacionId],
          );
          reservacionesActualizadas.addAll(
            reservaRows
                .map((row) => row['id'])
                .whereType<String>()
                .where((id) => id.isNotEmpty),
          );

          await txn.update(
            _tableCotizaciones,
            cotizacionData,
            where: 'id = ?',
            whereArgs: [venta.sourceCotizacionId],
          );

          // 6. Marcar la reserva asociada como 'realizada' si existe
          await txn.update(
            _tableReservaciones,
            reservaData,
            where: 'cotizacion_id = ?',
            whereArgs: [venta.sourceCotizacionId],
          );
        }
      });
    } catch (e) {
      throw DatabaseException(message: 'Error al registrar venta: $e');
    }

    await _syncManager.registrarOperacion(
      tabla: _tableVentas,
      registroId: venta.id,
      operacion: SyncOperation.insert,
      restaurantId: venta.restaurantId,
      datos: ventaData,
    );

    await _syncManager.registrarOperacion(
      tabla: _tablePedidos,
      registroId: venta.pedidoId,
      operacion: SyncOperation.update,
      restaurantId: venta.restaurantId,
      datos: pedidoData,
    );

    if (mesaId != null) {
      await _syncManager.registrarOperacion(
        tabla: _tableMesas,
        registroId: mesaId,
        operacion: SyncOperation.update,
        restaurantId: venta.restaurantId,
        datos: mesaData,
      );
    }

    if (venta.sourceCotizacionId != null) {
      await _syncManager.registrarOperacion(
        tabla: _tableCotizaciones,
        registroId: venta.sourceCotizacionId!,
        operacion: SyncOperation.update,
        restaurantId: venta.restaurantId,
        datos: cotizacionData,
      );

      for (final reservaId in reservacionesActualizadas) {
        await _syncManager.registrarOperacion(
          tabla: _tableReservaciones,
          registroId: reservaId,
          operacion: SyncOperation.update,
          restaurantId: venta.restaurantId,
          datos: reservaData,
        );
      }
    }
  }

  // ── Consultas de ventas ───────────────────────────────────────

  @override
  Future<List<VentaModel>> getVentas(String restaurantId) async {
    try {
      final results = await _dbHelper.rawQuery(
        '''
        SELECT v.*, u.nombre AS cajero_nombre
        FROM $_tableVentas v
        LEFT JOIN usuarios u ON v.cajero_id = u.id
        WHERE v.restaurant_id = ?
        ORDER BY v.created_at DESC
        ''',
        [restaurantId],
      );

      final ventaIds = results
          .map((row) => row['id'])
          .whereType<String>()
          .toList(growable: false);
      final detallesByVenta = await _getDetallesByVentaIds(ventaIds);

      return results
          .map((row) {
            final ventaId = row['id'] as String;
            final detalles =
                detallesByVenta[ventaId] ?? const <VentaDetalleModel>[];
            return VentaModel.fromMap(row, detalles: detalles);
          })
          .toList(growable: false);
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener ventas: $e');
    }
  }

  @override
  Future<List<VentaModel>> getVentasByFecha(
    String restaurantId,
    DateTime fecha,
  ) async {
    try {
      final fechaStr = fecha.toIso8601String().substring(0, 10);
      final results = await _dbHelper.rawQuery(
        '''
        SELECT v.*, u.nombre AS cajero_nombre
        FROM $_tableVentas v
        LEFT JOIN usuarios u ON v.cajero_id = u.id
        WHERE v.restaurant_id = ?
          AND date(v.created_at) = ?
        ORDER BY v.created_at DESC
        ''',
        [restaurantId, fechaStr],
      );

      final ventaIds = results
          .map((row) => row['id'])
          .whereType<String>()
          .toList(growable: false);
      final detallesByVenta = await _getDetallesByVentaIds(ventaIds);

      return results
          .map((row) {
            final ventaId = row['id'] as String;
            final detalles =
                detallesByVenta[ventaId] ?? const <VentaDetalleModel>[];
            return VentaModel.fromMap(row, detalles: detalles);
          })
          .toList(growable: false);
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener ventas por fecha: $e');
    }
  }

  @override
  Future<VentaModel?> getVentaById(String id) async {
    try {
      final results = await _dbHelper.rawQuery(
        '''
        SELECT v.*, u.nombre AS cajero_nombre
        FROM $_tableVentas v
        LEFT JOIN usuarios u ON v.cajero_id = u.id
        WHERE v.id = ?
        ''',
        [id],
      );
      if (results.isEmpty) return null;

      final detalles = await _getDetallesByVenta(id);
      return VentaModel.fromMap(results.first, detalles: detalles);
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener venta: $e');
    }
  }

  @override
  Future<VentaModel?> getVentaByPedido(String pedidoId) async {
    try {
      final results = await _dbHelper.rawQuery(
        '''
        SELECT v.*, u.nombre AS cajero_nombre
        FROM $_tableVentas v
        LEFT JOIN usuarios u ON v.cajero_id = u.id
        WHERE v.pedido_id = ?
        ORDER BY v.created_at DESC
        LIMIT 1
        ''',
        [pedidoId],
      );
      if (results.isEmpty) return null;
      final detalles = await _getDetallesByVenta(results.first['id'] as String);
      return VentaModel.fromMap(results.first, detalles: detalles);
    } catch (e) {
      throw DatabaseException(message: 'Error al obtener venta por pedido: $e');
    }
  }

  @override
  Future<List<PedidoModel>> getPedidosParaCobrar(String restaurantId) async {
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
          AND p.estado = 'finalizado'
        ORDER BY p.created_at ASC
        ''',
        [restaurantId],
      );

      final pedidoIds = results
          .map((row) => row['id'])
          .whereType<String>()
          .toList(growable: false);
      final itemsByPedido = await _getItemsByPedidoIds(pedidoIds);

      final pedidos = <PedidoModel>[];
      for (final row in results) {
        final mesaNombre =
            row['mesa_nombre'] as String? ??
            (row['mesa_numero'] != null ? 'Mesa ${row['mesa_numero']}' : null);
        final map = Map<String, dynamic>.from(row);
        map['mesa_nombre'] = mesaNombre;

        final pedidoId = row['id'] as String;
        final items = itemsByPedido[pedidoId] ?? const <PedidoItemModel>[];
        pedidos.add(PedidoModel.fromMap(map, items: items));
      }
      return pedidos;
    } catch (e) {
      throw DatabaseException(
        message: 'Error al obtener pedidos para cobrar: $e',
      );
    }
  }

  // ── Cotizaciones para cobrar ──────────────────────────────────

  @override
  Future<List<CotizacionModel>> getCotizacionesParaCobrar(
    String restaurantId,
  ) async {
    try {
      final results = await _dbHelper.rawQuery(
        '''
        SELECT *
        FROM $_tableCotizaciones
        WHERE restaurant_id = ?
          AND estado = 'aceptada'
        ORDER BY fecha_evento ASC, created_at ASC
        ''',
        [restaurantId],
      );

      final cotizacionIds = results
          .map((row) => row['id'])
          .whereType<String>()
          .toList(growable: false);
      final itemsByCotizacion = await _getCotizacionItemsByIds(cotizacionIds);

      final cotizaciones = <CotizacionModel>[];
      for (final row in results) {
        final cotizacionId = row['id'] as String;
        final items =
            itemsByCotizacion[cotizacionId] ?? const <CotizacionItemModel>[];
        cotizaciones.add(CotizacionModel.fromMap(row, items: items));
      }
      return cotizaciones;
    } catch (e) {
      throw DatabaseException(
        message: 'Error al obtener cotizaciones para cobrar: $e',
      );
    }
  }

  // ── Helpers privados ──────────────────────────────────────────

  Future<List<VentaDetalleModel>> _getDetallesByVenta(String ventaId) async {
    final results = await _dbHelper.query(
      _tableDetalles,
      where: 'venta_id = ?',
      whereArgs: [ventaId],
    );
    return results.map((r) => VentaDetalleModel.fromMap(r)).toList();
  }

  Future<Map<String, List<VentaDetalleModel>>> _getDetallesByVentaIds(
    List<String> ventaIds,
  ) async {
    if (ventaIds.isEmpty) return const {};

    final placeholders = List.filled(ventaIds.length, '?').join(',');
    final rows = await _dbHelper.rawQuery('''
      SELECT *
      FROM $_tableDetalles
      WHERE venta_id IN ($placeholders)
      ORDER BY venta_id ASC
      ''', ventaIds);

    final grouped = <String, List<VentaDetalleModel>>{};
    for (final row in rows) {
      final detalle = VentaDetalleModel.fromMap(row);
      grouped.putIfAbsent(detalle.ventaId, () => []).add(detalle);
    }
    return grouped;
  }

  Future<List<PedidoItemModel>> _getItemsByPedido(String pedidoId) async {
    final results = await _dbHelper.rawQuery(
      '''
      SELECT pi.*,
             p.nombre AS producto_nombre,
             v.nombre AS variante_nombre
      FROM $_tablePedidoItems pi
      LEFT JOIN productos p ON pi.producto_id = p.id
      LEFT JOIN variantes v ON pi.variante_id = v.id
      WHERE pi.pedido_id = ?
      ORDER BY pi.created_at ASC
      ''',
      [pedidoId],
    );
    return results.map((r) => PedidoItemModel.fromMap(r)).toList();
  }

  Future<Map<String, List<PedidoItemModel>>> _getItemsByPedidoIds(
    List<String> pedidoIds,
  ) async {
    if (pedidoIds.isEmpty) return const {};

    final placeholders = List.filled(pedidoIds.length, '?').join(',');
    final rows = await _dbHelper.rawQuery('''
      SELECT pi.*,
             p.nombre AS producto_nombre,
             v.nombre AS variante_nombre
      FROM $_tablePedidoItems pi
      LEFT JOIN productos p ON pi.producto_id = p.id
      LEFT JOIN variantes v ON pi.variante_id = v.id
      WHERE pi.pedido_id IN ($placeholders)
      ORDER BY pi.pedido_id ASC, pi.created_at ASC
      ''', pedidoIds);

    final grouped = <String, List<PedidoItemModel>>{};
    for (final row in rows) {
      final item = PedidoItemModel.fromMap(row);
      grouped.putIfAbsent(item.pedidoId, () => []).add(item);
    }
    return grouped;
  }

  Future<List<CotizacionItemModel>> _getCotizacionItems(
    String cotizacionId,
  ) async {
    final results = await _dbHelper.query(
      _tableCotizacionItems,
      where: 'cotizacion_id = ?',
      whereArgs: [cotizacionId],
      orderBy: 'rowid ASC',
    );
    return results.map((r) => CotizacionItemModel.fromMap(r)).toList();
  }

  Future<Map<String, List<CotizacionItemModel>>> _getCotizacionItemsByIds(
    List<String> cotizacionIds,
  ) async {
    if (cotizacionIds.isEmpty) return const {};

    final placeholders = List.filled(cotizacionIds.length, '?').join(',');
    final rows = await _dbHelper.rawQuery('''
      SELECT *
      FROM $_tableCotizacionItems
      WHERE cotizacion_id IN ($placeholders)
      ORDER BY cotizacion_id ASC, rowid ASC
      ''', cotizacionIds);

    final grouped = <String, List<CotizacionItemModel>>{};
    for (final row in rows) {
      final item = CotizacionItemModel.fromMap(row);
      grouped.putIfAbsent(item.cotizacionId, () => []).add(item);
    }
    return grouped;
  }

  String _extractSecuencial(String? claveAcceso) {
    final value = claveAcceso ?? '';
    if (value.length < 48) return '';
    return value.substring(30, 39);
  }
}
