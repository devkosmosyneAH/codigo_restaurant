import 'package:dartz/dartz.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/mesas/data/datasources/mesa_local_datasource.dart';
import 'package:restaurant_app/features/mesas/data/models/mesa_model.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';
import 'package:restaurant_app/features/mesas/domain/repositories/mesa_repository.dart';

/// Implementación del repositorio de Mesas.
///
/// Maneja la conversión de excepciones a [Failure] y
/// coordina entre datasource local y sync manager.
class MesaRepositoryImpl implements MesaRepository {
  final MesaLocalDataSource _localDataSource;

  MesaRepositoryImpl({required MesaLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  @override
  ResultFuture<List<Mesa>> getMesas(String restaurantId) async {
    try {
      final result = await _localDataSource.getMesas(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Mesa> getMesaById(String id) async {
    try {
      final result = await _localDataSource.getMesaById(id);
      if (result == null) {
        return const Left(
          DatabaseFailure(message: 'Mesa no encontrada'),
        );
      }
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> createMesa(Mesa mesa) async {
    try {
      await _localDataSource.createMesa(MesaModel.fromEntity(mesa));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateMesa(Mesa mesa) async {
    try {
      await _localDataSource.updateMesa(MesaModel.fromEntity(mesa));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> deleteMesa(String id) async {
    try {
      await _localDataSource.deleteMesa(id);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateEstadoMesa(String id, String estado) async {
    try {
      await _localDataSource.updateEstadoMesa(id, estado);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> unirMesas(
      List<String> mesaIds, String unionId) async {
    try {
      await _localDataSource.unirMesas(mesaIds, unionId);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> separarMesas(String unionId) async {
    try {
      await _localDataSource.separarMesas(unionId);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<int> getNextNumeroMesa(String restaurantId) async {
    try {
      final result =
          await _localDataSource.getNextNumeroMesa(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }
}
