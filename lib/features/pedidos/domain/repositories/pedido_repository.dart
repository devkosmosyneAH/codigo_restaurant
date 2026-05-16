import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';

/// Contrato del repositorio de Pedidos (capa de dominio).
///
/// Define las operaciones que la capa de presentación puede
/// solicitar sin conocer la fuente de datos.
abstract class PedidoRepository {
  // ── Pedidos ──────────────────────────────────────────────────────

  /// Obtiene todos los pedidos de un restaurante.
  ResultFuture<List<Pedido>> getPedidos(String restaurantId);

  /// Obtiene pedidos activos (no entregados).
  ResultFuture<List<Pedido>> getPedidosActivos(String restaurantId);

  /// Obtiene pedidos de una mesa específica.
  ResultFuture<List<Pedido>> getPedidosByMesa(String mesaId);

  /// Obtiene un pedido por ID con sus items.
  ResultFuture<Pedido> getPedidoById(String id);

  /// Crea un nuevo pedido.
  ResultFuture<void> createPedido(Pedido pedido);

  /// Actualiza un pedido existente.
  ResultFuture<void> updatePedido(Pedido pedido);

  /// Cambia el estado de un pedido.
  ResultFuture<void> updateEstadoPedido(String id, String estado);

  /// Elimina un pedido y sus items.
  ResultFuture<void> deletePedido(String id);

  // ── Items ────────────────────────────────────────────────────────

  /// Obtiene los items de un pedido.
  ResultFuture<List<PedidoItem>> getItemsByPedido(String pedidoId);

  /// Agrega un item al pedido.
  ResultFuture<void> addItem(PedidoItem item);

  /// Actualiza un item (cantidad, observaciones).
  ResultFuture<void> updateItem(PedidoItem item);

  /// Elimina un item del pedido.
  ResultFuture<void> deleteItem(String itemId);

  /// Cambia el estado de un item.
  ResultFuture<void> updateEstadoItem(String itemId, String estado);
}
