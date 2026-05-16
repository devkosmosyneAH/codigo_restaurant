import 'package:equatable/equatable.dart';
import 'package:restaurant_app/core/domain/enums.dart';

/// Entidad de dominio: Usuario del sistema.
///
/// Representa a un empleado con un rol asignado que puede
/// autenticarse mediante un PIN de 4 dígitos.
class Usuario extends Equatable {
  final String id;
  final String restaurantId;
  final String nombre;
  final String? email;
  final String? pin;
  final RolUsuario rol;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Usuario({
    required this.id,
    required this.restaurantId,
    required this.nombre,
    this.email,
    this.pin,
    required this.rol,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Usuario copyWith({
    String? id,
    String? restaurantId,
    String? nombre,
    String? email,
    String? pin,
    RolUsuario? rol,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Usuario(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      pin: pin ?? this.pin,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Iniciales para avatar (hasta 2 caracteres).
  String get iniciales {
    final parts = nombre.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nombre.substring(0, nombre.length.clamp(1, 2)).toUpperCase();
  }

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    nombre,
    email,
    pin,
    rol,
    activo,
    createdAt,
    updatedAt,
  ];
}
