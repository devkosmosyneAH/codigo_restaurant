import 'package:dartz/dartz.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/cotizaciones/data/datasources/cotizacion_local_datasource.dart';
import 'package:restaurant_app/features/cotizaciones/data/models/cotizacion_model.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/repositories/cotizacion_repository.dart';

/// Implementacion del repositorio de cotizaciones.
class CotizacionRepositoryImpl implements CotizacionRepository {
  final CotizacionLocalDataSource _dataSource;

  CotizacionRepositoryImpl({required CotizacionLocalDataSource dataSource})
    : _dataSource = dataSource;

  @override
  ResultFuture<void> createCotizacion(Cotizacion cotizacion) async {
    try {
      await _dataSource.createCotizacion(
        CotizacionModel.fromEntity(cotizacion),
      );
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Cotizacion>> getCotizaciones(String restaurantId) async {
    try {
      final rows = await _dataSource.getCotizaciones(restaurantId);
      return Right(rows);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateEstado(String cotizacionId, String estado) async {
    try {
      await _dataSource.updateEstado(cotizacionId, estado);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateCotizacion(Cotizacion cotizacion) async {
    try {
      await _dataSource.updateCotizacion(
        CotizacionModel.fromEntity(cotizacion),
      );
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> deleteCotizacion(String cotizacionId) async {
    try {
      await _dataSource.deleteCotizacion(cotizacionId);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }
}
