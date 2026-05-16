import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';
import 'package:restaurant_app/features/usuarios/domain/usecases/usuario_usecases.dart';
import 'package:uuid/uuid.dart';

// ── Estado ─────────────────────────────────────────────────────────────────────

class UsuarioState {
  final List<Usuario> usuarios;
  final RolUsuario? filtroRol;
  final bool isLoading;
  final bool isProcessing;
  final String? error;
  final String? successMessage;

  const UsuarioState({
    this.usuarios = const [],
    this.filtroRol,
    this.isLoading = false,
    this.isProcessing = false,
    this.error,
    this.successMessage,
  });

  List<Usuario> get usuariosFiltrados {
    if (filtroRol == null) return usuarios;
    return usuarios.where((u) => u.rol == filtroRol).toList();
  }

  UsuarioState copyWith({
    List<Usuario>? usuarios,
    RolUsuario? filtroRol,
    bool clearFiltro = false,
    bool? isLoading,
    bool? isProcessing,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return UsuarioState(
      usuarios: usuarios ?? this.usuarios,
      filtroRol: clearFiltro ? null : filtroRol ?? this.filtroRol,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      error: clearError ? null : error ?? this.error,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class UsuarioNotifier extends StateNotifier<UsuarioState> {
  UsuarioNotifier({
    required GetUsuarios getUsuarios,
    required CreateUsuario createUsuario,
    required UpdateUsuario updateUsuario,
    required DeleteUsuario deleteUsuario,
    required VerificarPin verificarPin,
  }) : _getUsuarios = getUsuarios,
       _createUsuario = createUsuario,
       _updateUsuario = updateUsuario,
       _deleteUsuario = deleteUsuario,
       _verificarPin = verificarPin,
       super(const UsuarioState()) {
    loadUsuarios();
  }

  final GetUsuarios _getUsuarios;
  final CreateUsuario _createUsuario;
  final UpdateUsuario _updateUsuario;
  final DeleteUsuario _deleteUsuario;
  final VerificarPin _verificarPin;

  final _uuid = const Uuid();

  int _countAdministradoresActivos({String? excludeUserId}) {
    return state.usuarios.where((u) {
      return u.activo &&
          u.rol == RolUsuario.administrador &&
          u.id != excludeUserId;
    }).length;
  }

  String? _normalizePin(String? pin) {
    final value = pin?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  String? _validateSecurityRules({
    required RolUsuario rol,
    required String? pin,
    String? excludeUserId,
  }) {
    if (pin == null || pin.isEmpty) {
      return 'Cada usuario debe tener un PIN de 4 dígitos.';
    }

    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return 'El PIN debe tener exactamente 4 dígitos.';
    }

    if (rol == RolUsuario.administrador &&
        _countAdministradoresActivos(excludeUserId: excludeUserId) > 0) {
      return 'Solo se permite un usuario administrador activo.';
    }

    return null;
  }

  Future<void> loadUsuarios() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getUsuarios(sl<TenantContext>().restaurantId);
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (usuarios) =>
          state = state.copyWith(isLoading: false, usuarios: usuarios),
    );
  }

  void cambiarFiltro(RolUsuario? rol) {
    state = state.copyWith(filtroRol: rol, clearFiltro: rol == null);
  }

  Future<bool> crearUsuario({
    required String nombre,
    String? email,
    String? pin,
    required RolUsuario rol,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true);

    final normalizedPin = _normalizePin(pin);
    final securityError = _validateSecurityRules(rol: rol, pin: normalizedPin);

    if (securityError != null) {
      state = state.copyWith(isProcessing: false, error: securityError);
      return false;
    }

    final ahora = DateTime.now();
    final usuario = Usuario(
      id: _uuid.v4(),
      restaurantId: sl<TenantContext>().restaurantId,
      nombre: nombre.trim(),
      email: email?.trim().isEmpty == true ? null : email?.trim(),
      pin: normalizedPin,
      rol: rol,
      activo: true,
      createdAt: ahora,
      updatedAt: ahora,
    );

    final result = await _createUsuario(usuario);
    return result.fold(
      (failure) {
        state = state.copyWith(isProcessing: false, error: failure.message);
        return false;
      },
      (created) {
        state = state.copyWith(
          isProcessing: false,
          usuarios: [...state.usuarios, created],
          successMessage: 'Usuario "${created.nombre}" creado correctamente',
        );
        return true;
      },
    );
  }

  Future<bool> actualizarUsuario({
    required Usuario usuario,
    required String nombre,
    String? email,
    String? pin,
    required RolUsuario rol,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true);

    final normalizedPin = _normalizePin(pin) ?? _normalizePin(usuario.pin);
    final securityError = _validateSecurityRules(
      rol: rol,
      pin: normalizedPin,
      excludeUserId: usuario.id,
    );

    if (securityError != null) {
      state = state.copyWith(isProcessing: false, error: securityError);
      return false;
    }

    final updated = usuario.copyWith(
      nombre: nombre.trim(),
      email: email?.trim().isEmpty == true ? null : email?.trim(),
      pin: normalizedPin,
      rol: rol,
      updatedAt: DateTime.now(),
    );

    final result = await _updateUsuario(updated);
    return result.fold(
      (failure) {
        state = state.copyWith(isProcessing: false, error: failure.message);
        return false;
      },
      (u) {
        final nuevos = state.usuarios.map((e) => e.id == u.id ? u : e).toList();
        state = state.copyWith(
          isProcessing: false,
          usuarios: nuevos,
          successMessage: 'Usuario "${u.nombre}" actualizado',
        );
        return true;
      },
    );
  }

  Future<bool> eliminarUsuario(Usuario usuario) async {
    state = state.copyWith(isProcessing: true, clearError: true);

    if (usuario.rol == RolUsuario.administrador &&
        _countAdministradoresActivos() <= 1) {
      state = state.copyWith(
        isProcessing: false,
        error: 'No se puede eliminar el único administrador activo.',
      );
      return false;
    }

    final result = await _deleteUsuario(usuario.id);
    return result.fold(
      (failure) {
        state = state.copyWith(isProcessing: false, error: failure.message);
        return false;
      },
      (_) {
        final nuevos = state.usuarios.where((u) => u.id != usuario.id).toList();
        state = state.copyWith(
          isProcessing: false,
          usuarios: nuevos,
          successMessage: 'Usuario "${usuario.nombre}" eliminado',
        );
        return true;
      },
    );
  }

  /// Verifica un PIN y retorna el usuario si es correcto.
  Future<Usuario?> verificarPin(String pin) async {
    final result = await _verificarPin(sl<TenantContext>().restaurantId, pin);
    return result.fold((_) => null, (u) => u);
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final usuarioProvider = StateNotifierProvider<UsuarioNotifier, UsuarioState>((
  ref,
) {
  return UsuarioNotifier(
    getUsuarios: sl(),
    createUsuario: sl(),
    updateUsuario: sl(),
    deleteUsuario: sl(),
    verificarPin: sl(),
  );
});
