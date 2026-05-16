import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta_detalle.dart';
import 'package:restaurant_app/services/facturacion/fiscal_config_service.dart';
import 'package:restaurant_app/services/facturacion/sri_ride_pdf_service.dart';

void main() {
  test('SriRidePdfService genera un PDF RIDE no vacio', () async {
    const service = SriRidePdfService();
    final bytes = await service.buildFacturaRide(
      venta: _ventaFixture(),
      config: const FiscalConfig(
        ruc: '1790012345001',
        razonSocial: 'RESTAURANTE DEMO S.A.',
        nombreComercial: 'Restaurante Demo',
        establecimiento: '001',
        puntoEmision: '002',
        direccion: 'Av. Siempre Viva 123',
        ambiente: 'pruebas',
      ),
      mock: true,
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}

Venta _ventaFixture() {
  return Venta(
    id: 'venta_ride_1',
    restaurantId: 'restaurante_a',
    pedidoId: 'pedido_1',
    clienteNombre: 'Cliente Demo',
    clienteEmail: 'cliente@example.com',
    clienteIdentificacion: '0102030400',
    metodoPago: MetodoPago.efectivo,
    tipoComprobante: TipoComprobante.factura,
    estadoSri: EstadoComprobanteSri.autorizado,
    subtotal: 10,
    impuestos: 1.5,
    total: 11.5,
    sriClaveAcceso: '1234567890123456789012345678901234567890123456789',
    sriNumeroAutorizacion: '1234567890123456789012345678901234567890123456789',
    sriFechaAutorizacion: DateTime(2026, 5, 1, 12, 45),
    createdAt: DateTime(2026, 5, 1, 12, 30),
    detalles: const [
      VentaDetalle(
        id: 'detalle_1',
        ventaId: 'venta_ride_1',
        productoId: 'prod_1',
        cantidad: 1,
        precioUnitario: 10,
        subtotal: 10,
        productoNombre: 'Almuerzo ejecutivo',
      ),
    ],
  );
}
