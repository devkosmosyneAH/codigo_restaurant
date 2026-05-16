import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:restaurant_app/core/constants/app_constants.dart';

/// Datos editables para generar la cotización PDF.
class CotizacionPdfData {
  // ── Empresa ────────────────────────────────────────────────────
  final String nombreEmpresa;
  final String direccionEmpresa;
  final String telefonoEmpresa;
  final String emailEmpresa;
  final String logoUrl;

  // ── Cotización ─────────────────────────────────────────────────
  final String numeroCotizacion;
  final DateTime fechaEmision;
  final DateTime fechaVigencia;

  // ── Cliente ────────────────────────────────────────────────────
  final String clienteNombre;
  final String clienteTelefono;
  final String clienteEmail;
  final String? clienteEmpresa;
  final String? clienteDireccion;

  // ── Estado de la cotización ────────────────────────────────────
  final String estado;

  // ── Items ──────────────────────────────────────────────────────
  final List<CotizacionPdfItem> items;

  // ── Totales ────────────────────────────────────────────────────
  final double descuento;
  final double tasaImpuesto; // 0.12 = 12%

  // ── Textos adicionales ─────────────────────────────────────────
  final String notas;
  final String terminosComerciales;
  final bool esEventoPrivado;
  final String? fechaEvento;
  final String? horaEvento;
  final String? lugarEvento;
  final int? personas;

  // ── Hora de la proforma ────────────────────────────────────────
  final String? horaEmision;

  // ── Firma del propietario ──────────────────────────────────────
  final Uint8List? firmaImagenBytes; // imagen manuscrita cargada
  final String? firmaNombre; // nombre para firma digital
  final String? firmaCargo; // cargo / título
  final String? firmaNumeroDocumento; // cédula / RUC

  CotizacionPdfData({
    required this.nombreEmpresa,
    required this.direccionEmpresa,
    required this.telefonoEmpresa,
    required this.emailEmpresa,
    required this.logoUrl,
    required this.numeroCotizacion,
    required this.fechaEmision,
    required this.fechaVigencia,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.clienteEmail,
    this.clienteEmpresa,
    this.clienteDireccion,
    required this.estado,
    required this.items,
    required this.descuento,
    required this.tasaImpuesto,
    required this.notas,
    required this.terminosComerciales,
    required this.esEventoPrivado,
    this.fechaEvento,
    this.horaEvento,
    this.lugarEvento,
    this.personas,
    this.horaEmision,
    this.firmaImagenBytes,
    this.firmaNombre,
    this.firmaCargo,
    this.firmaNumeroDocumento,
  });

  double get subtotalBruto =>
      items.fold(0, (s, i) => s + i.cantidad * i.precioUnitario);
  double get subtotalConDescuento => subtotalBruto - descuento;
  double get totalImpuesto => subtotalConDescuento * tasaImpuesto;
  double get totalFinal => subtotalConDescuento + totalImpuesto;
}

/// Item de la cotización PDF.
class CotizacionPdfItem {
  String descripcion;
  int cantidad;
  double precioUnitario;

