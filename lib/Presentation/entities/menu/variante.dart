import 'package:equatable/equatable.dart';

/// Entidad de dominio: Variante de producto.
///
/// Representa una variación de un producto (ej: tamaño, preparación)
/// con un precio específico.
///
/// Ejemplo:
/// - Producto: "Café" → Variantes: "Chico $25", "Mediano $35", "Grande $45"
class Variante extends Equatable {
  final String id;
  final String productoId;
  final String nombre;
  final double precio;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Variante({
    required this.id,
    required this.productoId,
    required this.nombre,
    required this.precio,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Variante copyWith({
    String? id,
    String? productoId,
    String? nombre,
    double? precio,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Variante(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      nombre: nombre ?? this.nombre,
      precio: precio ?? this.precio,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    productoId,
    nombre,
    precio,
    activo,
    createdAt,
    updatedAt,
  ];
}
