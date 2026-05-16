import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';

/// Modelo de datos: Pedido.
///
/// Serialización SQLite para la entidad [Pedido].
/// Los [items] se cargan opcionalmente con una query separada.
class PedidoModel extends Pedido {
  const PedidoModel({
    required super.id,
    required super.restaurantId,
    super.mesaId,
    super.meseroId,
    super.estado,
    super.observaciones,
    super.total,
    required super.createdAt,
    required super.updatedAt,
    super.items,
    super.mesaNombre,
    super.meseroNombre,
  });

  factory PedidoModel.fromMap(
    Map<String, dynamic> map, {
    List<PedidoItem>? items,
  }) {
    return PedidoModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      mesaId: map['mesa_id'] as String?,
      meseroId: map['mesero_id'] as String?,
      estado: EstadoPedido.fromString(map['estado'] as String? ?? 'creado'),
      observaciones: map['observaciones'] as String?,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      items: items ?? const [],
      // Campos de display (vienen de JOINs)
      mesaNombre: map['mesa_nombre'] as String?,
      meseroNombre: map['mesero_nombre'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'mesa_id': mesaId,
      'mesero_id': meseroId,
      'estado': estado.value,
      'observaciones': observaciones,
      'total': total,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PedidoModel.fromEntity(Pedido entity) {
    return PedidoModel(
      id: entity.id,
      restaurantId: entity.restaurantId,
      mesaId: entity.mesaId,
      meseroId: entity.meseroId,
      estado: entity.estado,
      observaciones: entity.observaciones,
      total: entity.total,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      items: entity.items,
      mesaNombre: entity.mesaNombre,
      meseroNombre: entity.meseroNombre,
    );
  }
}
