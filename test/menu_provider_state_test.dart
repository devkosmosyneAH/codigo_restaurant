import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';

void main() {
  test('productosDisponibles excluye productos inactivos', () {
    final activo = Producto(
      id: 'p1',
      restaurantId: 'r1',
      categoriaId: 'c1',
      nombre: 'Activo',
      precio: 10,
      disponible: true,
      activo: true,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

    final inactivo = Producto(
      id: 'p2',
      restaurantId: 'r1',
      categoriaId: 'c1',
      nombre: 'Inactivo',
      precio: 12,
      disponible: true,
      activo: false,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

    final state = MenuState(productos: [activo, inactivo]);

    expect(state.productosDisponibles, [activo]);
  });

  test('productosFiltrados excluye productos inactivos', () {
    final activo = Producto(
      id: 'p1',
      restaurantId: 'r1',
      categoriaId: 'c1',
      nombre: 'Activo',
      precio: 10,
      disponible: true,
      activo: true,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

    final inactivo = Producto(
      id: 'p2',
      restaurantId: 'r1',
      categoriaId: 'c1',
      nombre: 'Inactivo',
      precio: 12,
      disponible: true,
      activo: false,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

    final state = MenuState(
      productos: [activo, inactivo],
      categoriaSeleccionadaId: 'c1',
    );

    expect(state.productosFiltrados, [activo]);
  });
}
