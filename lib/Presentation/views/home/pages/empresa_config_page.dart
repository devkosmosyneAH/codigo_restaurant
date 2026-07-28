import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/core/utils/image_picker_util.dart';
import 'package:restaurant_app/core/utils/public_route_url_builder.dart';
import 'package:restaurant_app/features/pagina_publica/domain/entities/public_config.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/public_config_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Página de configuración institucional del negocio.
///
/// Solo accesible para administradores desde el dashboard.
/// Centraliza los datos corporativos que rigen en todo el sistema:
/// logo, nombre, propietario, correos, teléfonos y otros datos relevantes.
class EmpresaConfigPage extends ConsumerStatefulWidget {
  const EmpresaConfigPage({super.key});

  @override
  ConsumerState<EmpresaConfigPage> createState() => _EmpresaConfigPageState();
}

class _EmpresaConfigPageState extends ConsumerState<EmpresaConfigPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreNegocioCtrl;
  late final TextEditingController _propietarioCtrl;
  late final TextEditingController _telefonoPrincipalCtrl;
  late final TextEditingController _telefonoSecundarioCtrl;
  late final TextEditingController _emailContactoCtrl;
  late final TextEditingController _emailSecundarioCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _cocinaMinutosCtrl;

  /// Contiene el logo actual. Puede ser un data URI (`data:image/...`),
  /// una URL `http(s)://` heredada o cadena vacía.
  String _logoData = '';
  bool _uploadingLogo = false;

  bool _mostrarMenu = true;
  bool _mostrarReservas = true;
  bool _cocinaAutomatica = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nombreNegocioCtrl = TextEditingController();
    _propietarioCtrl = TextEditingController();
    _telefonoPrincipalCtrl = TextEditingController();
    _telefonoSecundarioCtrl = TextEditingController();
    _emailContactoCtrl = TextEditingController();
    _emailSecundarioCtrl = TextEditingController();
    _direccionCtrl = TextEditingController();
    _whatsappCtrl = TextEditingController();
    _cocinaMinutosCtrl = TextEditingController(text: '15');
  }

  @override
  void dispose() {
    _nombreNegocioCtrl.dispose();
    _propietarioCtrl.dispose();
    _telefonoPrincipalCtrl.dispose();
    _telefonoSecundarioCtrl.dispose();
    _emailContactoCtrl.dispose();
    _emailSecundarioCtrl.dispose();
    _direccionCtrl.dispose();
    _whatsappCtrl.dispose();
    _cocinaMinutosCtrl.dispose();
    super.dispose();
  }

  void _initFromConfig(PublicConfig config) {
    if (_initialized) return;
    _initialized = true;
    _nombreNegocioCtrl.text = config.nombreNegocio.isNotEmpty
        ? config.nombreNegocio
        : AppConstants.appFullName;
    _propietarioCtrl.text = config.propietario;
    _telefonoPrincipalCtrl.text = config.telefono.isNotEmpty
        ? config.telefono
        : AppConstants.contactPhone;
    _telefonoSecundarioCtrl.text = config.telefonoSecundario;
    _emailContactoCtrl.text = config.emailContacto.isNotEmpty
        ? config.emailContacto
        : AppConstants.contactEmail;
    _emailSecundarioCtrl.text = config.emailSecundario;
    _logoData = config.logoUrl;
    _direccionCtrl.text = config.direccion;
    _whatsappCtrl.text = config.whatsapp.isNotEmpty
        ? config.whatsapp
        : AppConstants.contactWhatsapp;
    _mostrarMenu = config.mostrarBotonMenu;
    _mostrarReservas = config.mostrarBotonReservas;
    _cocinaAutomatica = config.cocinaModoAutomatico;
    _cocinaMinutosCtrl.text = config.cocinaTiempoAutoMinutos.toString();
  }

  Future<void> _pickLogo() async {
    if (_uploadingLogo) return;
    setState(() => _uploadingLogo = true);
    try {
      final picked = await pickAndEncodeImage();
      if (!mounted) return;
      if (picked == null) return;
      setState(() => _logoData = picked.dataUri);
    } on PickedImageError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cargar la imagen. Intenta con otro archivo.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final current =
        ref.read(publicConfigProvider).config ??
        PublicConfig.defaults(sl<TenantContext>().restaurantId);

    final actualizado = current.copyWith(
      nombreNegocio: _nombreNegocioCtrl.text.trim(),
      propietario: _propietarioCtrl.text.trim(),
      telefono: _telefonoPrincipalCtrl.text.trim(),
      telefonoSecundario: _telefonoSecundarioCtrl.text.trim(),
      emailContacto: _emailContactoCtrl.text.trim(),
      emailSecundario: _emailSecundarioCtrl.text.trim(),
      logoUrl: _logoData.trim(),
      direccion: _direccionCtrl.text.trim(),
      whatsapp: _whatsappCtrl.text.trim(),
      mostrarBotonMenu: _mostrarMenu,
      mostrarBotonReservas: _mostrarReservas,
      cocinaModoAutomatico: _cocinaAutomatica,
      cocinaTiempoAutoMinutos: _cocinaAutomatica
          ? (int.tryParse(_cocinaMinutosCtrl.text.trim()) ?? 15).clamp(1, 600)
          : current.cocinaTiempoAutoMinutos,
      updatedAt: DateTime.now(),
    );

    final ok = await ref.read(publicConfigProvider.notifier).save(actualizado);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Información de la empresa guardada correctamente.'
              : ref.read(publicConfigProvider).error ?? 'Error al guardar',
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(publicConfigProvider);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.hasConfig && !_initialized) {
      _initFromConfig(state.config!);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Información de la Empresa'),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Encabezado descriptivo ────────────────────────────
            _InfoCard(
              icon: Icons.info_outline_rounded,
              message:
                  'Esta información se usa en todo el sistema: tickets, '
                  'reportes, documentos, encabezados y la página pública. '
                  'Mantenla actualizada.',
            ),
            const SizedBox(height: 20),

            // ── Logo ───────────────────────────────────────────────
            _Seccion(
              titulo: 'Logo del negocio',
              icono: Icons.image_rounded,
              children: [
                _LogoPreview(value: _logoData),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _uploadingLogo
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_rounded, size: 18),
                        label: Text(
                          _uploadingLogo
                              ? 'Procesando...'
                              : (_logoData.isEmpty
                                    ? 'Subir logo'
                                    : 'Cambiar logo'),
                        ),
                        onPressed: _uploadingLogo ? null : _pickLogo,
                      ),
                    ),
                    if (_logoData.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Quitar'),
                        onPressed: _uploadingLogo
                            ? null
                            : () => setState(() => _logoData = ''),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sube una imagen (PNG o JPG). Se optimiza automáticamente a '
                  '512 px y aparece en tickets, encabezados, reportes y la '
                  'página pública.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Nombre y propietario ───────────────────────────────
            _Seccion(
              titulo: 'Datos del negocio',
              icono: Icons.business_rounded,
              children: [
                _Campo(
                  controller: _nombreNegocioCtrl,
                  label: 'Nombre del negocio *',
                  hint: 'La Peña Bar & Restaurant',
                  icono: Icons.store_rounded,
                  maxLength: 100,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre del negocio es requerido'
                      : null,
                ),
                const SizedBox(height: 14),
                _Campo(
                  controller: _propietarioCtrl,
                  label: 'Nombre del propietario',
                  hint: 'Nombre completo',
                  icono: Icons.person_rounded,
                  maxLength: 100,
                ),
                const SizedBox(height: 14),
                _Campo(
                  controller: _direccionCtrl,
                  label: 'Dirección del negocio',
                  hint: 'Calle, número, ciudad, provincia...',
                  icono: Icons.location_on_rounded,
                  maxLines: 2,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Teléfonos ──────────────────────────────────────────
            _Seccion(
              titulo: 'Teléfonos',
              icono: Icons.phone_rounded,
              children: [
                _Campo(
                  controller: _telefonoPrincipalCtrl,
                  label: 'Teléfono principal',
                  hint: '099 000 0000',
                  icono: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _Campo(
                  controller: _whatsappCtrl,
                  label: 'WhatsApp',
                  hint: '0994645989 (sin espacios ni guiones)',
                  icono: Icons.chat_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _Campo(
                  controller: _telefonoSecundarioCtrl,
                  label: 'Teléfono secundario (opcional)',
                  hint: '02 000 0000',
                  icono: Icons.phone_forwarded_rounded,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Correos ────────────────────────────────────────────
            _Seccion(
              titulo: 'Correos electrónicos',
              icono: Icons.email_rounded,
              children: [
                _Campo(
                  controller: _emailContactoCtrl,
                  label: 'Correo principal',
                  hint: 'contacto@negocio.com',
                  icono: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final r = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!r.hasMatch(v.trim())) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Campo(
                  controller: _emailSecundarioCtrl,
                  label: 'Correo secundario (opcional)',
                  hint: 'otro@negocio.com',
                  icono: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final r = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!r.hasMatch(v.trim())) return 'Correo inválido';
                    return null;
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Accesos rápidos del sitio público ──────────────────
            _Seccion(
              titulo: 'Accesos rápidos del sitio público',
              icono: Icons.toggle_on_rounded,
              children: [
                const Text(
                  'Controla qué botones se muestran a tus clientes en la '
                  'página pública del restaurante.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar botón "Ver Menú"'),
                  value: _mostrarMenu,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _mostrarMenu = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar botón "Reservaciones"'),
                  value: _mostrarReservas,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _mostrarReservas = v),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Cocina ─────────────────────────────────────────────
            _Seccion(
              titulo: 'Cocina',
              icono: Icons.restaurant_menu_rounded,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cocina en modo automático'),
                  subtitle: const Text(
                    'Si está activado, los pedidos pasan solos a Listo '
                    'tras el tiempo configurado. La pantalla de Cocina '
                    'sigue visible como panel informativo.',
                  ),
                  value: _cocinaAutomatica,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _cocinaAutomatica = v),
                ),
                if (_cocinaAutomatica) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cocinaMinutosCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tiempo de cocina (minutos)',
                      hintText: 'Ej. 15',
                      prefixIcon: Icon(Icons.timer_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (!_cocinaAutomatica) return null;
                      final v = int.tryParse((value ?? '').trim());
                      if (v == null || v < 1) {
                        return 'Ingrese un entero mayor o igual a 1';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── Código QR del Menú ─────────────────────────────────
            const _QrMenuSection(),

            const SizedBox(height: 24),

            // ── Botón guardar ──────────────────────────────────────
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: state.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                state.isSaving ? 'Guardando...' : 'Guardar información',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: state.isSaving ? null : _guardar,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Widgets de apoyo ──────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InfoCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> children;

  const _Seccion({
    required this.titulo,
    required this.icono,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icono, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icono;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Campo({
    required this.controller,
    required this.label,
    required this.icono,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icono),
        border: const OutlineInputBorder(),
        isDense: false,
      ),
    );
  }
}

/// Vista previa del logo. Acepta data URIs (`data:image/...;base64,...`)
/// y URLs `http(s)://` heredadas.
class _LogoPreview extends StatelessWidget {
  final String value;

  const _LogoPreview({required this.value});

  @override
  Widget build(BuildContext context) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return _placeholder();
    }

    Widget image;
    if (raw.startsWith('data:image')) {
      final commaIndex = raw.indexOf(',');
      if (commaIndex == -1) return _placeholder();
      try {
        image = Image.memory(
          base64Decode(raw.substring(commaIndex + 1)),
          height: 110,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      } catch (_) {
        return _placeholder();
      }
    } else if (raw.startsWith('http://') || raw.startsWith('https://')) {
      image = Image.network(
        raw,
        height: 110,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const SizedBox(
                height: 110,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
      );
    } else {
      return _placeholder();
    }

    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      padding: const EdgeInsets.all(8),
      child: Center(
        child: ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.surfaceVariant,
          style: BorderStyle.solid,
        ),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: AppColors.textSecondary, size: 36),
          SizedBox(height: 6),
          Text(
            'Sin logo cargado',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── QR del Menú Público ───────────────────────────────────────────────────────

class _QrMenuSection extends StatefulWidget {
  const _QrMenuSection();

  @override
  State<_QrMenuSection> createState() => _QrMenuSectionState();
}

class _QrMenuSectionState extends State<_QrMenuSection> {
  final _qrKey = GlobalKey();

  String get _url => PublicRouteUrlBuilder.route(
    AppRouter.menuPublico,
    fallbackUrl: AppConstants.publicMenuBaseUrl,
  );

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enlace copiado al portapapeles'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareViaWhatsApp() async {
    final text = Uri.encodeComponent('¡Mira nuestro menú digital! $_url');
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaEmail() async {
    final subject = Uri.encodeComponent('Menú digital del restaurante');
    final body = Uri.encodeComponent(
      'Te compartimos nuestro menú digital.\n\nEscanea el código QR o visita el siguiente enlace:\n$_url',
    );
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _downloadQr() async {
    try {
      final context = _qrKey.currentContext;
      if (context == null) return;

      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final doc = pw.Document();
      final qrImage = pw.MemoryImage(pngBytes);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Escanea para ver nuestro menú',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Image(qrImage, width: 220, height: 220),
                pw.SizedBox(height: 12),
                pw.Text(
                  _url,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await Printing.sharePdf(bytes: await doc.save(), filename: 'menu-qr.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar el QR: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Seccion(
      titulo: 'Código QR del Menú',
      icono: Icons.qr_code_2_rounded,
      children: [
        const Text(
          'Comparte este código con tus clientes para que accedan al menú '
          'desde su celular sin necesidad de buscar la URL.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: RepaintBoundary(
            key: _qrKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(14),
              child: QrImageView(
                data: _url,
                version: QrVersions.auto,
                size: 190,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1A1A2E),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: SelectableText(
            _url,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _QrAction(
              icon: Icons.copy_rounded,
              label: 'Copiar enlace',
              onTap: _copyLink,
            ),
            _QrAction(
              icon: Icons.download_rounded,
              label: 'Descargar QR',
              onTap: _downloadQr,
            ),
            _QrAction(
              icon: FontAwesomeIcons.whatsapp,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: _shareViaWhatsApp,
            ),
            _QrAction(
              icon: Icons.email_outlined,
              label: 'Correo',
              onTap: _shareViaEmail,
            ),
          ],
        ),
      ],
    );
  }
}

class _QrAction extends StatelessWidget {
  const _QrAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: c.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: c,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
