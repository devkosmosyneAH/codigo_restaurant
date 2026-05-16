import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/presentation/providers/pedidos_provider.dart';

/// Panel que muestra los pedidos pendientes de aprobación para el mesero.
///
/// Se presenta como un bottom sheet. Cada pedido puede ser aprobado
/// (pasa a [EstadoPedido.creado] y va a cocina) o rechazado (eliminado).
class AprobarPedidosSheet extends ConsumerWidget {
  const AprobarPedidosSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AprobarPedidosSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientes = ref.watch(
      pedidosProvider.select((s) => s.pedidosPendientesAprobacion),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      builder: (_, scrollCtrl) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                children: [
                  const Icon(Icons.pending_actions_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pedidos por aprobar (${pendientes.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(),
              if (pendientes.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.green,
                        ),
                        SizedBox(height: 12),
                        Text('No hay pedidos pendientes'),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    itemCount: pendientes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) =>
                        _PedidoPendienteCard(pedido: pendientes[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PedidoPendienteCard extends ConsumerStatefulWidget {
  final Pedido pedido;

  const _PedidoPendienteCard({required this.pedido});

  @override
  ConsumerState<_PedidoPendienteCard> createState() =>
      _PedidoPendienteCardState();
}

class _PedidoPendienteCardState extends ConsumerState<_PedidoPendienteCard> {
  bool _processing = false;

  Future<void> _aprobar() async {
    setState(() => _processing = true);
    final ok = await ref
        .read(pedidosProvider.notifier)
        .aprobarPedido(widget.pedido.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al aprobar el pedido')),
      );
    }
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _rechazar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar pedido'),
        content: Text(
          '¿Rechazar el pedido de ${widget.pedido.mesaNombre ?? 'la mesa'}? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processing = true);
    final ok = await ref
        .read(pedidosProvider.notifier)
        .rechazarPedido(widget.pedido.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al rechazar el pedido')),
      );
    }
    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado mesa + hora
          Row(
            children: [
              const Icon(Icons.table_restaurant_rounded, size: 18),
              const SizedBox(width: 6),
              Text(
                p.mesaNombre ?? 'Mesa desconocida',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                _formatHora(p.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Items
          if (p.items.isNotEmpty)
            ...p.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Text(
                      '${item.cantidad}×',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.productoNombre ??
                            (item.varianteNombre != null
                                ? '${item.productoNombre} (${item.varianteNombre})'
                                : item.productoId),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${AppConstants.currencySymbol}${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Text('Sin detalle de items', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total: ${AppConstants.currencySymbol}${p.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Botones
          if (_processing)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Rechazar'),
                    onPressed: _rechazar,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Aprobar → Cocina'),
                    onPressed: _aprobar,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatHora(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
