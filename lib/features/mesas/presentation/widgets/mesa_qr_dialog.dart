import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/utils/public_route_url_builder.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';

/// Dialogo para mostrar el QR de pedido por mesa.
///
/// El cliente escanea el código, accede a la carta digital y puede
/// enviar su orden directamente al mesero para revisión antes de
/// que llegue a cocina.
class MesaQrDialog extends StatelessWidget {
  final Mesa mesa;

  const MesaQrDialog({super.key, required this.mesa});

  static Future<void> show(BuildContext context, {required Mesa mesa}) {
    return showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => MesaQrDialog(mesa: mesa),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = _buildOrderUrl(mesa);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 22),
          const SizedBox(width: 8),
          Text('QR Pedido — ${mesa.displayName}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: QrImageView(
              data: url,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El cliente escanea este QR, elige sus platos y envía el pedido. '
                    'El mesero lo revisa antes de que llegue a cocina.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            url,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  String _buildOrderUrl(Mesa mesa) {
    return PublicRouteUrlBuilder.route(
      AppRouter.pedidoMesa,
      fallbackUrl: AppConstants.publicOrderBaseUrl,
      queryParameters: {'mesa': mesa.id, 'nombre': mesa.displayName},
    );
  }
}
