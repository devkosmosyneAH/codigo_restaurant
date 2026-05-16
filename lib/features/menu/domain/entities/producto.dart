import 'package:equatable/equatable.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';

/// Entidad de dominio: Producto del menú.
///
/// Representa un platillo o bebida del restaurante.
/// Puede tener [variantes] (ej: tamaños) con precios distintos.
class Producto extends Equatable {
  final String id;
  final String restaurantId;
  final String categoriaId;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagenUrl;
  final bool disponible;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Lista de variantes del producto (cargada opcionalmente).
  final List<Variante> variantes;

  const Producto({
    required this.id,
    required this.restaurantId,
    required this.categoriaId,
    required this.nombre,
    this.descripcion,
    required this.precio,
    this.imagenUrl,
    this.disponible = true,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
    this.variantes = const [],
  });

  /// Precio mínimo considerando variantes.
  double get precioMinimo {
    if (variantes.isEmpty) return precio;
    final precios = variantes.map((v) => v.precio).toList()..add(precio);
    return precios.reduce((a, b) => a < b ? a : b);
  }

  /// Indica si tiene variantes configuradas.
  bool get tieneVariantes => variantes.isNotEmpty;

  Producto copyWith({
    String? id,
    String? restaurantId,
    String? categoriaId,
    String? nombre,
    String? descripcion,
    double? precio,
    String? imagenUrl,
    bool? disponible,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Variante>? variantes,
  }) {
    return Producto(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      categoriaId: categoriaId ?? this.categoriaId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precio: precio ?? this.precio,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      disponible: disponible ?? this.disponible,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      variantes: variantes ?? this.variantes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    categoriaId,
    nombre,
    descripcion,
    precio,
    imagenUrl,
    disponible,
    activo,
    createdAt,
    updatedAt,
  ];
}
