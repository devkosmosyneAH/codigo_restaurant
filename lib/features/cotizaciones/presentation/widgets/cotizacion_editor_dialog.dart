import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/usecases/cotizacion_usecases.dart';
import 'package:restaurant_app/features/cotizaciones/services/cotizacion_pdf_service.dart';
import 'package:restaurant_app/features/pagina_publica/domain/entities/public_config.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/public_config_provider.dart';

/// Diálogo completo para editar y generar el PDF de una cotización.
///
/// Permite al usuario ajustar todos los campos antes de generar el PDF,
/// y luego compartirlo por impresión, correo o WhatsApp.
class CotizacionEditorDialog extends ConsumerStatefulWidget {
  final Cotizacion cotizacion;
  final bool persistirFirma;

  const CotizacionEditorDialog({
    super.key,
    required this.cotizacion,
    this.persistirFirma = true,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    Cotizacion cotizacion, {
    bool persistirFirma = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CotizacionEditorDialog(
        cotizacion: cotizacion,
        persistirFirma: persistirFirma,
      ),
    );
  }

  @override
  ConsumerState<CotizacionEditorDialog> createState() =>
      _CotizacionEditorDialogState();
}

class _CotizacionEditorDialogState
    extends ConsumerState<CotizacionEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  // ── Empresa ────────────────────────────────────────────────────
  late final TextEditingController _nombreEmpresaCtrl;
  late final TextEditingController _direccionEmpresaCtrl;
  late final TextEditingController _telefonoEmpresaCtrl;
  late final TextEditingController _emailEmpresaCtrl;

  // ── Cotización ─────────────────────────────────────────────────
  late final TextEditingController _numCotCtrl;
  late DateTime _fechaEmision;
  late DateTime _fechaVigencia;

  // ── Cliente ────────────────────────────────────────────────────
  late final TextEditingController _clienteNombreCtrl;
  late final TextEditingController _clienteTelCtrl;
  late final TextEditingController _clienteEmailCtrl;

  // ── Items ──────────────────────────────────────────────────────
  late List<CotizacionPdfItem> _items;

  // ── Totales ────────────────────────────────────────────────────
  late final TextEditingController _descuentoCtrl;
  late final TextEditingController _tasaImpCtrl;

  // ── Textos ─────────────────────────────────────────────────────
  late final TextEditingController _notasCtrl;
  late final TextEditingController _terminosCtrl;

  bool _generando = false;

  // ── Firma y hora de la proforma ───────────────────────────────
  bool _firmaEsImagen = false;
  Uint8List? _firmaImagenBytes;
  TimeOfDay? _horaEmision;
  late final TextEditingController _firmaNombreCtrl;
  late final TextEditingController _firmaCargoCtrl;
  late final TextEditingController _firmaDocCtrl;

  static final _currencyFmt = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    final c = widget.cotizacion;
    final numStr =
        'COT-${c.id.replaceAll('-', '').toUpperCase().substring(0, 8)}';

    _fechaEmision = DateTime.now();
    _fechaVigencia = DateTime.now().add(const Duration(days: 30));

    _numCotCtrl = TextEditingController(text: numStr);
    _clienteNombreCtrl = TextEditingController(text: c.clienteNombre);
    _clienteTelCtrl = TextEditingController(text: c.clienteTelefono);
    _clienteEmailCtrl = TextEditingController(text: c.clienteEmail);

    // Items desde la cotización existente
    _items = c.items
        .map(
          (i) => CotizacionPdfItem(
            descripcion: i.productoNombre,
            cantidad: i.cantidad,
            precioUnitario: i.precioUnitario,
          ),
        )
        .toList();

    // Si no hay items pero hay comida preferida, agregar como línea genérica
    if (_items.isEmpty && (c.comidaPreferida?.trim().isNotEmpty ?? false)) {
      _items.add(
        CotizacionPdfItem(
          descripcion: c.comidaPreferida!.trim(),
          cantidad: c.personas ?? 1,
          precioUnitario: 0,
        ),
      );
    }

