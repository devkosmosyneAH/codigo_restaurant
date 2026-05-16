import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/domain/repositories/cliente_repository.dart';
import 'package:restaurant_app/features/clientes/domain/usecases/cliente_usecases.dart';

// ── Estado ──────────────────────────────────────────────────────────────────

class ClienteState {
  final List<Cliente> clientes;
  final List<Cliente> resultadosBusqueda;
  final String query;
  final bool isLoading;
  final bool isProcessing;
  final String? error;
  final String? successMessage;
  final ClienteResumen? resumenActual;

  const ClienteState({
    this.clientes = const [],
    this.resultadosBusqueda = const [],
    this.query = '',
    this.isLoading = false,
    this.isProcessing = false,
    this.error,
    this.successMessage,
    this.resumenActual,
  });

  List<Cliente> get listaVisible =>
      query.isEmpty ? clientes : resultadosBusqueda;

  ClienteState copyWith({
    List<Cliente>? clientes,
    List<Cliente>? resultadosBusqueda,
    String? query,
    bool? isLoading,
    bool? isProcessing,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    ClienteResumen? resumenActual,
    bool clearResumen = false,
  }) {
    return ClienteState(
      clientes: clientes ?? this.clientes,
      resultadosBusqueda: resultadosBusqueda ?? this.resultadosBusqueda,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      error: clearError ? null : error ?? this.error,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
      resumenActual: clearResumen ? null : resumenActual ?? this.resumenActual,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class ClienteNotifier extends StateNotifier<ClienteState> {
  ClienteNotifier({
    required GetClientes getClientes,
    required GetClienteByCedula getClienteByCedula,
    required BuscarClientes buscarClientes,
    required CreateCliente createCliente,
    required UpdateCliente updateCliente,
    required DeleteCliente deleteCliente,
    required GetResumenCliente getResumenCliente,
  }) : _getClientes = getClientes,
       _getClienteByCedula = getClienteByCedula,
       _buscarClientes = buscarClientes,
       _createCliente = createCliente,
       _updateCliente = updateCliente,
       _deleteCliente = deleteCliente,
       _getResumenCliente = getResumenCliente,
       super(const ClienteState()) {
    loadClientes();
  }

  final GetClientes _getClientes;
  final GetClienteByCedula _getClienteByCedula;
  final BuscarClientes _buscarClientes;
  final CreateCliente _createCliente;
  final UpdateCliente _updateCliente;
  final DeleteCliente _deleteCliente;
  final GetResumenCliente _getResumenCliente;

  String get _restaurantId => sl<TenantContext>().restaurantId;

  bool _matchesQuery(Cliente cliente, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return true;
    final digitQuery = cleanQuery.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneDigits = (cliente.telefono ?? '').replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return cliente.cedula.contains(
          digitQuery.isEmpty ? cleanQuery : digitQuery,
        ) ||
        cliente.nombreCompleto.toLowerCase().contains(cleanQuery) ||
        cliente.nombre.toLowerCase().contains(cleanQuery) ||
        (cliente.apellido?.toLowerCase().contains(cleanQuery) ?? false) ||
        (cliente.email?.toLowerCase().contains(cleanQuery) ?? false) ||
        (cliente.telefono?.toLowerCase().contains(cleanQuery) ?? false) ||
        (digitQuery.isNotEmpty && phoneDigits.contains(digitQuery));
  }

  // ── Carga ────────────────────────────────────────────────────────

  Future<void> loadClientes() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getClientes(_restaurantId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, clientes: list),
    );
  }

  // ── Búsqueda ─────────────────────────────────────────────────────

  Future<void> buscar(String query) async {
    state = state.copyWith(query: query, clearError: true);
    if (query.trim().isEmpty) {
      state = state.copyWith(resultadosBusqueda: []);
      return;
    }
    final result = await _buscarClientes(_restaurantId, query);
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (list) => state = state.copyWith(resultadosBusqueda: list),
    );
  }

  void limpiarBusqueda() {
    state = state.copyWith(query: '', resultadosBusqueda: []);
  }

  // ── Lookup por cédula (para caja) ────────────────────────────────

  Future<Cliente?> lookupByCedula(String cedula) async {
    final result = await _getClienteByCedula(_restaurantId, cedula);
    return result.fold((_) => null, (c) => c);
  }

  // ── Resumen ──────────────────────────────────────────────────────

