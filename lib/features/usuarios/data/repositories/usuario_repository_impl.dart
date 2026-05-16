import 'package:dartz/dartz.dart';
import 'package:restaurant_app/core/errors/exceptions.dart'
    show BusinessException;
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/usuarios/data/datasources/usuario_local_datasource.dart';
import 'package:restaurant_app/features/usuarios/data/models/usuario_model.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';
import 'package:restaurant_app/features/usuarios/domain/repositories/usuario_repository.dart';
import 'package:sqflite_common/sqlite_api.dart';

class UsuarioRepositoryImpl implements UsuarioRepository {
  const UsuarioRepositoryImpl({required UsuarioLocalDataSource localDataSource})
    : _dataSource = localDataSource;

  final UsuarioLocalDataSource _dataSource;

  @override
  ResultFuture<List<Usuario>> getUsuarios(String restaurantId) async {
    try {
      final result = await _dataSource.getUsuarios(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<Usuario?> getUsuarioById(String id) async {
    try {
      final result = await _dataSource.getUsuarioById(id);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<Usuario> createUsuario(Usuario usuario) async {
    try {
      final model = UsuarioModel.fromEntity(usuario);
      final result = await _dataSource.createUsuario(model);
      return Right(result);
    } on BusinessException catch (e) {
      return Left(ValidationFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<Usuario> updateUsuario(Usuario usuario) async {
    try {
      final model = UsuarioModel.fromEntity(usuario);
      final result = await _dataSource.updateUsuario(model);
      return Right(result);
    } on BusinessException catch (e) {
      return Left(ValidationFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<void> deleteUsuario(String id) async {
    try {
      await _dataSource.deleteUsuario(id);
      return const Right(null);
    } on BusinessException catch (e) {
      return Left(ValidationFailure(message: e.message));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<Usuario?> verificarPin(String restaurantId, String pin) async {
    try {
      final result = await _dataSource.verificarPin(restaurantId, pin);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<List<Usuario>> getUsuariosByRol(
    String restaurantId,
    String rol,
  ) async {
    try {
      final result = await _dataSource.getUsuariosByRol(restaurantId, rol);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }
}
