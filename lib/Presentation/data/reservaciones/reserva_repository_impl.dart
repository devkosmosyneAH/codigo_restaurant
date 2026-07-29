import 'package:dartz/dartz.dart';
import 'package:restaurant_app/Presentation/Models/reservaciones/reserva_model.dart';
import 'package:restaurant_app/Presentation/core/errors/exceptions.dart';
import 'package:restaurant_app/Presentation/core/errors/failures.dart';
import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/data/reservaciones/reserva_local_datasource.dart';
import 'package:restaurant_app/Presentation/domain/reservaciones/repositories/reserva_repository.dart';
import 'package:restaurant_app/Presentation/entities/reservaciones/reserva.dart';

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