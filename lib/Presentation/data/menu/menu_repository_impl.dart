import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurant_app/Presentation/Models/menu/categoria_model.dart';
import 'package:restaurant_app/Presentation/Models/menu/producto_model.dart';
import 'package:restaurant_app/Presentation/Models/menu/variante_model.dart';
import 'package:restaurant_app/Presentation/core/errors/exceptions.dart';
import 'package:restaurant_app/Presentation/core/errors/failures.dart';
import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/data/menu/menu_local_datasource.dart';
import 'package:restaurant_app/Presentation/domain/menu/repositories/menu_repository.dart';
import 'package:restaurant_app/Presentation/entities/menu/categoria.dart';
import 'package:restaurant_app/Presentation/entities/menu/producto.dart';
import 'package:restaurant_app/Presentation/entities/menu/variante.dart';

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
      await _dataSource.createCategoria(CategoriaModel.fromEntity(categoria));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateCategoria(Categoria categoria) async {
    try {
      await _dataSource.updateCategoria(CategoriaModel.fromEntity(categoria));
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
    String categoriaId,
  ) async {
    try {
      final result = await _dataSource.getProductosByCategoria(categoriaId);
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
      await _dataSource.createProducto(ProductoModel.fromEntity(producto));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateProducto(Producto producto) async {
    try {
      await _dataSource.updateProducto(ProductoModel.fromEntity(producto));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> deleteProducto(String id) async {
    try {
      debugPrint('MENU_REPOSITORY_DELETE [1] Entrando al repository');
      debugPrint('MENU_REPOSITORY_DELETE [2] Producto id=$id');
      await _dataSource.deleteProducto(id);
      debugPrint('MENU_REPOSITORY_DELETE [3] DataSource completó eliminación');
      return const Right(null);
    } on DatabaseException catch (e) {
      debugPrint('MENU_REPOSITORY_DELETE ERROR ${e.message}');
      return Left(DatabaseFailure(message: e.message));
    } catch (e, s) {
      debugPrint('MENU_REPOSITORY_DELETE ERROR');
      debugPrint(e.toString());
      debugPrint(s.toString());
      rethrow;
    }
  }

  @override
  ResultFuture<void> toggleDisponibilidad(String id, bool disponible) async {
    try {
      await _dataSource.toggleDisponibilidad(id, disponible);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  // ── Variantes ─────────────────────────────────────────────────

  @override
  ResultFuture<List<Variante>> getVariantesByProducto(String productoId) async {
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
      await _dataSource.createVariante(VarianteModel.fromEntity(variante));
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> updateVariante(Variante variante) async {
    try {
      await _dataSource.updateVariante(VarianteModel.fromEntity(variante));
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
