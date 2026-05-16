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
  static const _tableSriComprobantes = 'sri_comprobantes';
  static const _tableSriAttempts = 'sri_attempts';

  // ── Registro de venta ─────────────────────────────────────────

  @override
  Future<void> registrarVenta(VentaModel venta, {String? mesaId}) async {
    try {
      await _dbHelper.transaction((txn) async {
        // 1. Insertar venta principal
        await txn.insert(_tableVentas, venta.toMap());

        if (venta.sriComprobanteId != null) {
          final now = DateTime.now().toIso8601String();
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
            'created_at': now,
            'updated_at': now,
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
                ? now
                : null,
            'payload_hash': venta.sriXmlHash,
            'created_at': now,
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
          {
            'estado': 'entregado',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [venta.pedidoId],
        );

        // 4. Liberar la mesa si aplica
        if (mesaId != null) {
          await txn.update(
            _tableMesas,
            {'estado': 'libre', 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [mesaId],
          );
        }

        // 5. Marcar la cotización como cobrada si aplica
        if (venta.sourceCotizacionId != null) {
          await txn.update(
            _tableCotizaciones,
            {'estado': 'cobrada'},
            where: 'id = ?',
            whereArgs: [venta.sourceCotizacionId],
          );

          // 6. Marcar la reserva asociada como 'realizada' si existe
          await txn.rawUpdate(
            "UPDATE reservaciones SET estado = 'realizada' "
            'WHERE cotizacion_id = ?',
            [venta.sourceCotizacionId],
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
      datos: venta.toMap(),
    );
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

      final ventas = <VentaModel>[];
      for (final row in results) {
        final detalles = await _getDetallesByVenta(row['id'] as String);
        ventas.add(VentaModel.fromMap(row, detalles: detalles));
      }
      return ventas;
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

      final ventas = <VentaModel>[];
      for (final row in results) {
        final detalles = await _getDetallesByVenta(row['id'] as String);
        ventas.add(VentaModel.fromMap(row, detalles: detalles));
      }
      return ventas;
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

      final pedidos = <PedidoModel>[];
      for (final row in results) {
        final mesaNombre =
            row['mesa_nombre'] as String? ??
            (row['mesa_numero'] != null ? 'Mesa ${row['mesa_numero']}' : null);
        final map = Map<String, dynamic>.from(row);
        map['mesa_nombre'] = mesaNombre;

        final items = await _getItemsByPedido(row['id'] as String);
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

      final cotizaciones = <CotizacionModel>[];
      for (final row in results) {
        final items = await _getCotizacionItems(row['id'] as String);
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

  String _extractSecuencial(String? claveAcceso) {
    final value = claveAcceso ?? '';
    if (value.length < 48) return '';
    return value.substring(30, 39);
  }
}
