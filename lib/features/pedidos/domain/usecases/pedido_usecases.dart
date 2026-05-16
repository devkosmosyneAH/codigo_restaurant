import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/core/utils/usecase.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';
import 'package:restaurant_app/features/pedidos/domain/repositories/pedido_repository.dart';

// ═══════════════════════════════════════════════════════════════════
//  CASOS DE USO DE PEDIDOS
// ═══════════════════════════════════════════════════════════════════

/// Caso de uso: Obtener todos los pedidos de un restaurante.
class GetPedidos extends UseCase<List<Pedido>, String> {
  final PedidoRepository _repository;

  GetPedidos(this._repository);

  @override
  ResultFuture<List<Pedido>> call(String restaurantId) {
    return _repository.getPedidos(restaurantId);
  }
}

/// Caso de uso: Obtener pedidos activos.
class GetPedidosActivos extends UseCase<List<Pedido>, String> {
  final PedidoRepository _repository;

  GetPedidosActivos(this._repository);

  @override
  ResultFuture<List<Pedido>> call(String restaurantId) {
    return _repository.getPedidosActivos(restaurantId);
  }
}

/// Caso de uso: Obtener pedidos de una mesa.
class GetPedidosByMesa extends UseCase<List<Pedido>, String> {
  final PedidoRepository _repository;

  GetPedidosByMesa(this._repository);

  @override
  ResultFuture<List<Pedido>> call(String mesaId) {
    return _repository.getPedidosByMesa(mesaId);
  }
}

/// Caso de uso: Obtener un pedido por ID.
class GetPedidoById extends UseCase<Pedido, String> {
  final PedidoRepository _repository;

  GetPedidoById(this._repository);

  @override
  ResultFuture<Pedido> call(String id) {
    return _repository.getPedidoById(id);
  }
}

/// Caso de uso: Crear un nuevo pedido.
class CreatePedido extends UseCase<void, Pedido> {
  final PedidoRepository _repository;

  CreatePedido(this._repository);

  @override
  ResultFuture<void> call(Pedido pedido) {
    return _repository.createPedido(pedido);
  }
}

/// Caso de uso: Actualizar un pedido.
class UpdatePedido extends UseCase<void, Pedido> {
  final PedidoRepository _repository;

  UpdatePedido(this._repository);

  @override
  ResultFuture<void> call(Pedido pedido) {
    return _repository.updatePedido(pedido);
  }
}

/// Parámetros para cambiar estado de pedido.
class UpdateEstadoPedidoParams {
  final String id;
  final String estado;

  const UpdateEstadoPedidoParams({
    required this.id,
    required this.estado,
  });
}

/// Caso de uso: Cambiar el estado de un pedido.
class UpdateEstadoPedido extends UseCase<void, UpdateEstadoPedidoParams> {
  final PedidoRepository _repository;

  UpdateEstadoPedido(this._repository);

  @override
  ResultFuture<void> call(UpdateEstadoPedidoParams params) {
    return _repository.updateEstadoPedido(params.id, params.estado);
  }
}

/// Caso de uso: Eliminar un pedido.
class DeletePedido extends UseCase<void, String> {
  final PedidoRepository _repository;

  DeletePedido(this._repository);

  @override
  ResultFuture<void> call(String id) {
    return _repository.deletePedido(id);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CASOS DE USO DE PEDIDO ITEMS
// ═══════════════════════════════════════════════════════════════════

/// Caso de uso: Obtener items de un pedido.
class GetItemsByPedido extends UseCase<List<PedidoItem>, String> {
  final PedidoRepository _repository;

  GetItemsByPedido(this._repository);

  @override
  ResultFuture<List<PedidoItem>> call(String pedidoId) {
    return _repository.getItemsByPedido(pedidoId);
  }
}

/// Caso de uso: Agregar un item al pedido.
class AddPedidoItem extends UseCase<void, PedidoItem> {
  final PedidoRepository _repository;

  AddPedidoItem(this._repository);

  @override
  ResultFuture<void> call(PedidoItem item) {
    return _repository.addItem(item);
  }
}

/// Caso de uso: Actualizar un item del pedido.
class UpdatePedidoItem extends UseCase<void, PedidoItem> {
  final PedidoRepository _repository;

  UpdatePedidoItem(this._repository);

  @override
  ResultFuture<void> call(PedidoItem item) {
    return _repository.updateItem(item);
  }
}

/// Caso de uso: Eliminar un item del pedido.
class DeletePedidoItem extends UseCase<void, String> {
  final PedidoRepository _repository;

  DeletePedidoItem(this._repository);

  @override
  ResultFuture<void> call(String itemId) {
    return _repository.deleteItem(itemId);
  }
}

/// Parámetros para cambiar estado de un item.
class UpdateEstadoItemParams {
  final String itemId;
  final String estado;

  const UpdateEstadoItemParams({
    required this.itemId,
    required this.estado,
  });
}

/// Caso de uso: Cambiar el estado de un item.
class UpdateEstadoItem extends UseCase<void, UpdateEstadoItemParams> {
  final PedidoRepository _repository;

  UpdateEstadoItem(this._repository);

  @override
  ResultFuture<void> call(UpdateEstadoItemParams params) {
    return _repository.updateEstadoItem(params.itemId, params.estado);
  }
}
