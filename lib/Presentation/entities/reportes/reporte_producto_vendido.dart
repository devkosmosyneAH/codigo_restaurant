import 'package:equatable/equatable.dart';

/// Producto con sus métricas de venta en un período.
class ProductoVendido extends Equatable {
  final String productoId;
  final String nombre;
  final String? categoriaNombre;
  final int cantidadVendida;
  final double totalIngresado;

  const ProductoVendido({
    required this.productoId,
    required this.nombre,
    this.categoriaNombre,
    required this.cantidadVendida,
    required this.totalIngresado,
  });

  @override
  List<Object?> get props => [
    productoId,
    nombre,
    categoriaNombre,
    cantidadVendida,
    totalIngresado,
  ];
}
