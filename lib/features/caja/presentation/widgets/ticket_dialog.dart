import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta_detalle.dart';

// ── Datos del establecimiento ─────────────────────────────────────────────
const _kNegocio = 'La Peña Bar & Restaurant';
const _kDireccion = 'Av. Principal #123, Col. Centro';
const _kTelefono = 'Tel: (55) 1234-5678';
const _kRedes = 'FB/IG: @LaPenaBar';

/// Diálogo que muestra el ticket/cuenta de una venta de forma profesional.
///
/// Diseñado para parecer un comprobante real de restaurante,
/// con encabezado del negocio, tabla de artículos, totales y
/// botón de impresión en formato térmico de 80 mm.
class TicketDialog extends StatelessWidget {
  final Venta venta;
  final String? mesaNombre;

  const TicketDialog({super.key, required this.venta, this.mesaNombre});

  static Future<void> show(
    BuildContext context, {
    required Venta venta,
    String? mesaNombre,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TicketDialog(venta: venta, mesaNombre: mesaNombre),
    );
  }

  // ── Cálculos ────────────────────────────────────────────────────────────

  double get _descuento =>
      (venta.subtotal - venta.total).clamp(0.0, double.maxFinite);
  bool get _tieneDescuento => _descuento > 0.01;
  bool get _esFactura => venta.tipoComprobante == TipoComprobante.factura;
  bool get _esConsumidorFinal =>
      !_esFactura &&
      ((venta.nombreCliente ?? venta.clienteNombre)?.trim().isEmpty ?? true) &&
      ((venta.identificacionCliente ?? venta.clienteIdentificacion)
              ?.trim()
              .isEmpty ??
          true);
  bool get _tieneDetalles => venta.detalles.isNotEmpty;
  int get _cantidadItems =>
      venta.detalles.fold(0, (sum, d) => sum + d.cantidad);

  String get _clienteDisplayName => _esConsumidorFinal
      ? 'Consumidor final'
      : ((venta.nombreCliente ?? venta.clienteNombre)?.trim().isNotEmpty == true
            ? (venta.nombreCliente ?? venta.clienteNombre)!
            : 'Cliente identificado');

  String get _tipoClienteLabel => _esFactura
      ? 'Cliente para factura'
      : (_esConsumidorFinal ? 'Consumidor final' : 'Cliente registrado');

  String get _folio =>
      '#${venta.id.replaceAll('-', '').toUpperCase().substring(0, 8)}';

  String _detalleNombre(VentaDetalle detalle) {
    return detalle.varianteNombre != null
        ? '${detalle.productoNombre ?? '-'} (${detalle.varianteNombre})'
        : (detalle.productoNombre ?? 'Consumo registrado');
  }

  String _detalleResumen(VentaDetalle detalle, NumberFormat fmt) {
    return '${detalle.cantidad} × \$${fmt.format(detalle.precioUnitario)}';
  }

  String get _leyendaSri {
    if (!_esFactura) {
      return 'Este comprobante no es válido como factura fiscal.';
    }
    return venta.estadoSri == EstadoComprobanteSri.preparado
        ? 'Factura preparada localmente. El envío al backend/SRI quedó comentado hasta activarlo.'
        : (venta.sriMensaje ?? 'Factura pendiente de configuración SRI.');
  }

  // ── Vista XML del comprobante ─────────────────────────────────────────────

