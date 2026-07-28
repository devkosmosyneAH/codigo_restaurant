import 'package:equatable/equatable.dart';

/// Ventas agrupadas por mesero/cajero.
class VentaPorMesero extends Equatable {
  final String? meseroId;
  final String nombre;
  final int cantidadPedidos;
  final double total;

  const VentaPorMesero({
    this.meseroId,
    required this.nombre,
    required this.cantidadPedidos,
    required this.total,
  });

  @override
  List<Object?> get props => [meseroId, nombre, cantidadPedidos, total];
}
