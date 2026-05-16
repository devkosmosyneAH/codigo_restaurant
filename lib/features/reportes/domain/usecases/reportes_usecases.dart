import 'package:equatable/equatable.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_mesero.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_metodo_pago.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_producto_vendido.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_resumen.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_venta_dia.dart';
import 'package:restaurant_app/features/reportes/domain/repositories/reportes_repository.dart';

// ── Params compartidos ─────────────────────────────────────────────────────────

/// Parámetros base para todos los reportes con filtro de fecha.
class FiltroReporteParams extends Equatable {
  final String restaurantId;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  const FiltroReporteParams({
    required this.restaurantId,
    required this.fechaInicio,
    required this.fechaFin,
  });

  @override
  List<Object?> get props => [restaurantId, fechaInicio, fechaFin];
}

/// Parámetros para top productos (incluye límite).
class FiltroTopProductosParams extends FiltroReporteParams {
  final int limit;

  const FiltroTopProductosParams({
    required super.restaurantId,
    required super.fechaInicio,
    required super.fechaFin,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [...super.props, limit];
}

// ── Use Cases ──────────────────────────────────────────────────────────────────

/// Obtiene el resumen aggregado de ventas para el período.
class GetResumenVentas {
  const GetResumenVentas(this._repository);
  final ReportesRepository _repository;

  ResultFuture<ResumenVentas> call(FiltroReporteParams params) =>
      _repository.getResumenVentas(
        restaurantId: params.restaurantId,
        fechaInicio: params.fechaInicio,
        fechaFin: params.fechaFin,
      );
}

/// Obtiene las ventas agrupadas por día.
class GetVentasPorDia {
  const GetVentasPorDia(this._repository);
  final ReportesRepository _repository;

  ResultFuture<List<VentaPorDia>> call(FiltroReporteParams params) =>
      _repository.getVentasPorDia(
        restaurantId: params.restaurantId,
        fechaInicio: params.fechaInicio,
        fechaFin: params.fechaFin,
      );
}

/// Obtiene los productos más vendidos (por cantidad).
class GetTopProductos {
  const GetTopProductos(this._repository);
  final ReportesRepository _repository;

  ResultFuture<List<ProductoVendido>> call(FiltroTopProductosParams params) =>
      _repository.getTopProductos(
        restaurantId: params.restaurantId,
        fechaInicio: params.fechaInicio,
        fechaFin: params.fechaFin,
        limit: params.limit,
      );
}

/// Obtiene las ventas agrupadas por método de pago.
class GetVentasPorMetodo {
  const GetVentasPorMetodo(this._repository);
  final ReportesRepository _repository;

  ResultFuture<List<VentaPorMetodo>> call(FiltroReporteParams params) =>
      _repository.getVentasPorMetodo(
        restaurantId: params.restaurantId,
        fechaInicio: params.fechaInicio,
        fechaFin: params.fechaFin,
      );
}

/// Obtiene las ventas agrupadas por mesero/cajero.
class GetVentasPorMesero {
  const GetVentasPorMesero(this._repository);
  final ReportesRepository _repository;

  ResultFuture<List<VentaPorMesero>> call(FiltroReporteParams params) =>
      _repository.getVentasPorMesero(
        restaurantId: params.restaurantId,
        fechaInicio: params.fechaInicio,
        fechaFin: params.fechaFin,
      );
}
