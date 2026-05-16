import 'package:restaurant_app/features/caja/domain/entities/venta_detalle.dart';

/// Modelo de datos: VentaDetalle.
///
/// Serialización SQLite para la entidad [VentaDetalle].
class VentaDetalleModel extends VentaDetalle {
  const VentaDetalleModel({
    required super.id,
    required super.ventaId,
    required super.productoId,
    super.varianteId,
    required super.cantidad,
    required super.precioUnitario,
    required super.subtotal,
    super.productoNombre,
    super.varianteNombre,
  });

  factory VentaDetalleModel.fromMap(Map<String, dynamic> map) {
    return VentaDetalleModel(
      id: map['id'] as String,
      ventaId: map['venta_id'] as String,
      productoId: map['producto_id'] as String,
      varianteId: map['variante_id'] as String?,
      cantidad: map['cantidad'] as int,
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      productoNombre: map['producto_nombre'] as String?,
      varianteNombre: map['variante_nombre'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venta_id': ventaId,
      'producto_id': productoId,
      'variante_id': varianteId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
    };
  }

  factory VentaDetalleModel.fromEntity(VentaDetalle entity) {
    return VentaDetalleModel(
      id: entity.id,
      ventaId: entity.ventaId,
      productoId: entity.productoId,
      varianteId: entity.varianteId,
      cantidad: entity.cantidad,
      precioUnitario: entity.precioUnitario,
      subtotal: entity.subtotal,
      productoNombre: entity.productoNombre,
      varianteNombre: entity.varianteNombre,
    );
  }
}
