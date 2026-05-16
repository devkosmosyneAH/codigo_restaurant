import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/features/caja/presentation/providers/caja_provider.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/reportes/presentation/providers/reportes_provider.dart';

void main() {
  group('CajaState commercial summary', () {
    test('calculates pending total and average ticket for the day', () {
      final now = DateTime(2026, 4, 6, 12, 0);
      final state = CajaState(
        pedidosParaCobrar: [
          Pedido(
            id: 'p1',
            restaurantId: 'r1',
            estado: EstadoPedido.finalizado,
            total: 24.5,
            createdAt: now,
            updatedAt: now,
          ),
          Pedido(
            id: 'p2',
            restaurantId: 'r1',
            estado: EstadoPedido.entregado,
            total: 15.5,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        ventasHoy: [
          Venta(
            id: 'v1',
            restaurantId: 'r1',
            pedidoId: 'p1',
            metodoPago: MetodoPago.efectivo,
            subtotal: 10,
            total: 10,
            createdAt: now,
          ),
          Venta(
            id: 'v2',
            restaurantId: 'r1',
            pedidoId: 'p2',
            metodoPago: MetodoPago.tarjeta,
            subtotal: 30,
            total: 30,
            createdAt: now,
          ),
        ],
      );

      expect(state.totalPendientePorCobrar, 40.0);
      expect(state.ticketPromedioHoy, 20.0);
    });
  });

  group('FiltroFecha period boundaries', () {
    test('fechaFin closes at the end of the selected day', () {
      final now = DateTime(2026, 4, 6, 10, 30, 45);
      final end = FiltroFecha.hoy.fechaFin(now);

      expect(end.year, 2026);
      expect(end.month, 4);
      expect(end.day, 6);
      expect(end.hour, 23);
      expect(end.minute, 59);
    });

    test('custom report range keeps explicit boundaries', () {
      final now = DateTime(2026, 4, 6, 10, 30, 45);
      final state = ReportesState(
        filtro: FiltroFecha.personalizado,
        fechaInicioPersonalizada: DateTime(2026, 4, 1),
        fechaFinPersonalizada: DateTime(2026, 4, 8),
      );

      final start = state.fechaInicioActiva(now);
      final end = state.fechaFinActiva(now);

      expect(start, DateTime(2026, 4, 1));
      expect(end.year, 2026);
      expect(end.month, 4);
      expect(end.day, 8);
      expect(end.hour, 23);
      expect(end.minute, 59);
    });
  });
}
