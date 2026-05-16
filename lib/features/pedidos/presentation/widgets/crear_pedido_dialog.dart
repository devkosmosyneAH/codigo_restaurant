import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';
import 'package:restaurant_app/features/mesas/presentation/providers/mesas_provider.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';

/// Diálogo para crear un nuevo pedido.
///
/// Permite seleccionar mesa y agregar observaciones.
class CrearPedidoDialog extends ConsumerStatefulWidget {
  final String restaurantId;

  const CrearPedidoDialog({
    super.key,
    required this.restaurantId,
  });

  @override
  ConsumerState<CrearPedidoDialog> createState() =>
      _CrearPedidoDialogState();
}

class _CrearPedidoDialogState extends ConsumerState<CrearPedidoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _observacionesController = TextEditingController();
  Mesa? _mesaSeleccionada;

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mesasState = ref.watch(mesasProvider);
    final mesasDisponibles = mesasState.mesas
        .where((m) => m.estado == EstadoMesa.libre)
        .toList();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_circle_outline, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Nuevo Pedido'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Selección de mesa ────────────────────────────
              DropdownButtonFormField<Mesa>(
                value: _mesaSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Mesa',
                  prefixIcon: Icon(Icons.table_restaurant_rounded),
                  border: OutlineInputBorder(),
                ),
                items: mesasDisponibles.map((mesa) {
                  return DropdownMenuItem<Mesa>(
                    value: mesa,
                    child: Text(mesa.displayName),
                  );
                }).toList(),
                onChanged: (mesa) {
                  setState(() => _mesaSeleccionada = mesa);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Selecciona una mesa';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ── Observaciones ────────────────────────────────
              TextFormField(
                controller: _observacionesController,
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(),
                  hintText: 'Ej: cliente VIP, cumpleañero...',
                ),
                maxLines: 2,
                maxLength: 200,
              ),

              if (mesasDisponibles.isEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No hay mesas libres disponibles',
                          style: TextStyle(
                              color: AppColors.warning, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _mesaSeleccionada != null ? _submit : null,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Crear Pedido'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final pedido = Pedido(
      id: '', // Se asignará el UUID en la page
      restaurantId: widget.restaurantId,
      mesaId: _mesaSeleccionada!.id,
      estado: EstadoPedido.creado,
      observaciones: _observacionesController.text.trim().isEmpty
          ? null
          : _observacionesController.text.trim(),
      createdAt: now,
      updatedAt: now,
      mesaNombre: _mesaSeleccionada!.displayName,
    );

    Navigator.pop(context, pedido);
  }
}
