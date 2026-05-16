import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta_detalle.dart';
import 'package:restaurant_app/features/caja/presentation/widgets/ticket_dialog.dart';

void main() {
  testWidgets('shows client order breakdown with quantity and unit price', (
    tester,
  ) async {
    final venta = Venta(
      id: 'venta-001',
      restaurantId: 'la_pena_001',
      pedidoId: 'pedido-001',
      clienteNombre: 'Henry',
      clienteEmail: 'henry@gmail.com',
      metodoPago: MetodoPago.efectivo,
      subtotal: 10,
      total: 10,
      createdAt: DateTime(2026, 4, 6, 22, 11),
      detalles: const [
        VentaDetalle(
          id: 'det-1',
          ventaId: 'venta-001',
          productoId: 'prod-1',
          cantidad: 1,
          precioUnitario: 10,
          subtotal: 10,
          productoNombre: 'Pechuga a la plancha',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TicketDialog(venta: venta, mesaNombre: 'Mesa 4'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Pechuga a la plancha'), findsOneWidget);
    expect(find.text('1 × \$10.00'), findsOneWidget);
    expect(find.text('Mesa 4'), findsAtLeastNWidgets(1));
    expect(find.text('Consumidor final'), findsAtLeastNWidgets(1));
  });
}
