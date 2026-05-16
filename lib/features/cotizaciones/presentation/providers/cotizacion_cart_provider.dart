import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';

/// Item de carrito para cotizacion.
class CotizacionCartItem {
  final Producto producto;
  final int cantidad;

  const CotizacionCartItem({required this.producto, required this.cantidad});

  double get subtotal => cantidad * producto.precio;

  CotizacionCartItem copyWith({Producto? producto, int? cantidad}) {
    return CotizacionCartItem(
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
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

  void addProducto(Producto producto) {
    final existingIndex = state.items.indexWhere(
      (i) => i.producto.id == producto.id,
    );
    if (existingIndex == -1) {
      state = state.copyWith(
        items: [
          ...state.items,
          CotizacionCartItem(producto: producto, cantidad: 1),
        ],
      );
      return;
    }

    final updated = [...state.items];
    final item = updated[existingIndex];
    updated[existingIndex] = item.copyWith(cantidad: item.cantidad + 1);
    state = state.copyWith(items: updated);
  }

  void increment(String productoId) {
    final updated = state.items.map((item) {
      if (item.producto.id == productoId) {
        return item.copyWith(cantidad: item.cantidad + 1);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
  }

  void decrement(String productoId) {
    final updated = <CotizacionCartItem>[];
    for (final item in state.items) {
      if (item.producto.id == productoId) {
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

  void remove(String productoId) {
    state = state.copyWith(
      items: state.items.where((i) => i.producto.id != productoId).toList(),
    );
  }

  void clear() {
    state = state.copyWith(items: []);
  }

  int countFor(String productoId) {
    for (final item in state.items) {
      if (item.producto.id == productoId) return item.cantidad;
    }
    return 0;
  }
}

final cotizacionCartProvider =
    StateNotifierProvider<CotizacionCartNotifier, CotizacionCartState>((ref) {
      return CotizacionCartNotifier();
    });
