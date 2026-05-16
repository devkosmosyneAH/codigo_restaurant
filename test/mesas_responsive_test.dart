import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';
import 'package:restaurant_app/features/mesas/presentation/widgets/mesa_card.dart';

void main() {
  testWidgets('MesaCard does not overflow on compact mobile sizes', (
    WidgetTester tester,
  ) async {
    final mesa = Mesa(
      id: 'mesa-1',
      restaurantId: 'rest-1',
      numero: 12,
      nombre: 'Mesa familiar',
      capacidad: 8,
      estado: EstadoMesa.reservada,
      nombreReserva: 'Cumpleaños de Valentina',
      mesaUnionId: 'union-1',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 156,
              height: 164,
              child: MesaCard(mesa: mesa),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mesa familiar'), findsOneWidget);
  });
}
