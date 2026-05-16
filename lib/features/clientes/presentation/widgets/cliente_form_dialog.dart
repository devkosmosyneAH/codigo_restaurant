import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/presentation/providers/cliente_provider.dart';

/// Diálogo para crear o editar un cliente.
class ClienteFormDialog extends ConsumerStatefulWidget {
  const ClienteFormDialog({super.key, this.cliente});

  /// Si es null, se crea un nuevo cliente. Si no, se edita.
  final Cliente? cliente;

  static Future<bool> show(BuildContext context, {Cliente? cliente}) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ClienteFormDialog(cliente: cliente),
        ) ??
        false;
  }

  @override
  ConsumerState<ClienteFormDialog> createState() => _ClienteFormDialogState();
}

class _ClienteFormDialogState extends ConsumerState<ClienteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cedulaCtrl;
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _notasCtrl;

  bool _cedulaValidada = false;
  bool get _isEditing => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _cedulaCtrl = TextEditingController(text: c?.cedula ?? '');
    _nombreCtrl = TextEditingController(text: c?.nombre ?? '');
    _apellidoCtrl = TextEditingController(text: c?.apellido ?? '');
    _telefonoCtrl = TextEditingController(text: c?.telefono ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _direccionCtrl = TextEditingController(text: c?.direccion ?? '');
    _notasCtrl = TextEditingController(text: c?.notas ?? '');
    _cedulaValidada = _isEditing;
  }

  @override
  void dispose() {
    _cedulaCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(clienteProvider.notifier);
    bool ok;

    if (_isEditing) {
      ok = await notifier.actualizarCliente(
        cliente: widget.cliente!,
        nombre: _nombreCtrl.text,
        apellido: _apellidoCtrl.text,
        telefono: _telefonoCtrl.text,
        email: _emailCtrl.text,
        direccion: _direccionCtrl.text,
        notas: _notasCtrl.text,
      );
    } else {
      ok = await notifier.crearCliente(
        cedula: _cedulaCtrl.text,
        nombre: _nombreCtrl.text,
        apellido: _apellidoCtrl.text,
        telefono: _telefonoCtrl.text,
        email: _emailCtrl.text,
        direccion: _direccionCtrl.text,
        notas: _notasCtrl.text,
      );
    }

    if (mounted) Navigator.of(context).pop(ok);
  }

  String? _validarCedula(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'La cédula es obligatoria';
    if (!RegExp(r'^\d+$').hasMatch(v)) return 'Solo se permiten dígitos';
    if (v.length != 10 && v.length != 13) {
      return 'Debe tener 10 dígitos (cédula) o 13 (RUC)';
    }
    if (!Cliente.esCedulaValida(v)) {
      return 'Cédula inválida (dígito verificador)';
    }
    return null;
  }

  String? _validarEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Correo electrónico inválido';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(
      clienteProvider.select((s) => s.isProcessing),
    );
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(_isEditing ? Icons.edit_rounded : Icons.person_add_rounded),
          const SizedBox(width: 8),
          Text(_isEditing ? 'Editar cliente' : 'Nuevo cliente'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Cédula/RUC ───────────────────────────────────
                TextFormField(
                  controller: _cedulaCtrl,
                  readOnly: _isEditing,
                  decoration: InputDecoration(
                    labelText: 'Cédula / RUC *',
                    prefixIcon: const Icon(Icons.badge_rounded),
                    border: const OutlineInputBorder(),
                    helperText: _isEditing
                        ? 'La cédula no puede modificarse'
                        : 'Cédula (10 dígitos) o RUC (13 dígitos)',
                    filled: _isEditing,
                    fillColor: _isEditing ? cs.surfaceContainerHighest : null,
                    suffixIcon: _cedulaValidada && !_isEditing
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green.shade600,
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                  validator: _validarCedula,
                  onChanged: (v) {
                    setState(() {
                      _cedulaValidada = _validarCedula(v) == null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                // ── Nombre ────────────────────────────────────────
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre(s) *',
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // ── Apellido ──────────────────────────────────────
                TextFormField(
                  controller: _apellidoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Apellido(s)',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                // ── Teléfono ──────────────────────────────────────
                TextFormField(
                  controller: _telefonoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[\d\s\-\+\(\)]'),
                    ),
                    LengthLimitingTextInputFormatter(20),
                  ],
                ),
                const SizedBox(height: 14),
                // ── Email ─────────────────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_rounded),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validarEmail,
                ),
                const SizedBox(height: 14),
                // ── Dirección ─────────────────────────────────────
                TextFormField(
                  controller: _direccionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    prefixIcon: Icon(Icons.location_on_rounded),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                // ── Notas ─────────────────────────────────────────
                TextFormField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas internas',
                    prefixIcon: Icon(Icons.note_rounded),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isProcessing
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: isProcessing ? null : _submit,
          icon: isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
          label: Text(_isEditing ? 'Guardar' : 'Registrar'),
        ),
      ],
    );
  }
}
