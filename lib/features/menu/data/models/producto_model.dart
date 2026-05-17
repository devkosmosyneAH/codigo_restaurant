import 'package:restaurant_app/features/menu/data/models/variante_model.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';

/// Modelo de datos: Producto.
///
/// Serialización SQLite para la entidad [Producto].
/// Maneja la relación con [Variante] opcionalmente.
class ProductoModel extends Producto {
  const ProductoModel({
    required super.id,
    required super.restaurantId,
    required super.categoriaId,
    required super.nombre,
    super.descripcion,
    required super.precio,
    super.imagenUrl,
    super.driveFileId,
    super.drivePublicUrl,
    super.imagenLocalCachePath,
    super.disponible,
    super.activo,
    required super.createdAt,
    required super.updatedAt,
    super.variantes,
  });

  factory ProductoModel.fromMap(
    Map<String, dynamic> map, {
    List<Variante>? variantes,
  }) {
    return ProductoModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      categoriaId: map['categoria_id'] as String,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      precio: (map['precio'] as num).toDouble(),
      imagenUrl: map['imagen_url'] as String?,
      driveFileId: map['drive_file_id'] as String?,
      drivePublicUrl: map['drive_public_url'] as String?,
      imagenLocalCachePath: map['imagen_local_cache_path'] as String?,
      disponible: (map['disponible'] as int?) == 1,
      activo: (map['activo'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      variantes: variantes ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'categoria_id': categoriaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'imagen_url': imagenUrl,
      'drive_file_id': driveFileId,
      'drive_public_url': drivePublicUrl,
      'imagen_local_cache_path': imagenLocalCachePath,
      'disponible': disponible ? 1 : 0,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convierte variantes relacionadas a Map list para inserción batch.
  List<Map<String, dynamic>> variantesToMapList() {
    return variantes.map((v) => VarianteModel.fromEntity(v).toMap()).toList();
  }

  factory ProductoModel.fromEntity(Producto entity) {
    return ProductoModel(
      id: entity.id,
      restaurantId: entity.restaurantId,
      categoriaId: entity.categoriaId,
      nombre: entity.nombre,
      descripcion: entity.descripcion,
      precio: entity.precio,
      imagenUrl: entity.imagenUrl,
      driveFileId: entity.driveFileId,
      drivePublicUrl: entity.drivePublicUrl,
      imagenLocalCachePath: entity.imagenLocalCachePath,
      disponible: entity.disponible,
      activo: entity.activo,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      variantes: entity.variantes,
    );
  }
}
