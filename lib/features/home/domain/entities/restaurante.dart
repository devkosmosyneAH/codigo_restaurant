import 'package:equatable/equatable.dart';

/// Entidad de dominio: Restaurante.
///
/// Representa un restaurante en el sistema multi-tenant.
/// Todas las demás entidades se relacionan con un restaurante
/// a través de [id].
class Restaurante extends Equatable {
  final String id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final String? logoUrl;
  final Map<String, dynamic>? configuracion;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Restaurante({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.logoUrl,
    this.configuracion,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crea una copia con campos modificados.
  Restaurante copyWith({
    String? id,
    String? nombre,
    String? direccion,
    String? telefono,
    String? logoUrl,
    Map<String, dynamic>? configuracion,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Restaurante(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      logoUrl: logoUrl ?? this.logoUrl,
      configuracion: configuracion ?? this.configuracion,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    nombre,
    direccion,
    telefono,
    logoUrl,
    activo,
    createdAt,
    updatedAt,
  ];
}
