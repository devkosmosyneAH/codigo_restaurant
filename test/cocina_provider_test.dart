import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/cocina/presentation/providers/cocina_provider.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';
import 'package:restaurant_app/features/pedidos/domain/repositories/pedido_repository.dart';
import 'package:restaurant_app/features/pedidos/domain/usecases/pedido_usecases.dart';

void main() {
  group('CocinaNotifier simplified workflow', () {
    test('loads all active orders into a single flat list', () async {
      final repo = _FakePedidoRepository(
        activeOrders: [
          _pedido('p1', EstadoPedido.creado),
          _pedido('p2', EstadoPedido.aceptado),
          _pedido('p3', EstadoPedido.enPreparacion),
          _pedido('p4', EstadoPedido.finalizado),
        ],
      );

      final notifier = CocinaNotifier(
        getPedidosActivos: GetPedidosActivos(repo),
        updateEstadoPedido: UpdateEstadoPedido(repo),
        deletePedido: DeletePedido(repo),
      );

      await notifier.refresh('la_pena_001');

      expect(notifier.state.pedidos.map((p) => p.id).toList(), [
        'p1',
        'p2',
        'p3',
        'p4',
      ]);
    });

    test('marcarListo sets estado to finalizado', () async {
      final repo = _FakePedidoRepository();
      final notifier = CocinaNotifier(
        getPedidosActivos: GetPedidosActivos(repo),
        updateEstadoPedido: UpdateEstadoPedido(repo),
        deletePedido: DeletePedido(repo),
      );

      await notifier.marcarListo(_pedido('p1', EstadoPedido.creado));

      expect(repo.lastUpdatedPedidoId, 'p1');
      expect(repo.lastUpdatedPedidoEstado, EstadoPedido.finalizado.value);
    });

    test('rechazarPedido deletes the order', () async {
      final repo = _FakePedidoRepository();
      final notifier = CocinaNotifier(
        getPedidosActivos: GetPedidosActivos(repo),
        updateEstadoPedido: UpdateEstadoPedido(repo),
        deletePedido: DeletePedido(repo),
      );

      await notifier.rechazarPedido(_pedido('p1', EstadoPedido.creado));

      expect(repo.lastDeletedPedidoId, 'p1');
    });
  });
}

Pedido _pedido(String id, EstadoPedido estado) {
  final now = DateTime(2026, 4, 7, 12);
  return Pedido(
    id: id,
    restaurantId: 'la_pena_001',
    estado: estado,
    createdAt: now,
    updatedAt: now,
    mesaNombre: 'Mesa 1',
  );
}

class _FakePedidoRepository implements PedidoRepository {
  _FakePedidoRepository({this.activeOrders = const []});

  final List<Pedido> activeOrders;
  String? lastUpdatedPedidoId;
  String? lastUpdatedPedidoEstado;
  String? lastDeletedPedidoId;

  @override
  ResultFuture<List<Pedido>> getPedidosActivos(String restaurantId) async {
    return Right(activeOrders);
  }

  @override
  ResultFuture<void> updateEstadoPedido(String id, String estado) async {
    lastUpdatedPedidoId = id;
    lastUpdatedPedidoEstado = estado;
    return const Right(null);
  }

  @override
  ResultFuture<void> deletePedido(String id) async {
    lastDeletedPedidoId = id;
    return const Right(null);
  }

  @override
  ResultFuture<void> updateEstadoItem(String itemId, String estado) async {
    return const Right(null);
  }

  @override
  ResultFuture<void> deleteItem(String itemId) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<void> addItem(PedidoItem item) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<void> createPedido(Pedido pedido) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<Pedido> getPedidoById(String id) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<List<Pedido>> getPedidos(String restaurantId) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<List<Pedido>> getPedidosByMesa(String mesaId) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<List<PedidoItem>> getItemsByPedido(String pedidoId) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<void> updateItem(PedidoItem item) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<void> updatePedido(Pedido pedido) {
    throw UnimplementedError();
  }
}
