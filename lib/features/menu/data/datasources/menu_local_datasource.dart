import 'package:restaurant_app/features/menu/data/models/categoria_model.dart';
import 'package:restaurant_app/features/menu/data/models/producto_model.dart';
import 'package:restaurant_app/features/menu/data/models/variante_model.dart';

/// Contrato del datasource local para el Menú.
///
/// Define las operaciones CRUD contra SQLite para:
/// - Categorías
/// - Productos (con variantes)
/// - Variantes
abstract class MenuLocalDataSource {
  // ── Categorías ───────────────────────────────────────────────────

  /// Obtiene todas las categorías activas de un restaurante.
  Future<List<CategoriaModel>> getCategorias(String restaurantId);

  /// Obtiene una categoría por ID.
  Future<CategoriaModel?> getCategoriaById(String id);

  /// Crea una nueva categoría.
  Future<void> createCategoria(CategoriaModel categoria);

  /// Actualiza una categoría.
  Future<void> updateCategoria(CategoriaModel categoria);

  /// Elimina (soft delete) una categoría.
  Future<void> deleteCategoria(String id);

  /// Reordena las categorías.
  Future<void> reordenarCategorias(List<String> orderedIds);

  // ── Productos ────────────────────────────────────────────────────

  /// Obtiene todos los productos activos de un restaurante (con variantes).
  Future<List<ProductoModel>> getProductos(String restaurantId);

  /// Obtiene productos por categoría.
  Future<List<ProductoModel>> getProductosByCategoria(String categoriaId);

  /// Obtiene un producto por ID (con variantes).
  Future<ProductoModel?> getProductoById(String id);

  /// Crea un nuevo producto.
  Future<void> createProducto(ProductoModel producto);

  /// Actualiza un producto.
  Future<void> updateProducto(ProductoModel producto);

  /// Elimina (soft delete) un producto y sus variantes.
  Future<void> deleteProducto(String id);

  /// Cambia la disponibilidad de un producto (toggle activo en carta).
  Future<void> toggleDisponibilidad(String id, bool disponible);

  // ── Variantes ────────────────────────────────────────────────────

  /// Obtiene las variantes de un producto.
  Future<List<VarianteModel>> getVariantesByProducto(String productoId);

  /// Crea una nueva variante.
  Future<void> createVariante(VarianteModel variante);

  /// Actualiza una variante.
  Future<void> updateVariante(VarianteModel variante);

  /// Elimina una variante.
  Future<void> deleteVariante(String id);
}
