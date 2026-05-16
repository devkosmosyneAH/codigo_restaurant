import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta_detalle.dart';
import 'package:restaurant_app/services/facturacion/fiscal_config_service.dart';
import 'package:restaurant_app/services/facturacion/sri_xml_builder.dart';

void main() {
  group('SriXmlBuilder', () {
    const builder = SriXmlBuilder();

    test('genera clave de acceso factura con módulo 11 válido', () {
      final venta = _ventaFixture();
      const config = FiscalConfig(
        ruc: '1790012345001',
        razonSocial: 'RESTAURANTE DEMO S.A.',
        nombreComercial: 'Restaurante Demo',
        establecimiento: '002',
        puntoEmision: '003',
        direccion: 'Av. Siempre Viva 123',
      );

      final clave = builder.buildAccessKey(
        venta: venta,
        config: config,
        environmentCode: '1',
        secuencial: '000000123',
      );

      expect(clave, hasLength(49));
      expect(clave.substring(8, 10), '01');
      expect(clave.substring(10, 23), '1790012345001');
      expect(clave.substring(24, 30), '002003');
      expect(clave.substring(30, 39), '000000123');
      expect(clave, matches(RegExp(r'^\d{49}$')));
    });

    test('genera XML factura con emisor, comprador, totales e IVA', () {
      final venta = _ventaFixture();
      const config = FiscalConfig(
        ruc: '1790012345001',
        razonSocial: 'RESTAURANTE DEMO S.A.',
        nombreComercial: 'Restaurante Demo',
        establecimiento: '002',
        puntoEmision: '003',
        direccion: 'Av. Siempre Viva 123',
      );
      final clave = builder.buildAccessKey(
        venta: venta,
        config: config,
        environmentCode: '1',
        secuencial: '000000123',
      );

      final xml = builder.buildInvoiceXml(
        venta: venta,
        config: config,
        accessKey: clave,
        reference: 'FAC-20260501-ABCDEF12',
        environmentCode: '1',
        secuencial: '000000123',
      );

      expect(xml, contains('<factura id="comprobante" version="1.1.0">'));
      expect(xml, contains('<ruc>1790012345001</ruc>'));
      expect(xml, contains('<claveAcceso>$clave</claveAcceso>'));
      expect(
        xml,
        contains('<razonSocialComprador>Cliente Demo</razonSocialComprador>'),
      );
      expect(
        xml,
        contains(
          '<identificacionComprador>0102030400</identificacionComprador>',
        ),
      );
      expect(xml, contains('<totalSinImpuestos>10.00</totalSinImpuestos>'));
      expect(xml, contains('<importeTotal>11.50</importeTotal>'));
      expect(xml, contains('<codigoPorcentaje>4</codigoPorcentaje>'));
      expect(xml, contains('<formaPago>01</formaPago>'));
    });
  });
}

Venta _ventaFixture() {
  return Venta(
    id: 'abcdef12-3456-7890-abcd-ef1234567890',
    restaurantId: 'restaurante_a',
    pedidoId: 'pedido_1',
    clienteNombre: 'Cliente Demo',
    clienteEmail: 'cliente@example.com',
    clienteIdentificacion: '0102030400',
    metodoPago: MetodoPago.efectivo,
    tipoComprobante: TipoComprobante.factura,
    subtotal: 10,
    impuestos: 1.5,
    total: 11.5,
    createdAt: DateTime(2026, 5, 1, 12, 30),
    detalles: const [
      VentaDetalle(
        id: 'detalle_1',
        ventaId: 'abcdef12-3456-7890-abcd-ef1234567890',
        productoId: 'prod_1',
        cantidad: 1,
        precioUnitario: 10,
        subtotal: 10,
        productoNombre: 'Almuerzo ejecutivo',
      ),
    ],
  );
}
