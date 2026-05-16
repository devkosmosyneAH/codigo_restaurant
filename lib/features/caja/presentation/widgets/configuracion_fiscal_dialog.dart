import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/services/facturacion/fiscal_config_service.dart';
import 'package:restaurant_app/services/facturacion/sri_service.dart';

/// Diálogo para configurar los datos fiscales del emisor (SRI).
///
/// Solo accesible para el rol Administrador.
/// Los datos se persisten por restaurante y son leídos por [SriService].
class ConfiguracionFiscalDialog extends StatefulWidget {
  const ConfiguracionFiscalDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ConfiguracionFiscalDialog(),
    );
  }

  @override
  State<ConfiguracionFiscalDialog> createState() =>
      _ConfiguracionFiscalDialogState();
}

class _ConfiguracionFiscalDialogState extends State<ConfiguracionFiscalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rucCtrl = TextEditingController();
  final _razonSocialCtrl = TextEditingController();
  final _nombreComercialCtrl = TextEditingController();
  final _establecimientoCtrl = TextEditingController();
  final _puntoEmisionCtrl = TextEditingController();
  final _autorizacionCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _endpointBackendCtrl = TextEditingController();
  String _ambiente = 'pruebas';
  SriCertificateInfo? _certificateInfo;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingCertificate = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final service = FiscalConfigService();
    final cfg = await service.load();
    final certificateInfo = await service.loadCertificateInfo(
      restaurantId: cfg.restaurantId,
    );
    if (!mounted) return;
    setState(() {
      _rucCtrl.text = cfg.ruc;
      _razonSocialCtrl.text = cfg.razonSocial;
      _nombreComercialCtrl.text = cfg.nombreComercial;
      _establecimientoCtrl.text = cfg.establecimiento;
      _puntoEmisionCtrl.text = cfg.puntoEmision;
      _autorizacionCtrl.text = cfg.autorizacionSri;
      _direccionCtrl.text = cfg.direccion;
      _endpointBackendCtrl.text = cfg.endpointBackend;
      _ambiente = cfg.ambiente;
      _certificateInfo = certificateInfo;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _rucCtrl.dispose();
    _razonSocialCtrl.dispose();
    _nombreComercialCtrl.dispose();
    _establecimientoCtrl.dispose();
    _puntoEmisionCtrl.dispose();
    _autorizacionCtrl.dispose();
    _direccionCtrl.dispose();
    _endpointBackendCtrl.dispose();
    super.dispose();
  }

  /// Valida el RUC ecuatoriano verificando el dígito verificador.
  ///
  /// Tipos según tercer dígito:
  /// - 0-5: persona natural → módulo 10 sobre los primeros 10 dígitos (cédula)
  /// - 6: sector público → módulo 11 sobre 9 dígitos, coeficientes 3-2-7-6-5-4-3-2
  /// - 9: sociedad privada → módulo 11 sobre 9 dígitos, coeficientes 4-3-2-7-6-5-4-3-2
  ///
  /// Retorna null si es válido, o el mensaje de error.
  String? _validarRuc(String ruc) {
    final provincia = int.tryParse(ruc.substring(0, 2)) ?? 0;
    if (provincia < 1 || provincia > 24) {
      return 'Los primeros 2 dígitos deben corresponder a una provincia (01-24).';
    }

    final tipo = int.parse(ruc[2]);

    if (tipo >= 0 && tipo <= 5) {
      // Persona natural — módulo 10 sobre los 10 primeros dígitos
      const coef = [2, 1, 2, 1, 2, 1, 2, 1, 2];
      var suma = 0;
      for (var i = 0; i < 9; i++) {
        var val = int.parse(ruc[i]) * coef[i];
        if (val > 9) val -= 9;
        suma += val;
      }
      final verificador = (10 - (suma % 10)) % 10;
      if (verificador != int.parse(ruc[9])) {
        return 'RUC inválido: dígito verificador incorrecto.';
      }
      return null;
    }

    if (tipo == 6) {
      // Sector público — módulo 11, 9 dígitos, coef 3-2-7-6-5-4-3-2, verif pos 9
      const coef = [3, 2, 7, 6, 5, 4, 3, 2];
      var suma = 0;
      for (var i = 0; i < 8; i++) {
        suma += int.parse(ruc[i]) * coef[i];
      }
      final residuo = suma % 11;
      final verificador = residuo == 0 ? 0 : 11 - residuo;
      if (verificador != int.parse(ruc[8])) {
        return 'RUC inválido: dígito verificador incorrecto.';
      }
      return null;
    }

    if (tipo == 9) {
      // Sociedad privada — módulo 11, 9 dígitos, coef 4-3-2-7-6-5-4-3-2, verif pos 9
      const coef = [4, 3, 2, 7, 6, 5, 4, 3, 2];
      var suma = 0;
      for (var i = 0; i < 9; i++) {
        suma += int.parse(ruc[i]) * coef[i];
      }
      final residuo = suma % 11;
      final verificador = residuo == 0 ? 0 : 11 - residuo;
      if (verificador != int.parse(ruc[9])) {
        return 'RUC inválido: dígito verificador incorrecto.';
      }
      return null;
    }

    return 'RUC inválido: el tercer dígito debe ser 0-6 o 9.';
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    await _saveCurrentConfig();

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración fiscal guardada.')),
    );
  }

  Future<void> _pickAndUploadCertificate() async {
    if (!_formKey.currentState!.validate()) return;
    await _saveCurrentConfig();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['p12', 'pfx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo leer el certificado seleccionado.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final password = await _askCertificatePassword(file.name);
    if (password == null || password.trim().isEmpty) return;

    setState(() => _isUploadingCertificate = true);
    try {
      final sriService = sl.isRegistered<SriService>()
          ? sl<SriService>()
          : SriServiceImpl();
      final info = await sriService.uploadCertificate(
        p12Bytes: bytes,
        password: password,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() => _certificateInfo = info);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Certificado cargado en el backend puente.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar el certificado: $error')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingCertificate = false);
    }
  }

  Future<String?> _askCertificatePassword(String fileName) async {
    final passwordCtrl = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contraseña del certificado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña .p12',
                  prefixIcon: Icon(Icons.lock_outline),
                  isDense: true,
                ),
                onSubmitted: (_) =>
                    Navigator.of(context).pop(passwordCtrl.text),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(passwordCtrl.text),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Cargar'),
            ),
          ],
        ),
      );
    } finally {
      passwordCtrl.clear();
      passwordCtrl.dispose();
    }
  }

  Future<void> _saveCurrentConfig() async {
    await FiscalConfigService().save(
      FiscalConfig(
        ruc: _rucCtrl.text.trim(),
        razonSocial: _razonSocialCtrl.text.trim(),
        nombreComercial: _nombreComercialCtrl.text.trim(),
        establecimiento: _establecimientoCtrl.text.trim(),
        puntoEmision: _puntoEmisionCtrl.text.trim(),
        autorizacionSri: _autorizacionCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        ambiente: _ambiente,
        endpointBackend: _endpointBackendCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(child: Text('Configuración Fiscal (SRI)')),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.80,
        ),
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SectionTitle('Datos del emisor', theme),
                      const SizedBox(height: 10),

                      // RUC
                      TextFormField(
                        controller: _rucCtrl,
                        decoration: const InputDecoration(
                          labelText: 'RUC *',
                          hintText: 'Ej: 0912345678001',
                          prefixIcon: Icon(Icons.badge_outlined),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El RUC es obligatorio.';
                          }
                          final digits = v.trim().replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          );
                          if (digits.length != 13) {
                            return 'El RUC debe tener 13 dígitos.';
                          }
                          // Últimos 3 dígitos = código de establecimiento; mínimo 001
                          final estab = int.tryParse(digits.substring(10)) ?? 0;
                          if (estab < 1) {
                            return 'Los últimos 3 dígitos del RUC deben ser ≥ 001.';
                          }
                          // Verificar dígito verificador según tipo de RUC
                          final error = _validarRuc(digits);
                          return error;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Razón Social
                      TextFormField(
                        controller: _razonSocialCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Razón Social *',
                          hintText: 'Ej: LA PEÑA BAR & RESTAURANT S.A.',
                          prefixIcon: Icon(Icons.business_outlined),
                          isDense: true,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'La razón social es obligatoria.'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Nombre Comercial
                      TextFormField(
                        controller: _nombreComercialCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre Comercial',
                          hintText: 'Ej: La Peña',
                          prefixIcon: Icon(Icons.storefront_outlined),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Dirección
                      TextFormField(
                        controller: _direccionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dirección Matriz *',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'La dirección matriz es obligatoria.'
                            : null,
                      ),
                      const SizedBox(height: 18),

                      _SectionTitle('Datos de emisión', theme),
                      const SizedBox(height: 10),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _establecimientoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Establecimiento *',
                                hintText: '001',
                                helperText: '3 dígitos',
                                prefixIcon: Icon(Icons.store_outlined),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Requerido';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _puntoEmisionCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Punto de Emisión *',
                                hintText: '001',
                                helperText: '3 dígitos',
                                prefixIcon: Icon(Icons.print_outlined),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Requerido';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Autorización SRI
                      TextFormField(
                        controller: _autorizacionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Autorización SRI legacy',
                          hintText: 'Opcional: número histórico/legacy',
                          prefixIcon: Icon(Icons.verified_outlined),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 18),

                      _SectionTitle('Backend y certificado', theme),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _endpointBackendCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Endpoint backend puente',
                          hintText: 'https://api.tu-dominio.com/sri',
                          prefixIcon: Icon(Icons.cloud_outlined),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.url,
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return null;
                          final uri = Uri.tryParse(value);
                          if (uri == null ||
                              !uri.hasScheme ||
                              !uri.hasAuthority) {
                            return 'URL de backend inválida.';
                          }
                          if (uri.scheme != 'https') {
                            final isLocalhost =
                                uri.host == 'localhost' ||
                                uri.host == '127.0.0.1';
                            if (!isLocalhost) {
                              return 'El backend SRI debe usar HTTPS.';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _CertificateStatusTile(info: _certificateInfo),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _isUploadingCertificate || _isSaving
                              ? null
                              : _pickAndUploadCertificate,
                          icon: _isUploadingCertificate
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file_outlined),
                          label: Text(
                            _isUploadingCertificate
                                ? 'Cargando certificado'
                                : 'Cargar certificado .p12',
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      _SectionTitle('Ambiente', theme),
                      const SizedBox(height: 10),

                      // Ambiente
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Pruebas'),
                              subtitle: const Text(
                                'Ambiente de desarrollo',
                                style: TextStyle(fontSize: 11),
                              ),
                              value: 'pruebas',
                              groupValue: _ambiente,
                              onChanged: (v) => setState(() => _ambiente = v!),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Producción'),
                              subtitle: const Text(
                                'Ambiente real (SRI)',
                                style: TextStyle(fontSize: 11),
                              ),
                              value: 'produccion',
                              groupValue: _ambiente,
                              onChanged: (v) => setState(() => _ambiente = v!),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),

                      if (_ambiente == 'produccion') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ambiente de producción: los comprobantes generados serán válidos ante el SRI.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 4),
                      Text(
                        '* Campos obligatorios para generar comprobantes.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSaving || _isLoading ? null : _guardar,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _SectionTitle(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const Divider(height: 6),
      ],
    );
  }
}

class _CertificateStatusTile extends StatelessWidget {
  const _CertificateStatusTile({required this.info});

  final SriCertificateInfo? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loaded = info?.isLoaded ?? false;
    final expired = info?.isExpired ?? false;
    final color = expired
        ? Colors.red
        : loaded
        ? Colors.green
        : Colors.orange;
    final title = expired
        ? 'Certificado vencido'
        : loaded
        ? 'Certificado cargado en backend'
        : 'Certificado no cargado';
    final subtitle = info == null
        ? 'El .p12 y su contraseña no se guardan en la app. Deben custodiarse cifrados en el backend puente.'
        : [
            if (info!.fingerprintSha256.isNotEmpty)
              'Huella: ${info!.fingerprintSha256}',
            if (info!.validTo != null)
              'Válido hasta: ${info!.validTo!.toIso8601String().substring(0, 10)}',
          ].join('\n');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.enhanced_encryption_outlined, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.isEmpty
                      ? 'Referencia de certificado sin detalles.'
                      : subtitle,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