  Future<void> cargarResumen(String cedula) async {
    state = state.copyWith(clearResumen: true, clearError: true);
    final result = await _getResumenCliente(cedula, _restaurantId);
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (resumen) => state = state.copyWith(resumenActual: resumen),
    );
  }

  // ── CRUD ─────────────────────────────────────────────────────────

  Future<bool> crearCliente({
    required String cedula,
    required String nombre,
    String? apellido,
    String? telefono,
    String? email,
    String? direccion,
    DateTime? fechaNacimiento,
    String? notas,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    final now = DateTime.now();
    final cleanCedula = cedula.replaceAll(RegExp(r'[^0-9]'), '');
    final cliente = Cliente(
      cedula: cleanCedula,
      restaurantId: _restaurantId,
      nombre: nombre.trim(),
      apellido: apellido?.trim().isEmpty ?? true ? null : apellido?.trim(),
      telefono: telefono?.trim().isEmpty ?? true ? null : telefono?.trim(),
      email: email?.trim().isEmpty ?? true ? null : email?.trim(),
      direccion: direccion?.trim().isEmpty ?? true ? null : direccion?.trim(),
      fechaNacimiento: fechaNacimiento,
      notas: notas?.trim().isEmpty ?? true ? null : notas?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final result = await _createCliente(cliente);
    return result.fold(
      (f) {
        state = state.copyWith(isProcessing: false, error: f.message);
        return false;
      },
      (created) {
        final clientes = [
          created,
          ...state.clientes.where((c) => c.cedula != created.cedula),
        ];
        final resultadosBusqueda = state.query.trim().isEmpty
            ? state.resultadosBusqueda
            : _matchesQuery(created, state.query)
            ? [
                created,
                ...state.resultadosBusqueda.where(
                  (c) => c.cedula != created.cedula,
                ),
              ]
            : state.resultadosBusqueda
                  .where((c) => c.cedula != created.cedula)
                  .toList();
        state = state.copyWith(
          isProcessing: false,
          clientes: clientes,
          resultadosBusqueda: resultadosBusqueda,
          successMessage: 'Cliente registrado correctamente.',
        );
        return true;
      },
    );
  }

  Future<bool> actualizarCliente({
    required Cliente cliente,
    required String nombre,
    String? apellido,
    String? telefono,
    String? email,
    String? direccion,
    DateTime? fechaNacimiento,
    String? notas,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    final updated = Cliente(
      idCliente: cliente.idCliente,
      cedula: cliente.cedula,
      restaurantId: _restaurantId,
      nombre: nombre.trim(),
      apellido: apellido?.trim().isEmpty ?? true ? null : apellido?.trim(),
      telefono: telefono?.trim().isEmpty ?? true ? null : telefono?.trim(),
      email: email?.trim().isEmpty ?? true ? null : email?.trim(),
      direccion: direccion?.trim().isEmpty ?? true ? null : direccion?.trim(),
      fechaNacimiento: fechaNacimiento,
      notas: notas?.trim().isEmpty ?? true ? null : notas?.trim(),
      estado: cliente.estado,
      activo: cliente.activo,
      createdAt: cliente.createdAt,
      updatedAt: DateTime.now(),
    );

    final result = await _updateCliente(updated);
    return result.fold(
      (f) {
        state = state.copyWith(isProcessing: false, error: f.message);
        return false;
      },
      (c) {
        final list = state.clientes
            .map((e) => e.cedula == c.cedula ? c : e)
            .toList();
        final resultadosBusqueda = state.resultadosBusqueda
            .map((e) => e.cedula == c.cedula ? c : e)
            .where(
              (e) =>
                  state.query.trim().isEmpty || _matchesQuery(e, state.query),
            )
            .toList();
        state = state.copyWith(
          isProcessing: false,
          clientes: list,
          resultadosBusqueda: resultadosBusqueda,
          successMessage: 'Cliente actualizado correctamente.',
        );
        return true;
      },
    );
  }

  Future<bool> eliminarCliente(String cedula) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    final result = await _deleteCliente(_restaurantId, cedula);
    return result.fold(
      (f) {
        state = state.copyWith(isProcessing: false, error: f.message);
        return false;
      },
      (_) {
        final cleanCedula = cedula.replaceAll(RegExp(r'[^0-9]'), '');
        final list = state.clientes
            .where((c) => c.cedula != cleanCedula)
            .toList();
        final resultadosBusqueda = state.resultadosBusqueda
            .where((c) => c.cedula != cleanCedula)
            .toList();
        state = state.copyWith(
          isProcessing: false,
          clientes: list,
          resultadosBusqueda: resultadosBusqueda,
          successMessage: 'Cliente eliminado.',
        );
        return true;
      },
    );
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final clienteProvider = StateNotifierProvider<ClienteNotifier, ClienteState>((
  ref,
) {
  return ClienteNotifier(
    getClientes: sl(),
    getClienteByCedula: sl(),
    buscarClientes: sl(),
    createCliente: sl(),
    updateCliente: sl(),
    deleteCliente: sl(),
    getResumenCliente: sl(),
  );
});
