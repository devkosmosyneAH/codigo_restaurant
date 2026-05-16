import 'package:dartz/dartz.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/reservaciones/data/datasources/reserva_local_datasource.dart';
import 'package:restaurant_app/features/reservaciones/data/models/reserva_model.dart';
import 'package:restaurant_app/features/reservaciones/domain/entities/reserva.dart';
import 'package:restaurant_app/features/reservaciones/domain/repositories/reserva_repository.dart';

/// Implementacion del repositorio de reservaciones.
class ReservaRepositoryImpl implements ReservaRepository {
  final ReservaLocalDataSource _dataSource;

  ReservaRepositoryImpl({required ReservaLocalDataSource dataSource})
    : _dataSource = dataSource;

  @override
  ResultFuture<void> createReserva(Reserva reserva) async {
    try {
      await _dataSource.createReserva(ReservaModel.fromEntity(reserva));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateReserva(Reserva reserva) async {
    try {
      await _dataSource.updateReserva(ReservaModel.fromEntity(reserva));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Reserva>> getReservasByMonth(
    String restaurantId,
    String startDate,
    String endDate,
  ) async {
    try {
      final result = await _dataSource.getReservasByMonth(
        restaurantId,
        startDate,
        endDate,
      );
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Reserva>> getReservasByDate(
    String restaurantId,
    String date,
  ) async {
    try {
      final result = await _dataSource.getReservasByDate(restaurantId, date);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }
}
