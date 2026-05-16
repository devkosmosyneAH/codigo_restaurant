import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/domain/usecases/pedido_usecases.dart';

/// Estado de la pantalla de Cocina.
///
/// Lista plana de pedidos activos pendientes de preparar o listos.
class CocinaState {
  final List<Pedido> pedidos;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastRefresh;

  const CocinaState({
    this.pedidos = const [],
    this.isLoading = false,
    this.errorMessage,
    this.lastRefresh,
  });

  CocinaState copyWith({
    List<Pedido>? pedidos,
    bool? isLoading,
    String? errorMessage,
    DateTime? lastRefresh,
  }) {
    return CocinaState(
      pedidos: pedidos ?? this.pedidos,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }

  int get totalPedidos => pedidos.length;
}

/// Notifier para la pantalla de Cocina.
///
/// Auto-refresh cada [_refreshIntervalManual] (modo manual) o
/// [_refreshIntervalAuto] (modo automático).
/// Modo manual: dos acciones por pedido — marcarListo (→ finalizado) y rechazar (→ elimina).
/// Modo automático: refresca solamente; promueve pedidos aceptado/enPreparacion
/// a finalizado cuando supera el umbral configurado.
class CocinaNotifier extends StateNotifier<CocinaState> {
  final GetPedidosActivos _getPedidosActivos;
  final UpdateEstadoPedido _updateEstadoPedido;
  final DeletePedido _deletePedido;

  static const _refreshIntervalManual = Duration(seconds: 30);
  static const _refreshIntervalAuto = Duration(seconds: 15);
  Timer? _timer;
  String? _restaurantId;

  bool _autoMode = false;
  int _autoMinutes = 15;
  final Set<String> _autoAdvanceInFlight = <String>{};

  CocinaNotifier({
    required GetPedidosActivos getPedidosActivos,
    required UpdateEstadoPedido updateEstadoPedido,
    required DeletePedido deletePedido,
  }) : _getPedidosActivos = getPedidosActivos,
       _updateEstadoPedido = updateEstadoPedido,
       _deletePedido = deletePedido,
       super(const CocinaState());

  bool get autoMode => _autoMode;
  int get autoMinutes => _autoMinutes;

  /// Inicia la pantalla de cocina y el auto-refresh.
  void start([String? restaurantId]) {
    _restaurantId = restaurantId;
    refresh(restaurantId);
    _scheduleTimer();
  }

  /// Detiene el auto-refresh.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Actualiza el modo automático y los minutos configurados desde la UI.
  ///
  /// Si cambia el intervalo de refresco, reprograma el timer.
  void setAutoMode({required bool enabled, required int minutes}) {
    final normalizedMinutes = minutes < 1 ? 1 : minutes;
    final intervalChanged = enabled != _autoMode;
    _autoMode = enabled;
    _autoMinutes = normalizedMinutes;
    if (intervalChanged && _timer != null) {
      _scheduleTimer();
    }
  }

  void _scheduleTimer() {
    _timer?.cancel();
    final interval = _autoMode ? _refreshIntervalAuto : _refreshIntervalManual;
    _timer = Timer.periodic(interval, (_) => refresh(_restaurantId));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Recarga manualmente los pedidos.
  Future<void> refresh([String? restaurantId]) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final rid =
        restaurantId ?? _restaurantId ?? sl<TenantContext>().restaurantId;
    final result = await _getPedidosActivos(rid);

    await result.fold(
      (failure) async => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (pedidos) async {
        // Mostrar todos los pedidos activos excepto los ya entregados.
        final activos = pedidos
            .where((p) => p.estado != EstadoPedido.entregado)
            .toList();

        state = state.copyWith(
          isLoading: false,
          pedidos: activos,
          lastRefresh: DateTime.now(),
        );

        if (_autoMode) {
          await _autoAdvanceVencidos(activos);
        }
      },
    );
  }

  /// Promueve a `finalizado` los pedidos en `aceptado` o `enPreparacion`
  /// cuyo `updatedAt` supera el umbral configurado.
  Future<void> _autoAdvanceVencidos(List<Pedido> pedidos) async {
    final now = DateTime.now();
    final umbral = Duration(minutes: _autoMinutes);
    final candidatos = pedidos.where((p) {
      if (_autoAdvanceInFlight.contains(p.id)) return false;
      if (p.estado != EstadoPedido.aceptado &&
          p.estado != EstadoPedido.enPreparacion) {
        return false;
      }
      return now.difference(p.updatedAt) >= umbral;
    }).toList();

    if (candidatos.isEmpty) return;

    for (final p in candidatos) {
      _autoAdvanceInFlight.add(p.id);
    }

    try {
      for (final p in candidatos) {
        await _updateEstadoPedido(
          UpdateEstadoPedidoParams(
            id: p.id,
            estado: EstadoPedido.finalizado.value,
          ),
        );
      }
    } finally {
      for (final p in candidatos) {
        _autoAdvanceInFlight.remove(p.id);
      }
    }
  }

  /// Marca el pedido como finalizado (listo para entregar/cobrar).
  Future<void> marcarListo(Pedido pedido) async {
    final result = await _updateEstadoPedido(
      UpdateEstadoPedidoParams(
        id: pedido.id,
        estado: EstadoPedido.finalizado.value,
      ),
    );

    result.fold(
      (failure) => state = state.copyWith(errorMessage: failure.message),
      (_) => refresh(pedido.restaurantId),
    );
  }

  /// Elimina el pedido (rechazado por cocina).
  Future<void> rechazarPedido(Pedido pedido) async {
    final result = await _deletePedido(pedido.id);

    result.fold(
      (failure) => state = state.copyWith(errorMessage: failure.message),
      (_) => refresh(pedido.restaurantId),
    );
  }

  /// Limpia el mensaje de error.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider principal de la pantalla de Cocina.
final cocinaProvider = StateNotifierProvider<CocinaNotifier, CocinaState>((
  ref,
) {
  return CocinaNotifier(
    getPedidosActivos: sl<GetPedidosActivos>(),
    updateEstadoPedido: sl<UpdateEstadoPedido>(),
    deletePedido: sl<DeletePedido>(),
  );
});
