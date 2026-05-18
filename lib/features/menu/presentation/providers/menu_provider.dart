import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/sync/hybrid_sync_orchestrator.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/usecases/menu_usecases.dart';

/// Estado del módulo de Menú.
class MenuState {
  final List<Categoria> categorias;
  final List<Producto> productos;
  final String? categoriaSeleccionadaId;
  final bool isLoading;
  final String? errorMessage;

  const MenuState({
    this.categorias = const [],
    this.productos = const [],
    this.categoriaSeleccionadaId,
    this.isLoading = false,
    this.errorMessage,
  });

  MenuState copyWith({
    List<Categoria>? categorias,
    List<Producto>? productos,
    String? categoriaSeleccionadaId,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearCategoria = false,
  }) {
    return MenuState(
      categorias: categorias ?? this.categorias,
      productos: productos ?? this.productos,
      categoriaSeleccionadaId: clearCategoria
          ? null
          : (categoriaSeleccionadaId ?? this.categoriaSeleccionadaId),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Productos filtrados por la categoría seleccionada.
  List<Producto> get productosFiltrados {
    if (categoriaSeleccionadaId == null) return productos;
    return productos
        .where((p) => p.categoriaId == categoriaSeleccionadaId)
        .toList();
  }

  /// Productos disponibles.
  List<Producto> get productosDisponibles =>
      productos.where((p) => p.disponible).toList();

  int get totalProductos => productos.length;
  int get totalCategorias => categorias.length;
}

/// Notifier para gestionar el estado del Menú.
class MenuNotifier extends StateNotifier<MenuState> {
  final GetCategorias _getCategorias;
  final CreateCategoria _createCategoria;
  final UpdateCategoria _updateCategoria;
  final DeleteCategoria _deleteCategoria;
  final ReordenarCategorias _reordenarCategorias;
  final GetProductos _getProductos;
  final CreateProducto _createProducto;
  final UpdateProducto _updateProducto;
  final DeleteProducto _deleteProducto;
  final ToggleDisponibilidad _toggleDisponibilidad;
  final CreateVariante _createVariante;
  final UpdateVariante _updateVariante;
  final DeleteVariante _deleteVariante;
  final Future<void> Function(String reason)? _requestCloudSync;
  Future<void>? _loadMenuInFlight;

  MenuNotifier({
    required GetCategorias getCategorias,
    required CreateCategoria createCategoria,
    required UpdateCategoria updateCategoria,
    required DeleteCategoria deleteCategoria,
    required ReordenarCategorias reordenarCategorias,
    required GetProductos getProductos,
    required CreateProducto createProducto,
    required UpdateProducto updateProducto,
    required DeleteProducto deleteProducto,
    required ToggleDisponibilidad toggleDisponibilidad,
    required CreateVariante createVariante,
    required UpdateVariante updateVariante,
    required DeleteVariante deleteVariante,
    Future<void> Function(String reason)? requestCloudSync,
  }) : _getCategorias = getCategorias,
       _createCategoria = createCategoria,
       _updateCategoria = updateCategoria,
       _deleteCategoria = deleteCategoria,
       _reordenarCategorias = reordenarCategorias,
       _getProductos = getProductos,
       _createProducto = createProducto,
       _updateProducto = updateProducto,
       _deleteProducto = deleteProducto,
       _toggleDisponibilidad = toggleDisponibilidad,
       _createVariante = createVariante,
       _updateVariante = updateVariante,
       _deleteVariante = deleteVariante,
       _requestCloudSync = requestCloudSync,
       super(const MenuState());

  void _triggerCloudSync(String reason) {
    final callback = _requestCloudSync;
    if (callback == null) return;

    unawaited(_runCloudSync(callback, reason));
  }

  Future<void> _runCloudSync(
    Future<void> Function(String reason) callback,
    String reason,
  ) async {
    try {
      await callback(reason);
    } catch (_) {
      // No bloquea el flujo local del menú si la nube falla.
    }
  }

  // ── Carga inicial ─────────────────────────────────────────────

  Future<void> loadMenu([String? restaurantId, bool silent = false]) async {
    final inFlight = _loadMenuInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final loadFuture = _loadMenuInternal(restaurantId, silent);
    _loadMenuInFlight = loadFuture.whenComplete(() {
      _loadMenuInFlight = null;
    });
    return _loadMenuInFlight!;
  }

  Future<void> _loadMenuInternal(String? restaurantId, bool silent) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      state = state.copyWith(clearError: true);
    }
    final rid = restaurantId ?? sl<TenantContext>().restaurantId;

    final catResult = await _getCategorias(rid);
    await catResult.fold(
      (failure) async {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
      (cats) async {
        final prodResult = await _getProductos(rid);
        prodResult.fold(
          (failure) => state = state.copyWith(
            isLoading: false,
            categorias: cats,
            errorMessage: failure.message,
          ),
          (prods) => state = state.copyWith(
            isLoading: false,
            categorias: cats,
            productos: prods,
          ),
        );
      },
    );
  }

  // ── Filtrado por categoría ─────────────────────────────────────

  void seleccionarCategoria(String? categoriaId) {
    state = state.copyWith(
      categoriaSeleccionadaId: categoriaId,
      clearCategoria: categoriaId == null,
    );
  }

  // ── Categorías ─────────────────────────────────────────────────

  Future<bool> crearCategoria(Categoria categoria) async {
    state = state.copyWith(clearError: true);
    final result = await _createCategoria(categoria);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMenu(null, true);
        _triggerCloudSync('menu-create-categoria');
        return true;
      },
    );
  }

  Future<bool> actualizarCategoria(Categoria categoria) async {
    state = state.copyWith(clearError: true);
    final result = await _updateCategoria(categoria);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMenu(null, true);
        _triggerCloudSync('menu-update-categoria');
        return true;
      },
    );
  }

  Future<bool> eliminarCategoria(String id) async {
    state = state.copyWith(clearError: true);
    final result = await _deleteCategoria(id);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMenu(null, true);
        _triggerCloudSync('menu-delete-categoria');
        return true;
      },
    );
  }

  Future<void> reordenarCategorias(List<String> orderedIds) async {
    await _reordenarCategorias(orderedIds);
    loadMenu(null, true);
  }

  // ── Productos ──────────────────────────────────────────────────

  Future<bool> crearProducto(Producto producto) async {
    state = state.copyWith(clearError: true);
    final result = await _createProducto(producto);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMenu(null, true);
        _triggerCloudSync('menu-create-producto');
        return true;
      },
    );
  }

  Future<bool> actualizarProducto(Producto producto) async {
    state = state.copyWith(clearError: true);
    final result = await _updateProducto(producto);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMenu(null, true);
        _triggerCloudSync('menu-update-producto');
        return true;
      },
    );
  }

  Future<bool> eliminarProducto(String id) async {
    state = state.copyWith(clearError: true);
    final result = await _deleteProducto(id);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMenu(null, true);
        _triggerCloudSync('menu-delete-producto');
        return true;
      },
    );
  }

  Future<void> cambiarDisponibilidad(String id, bool disponible) async {
    // Actualización optimista
    final updated = state.productos
        .map((p) => p.id == id ? p.copyWith(disponible: disponible) : p)
        .toList();
    state = state.copyWith(productos: updated);

    final result = await _toggleDisponibilidad(id, disponible);
    result.fold(
      (failure) {
        // Revertir en caso de error
        final reverted = state.productos
            .map((p) => p.id == id ? p.copyWith(disponible: !disponible) : p)
            .toList();
        state = state.copyWith(
          productos: reverted,
          errorMessage: failure.message,
        );
      },
      (_) {
        _triggerCloudSync('menu-toggle-disponibilidad');
      },
    );
  }

  // ── Variantes ──────────────────────────────────────────────────

  Future<bool> crearVariante(
    String productoId,
    Producto productoActualizado,
  ) async {
    state = state.copyWith(clearError: true);
    for (final v in productoActualizado.variantes) {
      final result = await _createVariante(v);
      if (result.isLeft()) {
        final msg = result.fold((f) => f.message, (_) => 'Error desconocido');
        state = state.copyWith(errorMessage: msg);
        return false;
      }
    }
    loadMenu(null, true);
    _triggerCloudSync('menu-create-variante');
    return true;
  }

  Future<bool> actualizarVariante(dynamic variante) async {
    state = state.copyWith(clearError: true);
    final result = await _updateVariante(variante);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMenu(null, true);
        _triggerCloudSync('menu-update-variante');
        return true;
      },
    );
  }

  Future<bool> eliminarVariante(String id) async {
    state = state.copyWith(clearError: true);
    final result = await _deleteVariante(id);
    return result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
      (_) {
        loadMenu(null, true);
        _triggerCloudSync('menu-delete-variante');
        return true;
      },
    );
  }
}

/// Provider global del módulo de Menú.
final menuProvider = StateNotifierProvider<MenuNotifier, MenuState>((ref) {
  return MenuNotifier(
    getCategorias: sl(),
    createCategoria: sl(),
    updateCategoria: sl(),
    deleteCategoria: sl(),
    reordenarCategorias: sl(),
    getProductos: sl(),
    createProducto: sl(),
    updateProducto: sl(),
    deleteProducto: sl(),
    toggleDisponibilidad: sl(),
    createVariante: sl(),
    updateVariante: sl(),
    deleteVariante: sl(),
    requestCloudSync: (reason) =>
        sl<HybridSyncOrchestrator>().syncNow(reason: reason),
  );
});
