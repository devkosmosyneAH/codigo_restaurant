import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';
import 'package:restaurant_app/features/usuarios/presentation/providers/usuario_provider.dart';

/// Diálogo para crear o editar un usuario.
///
/// Si se pasa [usuario], entra en modo edición; si no, en modo creación.
class UsuarioFormDialog extends ConsumerStatefulWidget {
  const UsuarioFormDialog({super.key, this.usuario});

  final Usuario? usuario;

  static Future<bool> show(BuildContext context, {Usuario? usuario}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UsuarioFormDialog(usuario: usuario),
    );
    return result ?? false;
  }

  @override
  ConsumerState<UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends ConsumerState<UsuarioFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _pinCtrl;
  late RolUsuario _rol;
  bool _showPin = false;

  bool get _isEditing => widget.usuario != null;
  bool get _pinEsObligatorio =>
      !_isEditing || (widget.usuario?.pin?.trim().isEmpty ?? true);

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombreCtrl = TextEditingController(text: u?.nombre ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _pinCtrl = TextEditingController();
    _rol = u?.rol ?? RolUsuario.mesero;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(usuarioProvider.notifier);
    bool ok;

    if (_isEditing) {
      ok = await notifier.actualizarUsuario(
        usuario: widget.usuario!,
        nombre: _nombreCtrl.text,
        email: _emailCtrl.text,
        pin: _pinCtrl.text,
        rol: _rol,
      );
    } else {
      ok = await notifier.crearUsuario(
        nombre: _nombreCtrl.text,
        email: _emailCtrl.text,
        pin: _pinCtrl.text,
        rol: _rol,
      );
    }

    if (mounted) Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(
      usuarioProvider.select((s) => s.isProcessing),
    );
    final usuarios = ref.watch(usuarioProvider.select((s) => s.usuarios));
    final colors = Theme.of(context).colorScheme;
    final yaExisteOtroAdministrador = usuarios.any(
      (u) =>
          u.activo &&
          u.rol == RolUsuario.administrador &&
          u.id != widget.usuario?.id,
    );
    final adminBloqueado =
        yaExisteOtroAdministrador &&
        widget.usuario?.rol != RolUsuario.administrador;
    final esUnicoAdmin =
        _isEditing &&
        widget.usuario?.rol == RolUsuario.administrador &&
        !yaExisteOtroAdministrador;
    final rolesDisponibles = RolUsuario.values.where((rol) {
      if (rol != RolUsuario.administrador) return true;
      return !adminBloqueado;
    }).toList();

    return AlertDialog(
      title: Text(_isEditing ? 'Editar usuario' : 'Nuevo usuario'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nombre
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo *',
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El nombre es requerido';
                    }
                    if (v.trim().length < 2) {
                      return 'Mínimo 2 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Email (opcional)
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email (opcional)',
                    prefixIcon: Icon(Icons.email_rounded),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final emailRegex = RegExp(
                      r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$',
                    );
                    if (!emailRegex.hasMatch(v.trim())) {
                      return 'Formato de email inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // PIN
                TextFormField(
                  controller: _pinCtrl,
                  decoration: InputDecoration(
                    labelText: _pinEsObligatorio
                        ? 'PIN de acceso * (4 dígitos)'
                        : 'Nuevo PIN (opcional, 4 dígitos)',
                    helperText: _pinEsObligatorio
                        ? 'Obligatorio para ingresar al sistema.'
                        : 'Déjalo vacío solo si deseas conservar el PIN actual.',
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.lock_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPin
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () => setState(() => _showPin = !_showPin),
                    ),
                  ),
                  obscureText: !_showPin,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) {
                      if (_pinEsObligatorio) {
                        return 'El PIN es obligatorio';
                      }
                      return null;
                    }
                    if (value.length != 4) return 'El PIN debe tener 4 dígitos';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Rol
                DropdownButtonFormField<RolUsuario>(
                  value: _rol,
                  decoration: InputDecoration(
                    labelText: 'Rol *',
                    prefixIcon: const Icon(Icons.badge_rounded),
                    border: const OutlineInputBorder(),
                    helperText: esUnicoAdmin
                        ? 'No se puede cambiar el rol del único administrador activo.'
                        : null,
                    helperStyle: esUnicoAdmin
                        ? TextStyle(color: colors.error, fontSize: 12)
                        : null,
                  ),
                  items: rolesDisponibles
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Row(
                            children: [
                              Icon(
                                _iconRol(r),
                                size: 18,
                                color: _colorRol(r, colors),
                              ),
                              const SizedBox(width: 8),
                              Text(r.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: esUnicoAdmin
                      ? null
                      : (v) {
                          if (v != null) setState(() => _rol = v);
                        },
                ),
                if (adminBloqueado) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ya existe un administrador activo. No se puede crear otro.',
                      style: TextStyle(
                        color: colors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
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
          label: Text(_isEditing ? 'Guardar' : 'Crear usuario'),
        ),
      ],
    );
  }

  IconData _iconRol(RolUsuario rol) {
    switch (rol) {
      case RolUsuario.administrador:
        return Icons.admin_panel_settings_rounded;
      case RolUsuario.cajero:
        return Icons.point_of_sale_rounded;
      case RolUsuario.mesero:
        return Icons.room_service_rounded;
      case RolUsuario.cocina:
        return Icons.soup_kitchen_rounded;
    }
  }

  Color _colorRol(RolUsuario rol, ColorScheme colors) {
    switch (rol) {
      case RolUsuario.administrador:
        return colors.error;
      case RolUsuario.cajero:
        return Colors.green.shade700;
      case RolUsuario.mesero:
        return Colors.blue.shade700;
      case RolUsuario.cocina:
        return Colors.orange.shade700;
    }
  }
}
