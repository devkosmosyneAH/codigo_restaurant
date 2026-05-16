import 'package:restaurant_app/features/menu/domain/entities/variante.dart';

/// Modelo de datos: Variante.
///
/// Serialización SQLite para la entidad [Variante].
class VarianteModel extends Variante {
  const VarianteModel({
    required super.id,
    required super.productoId,
    required super.nombre,
    required super.precio,
    super.activo,
    required super.createdAt,
    required super.updatedAt,
  });

  factory VarianteModel.fromMap(Map<String, dynamic> map) {
    return VarianteModel(
      id: map['id'] as String,
      productoId: map['producto_id'] as String,
      nombre: map['nombre'] as String,
      precio: (map['precio'] as num).toDouble(),
      activo: (map['activo'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': productoId,
      'nombre': nombre,
      'precio': precio,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VarianteModel.fromEntity(Variante entity) {
    return VarianteModel(
      id: entity.id,
      productoId: entity.productoId,
      nombre: entity.nombre,
      precio: entity.precio,
      activo: entity.activo,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
