import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/features/menu/presentation/providers/drive_connection_provider.dart';

class DriveHelpDialog {
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ayuda - Google Drive'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pautas rápidas para resolver problemas de inicio de sesión en la web:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const Text('• Comprueba que los popups no estén bloqueados para este sitio.'),
              const Text('• En algunos navegadores, permite “Third‑party sign‑in” o FedCM desde el icono a la izquierda de la barra de URL o en la configuración del sitio.'),
              const Text('• Asegura que el Client ID OAuth (tipo Web) está registrado en Google Cloud Console y que tu dominio está en "Authorized JavaScript origins".'),
              const SizedBox(height: 8),
              const Text('Si después de esto sigues con el problema, pulsa "Reintentar (Conectar)" para abrir el flujo interactivo de OAuth.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(driveConnectionProvider.notifier).connectInteractively();
              // Mostrar snackbar desde el caller (menu_page) si es necesario.
            },
            child: const Text('Reintentar (Conectar)'),
          ),
        ],
      ),
    );
  }
}
