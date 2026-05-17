import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:restaurant_app/features/menu/domain/repositories/menu_repository.dart';
import 'package:restaurant_app/features/menu/domain/usecases/menu_usecases.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';

void main() {
  group('Menu externo rendimiento de carga', () {
    test('deduplica cargas concurrentes y evita consultas repetidas', () async {
      final repo = _FakeMenuRepository(delay: const Duration(milliseconds: 25));
      final notifier = MenuNotifier(
        getCategorias: GetCategorias(repo),
        createCategoria: CreateCategoria(repo),
        updateCategoria: UpdateCategoria(repo),
        deleteCategoria: DeleteCategoria(repo),
        reordenarCategorias: ReordenarCategorias(repo),
        getProductos: GetProductos(repo),
        createProducto: CreateProducto(repo),
        updateProducto: UpdateProducto(repo),
        deleteProducto: DeleteProducto(repo),
        toggleDisponibilidad: ToggleDisponibilidad(repo),
        createVariante: CreateVariante(repo),
        updateVariante: UpdateVariante(repo),
        deleteVariante: DeleteVariante(repo),
      );

      await Future.wait(
        List.generate(30, (_) => notifier.loadMenu('rest-1', true)),
      );

      expect(repo.getCategoriasCalls, 1);
      expect(repo.getProductosCalls, 1);
      expect(notifier.state.totalCategorias, 1);
      expect(notifier.state.totalProductos, 1);
    });
  });
}

class _FakeMenuRepository implements MenuRepository {
  _FakeMenuRepository({required this.delay});

  final Duration delay;
  int getCategoriasCalls = 0;
  int getProductosCalls = 0;

  @override
  ResultFuture<void> createCategoria(Categoria categoria) async =>
      const Right(null);

  @override
  ResultFuture<void> createProducto(Producto producto) async =>
      const Right(null);

  @override
  ResultFuture<void> createVariante(Variante variante) async =>
      const Right(null);

  @override
  ResultFuture<void> deleteCategoria(String id) async => const Right(null);

  @override
  ResultFuture<void> deleteProducto(String id) async => const Right(null);

  @override
  ResultFuture<void> deleteVariante(String id) async => const Right(null);

  @override
  ResultFuture<Categoria?> getCategoriaById(String id) async =>
      const Right(null);

  @override
  ResultFuture<List<Categoria>> getCategorias(String restaurantId) async {
    getCategoriasCalls++;
    await Future<void>.delayed(delay);
    final now = DateTime(2026, 1, 1);
    return Right([
      Categoria(
        id: 'cat-1',
        restaurantId: restaurantId,
        nombre: 'Bebidas',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  @override
  ResultFuture<Producto?> getProductoById(String id) async => const Right(null);

  @override
  ResultFuture<List<Producto>> getProductos(String restaurantId) async {
    getProductosCalls++;
    await Future<void>.delayed(delay);
    final now = DateTime(2026, 1, 1);
    return Right([
      Producto(
        id: 'prod-1',
        restaurantId: restaurantId,
        categoriaId: 'cat-1',
        nombre: 'Cafe',
        precio: 2,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  @override
  ResultFuture<List<Producto>> getProductosByCategoria(
    String categoriaId,
  ) async => const Right([]);

  @override
  ResultFuture<List<Variante>> getVariantesByProducto(
    String productoId,
  ) async => const Right([]);

  @override
  ResultFuture<void> reordenarCategorias(List<String> orderedIds) async =>
      const Right(null);

  @override
  ResultFuture<void> toggleDisponibilidad(String id, bool disponible) async =>
      const Right(null);

  @override
  ResultFuture<void> updateCategoria(Categoria categoria) async =>
      const Right(null);

  @override
  ResultFuture<void> updateProducto(Producto producto) async =>
      const Right(null);

  @override
  ResultFuture<void> updateVariante(Variante variante) async =>
      const Right(null);
}
