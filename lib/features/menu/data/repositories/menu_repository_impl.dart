import 'package:dartz/dartz.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/menu/data/datasources/menu_local_datasource.dart';
import 'package:restaurant_app/features/menu/data/models/categoria_model.dart';
import 'package:restaurant_app/features/menu/data/models/producto_model.dart';
import 'package:restaurant_app/features/menu/data/models/variante_model.dart';
import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:restaurant_app/features/menu/domain/repositories/menu_repository.dart';

/// Implementación del [MenuRepository] que delega en el datasource local.
class MenuRepositoryImpl implements MenuRepository {
  final MenuLocalDataSource _dataSource;

  MenuRepositoryImpl({required MenuLocalDataSource dataSource})
      : _dataSource = dataSource;

  // ── Categorías ────────────────────────────────────────────────

  @override
  ResultFuture<List<Categoria>> getCategorias(String restaurantId) async {
    try {
      final result = await _dataSource.getCategorias(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Categoria?> getCategoriaById(String id) async {
    try {
      final result = await _dataSource.getCategoriaById(id);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> createCategoria(Categoria categoria) async {
    try {
      await _dataSource.createCategoria(
          CategoriaModel.fromEntity(categoria));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateCategoria(Categoria categoria) async {
    try {
      await _dataSource.updateCategoria(
          CategoriaModel.fromEntity(categoria));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> deleteCategoria(String id) async {
    try {
      await _dataSource.deleteCategoria(id);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> reordenarCategorias(List<String> orderedIds) async {
    try {
      await _dataSource.reordenarCategorias(orderedIds);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  // ── Productos ─────────────────────────────────────────────────

  @override
  ResultFuture<List<Producto>> getProductos(String restaurantId) async {
    try {
      final result = await _dataSource.getProductos(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Producto>> getProductosByCategoria(
      String categoriaId) async {
    try {
      final result =
          await _dataSource.getProductosByCategoria(categoriaId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Producto?> getProductoById(String id) async {
    try {
      final result = await _dataSource.getProductoById(id);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> createProducto(Producto producto) async {
    try {
      await _dataSource
          .createProducto(ProductoModel.fromEntity(producto));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateProducto(Producto producto) async {
    try {
      await _dataSource
          .updateProducto(ProductoModel.fromEntity(producto));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> deleteProducto(String id) async {
    try {
      await _dataSource.deleteProducto(id);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> toggleDisponibilidad(
      String id, bool disponible) async {
    try {
      await _dataSource.toggleDisponibilidad(id, disponible);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  // ── Variantes ─────────────────────────────────────────────────

  @override
  ResultFuture<List<Variante>> getVariantesByProducto(
      String productoId) async {
    try {
      final result = await _dataSource.getVariantesByProducto(productoId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> createVariante(Variante variante) async {
    try {
      await _dataSource
          .createVariante(VarianteModel.fromEntity(variante));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateVariante(Variante variante) async {
    try {
      await _dataSource
          .updateVariante(VarianteModel.fromEntity(variante));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> deleteVariante(String id) async {
    try {
      await _dataSource.deleteVariante(id);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }
}
