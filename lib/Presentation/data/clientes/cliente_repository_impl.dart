import 'package:dartz/dartz.dart';
import 'package:restaurant_app/Presentation/Models/clientes/cliente_model.dart';
import 'package:restaurant_app/Presentation/core/errors/exceptions.dart';
import 'package:restaurant_app/Presentation/core/errors/failures.dart';
import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/data/clientes/cliente_local_datasource.dart';
import 'package:restaurant_app/Presentation/domain/clientes/repositories/cliente_repository.dart';
import 'package:restaurant_app/Presentation/entities/clientes/cliente.dart';

/// Implementación del [ClienteRepository].
class ClienteRepositoryImpl implements ClienteRepository {
  const ClienteRepositoryImpl({required ClienteLocalDataSource dataSource})
    : _ds = dataSource;

  final ClienteLocalDataSource _ds;

  @override
  ResultFuture<List<Cliente>> getClientes(String restaurantId) async {
    try {
      final result = await _ds.getClientes(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Cliente?> getClienteByCedula(
    String restaurantId,
    String cedula,
  ) async {
    try {
      final result = await _ds.getClienteByCedula(restaurantId, cedula);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Cliente>> buscarClientes(
    String restaurantId,
    String query,
  ) async {
    try {
      final result = await _ds.buscarClientes(restaurantId, query);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Cliente> createCliente(Cliente cliente) async {
    try {
      final result = await _ds.createCliente(ClienteModel.fromEntity(cliente));
      return Right(result);
    } on BusinessException catch (e) {
      return Left(BusinessFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Cliente> updateCliente(Cliente cliente) async {
    try {
      final result = await _ds.updateCliente(ClienteModel.fromEntity(cliente));
      return Right(result);
    } on BusinessException catch (e) {
      return Left(BusinessFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> deleteCliente(String restaurantId, String cedula) async {
    try {
      await _ds.deleteCliente(restaurantId, cedula);
      return const Right(null);
    } on BusinessException catch (e) {
      return Left(BusinessFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<ClienteResumen> getResumenCliente(
    String cedula,
    String restaurantId,
  ) async {
    try {
      final result = await _ds.getResumenCliente(cedula, restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }
}
