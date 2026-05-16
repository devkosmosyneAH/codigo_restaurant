import 'package:equatable/equatable.dart';
import 'package:restaurant_app/core/domain/enums.dart';

/// Ventas agrupadas por método de pago.
class VentaPorMetodo extends Equatable {
  final MetodoPago metodoPago;
  final int cantidad;
  final double total;

  /// Porcentaje sobre el total general (0–100).
  final double porcentaje;

  const VentaPorMetodo({
    required this.metodoPago,
    required this.cantidad,
    required this.total,
    required this.porcentaje,
  });

  @override
  List<Object?> get props => [metodoPago, cantidad, total, porcentaje];
}
