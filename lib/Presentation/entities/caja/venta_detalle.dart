import 'package:equatable/equatable.dart';

/// Entidad de dominio: Detalle de Venta.
///
/// Cada registro representa un producto vendido dentro
/// de una venta, con su cantidad y precio.
class VentaDetalle extends Equatable {
  final String id;
  final String ventaId;
  final String productoId;
  final String? varianteId;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  /// Nombre del producto (para display).
  final String? productoNombre;

  /// Nombre de la variante (para display).
  final String? varianteNombre;

  const VentaDetalle({
    required this.id,
    required this.ventaId,
    required this.productoId,
    this.varianteId,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.productoNombre,
    this.varianteNombre,
  });

  VentaDetalle copyWith({
    String? id,
    String? ventaId,
    String? productoId,
    String? varianteId,
    int? cantidad,
    double? precioUnitario,
    double? subtotal,
    String? productoNombre,
    String? varianteNombre,
  }) {
    return VentaDetalle(
      id: id ?? this.id,
      ventaId: ventaId ?? this.ventaId,
      productoId: productoId ?? this.productoId,
      varianteId: varianteId ?? this.varianteId,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      subtotal: subtotal ?? this.subtotal,
      productoNombre: productoNombre ?? this.productoNombre,
      varianteNombre: varianteNombre ?? this.varianteNombre,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ventaId,
    productoId,
    varianteId,
    cantidad,
    precioUnitario,
    subtotal,
  ];
}
