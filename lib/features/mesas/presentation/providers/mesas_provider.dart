import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';
import 'package:restaurant_app/features/mesas/domain/usecases/mesa_usecases.dart';

/// Estado del módulo de Mesas.
class MesasState {
  final List<Mesa> mesas;
  final bool isLoading;
  final String? errorMessage;

  const MesasState({
    this.mesas = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  MesasState copyWith({
    List<Mesa>? mesas,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MesasState(
      mesas: mesas ?? this.mesas,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Mesas filtradas por estado.
  List<Mesa> get mesasLibres =>
      mesas.where((m) => m.estado == EstadoMesa.libre).toList();

  List<Mesa> get mesasOcupadas =>
      mesas.where((m) => m.estado == EstadoMesa.ocupada).toList();

  List<Mesa> get mesasReservadas =>
      mesas.where((m) => m.estado == EstadoMesa.reservada).toList();

  /// Contadores para dashboard.
  int get totalMesas => mesas.length;
  int get totalLibres => mesasLibres.length;
  int get totalOcupadas => mesasOcupadas.length;
}

/// Notifier para gestionar el estado de Mesas.
class MesasNotifier extends StateNotifier<MesasState> {
  final GetMesas _getMesas;
  final CreateMesa _createMesa;
  final UpdateMesa _updateMesa;
  final DeleteMesa _deleteMesa;
  final UpdateEstadoMesa _updateEstadoMesa;
  final GetNextNumeroMesa _getNextNumeroMesa;

  MesasNotifier({
    required GetMesas getMesas,
    required CreateMesa createMesa,
    required UpdateMesa updateMesa,
    required DeleteMesa deleteMesa,
    required UpdateEstadoMesa updateEstadoMesa,
    required GetNextNumeroMesa getNextNumeroMesa,
  }) : _getMesas = getMesas,
       _createMesa = createMesa,
       _updateMesa = updateMesa,
       _deleteMesa = deleteMesa,
       _updateEstadoMesa = updateEstadoMesa,
       _getNextNumeroMesa = getNextNumeroMesa,
       super(const MesasState());

  /// Carga todas las mesas del restaurante.
  Future<void> loadMesas([String? restaurantId]) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _getMesas(
      restaurantId ?? sl<TenantContext>().restaurantId,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (mesas) => state = state.copyWith(isLoading: false, mesas: mesas),
    );
  }

  /// Crea una nueva mesa.
  Future<bool> crearMesa(Mesa mesa) async {
    final result = await _createMesa(mesa);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMesas(mesa.restaurantId);
        return true;
      },
    );
  }

  /// Actualiza una mesa existente.
  Future<bool> actualizarMesa(Mesa mesa) async {
    final result = await _updateMesa(mesa);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMesas(mesa.restaurantId);
        return true;
      },
    );
  }

  /// Elimina una mesa (soft delete).
  Future<bool> eliminarMesa(String id, String restaurantId) async {
    final result = await _deleteMesa(id);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMesas(restaurantId);
        return true;
      },
    );
  }

  /// Cambia el estado de una mesa.
  Future<bool> cambiarEstado(
    String id,
    EstadoMesa nuevoEstado,
    String restaurantId,
  ) async {
    final result = await _updateEstadoMesa(
      UpdateEstadoMesaParams(id: id, estado: nuevoEstado.value),
    );
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMesas(restaurantId);
        return true;
      },
    );
  }

  /// Obtiene el siguiente número de mesa disponible.
  Future<int> nextNumero([String? restaurantId]) async {
    final result = await _getNextNumeroMesa(
      restaurantId ?? sl<TenantContext>().restaurantId,
    );
    return result.fold((_) => state.mesas.length + 1, (numero) => numero);
  }

  /// Reserva una mesa con el nombre del cliente/institución.
  Future<bool> reservarMesa(
    Mesa mesa,
    String nombreReserva,
    String restaurantId,
  ) async {
    final mesaReservada = mesa.copyWith(
      estado: EstadoMesa.reservada,
      nombreReserva: nombreReserva.trim(),
    );
    return actualizarMesa(mesaReservada);
  }

  /// Reserva todas las mesas libres del local a un cliente/institución.
  Future<int> reservarTodoElLocal(
    String nombreReserva,
    String restaurantId,
  ) async {
    final mesasLibres = state.mesas
        .where((m) => m.estado == EstadoMesa.libre)
        .toList();
    int reservadas = 0;
    for (final mesa in mesasLibres) {
      final ok = await reservarMesa(mesa, nombreReserva, restaurantId);
      if (ok) reservadas++;
    }
    return reservadas;
  }

  /// Libera la reserva de una mesa.
  Future<bool> liberarReserva(Mesa mesa) async {
    final mesaLibre = mesa.copyWith(
      estado: EstadoMesa.libre,
      clearNombreReserva: true,
    );
    return actualizarMesa(mesaLibre);
  }

  /// Limpia el error actual.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider principal de Mesas.
final mesasProvider = StateNotifierProvider<MesasNotifier, MesasState>((ref) {
  return MesasNotifier(
    getMesas: sl<GetMesas>(),
    createMesa: sl<CreateMesa>(),
    updateMesa: sl<UpdateMesa>(),
    deleteMesa: sl<DeleteMesa>(),
    updateEstadoMesa: sl<UpdateEstadoMesa>(),
    getNextNumeroMesa: sl<GetNextNumeroMesa>(),
  );
});
