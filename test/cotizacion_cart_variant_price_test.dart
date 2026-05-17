import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizacion_cart_provider.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';

void main() {
  group('CotizacionCartNotifier precio referencial', () {
    test('usa precio base cuando no hay variantes', () {
      final notifier = CotizacionCartNotifier();
      final now = DateTime(2026, 1, 1);

      final producto = Producto(
        id: 'prod-base',
        restaurantId: 'rest-1',
        categoriaId: 'cat-1',
        nombre: 'Jugo natural',
        precio: 4.5,
        createdAt: now,
        updatedAt: now,
      );

      notifier.addProducto(producto);

      final item = notifier.state.items.single;
      expect(item.precioUnitario, 4.5);
      expect(item.subtotal, 4.5);
      expect(notifier.state.subtotal, 4.5);
    });

    test('usa precio minimo cuando el producto tiene variantes', () {
      final notifier = CotizacionCartNotifier();
      final now = DateTime(2026, 1, 1);

      final producto = Producto(
        id: 'prod-var',
        restaurantId: 'rest-1',
        categoriaId: 'cat-1',
        nombre: 'Cafe especial',
        precio: 0,
        createdAt: now,
        updatedAt: now,
        variantes: [
          Variante(
            id: 'var-1',
            productoId: 'prod-var',
            nombre: 'Pequeno',
            precio: 2.5,
            createdAt: now,
            updatedAt: now,
          ),
          Variante(
            id: 'var-2',
            productoId: 'prod-var',
            nombre: 'Grande',
            precio: 3.5,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      notifier.addProducto(producto);
      notifier.addProducto(producto);

      final item = notifier.state.items.single;
      expect(item.precioUnitario, 2.5);
      expect(item.cantidad, 2);
      expect(item.subtotal, 5);
      expect(notifier.state.subtotal, 5);
    });
  });
}
