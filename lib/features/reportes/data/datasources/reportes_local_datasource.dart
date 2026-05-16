import 'package:restaurant_app/features/reportes/domain/entities/reporte_mesero.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_metodo_pago.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_producto_vendido.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_resumen.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_venta_dia.dart';

/// Contrato del datasource local para el módulo de Reportes.
abstract class ReportesLocalDataSource {
  /// Resumen agregado (totales, promedio, máximo, mínimo) para el período.
  Future<ResumenVentas> getResumenVentas({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  });

  /// Ventas agrupadas por día (para gráfica de barras/línea).
  Future<List<VentaPorDia>> getVentasPorDia({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  });

  /// Productos más vendidos por cantidad en el período.
  Future<List<ProductoVendido>> getTopProductos({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    int limit = 10,
  });

  /// Ventas agrupadas por método de pago con porcentaje calculado.
  Future<List<VentaPorMetodo>> getVentasPorMetodo({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  });

  /// Ventas agrupadas por mesero/cajero.
  Future<List<VentaPorMesero>> getVentasPorMesero({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  });
}
