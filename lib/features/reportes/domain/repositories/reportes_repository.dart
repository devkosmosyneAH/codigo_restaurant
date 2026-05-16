import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_mesero.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_metodo_pago.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_producto_vendido.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_resumen.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_venta_dia.dart';

/// Contrato del repositorio de Reportes (capa de dominio).
abstract class ReportesRepository {
  ResultFuture<ResumenVentas> getResumenVentas({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  });

  ResultFuture<List<VentaPorDia>> getVentasPorDia({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  });

  ResultFuture<List<ProductoVendido>> getTopProductos({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    int limit = 10,
  });

  ResultFuture<List<VentaPorMetodo>> getVentasPorMetodo({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  });

  ResultFuture<List<VentaPorMesero>> getVentasPorMesero({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  });
}
