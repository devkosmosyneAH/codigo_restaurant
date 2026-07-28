import 'package:equatable/equatable.dart';

/// Ventas agrupadas por día.
class VentaPorDia extends Equatable {
  /// Fecha en formato 'yyyy-MM-dd'.
  final String fecha;
  final double total;
  final int cantidadVentas;

  const VentaPorDia({
    required this.fecha,
    required this.total,
    required this.cantidadVentas,
  });

  @override
  List<Object?> get props => [fecha, total, cantidadVentas];
}
