import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/public_producto_card.dart';

void main() {
  group('Menu externo funcionamiento', () {
    final now = DateTime(2026, 1, 1);

    testWidgets('muestra precio base cuando no hay variantes', (tester) async {
      final producto = Producto(
        id: 'prod-base',
        restaurantId: 'rest-1',
        categoriaId: 'cat-1',
        nombre: 'Limonada',
        precio: 4.5,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 320,
                child: PublicProductoCard(producto: producto),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('\$4.50'), findsOneWidget);
      expect(find.textContaining('Desde'), findsNothing);
      expect(find.textContaining('opciones:'), findsNothing);
    });

    testWidgets('muestra variantes y precio desde cuando existen opciones', (
      tester,
    ) async {
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
            precio: 3.75,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 320,
                child: PublicProductoCard(producto: producto),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Desde \$2.50'), findsOneWidget);
      expect(find.textContaining('2 opciones:'), findsOneWidget);
      expect(find.textContaining('Pequeno'), findsOneWidget);
    });
  });
}