    // Si aún no hay items, al menos un item vacío para empezar
    if (_items.isEmpty) {
      _items.add(
        CotizacionPdfItem(descripcion: '', cantidad: 1, precioUnitario: 0),
      );
    }

    // Descuento: diferencia entre subtotal y total
    final descuento = (c.subtotal - c.total).clamp(0.0, double.infinity);
    _descuentoCtrl = TextEditingController(text: descuento.toStringAsFixed(2));
    _tasaImpCtrl = TextEditingController(text: '12.00');
    _notasCtrl = TextEditingController(text: c.notas ?? '');
    _terminosCtrl = TextEditingController(text: _kTerminosDefault);

    // Empresa: se inicializa en build al leer el provider
    _nombreEmpresaCtrl = TextEditingController();
    _direccionEmpresaCtrl = TextEditingController();
    _telefonoEmpresaCtrl = TextEditingController();
    _emailEmpresaCtrl = TextEditingController();
    // Firma: cargar desde la cotización guardada
    _firmaEsImagen = c.firmaEsImagen;
    _firmaImagenBytes = c.firmaImagenBytes;
    _horaEmision = c.horaEmision != null
        ? _parseTimeOfDay(c.horaEmision!)
        : null;
    _firmaNombreCtrl = TextEditingController(text: c.firmaNombre ?? '');
    _firmaCargoCtrl = TextEditingController(text: c.firmaCargo ?? '');
    _firmaDocCtrl = TextEditingController(text: c.firmaNumeroDocumento ?? '');
  }

  /// Convierte 'HH:mm' en [TimeOfDay].
  TimeOfDay? _parseTimeOfDay(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  bool _empresaIniciada = false;

  void _initEmpresa(PublicConfig? config) {
    if (_empresaIniciada) return;
    _empresaIniciada = true;
    _nombreEmpresaCtrl.text = config?.nombreNegocio.isNotEmpty == true
        ? config!.nombreNegocio
        : AppConstants.appFullName;
    _direccionEmpresaCtrl.text = config?.direccion ?? '';
    _telefonoEmpresaCtrl.text = config?.telefono.isNotEmpty == true
        ? config!.telefono
        : AppConstants.contactPhone;
    _emailEmpresaCtrl.text = config?.emailContacto.isNotEmpty == true
        ? config!.emailContacto
        : AppConstants.contactEmail;
  }

  @override
  void dispose() {
    _nombreEmpresaCtrl.dispose();
    _direccionEmpresaCtrl.dispose();
    _telefonoEmpresaCtrl.dispose();
    _emailEmpresaCtrl.dispose();
    _numCotCtrl.dispose();
    _clienteNombreCtrl.dispose();
    _clienteTelCtrl.dispose();
    _clienteEmailCtrl.dispose();
    _descuentoCtrl.dispose();
    _tasaImpCtrl.dispose();
    _notasCtrl.dispose();
    _terminosCtrl.dispose();
    _firmaNombreCtrl.dispose();
    _firmaCargoCtrl.dispose();
    _firmaDocCtrl.dispose();
    super.dispose();
  }

  // ── Construcción del PDF data desde los campos ─────────────────────────

  CotizacionPdfData _buildPdfData(String logoUrl) {
    return CotizacionPdfData(
      nombreEmpresa: _nombreEmpresaCtrl.text.trim(),
      direccionEmpresa: _direccionEmpresaCtrl.text.trim(),
      telefonoEmpresa: _telefonoEmpresaCtrl.text.trim(),
      emailEmpresa: _emailEmpresaCtrl.text.trim(),
      logoUrl: logoUrl,
      numeroCotizacion: _numCotCtrl.text.trim(),
      fechaEmision: _fechaEmision,
      fechaVigencia: _fechaVigencia,
      clienteNombre: _clienteNombreCtrl.text.trim(),
      clienteTelefono: _clienteTelCtrl.text.trim(),
      clienteEmail: _clienteEmailCtrl.text.trim(),
      clienteEmpresa: widget.cotizacion.clienteEmpresa,
      clienteDireccion: widget.cotizacion.clienteDireccion,
      estado: widget.cotizacion.estado,
      items: _items,
      descuento: double.tryParse(_descuentoCtrl.text) ?? 0,
      tasaImpuesto: (double.tryParse(_tasaImpCtrl.text) ?? 12) / 100,
      notas: _notasCtrl.text.trim(),
      terminosComerciales: _terminosCtrl.text.trim(),
      esEventoPrivado: widget.cotizacion.reservaLocal,
      fechaEvento: widget.cotizacion.fechaEvento,
      horaEvento: widget.cotizacion.horaEvento,
      lugarEvento: widget.cotizacion.lugarEvento,
      personas: widget.cotizacion.personas,
      horaEmision: _horaEmision != null
          ? '${_horaEmision!.hour.toString().padLeft(2, '0')}:'
                '${_horaEmision!.minute.toString().padLeft(2, '0')}'
          : null,
      firmaImagenBytes: _firmaEsImagen ? _firmaImagenBytes : null,
      firmaNombre: _firmaEsImagen
          ? null
          : _firmaNombreCtrl.text.trim().isEmpty
          ? null
          : _firmaNombreCtrl.text.trim(),
      firmaCargo: _firmaEsImagen
          ? null
          : _firmaCargoCtrl.text.trim().isEmpty
          ? null
          : _firmaCargoCtrl.text.trim(),
      firmaNumeroDocumento: _firmaEsImagen
          ? null
          : _firmaDocCtrl.text.trim().isEmpty
          ? null
          : _firmaDocCtrl.text.trim(),
    );
  }

  double get _totalCalculado {
    final subtotal = _items.fold(0.0, (s, i) => s + i.subtotal);
    final descuento = double.tryParse(_descuentoCtrl.text) ?? 0;
    final tasa = (double.tryParse(_tasaImpCtrl.text) ?? 12) / 100;
    final base = subtotal - descuento;
    return base + base * tasa;
  }

  // ── Generar y devolver bytes PDF ───────────────────────────────────────

  Future<Uint8List?> _generarPdf() async {
    if (!_formKey.currentState!.validate()) return null;
    setState(() => _generando = true);
    try {
      final cfg = ref.read(publicConfigProvider).config;
      final logoUrl = cfg?.logoUrl ?? '';
      final data = _buildPdfData(logoUrl);
      final bytes = await CotizacionPdfService.generar(data);
      if (widget.persistirFirma) await _guardarFirmaEnBd();
      return bytes;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _guardarFirmaEnBd() async {
    try {
      final horaStr = _horaEmision != null
          ? '${_horaEmision!.hour.toString().padLeft(2, '0')}:'
                '${_horaEmision!.minute.toString().padLeft(2, '0')}'
          : null;
      final updated = widget.cotizacion.copyWith(
        horaEmision: horaStr,
        firmaEsImagen: _firmaEsImagen,
        firmaImagenBytes: _firmaEsImagen ? _firmaImagenBytes : null,
        firmaNombre: _firmaEsImagen
            ? null
            : _firmaNombreCtrl.text.trim().isEmpty
            ? null
            : _firmaNombreCtrl.text.trim(),
        firmaCargo: _firmaEsImagen
            ? null
            : _firmaCargoCtrl.text.trim().isEmpty
            ? null
            : _firmaCargoCtrl.text.trim(),
        firmaNumeroDocumento: _firmaEsImagen
            ? null
            : _firmaDocCtrl.text.trim().isEmpty
            ? null
            : _firmaDocCtrl.text.trim(),
      );
      await sl<UpdateCotizacion>()(updated);
    } catch (_) {
      // No es crítico; el PDF ya se generó
    }
  }

  Future<void> _previewImprimir() async {
    final bytes = await _generarPdf();
    if (bytes == null || !mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _compartirPdf() async {
    final bytes = await _generarPdf();
    if (bytes == null || !mounted) return;
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'cotizacion_${_numCotCtrl.text.trim()}.pdf',
    );
  }

  Future<void> _abrirWhatsAppMensaje() async {
    final phone = _clienteTelCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) return;
    final nombre = _clienteNombreCtrl.text.trim();
    final num = _numCotCtrl.text.trim();
    final total = _currencyFmt.format(_totalCalculado);
    final msg = Uri.encodeComponent(
      'Hola $nombre, adjunto la cotización $num por un total de $total. '
      'Quedo a disposición para cualquier consulta.',
    );
    final uri = Uri.parse(
      'https://wa.me/593${phone.replaceFirst(RegExp(r'^0'), '')}?text=$msg',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate({required bool esEmision}) async {
    final initial = esEmision ? _fechaEmision : _fechaVigencia;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      locale: const Locale('es'),
    );
    if (picked != null && mounted) {
      setState(() {
        if (esEmision) {
          _fechaEmision = picked;
        } else {
          _fechaVigencia = picked;
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaEmision ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _horaEmision = picked);
  }

  Future<void> _pickFirmaImagen() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null && mounted) {
      setState(() => _firmaImagenBytes = result.files.single.bytes!);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cfgState = ref.watch(publicConfigProvider);
    if (cfgState.hasConfig) _initEmpresa(cfgState.config);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: const Text('Generar Cotización PDF'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (_generando)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              else ...[
                IconButton(
                  tooltip: 'Vista previa / Imprimir',
                  icon: const Icon(Icons.print_rounded),
                  onPressed: _previewImprimir,
                ),
                IconButton(
                  tooltip: 'Compartir PDF',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: _compartirPdf,
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                // ── 1. Datos de la empresa ──────────────────────
                _Seccion(
                  titulo: 'Datos de la Empresa',
                  icono: Icons.business_rounded,
                  children: [
                    _Campo(
                      ctrl: _nombreEmpresaCtrl,
                      label: 'Nombre de la empresa *',
                      icono: Icons.store_rounded,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Campo(
                            ctrl: _telefonoEmpresaCtrl,
                            label: 'Teléfono',
                            icono: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Campo(
                            ctrl: _emailEmpresaCtrl,
                            label: 'Correo',
                            icono: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Campo(
                      ctrl: _direccionEmpresaCtrl,
                      label: 'Dirección',
                      icono: Icons.location_on_rounded,
                      maxLines: 2,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 2. Datos de la cotización ───────────────────
                _Seccion(
                  titulo: 'Datos de la Cotización',
                  icono: Icons.receipt_long_rounded,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Campo(
                            ctrl: _numCotCtrl,
                            label: 'Número *',
                            icono: Icons.tag_rounded,
                            validator: _required,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'Fecha de emisión',
                            fecha: _fechaEmision,
                            onTap: () => _pickDate(esEmision: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'Válida hasta',
                            fecha: _fechaVigencia,
                            onTap: () => _pickDate(esEmision: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: 'Hora de la proforma (opcional)',
                            hora: _horaEmision,
                            onTap: _pickTime,
                            onClear: _horaEmision != null
                                ? () => setState(() => _horaEmision = null)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 3. Datos del cliente ────────────────────────
                _Seccion(
                  titulo: 'Datos del Cliente',
                  icono: Icons.person_rounded,
                  children: [
                    _Campo(
                      ctrl: _clienteNombreCtrl,
                      label: 'Nombre *',
                      icono: Icons.person_outline,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Campo(
                            ctrl: _clienteTelCtrl,
                            label: 'Teléfono',
                            icono: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Campo(
                            ctrl: _clienteEmailCtrl,
                            label: 'Correo',
                            icono: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 4. Items ────────────────────────────────────
                _Seccion(
                  titulo: 'Productos / Servicios',
                  icono: Icons.shopping_bag_outlined,
                  trailingAction: TextButton.icon(
                    onPressed: () => setState(
                      () => _items.add(
                        CotizacionPdfItem(
                          descripcion: '',
                          cantidad: 1,
                          precioUnitario: 0,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Agregar'),
                  ),
                  children: [
                    // Encabezado tabla
                    const _ItemHeader(),
                    const Divider(height: 8),
                    // Filas de items
                    for (int i = 0; i < _items.length; i++)
                      _ItemRow(
                        key: ValueKey(i),
                        item: _items[i],
                        onChanged: () => setState(() {}),
                        onDelete: _items.length > 1
                            ? () => setState(() => _items.removeAt(i))
                            : null,
                      ),
                    const Divider(height: 16),
                    // Resumen total rápido
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total estimado: ${_currencyFmt.format(_totalCalculado)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 5. Descuentos e impuestos ───────────────────
                _Seccion(
                  titulo: 'Descuentos e Impuestos',
                  icono: Icons.calculate_rounded,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Campo(
                            ctrl: _descuentoCtrl,
                            label: 'Descuento (\$)',
                            icono: Icons.discount_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Campo(
                            ctrl: _tasaImpCtrl,
                            label: 'Tasa IVA (%)',
                            icono: Icons.percent_rounded,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 6. Observaciones ────────────────────────────
                _Seccion(
                  titulo: 'Observaciones',
                  icono: Icons.sticky_note_2_outlined,
                  children: [
                    _Campo(
                      ctrl: _notasCtrl,
                      label: 'Notas o aclaraciones para el cliente',
                      icono: Icons.notes_rounded,
                      maxLines: 4,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 7. Términos comerciales ─────────────────────
                _Seccion(
                  titulo: 'Términos y Condiciones',
                  icono: Icons.gavel_rounded,
                  children: [
                    _Campo(
                      ctrl: _terminosCtrl,
                      label: 'Términos comerciales',
                      icono: Icons.article_outlined,
                      maxLines: 6,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 8. Firma del documento ───────────────────────
                _Seccion(
                  titulo: 'Firma del Documento',
                  icono: Icons.draw_rounded,
                  children: [
                    // Toggle tipo de firma
                    Row(
                      children: [
                        const Text(
                          'Tipo de firma:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Digital'),
                          selected: !_firmaEsImagen,
                          onSelected: (_) =>
                              setState(() => _firmaEsImagen = false),
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          checkmarkColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Imagen manuscrita'),
                          selected: _firmaEsImagen,
                          onSelected: (_) =>
                              setState(() => _firmaEsImagen = true),
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          checkmarkColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!_firmaEsImagen) ...[
                      // ── Firma digital certificada ──────────────
                      _Campo(
                        ctrl: _firmaNombreCtrl,
                        label: 'Nombre del firmante',
                        icono: Icons.person_rounded,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Campo(
                              ctrl: _firmaCargoCtrl,
                              label: 'Cargo / Título',
                              icono: Icons.work_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Campo(
                              ctrl: _firmaDocCtrl,
                              label: 'Cédula / RUC',
                              icono: Icons.badge_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'La firma digital incluye nombre, cargo, número de documento y marca de tiempo en el PDF.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // ── Imagen de firma manuscrita ─────────────
                      if (_firmaImagenBytes != null)
                        Container(
                          height: 110,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _firmaImagenBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickFirmaImagen,
                          icon: Icon(
                            _firmaImagenBytes != null
                                ? Icons.refresh_rounded
                                : Icons.upload_file_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _firmaImagenBytes != null
                                ? 'Cambiar imagen de firma'
                                : 'Cargar imagen de firma',
                          ),
                        ),
                      ),
                      if (_firmaImagenBytes != null) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _firmaImagenBytes = null),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                            ),
                            label: const Text('Quitar firma'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Usa una imagen PNG o JPG sobre fondo blanco para mejor resultado en el PDF.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomBar(),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón principal: vista previa / imprimir
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _generando ? null : _previewImprimir,
              icon: _generando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                _generando ? 'Generando...' : 'Ver y guardar PDF',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Botones secundarios
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generando ? null : _compartirPdf,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Compartir PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generando ? null : _abrirWhatsAppMensaje,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null;
}

// ── Constante de términos default ────────────────────────────────────────────

const _kTerminosDefault =
    '1. Esta cotización tiene una vigencia de 30 días a partir de la fecha de emisión.\n'
    '2. Los precios indicados incluyen IVA según la tasa aplicable.\n'
    '3. El plazo de entrega/servicio se acordará al momento de confirmación.\n'
    '4. Se requiere un anticipo del 50% para confirmar la reserva o el pedido.\n'
    '5. Cualquier modificación al pedido debe ser notificada con al menos 48 horas de anticipación.\n'
    '6. El pago total debe realizarse antes del inicio del evento o entrega del servicio.';

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _Seccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> children;
  final Widget? trailingAction;

  const _Seccion({
    required this.titulo,
    required this.icono,
    required this.children,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              children: [
                Icon(icono, size: 17, color: AppColors.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailingAction != null) trailingAction!,
              ],
            ),
          ),
          const Divider(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icono;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _Campo({
    required this.ctrl,
    required this.label,
    required this.icono,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icono, size: 18),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime fecha;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  static final _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        child: Text(_fmt.format(fecha), style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? hora;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _TimeField({
    required this.label,
    required this.hora,
    required this.onTap,
    this.onClear,
  });

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time_rounded, size: 16),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          suffixIcon: hora != null && onClear != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: onClear,
                  tooltip: 'Quitar hora',
                )
              : null,
        ),
        child: Text(
          hora != null ? _fmt(hora!) : '— toca para agregar',
          style: TextStyle(
            fontSize: 14,
            color: hora != null ? null : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

class _ItemHeader extends StatelessWidget {
  const _ItemHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            'Descripción',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            'Cant.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            'Precio unit.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            'Subtotal',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(width: 36),
      ],
    );
  }
}

class _ItemRow extends StatefulWidget {
  final CotizacionPdfItem item;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _ItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _cantCtrl;
  late final TextEditingController _precioCtrl;

  static final _currFmt = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.item.descripcion);
    _cantCtrl = TextEditingController(text: widget.item.cantidad.toString());
    _precioCtrl = TextEditingController(
      text: widget.item.precioUnitario.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  void _sync() {
    widget.item.descripcion = _descCtrl.text;
    widget.item.cantidad = int.tryParse(_cantCtrl.text) ?? 1;
    widget.item.precioUnitario = double.tryParse(_precioCtrl.text) ?? 0;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Descripción
          Expanded(
            flex: 5,
            child: TextFormField(
              controller: _descCtrl,
              onChanged: (_) => _sync(),
              decoration: const InputDecoration(
                hintText: 'Producto o servicio',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
          ),
          const SizedBox(width: 8),
          // Cantidad
          SizedBox(
            width: 56,
            child: TextFormField(
              controller: _cantCtrl,
              onChanged: (_) => _sync(),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Precio unitario
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: _precioCtrl,
              onChanged: (_) => _sync(),
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Subtotal (solo lectura)
          SizedBox(
            width: 90,
            child: Text(
              _currFmt.format(widget.item.subtotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
          // Eliminar
          SizedBox(
            width: 36,
            child: widget.onDelete != null
                ? IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    onPressed: widget.onDelete,
                    tooltip: 'Eliminar',
                    padding: EdgeInsets.zero,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
