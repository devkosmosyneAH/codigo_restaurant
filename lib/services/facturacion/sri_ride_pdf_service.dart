import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/services/facturacion/fiscal_config_service.dart';

class SriRidePdfService {
  const SriRidePdfService();

  Future<Uint8List> buildFacturaRide({
    required Venta venta,
    required FiscalConfig config,
    String? numeroAutorizacion,
    DateTime? fechaAutorizacion,
    bool mock = false,
  }) async {
    final pdf = pw.Document();
    final money = NumberFormat.currency(
      locale: 'es_EC',
      symbol: AppConstants.currencySymbol,
    );
    final date = DateFormat('dd/MM/yyyy HH:mm');
    final authorization = numeroAutorizacion ?? venta.sriNumeroAutorizacion;
    final authorizationDate = fechaAutorizacion ?? venta.sriFechaAutorizacion;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _header(config, venta, mock),
          pw.SizedBox(height: 12),
          _authorizationBox(
            venta: venta,
            authorization: authorization,
            authorizationDate: authorizationDate,
            date: date,
          ),
          pw.SizedBox(height: 14),
          _buyerBox(venta),
          pw.SizedBox(height: 14),
          _detailsTable(venta, money),
          pw.SizedBox(height: 12),
          _totalsBox(venta, money),
          pw.SizedBox(height: 18),
          _accessKeyBox(venta),
          if (mock) ...[
            pw.SizedBox(height: 14),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.orange700),
              ),
              child: pw.Text(
                'RIDE generado en ambiente mock/homologacion. No representa una autorizacion productiva del SRI.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.orange900,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _header(FiscalConfig config, Venta venta, bool mock) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                config.razonSocial.isEmpty
                    ? AppConstants.appFullName
                    : config.razonSocial,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (config.nombreComercial.isNotEmpty)
                pw.Text(
                  config.nombreComercial,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                'RUC: ${config.ruc}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Direccion matriz: ${config.direccion}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Estab/Pto: ${config.establecimiento}-${config.puntoEmision}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        pw.Container(
          width: 180,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'RIDE FACTURA',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Ambiente: ${mock ? 'PRUEBAS MOCK' : config.ambiente.toUpperCase()}',
              ),
              pw.Text('Venta: ${venta.id}'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _authorizationBox({
    required Venta venta,
    required String? authorization,
    required DateTime? authorizationDate,
    required DateFormat date,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Clave de acceso',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(venta.sriClaveAcceso ?? 'Pendiente'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Numero de autorizacion',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(authorization ?? 'Pendiente de autorizacion'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Fecha de autorizacion',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            authorizationDate == null
                ? 'Pendiente'
                : date.format(authorizationDate),
          ),
        ],
      ),
    );
  }

  pw.Widget _buyerBox(Venta venta) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Comprador',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Nombre: ${venta.clienteNombre ?? venta.nombreCliente ?? 'Consumidor final'}',
          ),
          pw.Text(
            'Identificacion: ${venta.clienteIdentificacion ?? venta.identificacionCliente ?? '9999999999999'}',
          ),
          if ((venta.clienteEmail ?? '').isNotEmpty)
            pw.Text('Email: ${venta.clienteEmail}'),
          if ((venta.direccionCliente ?? '').isNotEmpty)
            pw.Text('Direccion: ${venta.direccionCliente}'),
        ],
      ),
    );
  }

  pw.Widget _detailsTable(Venta venta, NumberFormat money) {
    return pw.TableHelper.fromTextArray(
      headers: const ['Cant.', 'Descripcion', 'P. unitario', 'Subtotal'],
      data: venta.detalles
          .map(
            (detalle) => [
              detalle.cantidad.toString(),
              detalle.varianteNombre == null
                  ? (detalle.productoNombre ?? 'Producto')
                  : '${detalle.productoNombre ?? 'Producto'} (${detalle.varianteNombre})',
              money.format(detalle.precioUnitario),
              money.format(detalle.subtotal),
            ],
          )
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FixedColumnWidth(42),
        1: pw.FlexColumnWidth(3),
        2: pw.FixedColumnWidth(72),
        3: pw.FixedColumnWidth(72),
      },
    );
  }

  pw.Widget _totalsBox(Venta venta, NumberFormat money) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        child: pw.Column(
          children: [
            _totalRow('Subtotal', money.format(venta.subtotal)),
            _totalRow('IVA / impuestos', money.format(venta.impuestos)),
            pw.Divider(),
            _totalRow('Total', money.format(venta.total), bold: true),
          ],
        ),
      ),
    );
  }

  pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: bold ? 11 : 10,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  pw.Widget _accessKeyBox(Venta venta) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Representacion impresa del comprobante electronico'),
          pw.SizedBox(height: 4),
          pw.Text(
            venta.sriClaveAcceso ?? 'Clave pendiente',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }
}
