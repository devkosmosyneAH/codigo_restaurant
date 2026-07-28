import 'package:equatable/equatable.dart';

/// Entidad de dominio: Categoría del menú.
///
/// Las categorías agrupan los productos del menú
/// (ej: Entradas, Platos fuertes, Bebidas, Postres).
class Categoria extends Equatable {
  final String id;
  final String restaurantId;
  final String nombre;
  final String? descripcion;
  final int orden;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Categoria({
    required this.id,
    required this.restaurantId,
    required this.nombre,
    this.descripcion,
    this.orden = 0,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Categoria copyWith({
    String? id,
    String? restaurantId,
    String? nombre,
    String? descripcion,
    int? orden,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Categoria(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      orden: orden ?? this.orden,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    nombre,
    descripcion,
    orden,
    activo,
    createdAt,
    updatedAt,
  ];
}