  void _verXml(BuildContext context) {
    final xml = venta.sriMensaje ?? '';
    // El XML real está en el draft; usamos la clave de acceso como referencia
    final claveAcceso = venta.sriClaveAcceso ?? '';
    showDialog(
      context: context,
      builder: (ctx) {
        final viewport = MediaQuery.sizeOf(ctx);
        final dialogWidth = (viewport.width * 0.92).clamp(280.0, 560.0);
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.code_rounded, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Comprobante electrónico')),
            ],
          ),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clave de acceso
                  Text(
                    'Clave de acceso SRI',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          claveAcceso,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copiar clave',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: claveAcceso));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Clave de acceso copiada.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estado',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Chip(
                        label: Text(
                          venta.estadoSri.label,
                          style: const TextStyle(fontSize: 11),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor:
                            venta.estadoSri == EstadoComprobanteSri.preparado
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      xml.isNotEmpty
                          ? xml
                          : 'El XML se genera en tiempo real al cobrar. Registra una nueva venta de tipo Factura para verlo.',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'La transmisión real al SRI requiere activar el backend puente. '
                      'El XML y la clave de acceso ya están generados y listos para enviarse.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  // ── Impresión PDF ────────────────────────────────────────────────────────

  Future<void> _imprimir(BuildContext context) async {
    final fmt = NumberFormat('#,##0.00', 'es_MX');
    final fecha = DateFormat('dd/MM/yyyy').format(venta.createdAt);
    final hora = DateFormat('HH:mm').format(venta.createdAt);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        // Papel térmico de 80 mm, altura dinámica
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (ctx) {
          final normal = pw.TextStyle(fontSize: 9);
          final bold = pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          );
          final small = pw.TextStyle(fontSize: 7.5);
          final totalStyle = pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Encabezado negocio
              pw.Text(
                _kNegocio,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _kDireccion,
                style: small,
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(_kTelefono, style: small, textAlign: pw.TextAlign.center),
              pw.Text(_kRedes, style: small, textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.SizedBox(height: 4),

              // Folio + fecha
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Folio: $_folio', style: bold),
                  pw.Text('$fecha  $hora', style: normal),
                ],
              ),
              if (mesaNombre != null) ...[
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Mesa: $mesaNombre', style: normal),
                ),
              ],
              if (venta.cajeroNombre != null) ...[
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'Atendió: ${venta.cajeroNombre}',
                    style: normal,
                  ),
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Cliente: $_clienteDisplayName', style: normal),
              ),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Tipo: $_tipoClienteLabel', style: small),
              ),
              if (venta.nombreCliente != null ||
                  venta.clienteNombre != null ||
                  venta.clienteEmail != null ||
                  venta.identificacionCliente != null ||
                  venta.clienteIdentificacion != null) ...[
                if ((venta.identificacionCliente ??
                            venta.clienteIdentificacion) !=
                        null &&
                    (venta.identificacionCliente ??
                            venta.clienteIdentificacion)!
                        .isNotEmpty)
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'ID/RUC: ${(venta.identificacionCliente ?? venta.clienteIdentificacion)!}',
                      style: small,
                    ),
                  ),
                if (venta.clienteEmail != null &&
                    venta.clienteEmail!.isNotEmpty)
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(venta.clienteEmail!, style: small),
                  ),
              ],
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 4),

              // Tabla de artículos
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FixedColumnWidth(54),
                  2: const pw.FixedColumnWidth(54),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text(
                        'ARTÍCULO',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'DETALLE',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        'IMPORTE',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  if (!_tieneDetalles)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text('Detalle no disponible', style: small),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text(
                            '—',
                            style: small,
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text(
                            '\$${fmt.format(venta.total)}',
                            style: small,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ...venta.detalles.map((d) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                          child: pw.Text(_detalleNombre(d), style: small),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                          child: pw.Text(
                            _detalleResumen(d, fmt),
                            style: small,
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                          child: pw.Text(
                            '\$${fmt.format(d.subtotal)}',
                            style: small,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 4),

              // Totales
              if (venta.subtotal != venta.total || venta.impuestos > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal', style: normal),
                    pw.Text('\$${fmt.format(venta.subtotal)}', style: normal),
                  ],
                ),
              if (_tieneDescuento) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Descuento', style: normal),
                    pw.Text('-\$${fmt.format(_descuento)}', style: normal),
                  ],
                ),
              ],
              if (venta.impuestos > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('IVA', style: normal),
                    pw.Text('\$${fmt.format(venta.impuestos)}', style: normal),
                  ],
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: totalStyle),
                  pw.Text('\$${fmt.format(venta.total)}', style: totalStyle),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 4),

              // Forma de pago
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Comprobante: ${venta.tipoComprobante.label}',
                  style: bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Forma de pago: ${venta.metodoPago.label}',
                  style: bold,
                ),
              ),
              if (venta.sriClaveAcceso != null &&
                  venta.sriClaveAcceso!.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'Referencia SRI: ${venta.sriClaveAcceso}',
                    style: small,
                  ),
                ),
              ],
              if (venta.descripcionPago != null &&
                  venta.descripcionPago!.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(venta.descripcionPago!, style: small),
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 6),

              // Pie
              pw.Center(
                child: pw.Text(
                  '¡Gracias por visitarnos!',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Vuelva pronto  ·  $_kRedes',
                  style: pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  _leyendaSri,
                  style: pw.TextStyle(fontSize: 6.5),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (!context.mounted) return;
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Ticket_$_folio',
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fmt = NumberFormat('#,##0.00', 'es_MX');
    final fecha = DateFormat('dd/MM/yyyy').format(venta.createdAt);
    final hora = DateFormat('HH:mm').format(venta.createdAt);
    final viewport = MediaQuery.sizeOf(context);
    final dialogMaxWidth = (viewport.width * 0.92).clamp(280.0, 400.0);
    final dialogMaxHeight = (viewport.height * 0.90).clamp(420.0, 760.0);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogMaxWidth,
          maxHeight: dialogMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Encabezado del negocio ─────────────────────────
            Container(
              width: double.infinity,
              color: cs.primary,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.restaurant_menu, color: cs.onPrimary, size: 30),
                  const SizedBox(height: 6),
                  Text(
                    _kNegocio,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _kDireccion,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    _kTelefono,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    _kRedes,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),

            // ── Cuerpo del ticket ──────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Folio + fecha/hora
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LabelSm('FOLIO', theme),
                              Text(
                                _folio,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _LabelSm('FECHA / HORA', theme),
                            Text(
                              '$fecha  $hora',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Mesa + cajero
                    if (mesaNombre != null || venta.cajeroNombre != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (mesaNombre != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _LabelSm('MESA', theme),
                                  Text(
                                    mesaNombre!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (venta.cajeroNombre != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _LabelSm('ATENDIÓ', theme),
                                Text(
                                  venta.cajeroNombre!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LabelSm('CLIENTE', theme),
                              Text(
                                _clienteDisplayName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _tipoClienteLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _esFactura
                                      ? Colors.orange.shade700
                                      : cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (venta.clienteEmail != null &&
                                  venta.clienteEmail!.isNotEmpty)
                                Text(
                                  venta.clienteEmail!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TicketMetaChip(
                          icon: Icons.shopping_bag_outlined,
                          label: _cantidadItems > 0
                              ? '$_cantidadItems artículo(s)'
                              : 'Consumo registrado',
                        ),
                        if (mesaNombre != null)
                          _TicketMetaChip(
                            icon: Icons.table_restaurant_rounded,
                            label: mesaNombre!,
                          ),
                        _TicketMetaChip(
                          icon: _iconMetodo(venta.metodoPago),
                          label: venta.metodoPago.label,
                        ),
                        _TicketMetaChip(
                          icon: _esFactura
                              ? Icons.receipt_long_rounded
                              : Icons.person_outline_rounded,
                          label: _esFactura ? 'Factura' : 'Consumidor final',
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const _DashedDivider(),
                    const SizedBox(height: 10),

                    // Cabecera de la tabla de artículos
                    DefaultTextStyle.merge(
                      style: theme.textTheme.labelSmall!.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                      child: Row(
                        children: const [
                          Expanded(child: Text('ARTÍCULO')),
                          SizedBox(
                            width: 88,
                            child: Text('DETALLE', textAlign: TextAlign.center),
                          ),
                          SizedBox(width: 8),
                          SizedBox(
                            width: 72,
                            child: Text('IMPORTE', textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Artículos
                    if (!_tieneDetalles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          'El detalle del pedido no está disponible en este comprobante.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ...venta.detalles.map((d) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _detalleNombre(d),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    d.varianteNombre != null &&
                                            d.varianteNombre!.isNotEmpty
                                        ? 'Variante: ${d.varianteNombre}'
                                        : 'Producto del pedido',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 88,
                              child: Text(
                                _detalleResumen(d, fmt),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: Text(
                                '\$${fmt.format(d.subtotal)}',
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 8),
                    const _DashedDivider(),
                    const SizedBox(height: 8),

                    // Subtotal / descuento / impuestos
                    if (venta.subtotal != venta.total ||
                        venta.impuestos > 0) ...[
                      _TotalsRow(
                        label: 'Subtotal',
                        valueStr: '\$${fmt.format(venta.subtotal)}',
                        theme: theme,
                      ),
                    ],
                    if (_tieneDescuento)
                      _TotalsRow(
                        label: 'Descuento',
                        valueStr: '-\$${fmt.format(_descuento)}',
                        theme: theme,
                        valueColor: Colors.green.shade700,
                      ),
                    if (venta.impuestos > 0)
                      _TotalsRow(
                        label: 'IVA (incluido)',
                        valueStr: '\$${fmt.format(venta.impuestos)}',
                        theme: theme,
                      ),

                    const SizedBox(height: 6),

                    // TOTAL destacado
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            '\$${fmt.format(venta.total)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    const _DashedDivider(),
                    const SizedBox(height: 8),

                    // Forma de pago
                    Row(
                      children: [
                        Icon(
                          _esFactura
                              ? Icons.receipt_long_outlined
                              : Icons.receipt_outlined,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Comprobante: ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          venta.tipoComprobante.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _iconMetodo(venta.metodoPago),
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Forma de pago: ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          venta.metodoPago.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (venta.clienteIdentificacion != null &&
                        venta.clienteIdentificacion!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ID/RUC: ${venta.clienteIdentificacion}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (venta.sriClaveAcceso != null &&
                        venta.sriClaveAcceso!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Referencia SRI: ${venta.sriClaveAcceso}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (venta.descripcionPago != null &&
                        venta.descripcionPago!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        venta.descripcionPago!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const _DashedDivider(),
                    const SizedBox(height: 10),

                    // Pie de ticket
                    Center(
                      child: Text(
                        '¡Gracias por visitarnos!',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Center(
                      child: Text(
                        'Vuelva pronto  ·  $_kRedes',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        _leyendaSri,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // ── Botones de acción ──────────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _imprimir(context),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Imprimir'),
                  ),
                  if (_esFactura &&
                      venta.sriClaveAcceso != null &&
                      venta.sriClaveAcceso!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _verXml(context),
                      icon: const Icon(Icons.code_rounded, size: 18),
                      label: const Text('Ver XML'),
                    ),
                  ],
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconMetodo(MetodoPago m) => switch (m) {
    MetodoPago.efectivo => Icons.payments_outlined,
    MetodoPago.tarjeta => Icons.credit_card_outlined,
    MetodoPago.transferencia => Icons.account_balance_outlined,
  };
}

// ── Widgets auxiliares ───────────────────────────────────────────────────────

/// Etiqueta pequeña de sección en estilo ALL-CAPS.
class _LabelSm extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _LabelSm(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Divisor con línea punteada estilo ticket térmico.
class _TicketMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TicketMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return LayoutBuilder(
      builder: (_, constraints) {
        const dashW = 5.0;
        const gapW = 4.0;
        final count = (constraints.maxWidth / (dashW + gapW)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dashW,
              height: 1,
              margin: const EdgeInsets.only(right: gapW),
              color: color,
            ),
          ),
        );
      },
    );
  }
}

/// Fila de totales (subtotal, descuento, IVA).
class _TotalsRow extends StatelessWidget {
  final String label;
  final String valueStr;
  final ThemeData theme;
  final Color? valueColor;

  const _TotalsRow({
    required this.label,
    required this.valueStr,
    required this.theme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            valueStr,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
