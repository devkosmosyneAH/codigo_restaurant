import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';
import 'package:restaurant_app/features/pedidos/domain/usecases/pedido_usecases.dart';

/// Estado del módulo de Pedidos.
class PedidosState {
  final List<Pedido> pedidos;
  final Pedido? pedidoSeleccionado;
  final bool isLoading;
  final String? errorMessage;

  const PedidosState({
    this.pedidos = const [],
    this.pedidoSeleccionado,
    this.isLoading = false,
    this.errorMessage,
  });

  PedidosState copyWith({
    List<Pedido>? pedidos,
    Pedido? pedidoSeleccionado,
    bool? isLoading,
    String? errorMessage,
    bool clearPedidoSeleccionado = false,
  }) {
    return PedidosState(
      pedidos: pedidos ?? this.pedidos,
      pedidoSeleccionado: clearPedidoSeleccionado
          ? null
          : (pedidoSeleccionado ?? this.pedidoSeleccionado),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Pedidos filtrados por estado.
  List<Pedido> get pedidosPendientesAprobacion => pedidos
      .where((p) => p.estado == EstadoPedido.pendienteAprobacion)
      .toList();

  List<Pedido> get pedidosCreados =>
      pedidos.where((p) => p.estado == EstadoPedido.creado).toList();

  List<Pedido> get pedidosEnPreparacion => pedidos
      .where(
        (p) =>
            p.estado == EstadoPedido.aceptado ||
            p.estado == EstadoPedido.enPreparacion,
      )
      .toList();

  List<Pedido> get pedidosFinalizados =>
      pedidos.where((p) => p.estado == EstadoPedido.finalizado).toList();

  List<Pedido> get pedidosActivos => pedidos.where((p) => p.esActivo).toList();

  /// Contadores para dashboard.
  int get totalPedidos => pedidos.length;
  int get totalActivos => pedidosActivos.length;
  int get totalPendientesAprobacion => pedidosPendientesAprobacion.length;
  int get totalCreados => pedidosCreados.length;
  int get totalEnPreparacion => pedidosEnPreparacion.length;
}

/// Notifier para gestionar el estado de Pedidos.
class PedidosNotifier extends StateNotifier<PedidosState> {
  final GetPedidos _getPedidos;
  final GetPedidosActivos _getPedidosActivos;
  final GetPedidoById _getPedidoById;
  final CreatePedido _createPedido;
  final UpdatePedido _updatePedido;
  final UpdateEstadoPedido _updateEstadoPedido;
  final DeletePedido _deletePedido;
  final AddPedidoItem _addPedidoItem;
  final UpdatePedidoItem _updatePedidoItem;
  final DeletePedidoItem _deletePedidoItem;

  PedidosNotifier({
    required GetPedidos getPedidos,
    required GetPedidosActivos getPedidosActivos,
    required GetPedidoById getPedidoById,
    required CreatePedido createPedido,
    required UpdatePedido updatePedido,
    required UpdateEstadoPedido updateEstadoPedido,
    required DeletePedido deletePedido,
    required AddPedidoItem addPedidoItem,
    required UpdatePedidoItem updatePedidoItem,
    required DeletePedidoItem deletePedidoItem,
  }) : _getPedidos = getPedidos,
       _getPedidosActivos = getPedidosActivos,
       _getPedidoById = getPedidoById,
       _createPedido = createPedido,
       _updatePedido = updatePedido,
       _updateEstadoPedido = updateEstadoPedido,
       _deletePedido = deletePedido,
       _addPedidoItem = addPedidoItem,
       _updatePedidoItem = updatePedidoItem,
       _deletePedidoItem = deletePedidoItem,
       super(const PedidosState());

  /// Carga todos los pedidos del restaurante.
  Future<void> loadPedidos([String? restaurantId]) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _getPedidos(
      restaurantId ?? sl<TenantContext>().restaurantId,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (pedidos) => state = state.copyWith(isLoading: false, pedidos: pedidos),
    );
  }

  /// Carga solo los pedidos activos.
  Future<void> loadPedidosActivos([String? restaurantId]) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _getPedidosActivos(
      restaurantId ?? sl<TenantContext>().restaurantId,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (pedidos) => state = state.copyWith(isLoading: false, pedidos: pedidos),
    );
  }

