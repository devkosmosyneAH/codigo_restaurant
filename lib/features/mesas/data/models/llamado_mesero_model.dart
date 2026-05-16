import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/mesas/domain/entities/llamado_mesero.dart';

/// Modelo de datos: Llamado a mesero.
class LlamadoMeseroModel extends LlamadoMesero {
  const LlamadoMeseroModel({
    required super.id,
    required super.restaurantId,
    super.mesaId,
    super.mesaNombre,
    super.estado,
    required super.createdAt,
    super.atendidoAt,
  });

  factory LlamadoMeseroModel.fromMap(Map<String, dynamic> map) {
    return LlamadoMeseroModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      mesaId: map['mesa_id'] as String?,
      mesaNombre: map['mesa_nombre'] as String?,
      estado: EstadoLlamado.fromString(map['estado'] as String? ?? 'pendiente'),
      createdAt: DateTime.parse(map['created_at'] as String),
      atendidoAt: map['atendido_at'] != null
          ? DateTime.tryParse(map['atendido_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'mesa_id': mesaId,
      'estado': estado.value,
      'created_at': createdAt.toIso8601String(),
      'atendido_at': atendidoAt?.toIso8601String(),
    };
  }

  factory LlamadoMeseroModel.fromEntity(LlamadoMesero entity) {
    return LlamadoMeseroModel(
      id: entity.id,
      restaurantId: entity.restaurantId,
      mesaId: entity.mesaId,
      mesaNombre: entity.mesaNombre,
      estado: entity.estado,
      createdAt: entity.createdAt,
      atendidoAt: entity.atendidoAt,
    );
  }
}
