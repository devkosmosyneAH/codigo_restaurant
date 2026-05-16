import 'package:equatable/equatable.dart';

/// Entidad de dominio: item de cotizacion.
class CotizacionItem extends Equatable {
  final String id;
  final String cotizacionId;

  /// Null para ítems personalizados sin producto en catálogo.
  final String? productoId;
  final String productoNombre;

  /// Descripción adicional del ítem (opcional).
  final String? descripcion;
  final int cantidad;
  final double precioUnitario;

  /// Descuento aplicado al ítem, en porcentaje (0-100).
  final double descuento;

  /// Subtotal del ítem = cantidad × precio × (1 - descuento/100).
  final double subtotal;

  const CotizacionItem({
    required this.id,
    required this.cotizacionId,
    this.productoId,
    required this.productoNombre,
    this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    this.descuento = 0,
    required this.subtotal,
  });

  CotizacionItem copyWith({
    String? id,
    String? cotizacionId,
    String? productoId,
    String? productoNombre,
    String? descripcion,
    int? cantidad,
    double? precioUnitario,
    double? descuento,
    double? subtotal,
  }) {
    return CotizacionItem(
      id: id ?? this.id,
      cotizacionId: cotizacionId ?? this.cotizacionId,
      productoId: productoId ?? this.productoId,
      productoNombre: productoNombre ?? this.productoNombre,
      descripcion: descripcion ?? this.descripcion,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      descuento: descuento ?? this.descuento,
      subtotal: subtotal ?? this.subtotal,
    );
  }

  @override
  List<Object?> get props => [
    id,
    cotizacionId,
    productoId,
    productoNombre,
    descripcion,
    cantidad,
    precioUnitario,
    descuento,
    subtotal,
  ];
}
