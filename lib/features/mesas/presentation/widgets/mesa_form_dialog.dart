import 'package:flutter/material.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';

/// Dialog para crear o editar una mesa.
///
/// Muestra un formulario con:
/// - Número de mesa
/// - Nombre (opcional)
/// - Capacidad
/// - Estado
class MesaFormDialog extends StatefulWidget {
  final Mesa? mesa; // null = crear, no null = editar
  final int nextNumero;
  final String restaurantId;

  const MesaFormDialog({
    super.key,
    this.mesa,
    required this.nextNumero,
    required this.restaurantId,
  });

  @override
  State<MesaFormDialog> createState() => _MesaFormDialogState();
}

class _MesaFormDialogState extends State<MesaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numeroController;
  late final TextEditingController _nombreController;
  late final TextEditingController _capacidadController;
  late EstadoMesa _estado;

  bool get isEditing => widget.mesa != null;

  @override
  void initState() {
    super.initState();
    _numeroController = TextEditingController(
      text: isEditing
          ? widget.mesa!.numero.toString()
          : widget.nextNumero.toString(),
    );
    _nombreController = TextEditingController(text: widget.mesa?.nombre ?? '');
    _capacidadController = TextEditingController(
      text: (widget.mesa?.capacidad ?? 4).toString(),
    );
    _estado = widget.mesa?.estado ?? EstadoMesa.libre;
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _nombreController.dispose();
    _capacidadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Editar Mesa' : 'Nueva Mesa'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.80,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Número de mesa ──────────────────────────────
                TextFormField(
                  controller: _numeroController,
                  decoration: const InputDecoration(
                    labelText: 'Número de mesa *',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el número';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Debe ser un número válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Nombre (opcional) ───────────────────────────
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (opcional)',
                    prefixIcon: Icon(Icons.label_rounded),
                    hintText: 'Ej: Terraza 1, VIP',
                  ),
                ),
                const SizedBox(height: 16),

                // ── Capacidad ───────────────────────────────────
                TextFormField(
                  controller: _capacidadController,
                  decoration: const InputDecoration(
                    labelText: 'Capacidad (personas) *',
                    prefixIcon: Icon(Icons.people_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese la capacidad';
                    }
                    final num = int.tryParse(value);
                    if (num == null || num < 1) {
                      return 'Mínimo 1 persona';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Estado ──────────────────────────────────────
                DropdownButtonFormField<EstadoMesa>(
                  value: _estado,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    prefixIcon: Icon(Icons.circle_rounded),
                  ),
                  items: EstadoMesa.values.map((estado) {
                    return DropdownMenuItem(
                      value: estado,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getColorByEstado(estado),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(estado.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _estado = value);
                  },
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
        ElevatedButton.icon(
          onPressed: _submit,
          icon: Icon(isEditing ? Icons.save_rounded : Icons.add_rounded),
          label: Text(isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final mesa = Mesa(
      id: widget.mesa?.id ?? '', // se asigna en el provider si es nuevo
      restaurantId: widget.restaurantId,
      numero: int.parse(_numeroController.text),
      nombre: _nombreController.text.isEmpty ? null : _nombreController.text,
      capacidad: int.parse(_capacidadController.text),
      estado: _estado,
      mesaUnionId: widget.mesa?.mesaUnionId,
      posicionX: widget.mesa?.posicionX ?? 0,
      posicionY: widget.mesa?.posicionY ?? 0,
      activo: true,
      createdAt: widget.mesa?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(mesa);
  }

  Color _getColorByEstado(EstadoMesa estado) {
    switch (estado) {
      case EstadoMesa.libre:
        return AppColors.mesaLibre;
      case EstadoMesa.ocupada:
        return AppColors.mesaOcupada;
      case EstadoMesa.reservada:
        return AppColors.mesaReservada;
    }
  }
}