  CotizacionPdfItem({
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;
}

// ── Colores corporativos en PDF ───────────────────────────────────────────────

const _kPrimary = PdfColor.fromInt(0xFF1B7B8C);
const _kPrimaryLight = PdfColor.fromInt(0xFF2A9CAF);
const _kPrimaryDark = PdfColor.fromInt(0xFF125968);
const _kSecondary = PdfColor.fromInt(0xFF8B6339);
const _kTextPrimary = PdfColor.fromInt(0xFF212121);
const _kTextSecondary = PdfColor.fromInt(0xFF757575);
const _kSurface = PdfColor.fromInt(0xFFF8F4EF);
const _kWhite = PdfColors.white;
const _kBorder = PdfColor.fromInt(0xFFE0E0E0);

/// Servicio para generar PDFs profesionales de cotizaciones.
class CotizacionPdfService {
  CotizacionPdfService._();

  static final _currencyFmt = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  /// Genera el documento PDF y devuelve los bytes.
  static Future<Uint8List> generar(CotizacionPdfData data) async {
    final doc = pw.Document(
      title: 'Cotización ${data.numeroCotizacion}',
      author: data.nombreEmpresa,
      creator: AppConstants.appFullName,
    );

    // Intentar cargar el logo desde URL o data URI
    pw.ImageProvider? logoImage;
    final logoSource = data.logoUrl.trim();
    if (logoSource.isNotEmpty) {
      try {
        if (logoSource.startsWith('data:image')) {
          final commaIndex = logoSource.indexOf(',');
          if (commaIndex != -1) {
            final bytes = base64Decode(logoSource.substring(commaIndex + 1));
            logoImage = pw.MemoryImage(bytes);
          }
        } else if (logoSource.startsWith('http://') ||
            logoSource.startsWith('https://')) {
          final response = await http
              .get(Uri.parse(logoSource))
              .timeout(const Duration(seconds: 6));
          if (response.statusCode == 200) {
            logoImage = pw.MemoryImage(response.bodyBytes);
          }
        }
      } catch (_) {
        // fallback sin logo
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        footer: (ctx) => _buildFooter(ctx, data),
        build: (ctx) => [
          _buildHeader(data, logoImage),
          pw.SizedBox(height: 20),
          _buildMetaRow(data),
          pw.SizedBox(height: 16),
          _buildClientBlock(data),
          if (data.esEventoPrivado) ...[
            pw.SizedBox(height: 12),
            _buildEventoBlock(data),
          ],
          pw.SizedBox(height: 20),
          _buildItemsTable(data),
          pw.SizedBox(height: 14),
          _buildTotalesBlock(data),
          if (data.notas.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildTextBlock(
              titulo: 'Observaciones',
              contenido: data.notas.trim(),
              iconColor: _kSecondary,
            ),
          ],
          pw.SizedBox(height: 14),
          _buildTextBlock(
            titulo: 'Términos y Condiciones',
            contenido: data.terminosComerciales.trim(),
            iconColor: _kTextSecondary,
          ),
          pw.SizedBox(height: 24),
          _buildFirmaBlock(data),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header con logo y datos de empresa ───────────────────────────────────

  static pw.Widget _buildHeader(
    CotizacionPdfData data,
    pw.ImageProvider? logo,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _kPrimary,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(18),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo o iniciales
          pw.Container(
            width: 56,
            height: 56,
            decoration: pw.BoxDecoration(
              color: _kWhite,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: logo != null
                ? pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(logo, fit: pw.BoxFit.cover),
                  )
                : pw.Center(
                    child: pw.Text(
                      _initials(data.nombreEmpresa),
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _kPrimary,
                      ),
                    ),
                  ),
          ),
          pw.SizedBox(width: 16),
          // Datos empresa
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  data.nombreEmpresa,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _kWhite,
                  ),
                ),
                pw.SizedBox(height: 3),
                if (data.direccionEmpresa.isNotEmpty)
                  pw.Text(
                    data.direccionEmpresa,
                    style: pw.TextStyle(fontSize: 9, color: _kWhite),
                  ),
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    if (data.telefonoEmpresa.isNotEmpty) ...[
                      pw.Text(
                        'Tel: ${data.telefonoEmpresa}',
                        style: pw.TextStyle(fontSize: 9, color: _kWhite),
                      ),
                      pw.SizedBox(width: 12),
                    ],
                    if (data.emailEmpresa.isNotEmpty)
                      pw.Text(
                        data.emailEmpresa,
                        style: pw.TextStyle(fontSize: 9, color: _kWhite),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Título COTIZACIÓN + estado
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'COTIZACIÓN',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _kWhite,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: _kWhite,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'N° ${data.numeroCotizacion}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _kPrimary,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: _estadoBgColor(data.estado),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  _estadoLabel(data.estado).toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _kWhite,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Fechas de cotización ─────────────────────────────────────────────────

  static pw.Widget _buildMetaRow(CotizacionPdfData data) {
    final horaStr = (data.horaEmision ?? '').trim();
    final fechaLabel = horaStr.isNotEmpty
        ? '${_dateFmt.format(data.fechaEmision)}  $horaStr'
        : _dateFmt.format(data.fechaEmision);
    final fechaChipLabel = horaStr.isNotEmpty
        ? 'Fecha y hora de emisión'
        : 'Fecha de emisión';
    return pw.Row(
      children: [
        _metaChip(fechaChipLabel, fechaLabel),
        pw.SizedBox(width: 12),
        _metaChip('Válida hasta', _dateFmt.format(data.fechaVigencia)),
      ],
    );
  }

  static pw.Widget _metaChip(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: _kSurface,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _kBorder),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    label.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 7,
                      color: _kTextSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    value,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _kTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bloque cliente ───────────────────────────────────────────────────────

  static pw.Widget _buildClientBlock(CotizacionPdfData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _kPrimaryLight,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'COTIZADO A',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _kWhite,
              letterSpacing: 1.0,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 3,
                child: _clientField('Cliente', data.clienteNombre),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: _clientField('Teléfono', data.clienteTelefono),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 3,
                child: _clientField('Correo', data.clienteEmail),
              ),
            ],
          ),
          if ((data.clienteEmpresa ?? '').isNotEmpty ||
              (data.clienteDireccion ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                if ((data.clienteEmpresa ?? '').isNotEmpty) ...[
                  pw.Expanded(
                    flex: 3,
                    child: _clientField('Empresa', data.clienteEmpresa!),
                  ),
                  pw.SizedBox(width: 12),
                ],
                if ((data.clienteDireccion ?? '').isNotEmpty)
                  pw.Expanded(
                    flex: 5,
                    child: _clientField('Dirección', data.clienteDireccion!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _clientField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(fontSize: 7, color: _kWhite, letterSpacing: 0.5),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value.trim().isEmpty ? '—' : value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _kWhite,
          ),
        ),
      ],
    );
  }

  // ── Bloque evento privado ────────────────────────────────────────────────

  static pw.Widget _buildEventoBlock(CotizacionPdfData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _kSurface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _kSecondary),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DETALLES DEL EVENTO',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _kSecondary,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 24,
            runSpacing: 4,
            children: [
              if (data.fechaEvento != null)
                _eventoField('Fecha', data.fechaEvento!),
              if ((data.horaEvento ?? '').isNotEmpty)
                _eventoField('Hora', data.horaEvento!),
              if (data.personas != null)
                _eventoField('Personas', '${data.personas}'),
              if ((data.lugarEvento ?? '').isNotEmpty)
                _eventoField('Lugar', data.lugarEvento!),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tabla de items ───────────────────────────────────────────────────────

  static pw.Widget _buildItemsTable(CotizacionPdfData data) {
    const headerStyle = pw.TextStyle(fontSize: 9);
    const cellStyle = pw.TextStyle(fontSize: 10);

    final rows = <pw.TableRow>[
      // Encabezado
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _kPrimaryDark),
        children: [
          _tCell('#', headerStyle, align: pw.TextAlign.center, isHeader: true),
          _tCell('DESCRIPCIÓN', headerStyle, isHeader: true),
          _tCell(
            'CANT.',
            headerStyle,
            align: pw.TextAlign.center,
            isHeader: true,
          ),
          _tCell(
            'PRECIO UNIT.',
            headerStyle,
            align: pw.TextAlign.right,
            isHeader: true,
          ),
          _tCell(
            'SUBTOTAL',
            headerStyle,
            align: pw.TextAlign.right,
            isHeader: true,
          ),
        ],
      ),
      // Filas de items
      for (int i = 0; i < data.items.length; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: i.isEven ? _kWhite : _kSurface),
          children: [
            _tCell('${i + 1}', cellStyle, align: pw.TextAlign.center),
            _tCell(data.items[i].descripcion, cellStyle),
            _tCell(
              '${data.items[i].cantidad}',
              cellStyle,
              align: pw.TextAlign.center,
            ),
            _tCell(
              _currencyFmt.format(data.items[i].precioUnitario),
              cellStyle,
              align: pw.TextAlign.right,
            ),
            _tCell(
              _currencyFmt.format(data.items[i].subtotal),
              cellStyle,
              align: pw.TextAlign.right,
            ),
          ],
        ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(4),
        2: pw.FixedColumnWidth(40),
        3: pw.FixedColumnWidth(80),
        4: pw.FixedColumnWidth(80),
      },
      children: rows,
    );
  }

