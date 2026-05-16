import 'package:flutter/material.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';

/// Tarjeta visual para un pedido en la lista.
///
/// Muestra: mesa, estado, total, tiempo transcurrido, cantidad de items.
class PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback? onTap;

  const PedidoCard({super.key, required this.pedido, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorEstado = _getColorByEstado(pedido.estado);
    final tiempo = _formatDuration(pedido.tiempoTranscurrido);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header con estado ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: colorEstado.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: colorEstado,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pedido.mesaNombre ?? 'Sin mesa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorEstado,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorEstado.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pedido.estado.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorEstado,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items count
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${pedido.cantidadItems} item${pedido.cantidadItems != 1 ? "s" : ""}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      // Tiempo
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: _getTimeColor(tiempo),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tiempo,
                        style: TextStyle(
                          color: _getTimeColor(tiempo),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Observaciones
                  if (pedido.observaciones != null &&
                      pedido.observaciones!.isNotEmpty) ...[
                    Text(
                      pedido.observaciones!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Total
                  Row(
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '\$${pedido.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorByEstado(EstadoPedido estado) {
    switch (estado) {
      case EstadoPedido.pendienteAprobacion:
        return Colors.orange;
      case EstadoPedido.creado:
        return AppColors.pedidoCreado;
      case EstadoPedido.aceptado:
        return AppColors.pedidoAceptado;
      case EstadoPedido.enPreparacion:
        return AppColors.pedidoEnPreparacion;
      case EstadoPedido.finalizado:
        return AppColors.pedidoFinalizado;
      case EstadoPedido.entregado:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes}m';
  }

  Color _getTimeColor(String tiempo) {
    final mins = _parseMins(tiempo);
    if (mins > 30) return AppColors.error;
    if (mins > 15) return AppColors.warning;
    return AppColors.textSecondary;
  }

  int _parseMins(String time) {
    // Simple parser for "Xh Ym" or "Xm"
    final parts = time
        .replaceAll('h', '')
        .replaceAll('m', '')
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.length == 2) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final mins = int.tryParse(parts[1]) ?? 0;
      return (hours * 60) + mins;
    }
    return int.tryParse(parts[0]) ?? 0;
  }
}
