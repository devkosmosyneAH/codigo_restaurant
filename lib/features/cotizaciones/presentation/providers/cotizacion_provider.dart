import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion_item.dart';
import 'package:restaurant_app/features/cotizaciones/domain/usecases/cotizacion_usecases.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizacion_cart_provider.dart';
import 'package:uuid/uuid.dart';

/// Estado de cotizacion.
class CotizacionState {
  final bool isSaving;
  final String? errorMessage;

  const CotizacionState({this.isSaving = false, this.errorMessage});

  CotizacionState copyWith({bool? isSaving, String? errorMessage}) {
    return CotizacionState(
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier de cotizaciones.
class CotizacionNotifier extends StateNotifier<CotizacionState> {
  final CreateCotizacion _createCotizacion;

  CotizacionNotifier({required CreateCotizacion createCotizacion})
    : _createCotizacion = createCotizacion,
      super(const CotizacionState());

  Future<String?> crearCotizacion({
    required String restaurantId,
    String? mesaId,
    int? idCliente,
    required String clienteNombre,
    required String clienteTelefono,
    required String clienteEmail,
    bool reservaLocal = false,
    int? personas,
    String? fechaEvento,
    String? comidaPreferida,
    String? notas,
    required List<CotizacionCartItem> items,
  }) async {
    state = state.copyWith(isSaving: true, errorMessage: null);

    final cotizacionId = const Uuid().v4();
    final cotItems = items.map((item) {
      return CotizacionItem(
        id: const Uuid().v4(),
        cotizacionId: cotizacionId,
        productoId: item.producto.id,
        productoNombre: item.producto.nombre,
        cantidad: item.cantidad,
        precioUnitario: item.precioUnitario,
        subtotal: item.subtotal,
      );
    }).toList();

    final subtotal = items.fold(0.0, (sum, i) => sum + i.subtotal);

    final cotizacion = Cotizacion(
      id: cotizacionId,
      restaurantId: restaurantId,
      mesaId: mesaId,
      idCliente: idCliente,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      clienteEmail: clienteEmail,
      reservaLocal: reservaLocal,
      personas: personas,
      fechaEvento: fechaEvento,
      comidaPreferida: comidaPreferida,
      notas: notas,
      subtotal: subtotal,
      total: subtotal,
      createdAt: DateTime.now(),
      items: cotItems,
    );

    final result = await _createCotizacion(cotizacion);
    return result.fold(
      (f) {
        state = state.copyWith(isSaving: false, errorMessage: f.message);
        return null;
      },
      (_) {
        state = state.copyWith(isSaving: false, errorMessage: null);
        return cotizacionId;
      },
    );
  }
}

final cotizacionProvider =
    StateNotifierProvider<CotizacionNotifier, CotizacionState>((ref) {
      return CotizacionNotifier(createCotizacion: sl<CreateCotizacion>());
    });
