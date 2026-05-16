import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';

/// Modelo de datos para la tabla [usuarios] en SQLite.
class UsuarioModel extends Usuario {
  const UsuarioModel({
    required super.id,
    required super.restaurantId,
    required super.nombre,
    super.email,
    super.pin,
    required super.rol,
    super.activo,
    required super.createdAt,
    required super.updatedAt,
  });

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      nombre: map['nombre'] as String,
      email: map['email'] as String?,
      pin: map['pin'] as String?,
      rol: RolUsuario.fromString(map['rol'] as String),
      activo: (map['activo'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'nombre': nombre,
      'email': email,
      'pin': pin,
      'rol': rol.value,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UsuarioModel.fromEntity(Usuario usuario) {
    return UsuarioModel(
      id: usuario.id,
      restaurantId: usuario.restaurantId,
      nombre: usuario.nombre,
      email: usuario.email,
      pin: usuario.pin,
      rol: usuario.rol,
      activo: usuario.activo,
      createdAt: usuario.createdAt,
      updatedAt: usuario.updatedAt,
    );
  }
}
