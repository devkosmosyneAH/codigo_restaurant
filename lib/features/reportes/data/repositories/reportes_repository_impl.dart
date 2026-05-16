import 'package:dartz/dartz.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/reportes/data/datasources/reportes_local_datasource.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_mesero.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_metodo_pago.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_producto_vendido.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_resumen.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_venta_dia.dart';
import 'package:restaurant_app/features/reportes/domain/repositories/reportes_repository.dart';
import 'package:sqflite_common/sqlite_api.dart';

class ReportesRepositoryImpl implements ReportesRepository {
  const ReportesRepositoryImpl({required ReportesLocalDataSource dataSource})
    : _dataSource = dataSource;

  final ReportesLocalDataSource _dataSource;

  @override
  ResultFuture<ResumenVentas> getResumenVentas({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    try {
      final result = await _dataSource.getResumenVentas(
        restaurantId: restaurantId,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<List<VentaPorDia>> getVentasPorDia({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    try {
      final result = await _dataSource.getVentasPorDia(
        restaurantId: restaurantId,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<List<ProductoVendido>> getTopProductos({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    int limit = 10,
  }) async {
    try {
      final result = await _dataSource.getTopProductos(
        restaurantId: restaurantId,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        limit: limit,
      );
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<List<VentaPorMetodo>> getVentasPorMetodo({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    try {
      final result = await _dataSource.getVentasPorMetodo(
        restaurantId: restaurantId,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<List<VentaPorMesero>> getVentasPorMesero({
    required String restaurantId,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    try {
      final result = await _dataSource.getVentasPorMesero(
        restaurantId: restaurantId,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }
}
