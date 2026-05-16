import 'package:dartz/dartz.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/pedidos/data/datasources/pedido_local_datasource.dart';
import 'package:restaurant_app/features/pedidos/data/models/pedido_item_model.dart';
import 'package:restaurant_app/features/pedidos/data/models/pedido_model.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';
import 'package:restaurant_app/features/pedidos/domain/repositories/pedido_repository.dart';

/// Implementación del repositorio de Pedidos.
///
/// Maneja la conversión de excepciones a [Failure] y
/// coordina entre datasource local y sync manager.
class PedidoRepositoryImpl implements PedidoRepository {
  final PedidoLocalDataSource _localDataSource;

  PedidoRepositoryImpl({required PedidoLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  // ── Pedidos ──────────────────────────────────────────────────────

  @override
  ResultFuture<List<Pedido>> getPedidos(String restaurantId) async {
    try {
      final result = await _localDataSource.getPedidos(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Pedido>> getPedidosActivos(
      String restaurantId) async {
    try {
      final result =
          await _localDataSource.getPedidosActivos(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Pedido>> getPedidosByMesa(String mesaId) async {
    try {
      final result = await _localDataSource.getPedidosByMesa(mesaId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Pedido> getPedidoById(String id) async {
    try {
      final result = await _localDataSource.getPedidoById(id);
      if (result == null) {
        return const Left(
          DatabaseFailure(message: 'Pedido no encontrado'),
        );
      }
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> createPedido(Pedido pedido) async {
    try {
      await _localDataSource
          .createPedido(PedidoModel.fromEntity(pedido));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updatePedido(Pedido pedido) async {
    try {
      await _localDataSource
          .updatePedido(PedidoModel.fromEntity(pedido));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateEstadoPedido(String id, String estado) async {
    try {
      await _localDataSource.updateEstadoPedido(id, estado);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> deletePedido(String id) async {
    try {
      await _localDataSource.deletePedido(id);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  // ── Items ────────────────────────────────────────────────────────

  @override
  ResultFuture<List<PedidoItem>> getItemsByPedido(
      String pedidoId) async {
    try {
      final result = await _localDataSource.getItemsByPedido(pedidoId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> addItem(PedidoItem item) async {
    try {
      await _localDataSource
          .addItem(PedidoItemModel.fromEntity(item));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateItem(PedidoItem item) async {
    try {
      await _localDataSource
          .updateItem(PedidoItemModel.fromEntity(item));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> deleteItem(String itemId) async {
    try {
      await _localDataSource.deleteItem(itemId);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateEstadoItem(
      String itemId, String estado) async {
    try {
      await _localDataSource.updateEstadoItem(itemId, estado);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }
}
