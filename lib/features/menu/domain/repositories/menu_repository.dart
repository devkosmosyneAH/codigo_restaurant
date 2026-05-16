import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';

/// Contrato del repositorio de Menú (dominio).
abstract class MenuRepository {
  // ── Categorías ────────────────────────────────────────────────
  ResultFuture<List<Categoria>> getCategorias(String restaurantId);
  ResultFuture<Categoria?> getCategoriaById(String id);
  ResultFuture<void> createCategoria(Categoria categoria);
  ResultFuture<void> updateCategoria(Categoria categoria);
  ResultFuture<void> deleteCategoria(String id);
  ResultFuture<void> reordenarCategorias(List<String> orderedIds);

  // ── Productos ─────────────────────────────────────────────────
  ResultFuture<List<Producto>> getProductos(String restaurantId);
  ResultFuture<List<Producto>> getProductosByCategoria(String categoriaId);
  ResultFuture<Producto?> getProductoById(String id);
  ResultFuture<void> createProducto(Producto producto);
  ResultFuture<void> updateProducto(Producto producto);
  ResultFuture<void> deleteProducto(String id);
  ResultFuture<void> toggleDisponibilidad(String id, bool disponible);

  // ── Variantes ─────────────────────────────────────────────────
  ResultFuture<List<Variante>> getVariantesByProducto(String productoId);
  ResultFuture<void> createVariante(Variante variante);
  ResultFuture<void> updateVariante(Variante variante);
  ResultFuture<void> deleteVariante(String id);
}
