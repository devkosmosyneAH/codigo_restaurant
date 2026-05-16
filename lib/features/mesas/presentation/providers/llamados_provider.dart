import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/mesas/domain/entities/llamado_mesero.dart';
import 'package:restaurant_app/features/mesas/domain/usecases/llamado_usecases.dart';
import 'package:uuid/uuid.dart';

/// Estado de llamados a mesero.
class LlamadosState {
  final List<LlamadoMesero> pendientes;
  final bool isLoading;
  final String? errorMessage;

  const LlamadosState({
    this.pendientes = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  LlamadosState copyWith({
    List<LlamadoMesero>? pendientes,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LlamadosState(
      pendientes: pendientes ?? this.pendientes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  int get totalPendientes => pendientes.length;
}

/// Notifier de llamados a mesero.
class LlamadosNotifier extends StateNotifier<LlamadosState> {
  final CreateLlamado _createLlamado;
  final GetLlamadosPendientes _getPendientes;
  final MarcarLlamadoAtendido _marcarAtendido;

  LlamadosNotifier({
    required CreateLlamado createLlamado,
    required GetLlamadosPendientes getPendientes,
    required MarcarLlamadoAtendido marcarAtendido,
  }) : _createLlamado = createLlamado,
       _getPendientes = getPendientes,
       _marcarAtendido = marcarAtendido,
       super(const LlamadosState());

  Future<void> loadPendientes([String? restaurantId]) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final rid = restaurantId ?? sl<TenantContext>().restaurantId;

    final result = await _getPendientes(rid);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, errorMessage: f.message),
      (items) => state = state.copyWith(isLoading: false, pendientes: items),
    );
  }

  Future<bool> crearLlamado({
    required String restaurantId,
    required String mesaId,
  }) async {
    final llamado = LlamadoMesero(
      id: const Uuid().v4(),
      restaurantId: restaurantId,
      mesaId: mesaId,
      estado: EstadoLlamado.pendiente,
      createdAt: DateTime.now(),
    );

    final result = await _createLlamado(llamado);
    return result.fold(
      (f) {
        state = state.copyWith(errorMessage: f.message);
        return false;
      },
      (_) {
        loadPendientes(restaurantId);
        return true;
      },
    );
  }

  Future<bool> marcarAtendido(String id, [String? restaurantId]) async {
    final result = await _marcarAtendido(id);
    return result.fold(
      (f) {
        state = state.copyWith(errorMessage: f.message);
        return false;
      },
      (_) {
        loadPendientes(restaurantId ?? sl<TenantContext>().restaurantId);
        return true;
      },
    );
  }
}

/// Provider global de llamados a mesero.
final llamadosProvider = StateNotifierProvider<LlamadosNotifier, LlamadosState>(
  (ref) {
    return LlamadosNotifier(
      createLlamado: sl<CreateLlamado>(),
      getPendientes: sl<GetLlamadosPendientes>(),
      marcarAtendido: sl<MarcarLlamadoAtendido>(),
    );
  },
);
