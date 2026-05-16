import 'package:restaurant_app/features/pedidos/data/models/pedido_item_model.dart';
import 'package:restaurant_app/features/pedidos/data/models/pedido_model.dart';

/// Contrato del datasource local para Pedidos.
///
/// Define las operaciones CRUD contra SQLite para pedidos e items.
abstract class PedidoLocalDataSource {
  // ── Pedidos ──────────────────────────────────────────────────────

  /// Obtiene todos los pedidos de un restaurante (con items y display names).
  Future<List<PedidoModel>> getPedidos(String restaurantId);

  /// Obtiene pedidos activos (estado != 'entregado').
  Future<List<PedidoModel>> getPedidosActivos(String restaurantId);

  /// Obtiene pedidos de una mesa específica.
  Future<List<PedidoModel>> getPedidosByMesa(String mesaId);

  /// Obtiene un pedido por ID (con items completos).
  Future<PedidoModel?> getPedidoById(String id);

  /// Crea un nuevo pedido (sin items, se agregan después).
  Future<void> createPedido(PedidoModel pedido);

  /// Actualiza un pedido existente.
  Future<void> updatePedido(PedidoModel pedido);

  /// Cambia el estado de un pedido.
  Future<void> updateEstadoPedido(String id, String estado);

  /// Elimina un pedido y sus items.
  Future<void> deletePedido(String id);

  /// Actualiza el total del pedido recalculando desde items.
  Future<void> recalcularTotal(String pedidoId);

  // ── Pedido Items ─────────────────────────────────────────────────

  /// Obtiene los items de un pedido.
  Future<List<PedidoItemModel>> getItemsByPedido(String pedidoId);

  /// Agrega un item al pedido.
  Future<void> addItem(PedidoItemModel item);

  /// Actualiza un item (cantidad, observaciones).
  Future<void> updateItem(PedidoItemModel item);

  /// Elimina un item del pedido.
  Future<void> deleteItem(String itemId);

  /// Cambia el estado de un item.
  Future<void> updateEstadoItem(String itemId, String estado);
}
