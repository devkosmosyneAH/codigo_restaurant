import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';

/// Modelo de datos: PedidoItem.
///
/// Serialización SQLite para la entidad [PedidoItem].
class PedidoItemModel extends PedidoItem {
  const PedidoItemModel({
    required super.id,
    required super.pedidoId,
    required super.productoId,
    super.varianteId,
    super.cantidad,
    required super.precioUnitario,
    super.observaciones,
    super.estado,
    required super.createdAt,
    required super.updatedAt,
    super.productoNombre,
    super.varianteNombre,
  });

  factory PedidoItemModel.fromMap(Map<String, dynamic> map) {
    return PedidoItemModel(
      id: map['id'] as String,
      pedidoId: map['pedido_id'] as String,
      productoId: map['producto_id'] as String? ?? 'manual',
      varianteId: map['variante_id'] as String?,
      cantidad: (map['cantidad'] as int?) ?? 1,
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      observaciones: map['observaciones'] as String?,
      estado: EstadoPedido.fromString(map['estado'] as String? ?? 'creado'),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      // nombre_display tiene prioridad (cargos manuales); fallback al JOIN
      productoNombre:
          (map['nombre_display'] as String?) ??
          (map['producto_nombre'] as String?),
      varianteNombre: map['variante_nombre'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pedido_id': pedidoId,
      'producto_id': productoId,
      'variante_id': varianteId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'observaciones': observaciones,
      'estado': estado.value,
      'nombre_display': productoNombre,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PedidoItemModel.fromEntity(PedidoItem entity) {
    return PedidoItemModel(
      id: entity.id,
      pedidoId: entity.pedidoId,
      productoId: entity.productoId,
      varianteId: entity.varianteId,
      cantidad: entity.cantidad,
      precioUnitario: entity.precioUnitario,
      observaciones: entity.observaciones,
      estado: entity.estado,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      productoNombre: entity.productoNombre,
      varianteNombre: entity.varianteNombre,
    );
  }
}
