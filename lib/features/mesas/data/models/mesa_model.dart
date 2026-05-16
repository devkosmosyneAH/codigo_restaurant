import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';

/// Modelo de datos: Mesa.
///
/// Serialización SQLite para la entidad [Mesa].
class MesaModel extends Mesa {
  const MesaModel({
    required super.id,
    required super.restaurantId,
    required super.numero,
    super.nombre,
    super.capacidad,
    super.estado,
    super.mesaUnionId,
    super.nombreReserva,
    super.posicionX,
    super.posicionY,
    super.activo,
    required super.createdAt,
    required super.updatedAt,
  });

  factory MesaModel.fromMap(Map<String, dynamic> map) {
    return MesaModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      numero: map['numero'] as int,
      nombre: map['nombre'] as String?,
      capacidad: (map['capacidad'] as int?) ?? 4,
      estado: EstadoMesa.fromString(map['estado'] as String? ?? 'libre'),
      mesaUnionId: map['mesa_union_id'] as String?,
      nombreReserva: map['nombre_reserva'] as String?,
      posicionX: (map['posicion_x'] as num?)?.toDouble() ?? 0,
      posicionY: (map['posicion_y'] as num?)?.toDouble() ?? 0,
      activo: (map['activo'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'numero': numero,
      'nombre': nombre,
      'capacidad': capacidad,
      'estado': estado.value,
      'mesa_union_id': mesaUnionId,
      'nombre_reserva': nombreReserva,
      'posicion_x': posicionX,
      'posicion_y': posicionY,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MesaModel.fromEntity(Mesa entity) {
    return MesaModel(
      id: entity.id,
      restaurantId: entity.restaurantId,
      numero: entity.numero,
      nombre: entity.nombre,
      capacidad: entity.capacidad,
      estado: entity.estado,
      mesaUnionId: entity.mesaUnionId,
      nombreReserva: entity.nombreReserva,
      posicionX: entity.posicionX,
      posicionY: entity.posicionY,
      activo: entity.activo,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
