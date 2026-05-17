import 'package:flutter/material.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';
import 'package:uuid/uuid.dart';

/// Diálogo para crear o editar una categoría del menú.
class CategoriaFormDialog extends StatefulWidget {
  final Categoria? categoria;

  const CategoriaFormDialog({super.key, this.categoria});

  /// Abre el diálogo y retorna la categoría creada/editada, o null si se cancela.
  static Future<Categoria?> show(BuildContext context, {Categoria? categoria}) {
    return showDialog<Categoria>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CategoriaFormDialog(categoria: categoria),
    );
  }

  @override
  State<CategoriaFormDialog> createState() => _CategoriaFormDialogState();
}

class _CategoriaFormDialogState extends State<CategoriaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _ordenCtrl;
  bool _activo = true;

  bool get _isEditing => widget.categoria != null;

  @override
  void initState() {
    super.initState();
    final cat = widget.categoria;
    _nombreCtrl = TextEditingController(text: cat?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: cat?.descripcion ?? '');
    _ordenCtrl = TextEditingController(text: (cat?.orden ?? 0).toString());
    _activo = cat?.activo ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _ordenCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final categoria = Categoria(
      id: widget.categoria?.id ?? const Uuid().v4(),
      restaurantId:
          widget.categoria?.restaurantId ?? sl<TenantContext>().restaurantId,
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      orden: int.tryParse(_ordenCtrl.text.trim()) ?? 0,
      activo: _activo,
      createdAt: widget.categoria?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(categoria);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final dialogMaxWidth = (viewport.width * 0.92).clamp(280.0, 420.0);
    final dialogMaxHeight = (viewport.height * 0.80).clamp(360.0, 760.0);

    return AlertDialog(
      title: Text(_isEditing ? 'Editar Categoría' : 'Nueva Categoría'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogMaxWidth,
          maxHeight: dialogMaxHeight,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nombre
                TextFormField(
                  controller: _nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Ej: Platos Fuertes',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (v.trim().length < 2) {
                      return 'Mínimo 2 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Descripción
                TextFormField(
                  controller: _descripcionCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Opcional',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Orden
                TextFormField(
                  controller: _ordenCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Orden de visualización',
                    hintText: '0',
                    prefixIcon: Icon(Icons.sort),
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                      return 'Ingresa un número entero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Activo
                SwitchListTile.adaptive(
                  title: const Text('Categoría activa'),
                  subtitle: Text(
                    _activo ? 'Visible en el menú' : 'Oculta del menú',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                  contentPadding: EdgeInsets.zero,
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
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}
