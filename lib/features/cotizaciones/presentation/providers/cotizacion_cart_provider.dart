import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';

/// Item de carrito para cotizacion.
class CotizacionCartItem {
  final Producto producto;
  final int cantidad;
  final String? varianteId;
  final String? varianteNombre;
  final double _precioUnitario;

  const CotizacionCartItem({
    required this.producto,
    required this.cantidad,
    required double precioUnitario,
    this.varianteId,
    this.varianteNombre,
  }) : _precioUnitario = precioUnitario;

  double get precioUnitario => _precioUnitario;

  bool get hasVariante =>
      varianteId != null &&
      varianteNombre != null &&
      varianteNombre!.isNotEmpty;

  String get nombreLinea =>
      hasVariante ? '${producto.nombre} (${varianteNombre!})' : producto.nombre;

  double get subtotal => cantidad * precioUnitario;

  CotizacionCartItem copyWith({
    Producto? producto,
    int? cantidad,
    String? varianteId,
    String? varianteNombre,
    double? precioUnitario,
  }) {
    return CotizacionCartItem(
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
      varianteId: varianteId ?? this.varianteId,
      varianteNombre: varianteNombre ?? this.varianteNombre,
      precioUnitario: precioUnitario ?? this.precioUnitario,
    );
  }
}

/// Estado del carrito de cotizacion.
class CotizacionCartState {
  final List<CotizacionCartItem> items;

  const CotizacionCartState({this.items = const []});

  CotizacionCartState copyWith({List<CotizacionCartItem>? items}) {
    return CotizacionCartState(items: items ?? this.items);
  }

  int get totalItems => items.fold(0, (sum, i) => sum + i.cantidad);

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);
}

/// Notifier del carrito de cotizacion.
class CotizacionCartNotifier extends StateNotifier<CotizacionCartState> {
  CotizacionCartNotifier() : super(const CotizacionCartState());

  void addProducto(
    Producto producto, {
    Variante? variante,
    double? precioUnitario,
  }) {
    final varianteId = variante?.id;
    final varianteNombre = variante?.nombre;
    final unitario =
        precioUnitario ?? variante?.precio ?? producto.precioReferencial;
    final existingIndex = state.items.indexWhere(
      (i) => i.producto.id == producto.id && i.varianteId == varianteId,
    );
    if (existingIndex == -1) {
      state = state.copyWith(
        items: [
          ...state.items,
          CotizacionCartItem(
            producto: producto,
            cantidad: 1,
            varianteId: varianteId,
            varianteNombre: varianteNombre,
            precioUnitario: unitario,
          ),
        ],
      );
      return;
    }

    final updated = [...state.items];
    final item = updated[existingIndex];
    updated[existingIndex] = item.copyWith(cantidad: item.cantidad + 1);
    state = state.copyWith(items: updated);
  }

  void increment(String productoId, {String? varianteId}) {
    final updated = state.items.map((item) {
      if (item.producto.id == productoId && item.varianteId == varianteId) {
        return item.copyWith(cantidad: item.cantidad + 1);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
  }

  void decrement(String productoId, {String? varianteId}) {
    final updated = <CotizacionCartItem>[];
    for (final item in state.items) {
      if (item.producto.id == productoId && item.varianteId == varianteId) {
        final nextQty = item.cantidad - 1;
        if (nextQty > 0) {
          updated.add(item.copyWith(cantidad: nextQty));
        }
      } else {
        updated.add(item);
      }
    }
    state = state.copyWith(items: updated);
  }

  void incrementProducto(Producto producto) {
    final index = state.items.indexWhere(
      (item) => item.producto.id == producto.id,
    );
    if (index == -1) {
      addProducto(producto);
      return;
    }

    final updated = [...state.items];
    final item = updated[index];
    updated[index] = item.copyWith(cantidad: item.cantidad + 1);
    state = state.copyWith(items: updated);
  }

  void decrementProducto(String productoId) {
    final updated = [...state.items];
    for (var i = updated.length - 1; i >= 0; i--) {
      final item = updated[i];
      if (item.producto.id != productoId) {
        continue;
      }
      final nextQty = item.cantidad - 1;
      if (nextQty > 0) {
        updated[i] = item.copyWith(cantidad: nextQty);
      } else {
        updated.removeAt(i);
      }
      state = state.copyWith(items: updated);
      return;
    }
  }

  void remove(String productoId, {String? varianteId}) {
    state = state.copyWith(
      items: state.items
          .where(
            (i) =>
                i.producto.id != productoId ||
                (varianteId != null && i.varianteId != varianteId),
          )
          .toList(),
    );
  }

  void clear() {
    state = state.copyWith(items: []);
  }

  int countFor(String productoId, {String? varianteId}) {
    for (final item in state.items) {
      if (item.producto.id == productoId && item.varianteId == varianteId) {
        return item.cantidad;
      }
    }
    return 0;
  }

  int totalForProducto(String productoId) {
    return state.items
        .where((item) => item.producto.id == productoId)
        .fold(0, (sum, item) => sum + item.cantidad);
  }
}

final cotizacionCartProvider =
    StateNotifierProvider<CotizacionCartNotifier, CotizacionCartState>((ref) {
      return CotizacionCartNotifier();
    });
