import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';

/// Modelo de datos: Categoría.
///
/// Serialización SQLite para la entidad [Categoria].
class CategoriaModel extends Categoria {
  const CategoriaModel({
    required super.id,
    required super.restaurantId,
    required super.nombre,
    super.descripcion,
    super.orden,
    super.activo,
    required super.createdAt,
    required super.updatedAt,
  });

  factory CategoriaModel.fromMap(Map<String, dynamic> map) {
    return CategoriaModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      orden: (map['orden'] as int?) ?? 0,
      activo: (map['activo'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'nombre': nombre,
      'descripcion': descripcion,
      'orden': orden,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CategoriaModel.fromEntity(Categoria entity) {
    return CategoriaModel(
      id: entity.id,
      restaurantId: entity.restaurantId,
      nombre: entity.nombre,
      descripcion: entity.descripcion,
      orden: entity.orden,
      activo: entity.activo,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
