import 'package:flutter/material.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';

/// Tarjeta de usuario para la lista de gestión.
class UsuarioCard extends StatelessWidget {
  const UsuarioCard({
    super.key,
    required this.usuario,
    required this.onEdit,
    required this.onDelete,
    this.canDelete = true,
  });

  final Usuario usuario;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rolColor = _colorRol(usuario.rol, colors);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: rolColor.withValues(alpha: 0.15),
          child: Text(
            usuario.iniciales,
            style: TextStyle(
              color: rolColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                usuario.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: rolColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                usuario.rol.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: rolColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (usuario.email != null && usuario.email!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.email_rounded, size: 13, color: colors.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      usuario.email!,
                      style: TextStyle(fontSize: 12, color: colors.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  usuario.pin != null
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  size: 13,
                  color: colors.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  usuario.pin != null ? 'PIN configurado' : 'Sin PIN',
                  style: TextStyle(fontSize: 12, color: colors.outline),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Editar',
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(
                Icons.delete_rounded,
                color: canDelete ? colors.error : colors.outlineVariant,
              ),
              tooltip: canDelete
                  ? 'Eliminar'
                  : 'No se puede eliminar el único administrador',
              onPressed: canDelete ? onDelete : null,
            ),
          ],
        ),
      ),
    );
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
