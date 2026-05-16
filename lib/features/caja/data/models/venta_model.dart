import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta_detalle.dart';

/// Modelo de datos: Venta.
///
/// Serialización SQLite para la entidad [Venta].
/// Los [detalles] se cargan opcionalmente con una query separada.
class VentaModel extends Venta {
  const VentaModel({
    required super.id,
    required super.restaurantId,
    required super.pedidoId,
    super.cajeroId,
    super.idCliente,
    super.tipoCliente,
    super.identificacionCliente,
    super.nombreCliente,
    super.telefonoCliente,
    super.direccionCliente,
    super.clienteNombre,
    super.clienteEmail,
    super.clienteIdentificacion,
    required super.metodoPago,
    super.tipoComprobante,
    super.estadoSri,
    required super.subtotal,
    super.impuestos,
    required super.total,
    super.descripcionPago,
    super.sriClaveAcceso,
    super.sriMensaje,
    super.sriComprobanteId,
    super.sriNumeroAutorizacion,
    super.sriFechaAutorizacion,
    super.sriXmlHash,
    super.sriRidePath,
    required super.createdAt,
    super.sourceCotizacionId,
    super.detalles,
    super.cajeroNombre,
  });

  factory VentaModel.fromMap(
    Map<String, dynamic> map, {
    List<VentaDetalle>? detalles,
  }) {
    return VentaModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      pedidoId: map['pedido_id'] as String,
      cajeroId: map['cajero_id'] as String?,
      idCliente: (map['id_cliente'] as num?)?.toInt(),
      tipoCliente:
          (map['tipo_cliente'] as String?) ??
          (((map['cliente_identificacion'] as String?)?.trim().isNotEmpty ??
                  false)
              ? 'registrado'
              : 'consumidor_final'),
      identificacionCliente:
          map['identificacion_cliente'] as String? ??
          map['cliente_identificacion'] as String?,
      nombreCliente:
          map['nombre_cliente'] as String? ?? map['cliente_nombre'] as String?,
      telefonoCliente: map['telefono_cliente'] as String?,
      direccionCliente: map['direccion_cliente'] as String?,
      clienteNombre: map['cliente_nombre'] as String?,
      clienteEmail: map['cliente_email'] as String?,
      clienteIdentificacion: map['cliente_identificacion'] as String?,
      metodoPago: MetodoPago.fromString(map['metodo_pago'] as String),
      tipoComprobante: TipoComprobante.fromString(
        (map['tipo_comprobante'] as String?) ?? 'ticket',
      ),
      estadoSri: EstadoComprobanteSri.fromString(
        (map['sri_estado'] as String?) ?? 'no_aplica',
      ),
      subtotal: (map['subtotal'] as num).toDouble(),
      impuestos: (map['impuestos'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num).toDouble(),
      descripcionPago: map['descripcion_pago'] as String?,
      sriClaveAcceso: map['sri_clave_acceso'] as String?,
      sriMensaje: map['sri_mensaje'] as String?,
      sriComprobanteId: map['sri_comprobante_id'] as String?,
      sriNumeroAutorizacion: map['sri_numero_autorizacion'] as String?,
      sriFechaAutorizacion: map['sri_fecha_autorizacion'] == null
          ? null
          : DateTime.parse(map['sri_fecha_autorizacion'] as String),
      sriXmlHash: map['sri_xml_hash'] as String?,
      sriRidePath: map['sri_ride_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      sourceCotizacionId: map['source_cotizacion_id'] as String?,
      detalles: detalles ?? const [],
      cajeroNombre: map['cajero_nombre'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'pedido_id': pedidoId,
      'cajero_id': cajeroId,
      'id_cliente': idCliente,
      'tipo_cliente': tipoCliente,
      'identificacion_cliente': identificacionCliente,
      'nombre_cliente': nombreCliente,
      'telefono_cliente': telefonoCliente,
      'direccion_cliente': direccionCliente,
      'cliente_nombre': clienteNombre,
      'cliente_email': clienteEmail,
      'cliente_identificacion': clienteIdentificacion,
      'metodo_pago': metodoPago.value,
      'tipo_comprobante': tipoComprobante.value,
      'sri_estado': estadoSri.value,
      'subtotal': subtotal,
      'impuestos': impuestos,
      'total': total,
      'descripcion_pago': descripcionPago,
      'sri_clave_acceso': sriClaveAcceso,
      'sri_mensaje': sriMensaje,
      'sri_comprobante_id': sriComprobanteId,
      'sri_numero_autorizacion': sriNumeroAutorizacion,
      'sri_fecha_autorizacion': sriFechaAutorizacion?.toIso8601String(),
      'sri_xml_hash': sriXmlHash,
      'sri_ride_path': sriRidePath,
      'created_at': createdAt.toIso8601String(),
      'source_cotizacion_id': sourceCotizacionId,
    };
  }

  factory VentaModel.fromEntity(Venta entity) {
    return VentaModel(
      id: entity.id,
      restaurantId: entity.restaurantId,
      pedidoId: entity.pedidoId,
      cajeroId: entity.cajeroId,
      idCliente: entity.idCliente,
      tipoCliente: entity.tipoCliente,
      identificacionCliente: entity.identificacionCliente,
      nombreCliente: entity.nombreCliente,
      telefonoCliente: entity.telefonoCliente,
      direccionCliente: entity.direccionCliente,
      clienteNombre: entity.clienteNombre,
      clienteEmail: entity.clienteEmail,
      clienteIdentificacion: entity.clienteIdentificacion,
      metodoPago: entity.metodoPago,
      tipoComprobante: entity.tipoComprobante,
      estadoSri: entity.estadoSri,
      subtotal: entity.subtotal,
      impuestos: entity.impuestos,
      total: entity.total,
      descripcionPago: entity.descripcionPago,
      sriClaveAcceso: entity.sriClaveAcceso,
      sriMensaje: entity.sriMensaje,
      sriComprobanteId: entity.sriComprobanteId,
      sriNumeroAutorizacion: entity.sriNumeroAutorizacion,
      sriFechaAutorizacion: entity.sriFechaAutorizacion,
      sriXmlHash: entity.sriXmlHash,
      sriRidePath: entity.sriRidePath,
      createdAt: entity.createdAt,
      sourceCotizacionId: entity.sourceCotizacionId,
      detalles: entity.detalles,
      cajeroNombre: entity.cajeroNombre,
    );
  }
}
