import 'package:equatable/equatable.dart';

/// Entidad de dominio: Relación Producto-Ingrediente.
///
/// Define cuánto de cada ingrediente se necesita para
/// preparar un producto. Esto permite el descuento automático
/// de inventario al vender.
class ProductoIngrediente extends Equatable {
  final String id;
  final String productoId;
  final String ingredienteId;
  final double cantidadRequerida;

  /// Nombre del ingrediente (para display).
  final String? ingredienteNombre;

  /// Unidad de medida del ingrediente (para display).
  final String? unidadMedida;

  const ProductoIngrediente({
    required this.id,
    required this.productoId,
    required this.ingredienteId,
    required this.cantidadRequerida,
    this.ingredienteNombre,
    this.unidadMedida,
  });

  /// Texto descriptivo: "200 gr de Pollo"
  String get descripcion =>
      '${cantidadRequerida.toStringAsFixed(1)} ${unidadMedida ?? ''} de ${ingredienteNombre ?? ingredienteId}';

  ProductoIngrediente copyWith({
    String? id,
    String? productoId,
    String? ingredienteId,
    double? cantidadRequerida,
    String? ingredienteNombre,
    String? unidadMedida,
  }) {
    return ProductoIngrediente(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      ingredienteId: ingredienteId ?? this.ingredienteId,
      cantidadRequerida: cantidadRequerida ?? this.cantidadRequerida,
      ingredienteNombre: ingredienteNombre ?? this.ingredienteNombre,
      unidadMedida: unidadMedida ?? this.unidadMedida,
    );
  }

  @override
  List<Object?> get props => [id, productoId, ingredienteId, cantidadRequerida];
}
