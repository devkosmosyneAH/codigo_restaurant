import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/pagina_publica/domain/entities/public_config.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/public_config_provider.dart';

/// Panel interno para administrar el contenido de la página pública.
///
/// Solo accesible para administradores. Los cambios se reflejan
/// inmediatamente en la vista pública del restaurante.
class RestauranteConfigPage extends ConsumerStatefulWidget {
  const RestauranteConfigPage({super.key});

  @override
  ConsumerState<RestauranteConfigPage> createState() =>
      _RestauranteConfigPageState();
}

class _RestauranteConfigPageState extends ConsumerState<RestauranteConfigPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _sloganCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _facebookCtrl;
  late final TextEditingController _instagramCtrl;

  // Textos de secciones editables
  late final TextEditingController _exp1TituloCtrl;
  late final TextEditingController _exp1DescCtrl;
  late final TextEditingController _exp2TituloCtrl;
  late final TextEditingController _exp2DescCtrl;
  late final TextEditingController _exp3TituloCtrl;
  late final TextEditingController _exp3DescCtrl;
  late final TextEditingController _tituloMenuCtrl;
  late final TextEditingController _subtituloMenuCtrl;
  late final TextEditingController _tituloReservasCtrl;
  late final TextEditingController _subtituloReservasCtrl;
  late final TextEditingController _mapUrlCtrl;

  // Datos corporativos / institucionales
  late final TextEditingController _nombreNegocioCtrl;
  late final TextEditingController _propietarioCtrl;
  late final TextEditingController _emailContactoCtrl;
  late final TextEditingController _emailSecundarioCtrl;
  late final TextEditingController _telefonoSecundarioCtrl;

  List<HorarioEntry> _horarios = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _sloganCtrl = TextEditingController();
    _descripcionCtrl = TextEditingController();
    _telefonoCtrl = TextEditingController();
    _whatsappCtrl = TextEditingController();
    _direccionCtrl = TextEditingController();
    _facebookCtrl = TextEditingController();
    _instagramCtrl = TextEditingController();
    _exp1TituloCtrl = TextEditingController();
    _exp1DescCtrl = TextEditingController();
    _exp2TituloCtrl = TextEditingController();
    _exp2DescCtrl = TextEditingController();
    _exp3TituloCtrl = TextEditingController();
    _exp3DescCtrl = TextEditingController();
    _tituloMenuCtrl = TextEditingController();
    _subtituloMenuCtrl = TextEditingController();
    _tituloReservasCtrl = TextEditingController();
    _subtituloReservasCtrl = TextEditingController();
    _mapUrlCtrl = TextEditingController();
    _nombreNegocioCtrl = TextEditingController();
    _propietarioCtrl = TextEditingController();
    _emailContactoCtrl = TextEditingController();
    _emailSecundarioCtrl = TextEditingController();
    _telefonoSecundarioCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _sloganCtrl.dispose();
    _descripcionCtrl.dispose();
    _telefonoCtrl.dispose();
    _whatsappCtrl.dispose();
    _direccionCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    _exp1TituloCtrl.dispose();
    _exp1DescCtrl.dispose();
    _exp2TituloCtrl.dispose();
    _exp2DescCtrl.dispose();
    _exp3TituloCtrl.dispose();
    _exp3DescCtrl.dispose();
    _tituloMenuCtrl.dispose();
    _subtituloMenuCtrl.dispose();
    _tituloReservasCtrl.dispose();
    _subtituloReservasCtrl.dispose();
    _mapUrlCtrl.dispose();
    _nombreNegocioCtrl.dispose();
    _propietarioCtrl.dispose();
    _emailContactoCtrl.dispose();
    _emailSecundarioCtrl.dispose();
    _telefonoSecundarioCtrl.dispose();
    super.dispose();
  }

  void _initFromConfig(PublicConfig config) {
    if (_initialized) return;
    _initialized = true;
    _sloganCtrl.text = config.slogan;
    _descripcionCtrl.text = config.descripcion;
    _telefonoCtrl.text = config.telefono;
    _whatsappCtrl.text = config.whatsapp;
    _direccionCtrl.text = config.direccion;
    _facebookCtrl.text = config.facebook;
    _instagramCtrl.text = config.instagram;
    _exp1TituloCtrl.text = config.exp1Titulo;
    _exp1DescCtrl.text = config.exp1Desc;
    _exp2TituloCtrl.text = config.exp2Titulo;
    _exp2DescCtrl.text = config.exp2Desc;
    _exp3TituloCtrl.text = config.exp3Titulo;
    _exp3DescCtrl.text = config.exp3Desc;
    _tituloMenuCtrl.text = config.tituloMenu;
    _subtituloMenuCtrl.text = config.subtituloMenu;
    _tituloReservasCtrl.text = config.tituloReservas;
    _subtituloReservasCtrl.text = config.subtituloReservas;
    _mapUrlCtrl.text = config.mapUrl;
    _horarios = List.from(config.horarios);
    _nombreNegocioCtrl.text = config.nombreNegocio;
    _propietarioCtrl.text = config.propietario;
    _emailContactoCtrl.text = config.emailContacto;
    _emailSecundarioCtrl.text = config.emailSecundario;
    _telefonoSecundarioCtrl.text = config.telefonoSecundario;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final currentConfig =
        ref.read(publicConfigProvider).config ??
        PublicConfig.defaults(sl<TenantContext>().restaurantId);

    final updated = currentConfig.copyWith(
      slogan: _sloganCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      whatsapp: _whatsappCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      facebook: _facebookCtrl.text.trim(),
      instagram: _instagramCtrl.text.trim(),
      horarios: _horarios,
      exp1Titulo: _exp1TituloCtrl.text.trim(),
      exp1Desc: _exp1DescCtrl.text.trim(),
      exp2Titulo: _exp2TituloCtrl.text.trim(),
      exp2Desc: _exp2DescCtrl.text.trim(),
      exp3Titulo: _exp3TituloCtrl.text.trim(),
      exp3Desc: _exp3DescCtrl.text.trim(),
      tituloMenu: _tituloMenuCtrl.text.trim(),
      subtituloMenu: _subtituloMenuCtrl.text.trim(),
      tituloReservas: _tituloReservasCtrl.text.trim(),
      subtituloReservas: _subtituloReservasCtrl.text.trim(),
      mapUrl: _mapUrlCtrl.text.trim().isEmpty
          ? 'https://maps.app.goo.gl/KL4cFAxBxDDKmgaS9'
          : _mapUrlCtrl.text.trim(),
      nombreNegocio: _nombreNegocioCtrl.text.trim(),
      propietario: _propietarioCtrl.text.trim(),
      emailContacto: _emailContactoCtrl.text.trim(),
      emailSecundario: _emailSecundarioCtrl.text.trim(),
      telefonoSecundario: _telefonoSecundarioCtrl.text.trim(),
    );

    final ok = await ref.read(publicConfigProvider.notifier).save(updated);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Página pública actualizada correctamente.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _addHorario() {
    setState(() {
      _horarios.add(const HorarioEntry(dia: '', hora: ''));
    });
  }

  void _removeHorario(int index) {
    setState(() => _horarios.removeAt(index));
  }

  void _updateHorario(int index, {String? dia, String? hora}) {
    setState(() {
      _horarios[index] = _horarios[index].copyWith(dia: dia, hora: hora);
    });
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
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Página pública'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.visibility_rounded, size: 18),
            label: const Text('Vista previa'),
            onPressed: () => context.go(AppRouter.restaurantePublico),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Info Banner ────────────────────────────────────────
            _InfoBanner(updatedAt: state.config?.updatedAt),

            const SizedBox(height: 16),

            // ── Información corporativa ────────────────────────────
            _Section(
              title: 'Información corporativa',
              icon: Icons.business_rounded,
              children: [
                _Field(
                  controller: _nombreNegocioCtrl,
                  label: 'Nombre del negocio',
                  hint: 'La Peña Bar & Restaurant',
                  icon: Icons.store_rounded,
                  maxLength: 100,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _propietarioCtrl,
                  label: 'Nombre del propietario',
                  hint: 'Nombre completo del dueño',
                  icon: Icons.person_rounded,
                  maxLength: 100,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _emailContactoCtrl,
                  label: 'Correo principal',
                  hint: 'contacto@negocio.com',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final r = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!r.hasMatch(v.trim())) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _emailSecundarioCtrl,
                  label: 'Correo secundario (opcional)',
                  hint: 'otro@negocio.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final r = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!r.hasMatch(v.trim())) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _telefonoSecundarioCtrl,
                  label: 'Teléfono secundario (opcional)',
                  hint: '099 000 0000',
                  icon: Icons.phone_forwarded_rounded,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Identidad ──────────────────────────────────────────
            _Section(
              title: 'Identidad',
              icon: Icons.storefront_rounded,
              children: [
                _Field(
                  controller: _sloganCtrl,
                  label: 'Eslogan',
                  hint: 'El sabor auténtico que te hace volver',
                  icon: Icons.format_quote_rounded,
                  maxLength: 120,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _descripcionCtrl,
                  label: 'Descripción',
                  hint: 'Cuéntale a tus clientes sobre el restaurante...',
                  icon: Icons.description_rounded,
                  maxLines: 4,
                  maxLength: 600,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Textos de secciones ────────────────────────────────
            _Section(
              title: 'Textos de secciones',
              icon: Icons.text_fields_rounded,
              children: [
                // Tarjeta 1
                _SubSectionLabel(label: '🍽️  Tarjeta 1 — Por qué elegirnos'),
                _Field(
                  controller: _exp1TituloCtrl,
                  label: 'Título tarjeta 1',
                  hint: 'Gastronomía Auténtica',
                  icon: Icons.title_rounded,
                  maxLength: 60,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _exp1DescCtrl,
                  label: 'Descripción tarjeta 1',
                  hint: 'Recetas tradicionales con ingredientes frescos...',
                  icon: Icons.short_text_rounded,
                  maxLines: 2,
                  maxLength: 120,
                ),
                const SizedBox(height: 14),
                // Tarjeta 2
                _SubSectionLabel(label: '🏠  Tarjeta 2 — Por qué elegirnos'),
                _Field(
                  controller: _exp2TituloCtrl,
                  label: 'Título tarjeta 2',
                  hint: 'Ambiente Familiar',
                  icon: Icons.title_rounded,
                  maxLength: 60,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _exp2DescCtrl,
                  label: 'Descripción tarjeta 2',
                  hint: 'Un espacio cálido y acogedor...',
                  icon: Icons.short_text_rounded,
                  maxLines: 2,
                  maxLength: 120,
                ),
                const SizedBox(height: 14),
                // Tarjeta 3
                _SubSectionLabel(label: '⭐  Tarjeta 3 — Por qué elegirnos'),
                _Field(
                  controller: _exp3TituloCtrl,
                  label: 'Título tarjeta 3',
                  hint: 'Servicio Excepcional',
                  icon: Icons.title_rounded,
                  maxLength: 60,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _exp3DescCtrl,
                  label: 'Descripción tarjeta 3',
                  hint: 'Atención personalizada que supera expectativas...',
                  icon: Icons.short_text_rounded,
                  maxLines: 2,
                  maxLength: 120,
                ),
                const Divider(height: 24),
                // Sección Menú
                _SubSectionLabel(label: '🥘  Sección Menú'),
                _Field(
                  controller: _tituloMenuCtrl,
                  label: 'Título sección menú',
                  hint: 'Nuestro Menú',
                  icon: Icons.restaurant_menu_rounded,
                  maxLength: 60,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _subtituloMenuCtrl,
                  label: 'Subtítulo sección menú',
                  hint: 'Platos elaborados con ingredientes frescos...',
                  icon: Icons.short_text_rounded,
                  maxLength: 120,
                ),
                const Divider(height: 24),
                // Sección Reservaciones
                _SubSectionLabel(label: '📅  Sección Reservaciones'),
                _Field(
                  controller: _tituloReservasCtrl,
                  label: 'Título sección reservas',
                  hint: 'Reserva tu Mesa',
                  icon: Icons.calendar_month_rounded,
                  maxLength: 60,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _subtituloReservasCtrl,
                  label: 'Subtítulo sección reservas',
                  hint: 'Asegura tu lugar para una experiencia especial...',
                  icon: Icons.short_text_rounded,
                  maxLength: 120,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Mapa de ubicación ──────────────────────────────────
            _Section(
              title: 'Mapa de ubicación',
              icon: Icons.map_rounded,
              children: [
                _Field(
                  controller: _mapUrlCtrl,
                  label: 'URL de Google Maps',
                  hint: 'https://maps.app.goo.gl/...',
                  icon: Icons.location_on_rounded,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pega el enlace de tu ubicación en Google Maps. '
                  'Este enlace se usará para el botón "Ir ahora" del mapa.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Contacto ───────────────────────────────────────────
            _Section(
              title: 'Contacto y ubicación',
              icon: Icons.contact_phone_rounded,
              children: [
                _Field(
                  controller: _telefonoCtrl,
                  label: 'Teléfono',
                  hint: '809-000-0000',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _whatsappCtrl,
                  label: 'WhatsApp',
                  hint: '809-000-0000',
                  icon: Icons.chat_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _direccionCtrl,
                  label: 'Dirección',
                  hint: 'Calle, número, ciudad...',
                  icon: Icons.location_on_rounded,
                  maxLines: 2,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Horarios ───────────────────────────────────────────
            _Section(
              title: 'Horarios de atención',
              icon: Icons.schedule_rounded,
              trailing: IconButton(
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Agregar horario',
                onPressed: _addHorario,
              ),
              children: [
                if (_horarios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sin horarios definidos. Toca + para agregar.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ..._horarios.asMap().entries.map((entry) {
                  final i = entry.key;
                  final h = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            initialValue: h.dia,
                            decoration: const InputDecoration(
                              labelText: 'Día(s)',
                              hintText: 'Lunes – Viernes',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) => _updateHorario(i, dia: v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            initialValue: h.hora,
                            decoration: const InputDecoration(
                              labelText: 'Hora',
                              hintText: '12:00 – 22:00',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) => _updateHorario(i, hora: v),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            size: 20,
                            color: AppColors.error,
                          ),
                          tooltip: 'Eliminar',
                          onPressed: () => _removeHorario(i),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 14),

            // ── Redes Sociales ─────────────────────────────────────
            _Section(
              title: 'Redes sociales',
              icon: Icons.share_rounded,
              children: [
                _Field(
                  controller: _facebookCtrl,
                  label: 'Facebook (URL)',
                  hint: 'https://facebook.com/...',
                  icon: Icons.facebook_rounded,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _instagramCtrl,
                  label: 'Instagram (URL)',
                  hint: 'https://instagram.com/...',
                  icon: Icons.camera_alt_rounded,
                  keyboardType: TextInputType.url,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Guardar ────────────────────────────────────────────
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
                state.isSaving ? 'Guardando...' : 'Guardar cambios',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: state.isSaving ? null : _save,
            ),

            if (state.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Componentes internos ──────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({this.updatedAt});
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Los cambios se reflejan inmediatamente en la página pública.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (updatedAt != null)
                  Text(
                    'Última actualización: ${_format(updatedAt!)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _format(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Pequeño encabezado de sub-sección dentro de un formulario.
class _SubSectionLabel extends StatelessWidget {
  const _SubSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

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
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        isDense: false,
      ),
    );
  }
}
