import 'package:equatable/equatable.dart';

/// Resumen agregado de ventas para un período.
class ResumenVentas extends Equatable {
  final double totalVentas;
  final int cantidadVentas;
  final double promedioTicket;
  final double ticketMaximo;
  final double ticketMinimo;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  const ResumenVentas({
    required this.totalVentas,
    required this.cantidadVentas,
    required this.promedioTicket,
    required this.ticketMaximo,
    required this.ticketMinimo,
    required this.fechaInicio,
    required this.fechaFin,
  });

  bool get tieneVentas => cantidadVentas > 0;

  @override
  List<Object?> get props => [
    totalVentas,
    cantidadVentas,
    promedioTicket,
    ticketMaximo,
    ticketMinimo,
    fechaInicio,
    fechaFin,
  ];
}
