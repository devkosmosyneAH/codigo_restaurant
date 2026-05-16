import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/reportes/data/datasources/reportes_local_datasource.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_mesero.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_metodo_pago.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_producto_vendido.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_resumen.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_venta_dia.dart';

/// Implementación SQLite del datasource de Reportes.
///
/// Ejecuta consultas agregadas (GROUP BY, SUM, COUNT, AVG) sobre
/// las tablas [ventas] y [venta_detalles] para generar métricas de negocio.
class ReportesLocalDataSourceImpl implements ReportesLocalDataSource {
  const ReportesLocalDataSourceImpl({required DatabaseHelper dbHelper})
    : _dbHelper = dbHelper;

  final DatabaseHelper _dbHelper;

  /// Formato 'yyyy-MM-dd' para comparaciones SQLite con date().
  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ResumenVentas> getResumenVentas({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final results = await _dbHelper.rawQuery(
      '''
      SELECT
        COUNT(*)           AS cantidad,
        IFNULL(SUM(total), 0)  AS total_sum,
        IFNULL(AVG(total), 0)  AS promedio,
        IFNULL(MAX(total), 0)  AS maximo,
        IFNULL(MIN(total), 0)  AS minimo
      FROM ventas
      WHERE restaurant_id = ?
        AND date(created_at) BETWEEN date(?) AND date(?)
      ''',
      [restaurantId, _fmt(fechaInicio), _fmt(fechaFin)],
    );

    final row = results.isNotEmpty ? results.first : <String, Object?>{};
    final cantidad = (row['cantidad'] as int?) ?? 0;

    return ResumenVentas(
      cantidadVentas: cantidad,
      totalVentas: (row['total_sum'] as num?)?.toDouble() ?? 0.0,
      promedioTicket: (row['promedio'] as num?)?.toDouble() ?? 0.0,
      ticketMaximo: cantidad > 0
          ? (row['maximo'] as num?)?.toDouble() ?? 0.0
          : 0.0,
      ticketMinimo: cantidad > 0
          ? (row['minimo'] as num?)?.toDouble() ?? 0.0
          : 0.0,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
    );
  }

  @override
  Future<List<VentaPorDia>> getVentasPorDia({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final results = await _dbHelper.rawQuery(
      '''
      SELECT
        date(created_at)   AS fecha,
        COUNT(*)           AS cantidad,
        SUM(total)         AS total
      FROM ventas
      WHERE restaurant_id = ?
        AND date(created_at) BETWEEN date(?) AND date(?)
      GROUP BY date(created_at)
      ORDER BY fecha ASC
      ''',
      [restaurantId, _fmt(fechaInicio), _fmt(fechaFin)],
    );

    return results
        .map(
          (row) => VentaPorDia(
            fecha: row['fecha'] as String,
            cantidadVentas: (row['cantidad'] as int?) ?? 0,
            total: (row['total'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();
  }

  @override
  Future<List<ProductoVendido>> getTopProductos({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    int limit = 10,
  }) async {
    final results = await _dbHelper.rawQuery(
      '''
      SELECT
        vd.producto_id,
        p.nombre,
        c.nombre        AS categoria_nombre,
        SUM(vd.cantidad)  AS cantidad_vendida,
        SUM(vd.subtotal)  AS total_ingresado
      FROM venta_detalles vd
      JOIN ventas   v ON vd.venta_id    = v.id
      JOIN productos p ON vd.producto_id = p.id
      LEFT JOIN categorias c ON p.categoria_id = c.id
      WHERE v.restaurant_id = ?
        AND date(v.created_at) BETWEEN date(?) AND date(?)
      GROUP BY vd.producto_id, p.nombre, c.nombre
      ORDER BY cantidad_vendida DESC
      LIMIT ?
      ''',
      [restaurantId, _fmt(fechaInicio), _fmt(fechaFin), limit],
    );

    return results
        .map(
          (row) => ProductoVendido(
            productoId: row['producto_id'] as String,
            nombre: row['nombre'] as String,
            categoriaNombre: row['categoria_nombre'] as String?,
            cantidadVendida: (row['cantidad_vendida'] as num?)?.toInt() ?? 0,
            totalIngresado: (row['total_ingresado'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();
  }

  @override
  Future<List<VentaPorMetodo>> getVentasPorMetodo({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final results = await _dbHelper.rawQuery(
      '''
      SELECT
        metodo_pago,
        COUNT(*)   AS cantidad,
        SUM(total) AS total
      FROM ventas
      WHERE restaurant_id = ?
        AND date(created_at) BETWEEN date(?) AND date(?)
      GROUP BY metodo_pago
      ORDER BY total DESC
      ''',
      [restaurantId, _fmt(fechaInicio), _fmt(fechaFin)],
    );

    final grandTotal = results.fold<double>(
      0.0,
      (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0.0),
    );

    return results.map((row) {
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      return VentaPorMetodo(
        metodoPago: MetodoPago.values.firstWhere(
          (m) => m.name == row['metodo_pago'],
          orElse: () => MetodoPago.efectivo,
        ),
        cantidad: (row['cantidad'] as int?) ?? 0,
        total: total,
        porcentaje: grandTotal > 0 ? (total / grandTotal) * 100 : 0.0,
      );
    }).toList();
  }

  @override
  Future<List<VentaPorMesero>> getVentasPorMesero({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final results = await _dbHelper.rawQuery(
      '''
      SELECT
        v.cajero_id AS mesero_id,
        COALESCE(u.nombre, 'Sin asignar') AS nombre,
        COUNT(v.id)   AS cantidad_pedidos,
        SUM(v.total)  AS total
      FROM ventas v
      LEFT JOIN usuarios u ON v.cajero_id = u.id
      WHERE v.restaurant_id = ?
        AND date(v.created_at) BETWEEN date(?) AND date(?)
      GROUP BY v.cajero_id
      ORDER BY total DESC
      ''',
      [restaurantId, _fmt(fechaInicio), _fmt(fechaFin)],
    );

    return results
        .map(
          (row) => VentaPorMesero(
            meseroId: row['mesero_id'] as String?,
            nombre: row['nombre'] as String,
            cantidadPedidos: (row['cantidad_pedidos'] as int?) ?? 0,
            total: (row['total'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();
  }
}