  static pw.Widget _tCell(
    String text,
    pw.TextStyle style, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: isHeader
            ? style.copyWith(fontWeight: pw.FontWeight.bold, color: _kWhite)
            : style.copyWith(color: _kTextPrimary),
      ),
    );
  }

  // ── Bloque de totales ────────────────────────────────────────────────────

  static pw.Widget _buildTotalesBlock(CotizacionPdfData data) {
    final tieneDescuento = data.descuento > 0;
    final tieneImpuesto = data.tasaImpuesto > 0;
    final labelImpuesto =
        'IVA (${(data.tasaImpuesto * 100).toStringAsFixed(0)}%)';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 220,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorder),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              _totalRow('Subtotal', _currencyFmt.format(data.subtotalBruto)),
              if (tieneDescuento)
                _totalRow(
                  'Descuento',
                  '- ${_currencyFmt.format(data.descuento)}',
                  valueColor: PdfColors.red700,
                ),
              if (tieneImpuesto)
                _totalRow(
                  labelImpuesto,
                  _currencyFmt.format(data.totalImpuesto),
                ),
              pw.Container(height: 0.5, color: _kBorder),
              _totalRow(
                'TOTAL',
                _currencyFmt.format(data.totalFinal),
                isBold: true,
                bgColor: _kPrimary,
                valueColor: _kWhite,
                labelColor: _kWhite,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? bgColor,
    PdfColor? valueColor,
    PdfColor? labelColor,
  }) {
    final style = pw.TextStyle(
      fontSize: isBold ? 12 : 10,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Container(
      color: bgColor,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: style.copyWith(color: labelColor ?? _kTextSecondary),
          ),
          pw.Text(
            value,
            style: style.copyWith(color: valueColor ?? _kTextPrimary),
          ),
        ],
      ),
    );
  }

  // ── Bloque de texto (notas / términos) ───────────────────────────────────

  static pw.Widget _buildTextBlock({
    required String titulo,
    required String contenido,
    PdfColor iconColor = _kPrimary,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _kSurface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _kBorder),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            titulo.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: iconColor,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            contenido,
            style: pw.TextStyle(
              fontSize: 10,
              color: _kTextPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bloque de firma ──────────────────────────────────────────────────────

  static pw.Widget _buildFirmaBlock(CotizacionPdfData data) {
    final hasImage = data.firmaImagenBytes != null;
    final hasDigital = (data.firmaNombre ?? '').trim().isNotEmpty;
    final timestampFirma = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.now());

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _kSurface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _kBorder),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Firma del propietario ─────────────────────────────
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'AUTORIZACIÓN',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _kPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 10),
                // Contenido de firma
                if (hasImage)
                  pw.Container(
                    height: 64,
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Image(
                      pw.MemoryImage(data.firmaImagenBytes!),
                      height: 64,
                      fit: pw.BoxFit.contain,
                    ),
                  )
                else if (hasDigital)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _kPrimary,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FIRMA DIGITAL CERTIFICADA',
                          style: pw.TextStyle(
                            fontSize: 7,
                            color: _kWhite,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          data.firmaNombre!,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: _kWhite,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if ((data.firmaCargo ?? '').isNotEmpty)
                          pw.Text(
                            data.firmaCargo!,
                            style: pw.TextStyle(fontSize: 8.5, color: _kWhite),
                          ),
                        if ((data.firmaNumeroDocumento ?? '').isNotEmpty)
                          pw.Text(
                            'Doc: ${data.firmaNumeroDocumento}',
                            style: pw.TextStyle(fontSize: 8, color: _kWhite),
                          ),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          height: 0.5,
                          color: _kWhite,
                          margin: const pw.EdgeInsets.symmetric(vertical: 2),
                        ),
                        pw.Text(
                          'Firmado el: $timestampFirma',
                          style: pw.TextStyle(fontSize: 7.5, color: _kWhite),
                        ),
                      ],
                    ),
                  )
                else
                  pw.SizedBox(height: 64),
                pw.SizedBox(height: 10),
                pw.Container(height: 0.5, color: _kTextPrimary),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Autorizado por: ${data.nombreEmpresa}',
                  style: pw.TextStyle(fontSize: 9, color: _kTextSecondary),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 32),
          // ── Espacio para firma del cliente ────────────────────
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ACEPTACIÓN DEL CLIENTE',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _kTextSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.SizedBox(height: 64),
                pw.SizedBox(height: 10),
                pw.Container(height: 0.5, color: _kTextSecondary),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Recibido / Aceptado: ${data.clienteNombre}',
                  style: pw.TextStyle(fontSize: 9, color: _kTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context ctx, CotizacionPdfData data) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${data.nombreEmpresa} · Cotización ${data.numeroCotizacion}',
            style: pw.TextStyle(fontSize: 8, color: _kTextSecondary),
          ),
          pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _kTextSecondary),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _estadoLabel(String estado) => switch (estado) {
    'borrador' => 'Borrador',
    'aceptada' => 'Aceptada',
    'rechazada' => 'Rechazada',
    'finalizada' => 'Finalizada',
    'cobrada' => 'Cobrada',
    _ => 'Pendiente',
  };

  static PdfColor _estadoBgColor(String estado) => switch (estado) {
    'aceptada' => const PdfColor.fromInt(0xFF388E3C),
    'rechazada' => const PdfColor.fromInt(0xFFD32F2F),
    'finalizada' => _kPrimaryDark,
    'borrador' => const PdfColor.fromInt(0xFF546E7A),
    'cobrada' => const PdfColor.fromInt(0xFF00796B),
    _ => const PdfColor.fromInt(0xFF757575),
  };

  static pw.Widget _eventoField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 7,
            color: _kTextSecondary,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _kTextPrimary,
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
