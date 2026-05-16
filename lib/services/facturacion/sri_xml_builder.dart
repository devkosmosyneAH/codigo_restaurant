import 'package:intl/intl.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/services/facturacion/fiscal_config_service.dart';

class SriXmlBuilder {
  const SriXmlBuilder();

  String buildAccessKey({
    required Venta venta,
    required FiscalConfig config,
    required String environmentCode,
    required String secuencial,
  }) {
    final fecha = DateFormat('ddMMyyyy').format(venta.createdAt);
    final docCode = switch (venta.tipoComprobante) {
      TipoComprobante.notaCredito => '04',
      _ => '01',
    };
    final ruc = normalizeDigits(config.ruc, 13, fallback: '9999999999999');
    final establecimiento = normalizeDigits(
      config.establecimiento,
      3,
      fallback: '001',
    );
    final puntoEmision = normalizeDigits(
      config.puntoEmision,
      3,
      fallback: '001',
    );
    final codigoNumerico = normalizeDigits(venta.id, 8, fallback: '12345678');
    const tipoEmision = '1';

    final base =
        '$fecha$docCode$ruc$environmentCode$establecimiento$puntoEmision$secuencial$codigoNumerico$tipoEmision';
    return '$base${modulo11(base)}';
  }

  String buildInvoiceXml({
    required Venta venta,
    required FiscalConfig config,
    required String accessKey,
    required String reference,
    required String environmentCode,
    required String secuencial,
  }) {
    final razonSocial = config.razonSocial.isNotEmpty
        ? config.razonSocial
        : AppConstants.appFullName;
    final nombreComercial = config.nombreComercial.isNotEmpty
        ? config.nombreComercial
        : razonSocial;
    final identificacion = venta.clienteIdentificacion ?? '9999999999999';
    final cliente = venta.clienteNombre ?? 'CONSUMIDOR FINAL';
    final fechaEmision = DateFormat('dd/MM/yyyy').format(venta.createdAt);
    final establecimiento = normalizeDigits(
      config.establecimiento,
      3,
      fallback: '001',
    );
    final puntoEmision = normalizeDigits(
      config.puntoEmision,
      3,
      fallback: '001',
    );
    final direccion = config.direccion.isNotEmpty
        ? config.direccion
        : 'Dirección no configurada';
    final ivaCodPct = ivaCodigoPorcentaje(venta.impuestos, venta.subtotal);
    final ivaTarifaValue = ivaTarifa(venta.impuestos, venta.subtotal);
    final baseImponible = venta.subtotal.toStringAsFixed(2);
    final valorIva = venta.impuestos.toStringAsFixed(2);
    final detallesXml = venta.detalles
        .map((detalle) {
          final descripcion = detalle.varianteNombre != null
              ? '${detalle.productoNombre ?? 'Producto'} (${detalle.varianteNombre})'
              : (detalle.productoNombre ?? 'Producto');
          final lineaBase = detalle.subtotal.toStringAsFixed(2);
          final lineaIva = venta.subtotal > 0
              ? (detalle.subtotal * venta.impuestos / venta.subtotal)
                    .toStringAsFixed(2)
              : '0.00';
          return '''
    <detalle>
      <codigoPrincipal>${xmlEscape(detalle.productoId)}</codigoPrincipal>
      <descripcion>${xmlEscape(descripcion)}</descripcion>
      <cantidad>${detalle.cantidad}</cantidad>
      <precioUnitario>${detalle.precioUnitario.toStringAsFixed(6)}</precioUnitario>
      <descuento>0.00</descuento>
      <precioTotalSinImpuesto>$lineaBase</precioTotalSinImpuesto>
      <impuestos>
        <impuesto>
          <codigo>2</codigo>
          <codigoPorcentaje>$ivaCodPct</codigoPorcentaje>
          <tarifa>$ivaTarifaValue</tarifa>
          <baseImponible>$lineaBase</baseImponible>
          <valor>$lineaIva</valor>
        </impuesto>
      </impuestos>
    </detalle>''';
        })
        .join('\n');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<factura id="comprobante" version="1.1.0">
  <infoTributaria>
    <ambiente>$environmentCode</ambiente>
    <tipoEmision>1</tipoEmision>
    <razonSocial>${xmlEscape(razonSocial)}</razonSocial>
    <nombreComercial>${xmlEscape(nombreComercial)}</nombreComercial>
    <ruc>${normalizeDigits(config.ruc, 13, fallback: '9999999999999')}</ruc>
    <claveAcceso>$accessKey</claveAcceso>
    <codDoc>01</codDoc>
    <estab>$establecimiento</estab>
    <ptoEmi>$puntoEmision</ptoEmi>
    <secuencial>$secuencial</secuencial>
    <dirMatriz>${xmlEscape(direccion)}</dirMatriz>
  </infoTributaria>
  <infoFactura>
    <fechaEmision>$fechaEmision</fechaEmision>
    <dirEstablecimiento>${xmlEscape(direccion)}</dirEstablecimiento>
    <tipoIdentificacionComprador>${tipoIdentificacion(identificacion)}</tipoIdentificacionComprador>
    <razonSocialComprador>${xmlEscape(cliente)}</razonSocialComprador>
    <identificacionComprador>${xmlEscape(identificacion)}</identificacionComprador>
    <totalSinImpuestos>$baseImponible</totalSinImpuestos>
    <totalDescuento>0.00</totalDescuento>
    <totalConImpuestos>
      <totalImpuesto>
        <codigo>2</codigo>
        <codigoPorcentaje>$ivaCodPct</codigoPorcentaje>
        <baseImponible>$baseImponible</baseImponible>
        <valor>$valorIva</valor>
      </totalImpuesto>
    </totalConImpuestos>
    <propina>0.00</propina>
    <importeTotal>${venta.total.toStringAsFixed(2)}</importeTotal>
    <moneda>DOLAR</moneda>
    <pagos>
      <pago>
        <formaPago>${formaPagoCode(venta.metodoPago)}</formaPago>
        <total>${venta.total.toStringAsFixed(2)}</total>
      </pago>
    </pagos>
  </infoFactura>
  <detalles>
$detallesXml
  </detalles>
  <infoAdicional>
    <campoAdicional nombre="referenciaInterna">${xmlEscape(reference)}</campoAdicional>
    <campoAdicional nombre="correo">${xmlEscape(venta.clienteEmail ?? '')}</campoAdicional>
  </infoAdicional>
</factura>
''';
  }

  String tipoIdentificacion(String identificacion) {
    if (identificacion == '9999999999999') return '07';
    if (identificacion.length == 13) return '04';
    if (identificacion.length == 10) return '05';
    return '06';
  }

  String ivaCodigoPorcentaje(double impuestos, double subtotal) {
    if (impuestos == 0 || subtotal == 0) return '0';
    final rate = (impuestos / subtotal * 100).round();
    if (rate <= 1) return '0';
    if (rate <= 12) return '2';
    if (rate <= 13) return '3';
    return '4';
  }

  String ivaTarifa(double impuestos, double subtotal) {
    if (impuestos == 0 || subtotal == 0) return '0.00';
    final rate = (impuestos / subtotal * 100).round();
    if (rate <= 1) return '0.00';
    if (rate <= 12) return '12.00';
    if (rate <= 13) return '13.00';
    if (rate <= 14) return '14.00';
    return '15.00';
  }

  String formaPagoCode(MetodoPago metodoPago) => switch (metodoPago) {
    MetodoPago.efectivo => '01',
    MetodoPago.tarjeta => '19',
    MetodoPago.transferencia => '17',
  };

  String normalizeDigits(
    String? value,
    int length, {
    required String fallback,
  }) {
    final digits = onlyDigits(value ?? '');
    final source = digits.isEmpty ? fallback : digits;
    final trimmed = source.length > length
        ? source.substring(source.length - length)
        : source;
    return trimmed.padLeft(length, '0');
  }

  String onlyDigits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  int modulo11(String input) {
    var factor = 2;
    var total = 0;

    for (var index = input.length - 1; index >= 0; index--) {
      total += int.parse(input[index]) * factor;
      factor = factor == 7 ? 2 : factor + 1;
    }

    final modulo = 11 - (total % 11);
    if (modulo == 11) return 0;
    if (modulo == 10) return 1;
    return modulo;
  }

  String xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
