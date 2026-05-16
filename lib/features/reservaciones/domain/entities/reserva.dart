import 'package:equatable/equatable.dart';
import 'package:restaurant_app/core/domain/enums.dart';

/// Entidad de dominio: Reserva.
class Reserva extends Equatable {
  final String id;
  final String restaurantId;
  final TipoReserva tipo;
  final String? mesaId;
  final String? mesaNombre;
  final int? idCliente;
  final String fecha; // YYYY-MM-DD
  final String horaInicio;
  final String horaFin;
  final int numeroPersonas;
  final EstadoReserva estado;
  final String? tipoEvento;
  final String clienteNombre;
  final String clienteTelefono;
  final String clienteEmail;
  final String? notas;
  final String? requerimientos;
  final DateTime createdAt;

  // ── Vínculo con cotización ───────────────────────────────────
  /// ID de la cotización que originó esta reserva (nullable).
  /// Una cotización puede tener como máximo una reserva asociada.
  final String? cotizacionId;

  // ── Mantelería y detalles del evento ───────────────────────────
  final String? nombreLocalEvento;
  final String? manteles;
  final String? colorManteleria;
  final double? precioEstimado;

  const Reserva({
    required this.id,
    required this.restaurantId,
    required this.tipo,
    this.mesaId,
    this.mesaNombre,
    this.idCliente,
    required this.fecha,
    this.horaInicio = '19:00',
    this.horaFin = '20:30',
    this.numeroPersonas = 2,
    this.estado = EstadoReserva.pendiente,
    this.tipoEvento,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.clienteEmail,
    this.notas,
    this.requerimientos,
    required this.createdAt,
    this.cotizacionId,
    this.nombreLocalEvento,
    this.manteles,
    this.colorManteleria,
    this.precioEstimado,
  });

  bool get esEventoPrivado => tipo == TipoReserva.local;
  String get horarioLabel => '$horaInicio - $horaFin';

  Reserva copyWith({
    String? id,
    String? restaurantId,
    TipoReserva? tipo,
    String? mesaId,
    String? mesaNombre,
    int? idCliente,
    String? fecha,
    String? horaInicio,
    String? horaFin,
    int? numeroPersonas,
    EstadoReserva? estado,
    String? tipoEvento,
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteEmail,
    String? notas,
    String? requerimientos,
    DateTime? createdAt,
    Object? cotizacionId = _keep,
    Object? nombreLocalEvento = _keep,
    Object? manteles = _keep,
    Object? colorManteleria = _keep,
    Object? precioEstimado = _keep,
  }) {
    return Reserva(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      tipo: tipo ?? this.tipo,
      mesaId: mesaId ?? this.mesaId,
      mesaNombre: mesaNombre ?? this.mesaNombre,
      idCliente: idCliente ?? this.idCliente,
      fecha: fecha ?? this.fecha,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      numeroPersonas: numeroPersonas ?? this.numeroPersonas,
      estado: estado ?? this.estado,
      tipoEvento: tipoEvento ?? this.tipoEvento,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      clienteEmail: clienteEmail ?? this.clienteEmail,
      notas: notas ?? this.notas,
      requerimientos: requerimientos ?? this.requerimientos,
      createdAt: createdAt ?? this.createdAt,
      cotizacionId: identical(cotizacionId, _keep)
          ? this.cotizacionId
          : cotizacionId as String?,
      nombreLocalEvento: identical(nombreLocalEvento, _keep)
          ? this.nombreLocalEvento
          : nombreLocalEvento as String?,
      manteles: identical(manteles, _keep)
          ? this.manteles
          : manteles as String?,
      colorManteleria: identical(colorManteleria, _keep)
          ? this.colorManteleria
          : colorManteleria as String?,
      precioEstimado: identical(precioEstimado, _keep)
          ? this.precioEstimado
          : precioEstimado as double?,
    );
  }

  static const Object _keep = Object();

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    tipo,
    mesaId,
    mesaNombre,
    idCliente,
    fecha,
    horaInicio,
    horaFin,
    numeroPersonas,
    estado,
    tipoEvento,
    clienteNombre,
    clienteTelefono,
    clienteEmail,
    notas,
    requerimientos,
    createdAt,
    cotizacionId,
    nombreLocalEvento,
    manteles,
    colorManteleria,
    precioEstimado,
  ];
}
