import 'package:dartz/dartz.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/mesas/data/datasources/llamado_local_datasource.dart';
import 'package:restaurant_app/features/mesas/data/models/llamado_mesero_model.dart';
import 'package:restaurant_app/features/mesas/domain/entities/llamado_mesero.dart';
import 'package:restaurant_app/features/mesas/domain/repositories/llamado_repository.dart';

/// Implementacion del repositorio de llamados a mesero.
class LlamadoRepositoryImpl implements LlamadoRepository {
  final LlamadoLocalDataSource _dataSource;

  LlamadoRepositoryImpl({required LlamadoLocalDataSource dataSource})
    : _dataSource = dataSource;

  @override
  ResultFuture<void> createLlamado(LlamadoMesero llamado) async {
    try {
      await _dataSource.createLlamado(LlamadoMeseroModel.fromEntity(llamado));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<LlamadoMesero>> getPendientes(String restaurantId) async {
    try {
      final result = await _dataSource.getPendientes(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> marcarAtendido(String id) async {
    try {
      await _dataSource.marcarAtendido(id);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }
}
