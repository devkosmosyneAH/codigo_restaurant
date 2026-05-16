import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:restaurant_app/features/menu/domain/repositories/menu_repository.dart';

// ═══════════════════════════════════════════════════════════════
// CATEGORÍAS
// ═══════════════════════════════════════════════════════════════

class GetCategorias {
  final MenuRepository _repo;
  GetCategorias(this._repo);
  ResultFuture<List<Categoria>> call(String restaurantId) =>
      _repo.getCategorias(restaurantId);
}

class GetCategoriaById {
  final MenuRepository _repo;
  GetCategoriaById(this._repo);
  ResultFuture<Categoria?> call(String id) => _repo.getCategoriaById(id);
}

class CreateCategoria {
  final MenuRepository _repo;
  CreateCategoria(this._repo);
  ResultFuture<void> call(Categoria categoria) =>
      _repo.createCategoria(categoria);
}

class UpdateCategoria {
  final MenuRepository _repo;
  UpdateCategoria(this._repo);
  ResultFuture<void> call(Categoria categoria) =>
      _repo.updateCategoria(categoria);
}

class DeleteCategoria {
  final MenuRepository _repo;
  DeleteCategoria(this._repo);
  ResultFuture<void> call(String id) => _repo.deleteCategoria(id);
}

class ReordenarCategorias {
  final MenuRepository _repo;
  ReordenarCategorias(this._repo);
  ResultFuture<void> call(List<String> orderedIds) =>
      _repo.reordenarCategorias(orderedIds);
}

// ═══════════════════════════════════════════════════════════════
// PRODUCTOS
// ═══════════════════════════════════════════════════════════════

class GetProductos {
  final MenuRepository _repo;
  GetProductos(this._repo);
  ResultFuture<List<Producto>> call(String restaurantId) =>
      _repo.getProductos(restaurantId);
}

class GetProductosByCategoria {
  final MenuRepository _repo;
  GetProductosByCategoria(this._repo);
  ResultFuture<List<Producto>> call(String categoriaId) =>
      _repo.getProductosByCategoria(categoriaId);
}

class GetProductoById {
  final MenuRepository _repo;
  GetProductoById(this._repo);
  ResultFuture<Producto?> call(String id) => _repo.getProductoById(id);
}

class CreateProducto {
  final MenuRepository _repo;
  CreateProducto(this._repo);
  ResultFuture<void> call(Producto producto) =>
      _repo.createProducto(producto);
}

class UpdateProducto {
  final MenuRepository _repo;
  UpdateProducto(this._repo);
  ResultFuture<void> call(Producto producto) =>
      _repo.updateProducto(producto);
}

class DeleteProducto {
  final MenuRepository _repo;
  DeleteProducto(this._repo);
  ResultFuture<void> call(String id) => _repo.deleteProducto(id);
}

class ToggleDisponibilidad {
  final MenuRepository _repo;
  ToggleDisponibilidad(this._repo);
  ResultFuture<void> call(String id, bool disponible) =>
      _repo.toggleDisponibilidad(id, disponible);
}

// ═══════════════════════════════════════════════════════════════
// VARIANTES
// ═══════════════════════════════════════════════════════════════

class GetVariantesByProducto {
  final MenuRepository _repo;
  GetVariantesByProducto(this._repo);
  ResultFuture<List<Variante>> call(String productoId) =>
      _repo.getVariantesByProducto(productoId);
}

class CreateVariante {
  final MenuRepository _repo;
  CreateVariante(this._repo);
  ResultFuture<void> call(Variante variante) =>
      _repo.createVariante(variante);
}

class UpdateVariante {
  final MenuRepository _repo;
  UpdateVariante(this._repo);
  ResultFuture<void> call(Variante variante) =>
      _repo.updateVariante(variante);
}

class DeleteVariante {
  final MenuRepository _repo;
  DeleteVariante(this._repo);
  ResultFuture<void> call(String id) => _repo.deleteVariante(id);
}
