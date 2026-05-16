import 'package:equatable/equatable.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta_detalle.dart';

/// Entidad de dominio: Venta.
///
/// Representa una transacción de cobro completada.
/// Cada venta está asociada a un [pedidoId] y registra
/// el método de pago y el cajero que la procesó.
class Venta extends Equatable {
  final String id;
  final String restaurantId;
  final String pedidoId;
  final String? cajeroId;
  final int? idCliente;
  final String tipoCliente;
  final String? identificacionCliente;
  final String? nombreCliente;
  final String? telefonoCliente;
  final String? direccionCliente;
  final String? clienteNombre;
  final String? clienteEmail;
  final String? clienteIdentificacion;
  final MetodoPago metodoPago;
  final TipoComprobante tipoComprobante;
  final EstadoComprobanteSri estadoSri;
  final double subtotal;
  final double impuestos;
  final double total;
  final String? descripcionPago;
  final String? sriClaveAcceso;
  final String? sriMensaje;
  final String? sriComprobanteId;
  final String? sriNumeroAutorizacion;
  final DateTime? sriFechaAutorizacion;
  final String? sriXmlHash;
  final String? sriRidePath;
  final DateTime createdAt;

  /// Referencia opcional a la cotización que originó esta venta.
  final String? sourceCotizacionId;

  /// Detalles de los productos vendidos (cargados opcionalmente).
  final List<VentaDetalle> detalles;

  /// Nombre del cajero (para display).
  final String? cajeroNombre;

  const Venta({
    required this.id,
    required this.restaurantId,
    required this.pedidoId,
    this.cajeroId,
    this.idCliente,
    this.tipoCliente = 'consumidor_final',
    this.identificacionCliente,
    this.nombreCliente,
    this.telefonoCliente,
    this.direccionCliente,
    this.clienteNombre,
    this.clienteEmail,
    this.clienteIdentificacion,
    required this.metodoPago,
    this.tipoComprobante = TipoComprobante.ticket,
    this.estadoSri = EstadoComprobanteSri.noAplica,
    required this.subtotal,
    this.impuestos = 0,
    required this.total,
    this.descripcionPago,
    this.sriClaveAcceso,
    this.sriMensaje,
    this.sriComprobanteId,
    this.sriNumeroAutorizacion,
    this.sriFechaAutorizacion,
    this.sriXmlHash,
    this.sriRidePath,
    required this.createdAt,
    this.sourceCotizacionId,
    this.detalles = const [],
    this.cajeroNombre,
  });

  /// Cantidad de items vendidos.
  int get cantidadItems => detalles.fold(0, (sum, d) => sum + d.cantidad);

  Venta copyWith({
    String? id,
    String? restaurantId,
    String? pedidoId,
    String? cajeroId,
    int? idCliente,
    String? tipoCliente,
    String? identificacionCliente,
    String? nombreCliente,
    String? telefonoCliente,
    String? direccionCliente,
    String? clienteNombre,
    String? clienteEmail,
    String? clienteIdentificacion,
    MetodoPago? metodoPago,
    TipoComprobante? tipoComprobante,
    EstadoComprobanteSri? estadoSri,
    double? subtotal,
    double? impuestos,
    double? total,
    String? descripcionPago,
    String? sriClaveAcceso,
    String? sriMensaje,
    String? sriComprobanteId,
    String? sriNumeroAutorizacion,
    DateTime? sriFechaAutorizacion,
    String? sriXmlHash,
    String? sriRidePath,
    DateTime? createdAt,
    String? sourceCotizacionId,
    List<VentaDetalle>? detalles,
    String? cajeroNombre,
  }) {
    return Venta(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      pedidoId: pedidoId ?? this.pedidoId,
      cajeroId: cajeroId ?? this.cajeroId,
      idCliente: idCliente ?? this.idCliente,
      tipoCliente: tipoCliente ?? this.tipoCliente,
      identificacionCliente:
          identificacionCliente ?? this.identificacionCliente,
      nombreCliente: nombreCliente ?? this.nombreCliente,
      telefonoCliente: telefonoCliente ?? this.telefonoCliente,
      direccionCliente: direccionCliente ?? this.direccionCliente,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteEmail: clienteEmail ?? this.clienteEmail,
      clienteIdentificacion:
          clienteIdentificacion ?? this.clienteIdentificacion,
      metodoPago: metodoPago ?? this.metodoPago,
      tipoComprobante: tipoComprobante ?? this.tipoComprobante,
      estadoSri: estadoSri ?? this.estadoSri,
      subtotal: subtotal ?? this.subtotal,
      impuestos: impuestos ?? this.impuestos,
      total: total ?? this.total,
      descripcionPago: descripcionPago ?? this.descripcionPago,
      sriClaveAcceso: sriClaveAcceso ?? this.sriClaveAcceso,
      sriMensaje: sriMensaje ?? this.sriMensaje,
      sriComprobanteId: sriComprobanteId ?? this.sriComprobanteId,
      sriNumeroAutorizacion:
          sriNumeroAutorizacion ?? this.sriNumeroAutorizacion,
      sriFechaAutorizacion: sriFechaAutorizacion ?? this.sriFechaAutorizacion,
      sriXmlHash: sriXmlHash ?? this.sriXmlHash,
      sriRidePath: sriRidePath ?? this.sriRidePath,
      createdAt: createdAt ?? this.createdAt,
      sourceCotizacionId: sourceCotizacionId ?? this.sourceCotizacionId,
      detalles: detalles ?? this.detalles,
      cajeroNombre: cajeroNombre ?? this.cajeroNombre,
    );
  }

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    pedidoId,
    cajeroId,
    idCliente,
    tipoCliente,
    identificacionCliente,
    nombreCliente,
    telefonoCliente,
    direccionCliente,
    clienteNombre,
    clienteEmail,
    clienteIdentificacion,
    metodoPago,
    tipoComprobante,
    estadoSri,
    subtotal,
    impuestos,
    total,
    descripcionPago,
    sriClaveAcceso,
    sriMensaje,
    sriComprobanteId,
    sriNumeroAutorizacion,
    sriFechaAutorizacion,
    sriXmlHash,
    sriRidePath,
    createdAt,
    sourceCotizacionId,
  ];
}