  /// Selecciona un pedido y carga sus detalles.
  Future<void> seleccionarPedido(String pedidoId) async {
    final result = await _getPedidoById(pedidoId);
    result.fold(
      (failure) => state = state.copyWith(errorMessage: failure.message),
      (pedido) => state = state.copyWith(pedidoSeleccionado: pedido),
    );
  }

  /// Deselecciona el pedido activo.
  void deseleccionarPedido() {
    state = state.copyWith(clearPedidoSeleccionado: true);
  }

  /// Crea un nuevo pedido.
  Future<bool> crearPedido(Pedido pedido) async {
    final result = await _createPedido(pedido);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadPedidosActivos(pedido.restaurantId);
        return true;
      },
    );
  }

  /// Actualiza un pedido existente.
  Future<bool> actualizarPedido(Pedido pedido) async {
    final result = await _updatePedido(pedido);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadPedidosActivos(pedido.restaurantId);
        return true;
      },
    );
  }

  /// Cambia el estado de un pedido.
  Future<bool> cambiarEstado(
    String id,
    EstadoPedido nuevoEstado, [
    String? restaurantId,
  ]) async {
    final result = await _updateEstadoPedido(
      UpdateEstadoPedidoParams(id: id, estado: nuevoEstado.value),
    );
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadPedidosActivos(restaurantId ?? sl<TenantContext>().restaurantId);
        return true;
      },
    );
  }

  /// Elimina un pedido.
  Future<bool> eliminarPedido(String id, [String? restaurantId]) async {
    final result = await _deletePedido(id);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadPedidosActivos(restaurantId ?? sl<TenantContext>().restaurantId);
        return true;
      },
    );
  }

  // ── Items ────────────────────────────────────────────────────────

  /// Agrega un item al pedido seleccionado.
  Future<bool> agregarItem(PedidoItem item) async {
    final result = await _addPedidoItem(item);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        // Recargar pedido seleccionado para reflejar el nuevo item
        seleccionarPedido(item.pedidoId);
        return true;
      },
    );
  }

  /// Actualiza un item del pedido.
  Future<bool> actualizarItem(PedidoItem item) async {
    final result = await _updatePedidoItem(item);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        seleccionarPedido(item.pedidoId);
        return true;
      },
    );
  }

  /// Elimina un item del pedido.
  Future<bool> eliminarItem(String itemId, String pedidoId) async {
    final result = await _deletePedidoItem(itemId);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        seleccionarPedido(pedidoId);
        return true;
      },
    );
  }

  /// Limpia el error actual.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Aprueba un pedido pendiente de aprobación → pasa a [EstadoPedido.creado].
  Future<bool> aprobarPedido(String id, [String? restaurantId]) =>
      cambiarEstado(id, EstadoPedido.creado, restaurantId);

  /// Rechaza un pedido pendiente de aprobación → lo elimina.
  Future<bool> rechazarPedido(String id, [String? restaurantId]) =>
      eliminarPedido(id, restaurantId);
}

/// Provider principal de Pedidos.
final pedidosProvider = StateNotifierProvider<PedidosNotifier, PedidosState>((
  ref,
) {
  return PedidosNotifier(
    getPedidos: sl<GetPedidos>(),
    getPedidosActivos: sl<GetPedidosActivos>(),
    getPedidoById: sl<GetPedidoById>(),
    createPedido: sl<CreatePedido>(),
    updatePedido: sl<UpdatePedido>(),
    updateEstadoPedido: sl<UpdateEstadoPedido>(),
    deletePedido: sl<DeletePedido>(),
    addPedidoItem: sl<AddPedidoItem>(),
    updatePedidoItem: sl<UpdatePedidoItem>(),
    deletePedidoItem: sl<DeletePedidoItem>(),
  );
});
