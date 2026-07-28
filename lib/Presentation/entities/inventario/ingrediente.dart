import 'package:equatable/equatable.dart';

/// Entidad de dominio: Ingrediente.
///
/// Representa un ingrediente del inventario del restaurante.
/// El módulo de inventario es opcional y puede activarse/desactivarse.
class Ingrediente extends Equatable {
  final String id;
  final String restaurantId;
  final String nombre;
  final String unidadMedida;
  final double stockActual;
  final double stockMinimo;
  final double costoUnitario;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Ingrediente({
    required this.id,
    required this.restaurantId,
    required this.nombre,
    required this.unidadMedida,
    this.stockActual = 0,
    this.stockMinimo = 0,
    this.costoUnitario = 0,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Indica si el stock está por debajo del mínimo.
  bool get stockBajo => stockActual <= stockMinimo;

  /// Indica si no hay stock disponible.
  bool get sinStock => stockActual <= 0;

  /// Texto descriptivo del stock: "150 gr", "3 lt", etc.
  String get stockDisplay => '${stockActual.toStringAsFixed(1)} $unidadMedida';

  Ingrediente copyWith({
    String? id,
    String? restaurantId,
    String? nombre,
    String? unidadMedida,
    double? stockActual,
    double? stockMinimo,
    double? costoUnitario,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ingrediente(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      nombre: nombre ?? this.nombre,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      costoUnitario: costoUnitario ?? this.costoUnitario,
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
    unidadMedida,
    stockActual,
    stockMinimo,
    costoUnitario,
    activo,
    createdAt,
    updatedAt,
  ];
}
