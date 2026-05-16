import 'dart:convert';
import 'package:restaurant_app/features/home/domain/entities/restaurante.dart';

/// Modelo de datos: Restaurante.
///
/// Extiende la entidad de dominio añadiendo serialización
/// para SQLite (toMap / fromMap).
class RestauranteModel extends Restaurante {
  const RestauranteModel({
    required super.id,
    required super.nombre,
    super.direccion,
    super.telefono,
    super.logoUrl,
    super.configuracion,
    super.activo,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Crea un [RestauranteModel] desde un Map de SQLite.
  factory RestauranteModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? config;
    if (map['configuracion'] != null &&
        (map['configuracion'] as String).isNotEmpty) {
      config =
          jsonDecode(map['configuracion'] as String) as Map<String, dynamic>;
    }

    return RestauranteModel(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      direccion: map['direccion'] as String?,
      telefono: map['telefono'] as String?,
      logoUrl: map['logo_url'] as String?,
      configuracion: config,
      activo: (map['activo'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convierte a Map para insertar en SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'direccion': direccion,
      'telefono': telefono,
      'logo_url': logoUrl,
      'configuracion': configuracion != null ? jsonEncode(configuracion) : null,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Crea un modelo desde una entidad de dominio.
  factory RestauranteModel.fromEntity(Restaurante entity) {
    return RestauranteModel(
      id: entity.id,
      nombre: entity.nombre,
      direccion: entity.direccion,
      telefono: entity.telefono,
      logoUrl: entity.logoUrl,
      configuracion: entity.configuracion,
      activo: entity.activo,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
