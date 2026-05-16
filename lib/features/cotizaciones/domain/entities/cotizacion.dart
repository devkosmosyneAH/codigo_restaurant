import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion_item.dart';

/// Entidad de dominio: Cotizacion.
class Cotizacion extends Equatable {
  final String id;
  final String restaurantId;
  final String? mesaId;
  final int? idCliente;
  final String clienteNombre;
  final String clienteTelefono;
  final String clienteEmail;
  final String estado;
  final bool reservaLocal;
  final int? personas;
  final String? fechaEvento;
  final String? comidaPreferida;
  final String? notas;
  final double subtotal;
  final double total;
  final DateTime createdAt;

  /// Empresa del cliente (opcional).
  final String? clienteEmpresa;

  /// Dirección del cliente (opcional).
  final String? clienteDireccion;

  /// Hora del evento, p.ej. '19:00' (opcional).
  final String? horaEvento;

  /// Lugar del evento (opcional).
  final String? lugarEvento;

  /// Descuento global en porcentaje (0-100).
  final double descuento;

  /// Tasa de impuesto global en porcentaje (0-100).
  final double tasaImpuesto;

  /// Origen de la cotización: 'publica' | 'admin'.
  final String origen;

  // ── Firma y hora de emisión del PDF ───────────────────────────
  final String? horaEmision;
  final String? firmaNombre;
  final String? firmaCargo;
  final String? firmaNumeroDocumento;
  final bool firmaEsImagen;
  final Uint8List? firmaImagenBytes;

  final List<CotizacionItem> items;

  const Cotizacion({
    required this.id,
    required this.restaurantId,
    this.mesaId,
    this.idCliente,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.clienteEmail,
    this.estado = 'pendiente',
    this.reservaLocal = false,
    this.personas,
    this.fechaEvento,
    this.comidaPreferida,
    this.notas,
    this.clienteEmpresa,
    this.clienteDireccion,
    this.horaEvento,
    this.lugarEvento,
    this.descuento = 0,
    this.tasaImpuesto = 0,
    this.origen = 'publica',
    this.horaEmision,
    this.firmaNombre,
    this.firmaCargo,
    this.firmaNumeroDocumento,
    this.firmaEsImagen = false,
    this.firmaImagenBytes,
    required this.subtotal,
    required this.total,
    required this.createdAt,
    this.items = const [],
  });

  Cotizacion copyWith({
    String? id,
    String? restaurantId,
    String? mesaId,
    int? idCliente,
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteEmail,
    String? estado,
    bool? reservaLocal,
    int? personas,
    String? fechaEvento,
    String? comidaPreferida,
    String? notas,
    String? clienteEmpresa,
    String? clienteDireccion,
    String? horaEvento,
    String? lugarEvento,
    double? descuento,
    double? tasaImpuesto,
    String? origen,
    String? horaEmision,
    String? firmaNombre,
    String? firmaCargo,
    String? firmaNumeroDocumento,
    bool? firmaEsImagen,
    Uint8List? firmaImagenBytes,
    double? subtotal,
    double? total,
    DateTime? createdAt,
    List<CotizacionItem>? items,
  }) {
    return Cotizacion(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      mesaId: mesaId ?? this.mesaId,
      idCliente: idCliente ?? this.idCliente,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      clienteEmail: clienteEmail ?? this.clienteEmail,
      estado: estado ?? this.estado,
      reservaLocal: reservaLocal ?? this.reservaLocal,
      personas: personas ?? this.personas,
      fechaEvento: fechaEvento ?? this.fechaEvento,
      comidaPreferida: comidaPreferida ?? this.comidaPreferida,
      notas: notas ?? this.notas,
      clienteEmpresa: clienteEmpresa ?? this.clienteEmpresa,
      clienteDireccion: clienteDireccion ?? this.clienteDireccion,
      horaEvento: horaEvento ?? this.horaEvento,
      lugarEvento: lugarEvento ?? this.lugarEvento,
      descuento: descuento ?? this.descuento,
      tasaImpuesto: tasaImpuesto ?? this.tasaImpuesto,
      origen: origen ?? this.origen,
      horaEmision: horaEmision ?? this.horaEmision,
      firmaNombre: firmaNombre ?? this.firmaNombre,
      firmaCargo: firmaCargo ?? this.firmaCargo,
      firmaNumeroDocumento: firmaNumeroDocumento ?? this.firmaNumeroDocumento,
      firmaEsImagen: firmaEsImagen ?? this.firmaEsImagen,
      firmaImagenBytes: firmaImagenBytes ?? this.firmaImagenBytes,
      subtotal: subtotal ?? this.subtotal,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    mesaId,
    idCliente,
    clienteNombre,
    clienteTelefono,
    clienteEmail,
    estado,
    reservaLocal,
    personas,
    fechaEvento,
    comidaPreferida,
    notas,
    clienteEmpresa,
    clienteDireccion,
    horaEvento,
    lugarEvento,
    descuento,
    tasaImpuesto,
    origen,
    horaEmision,
    firmaNombre,
    firmaCargo,
    firmaNumeroDocumento,
    firmaEsImagen,
    subtotal,
    total,
    createdAt,
  ];
}
