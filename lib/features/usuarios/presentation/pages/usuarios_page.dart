import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';
import 'package:restaurant_app/features/usuarios/presentation/providers/usuario_provider.dart';
import 'package:restaurant_app/features/usuarios/presentation/widgets/usuario_card.dart';
import 'package:restaurant_app/features/usuarios/presentation/widgets/usuario_form_dialog.dart';

/// Página principal de gestión de Usuarios y Roles.
class UsuariosPage extends ConsumerWidget {
  const UsuariosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usuarioProvider);
    final colors = Theme.of(context).colorScheme;

    // Mostrar snackbars de resultado
    ref.listen(usuarioProvider.select((s) => s.successMessage), (_, msg) {
      if (msg != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700),
        );
        ref.read(usuarioProvider.notifier).clearMessages();
      }
    });

    ref.listen(usuarioProvider.select((s) => s.error), (_, err) {
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: colors.error),
        );
        ref.read(usuarioProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            _Header(
              totalUsuarios: state.usuarios.length,
              filtroRol: state.filtroRol,
              onFiltroChanged: (rol) =>
                  ref.read(usuarioProvider.notifier).cambiarFiltro(rol),
              onNuevoUsuario: () => _onNuevoUsuario(context, ref),
            ),
            // ── Contadores por rol ───────────────────────────────────────
            _RolStats(usuarios: state.usuarios),
            // ── Lista ───────────────────────────────────────────────────
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.usuariosFiltrados.isEmpty
                  ? _EmptyState(
                      tieneUsuarios: state.usuarios.isNotEmpty,
                      onCrear: () => _onNuevoUsuario(context, ref),
                    )
                  : RefreshIndicator(
                      onRefresh: ref
                          .read(usuarioProvider.notifier)
                          .loadUsuarios,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: state.usuariosFiltrados.length,
                        itemBuilder: (context, i) {
                          final usuario = state.usuariosFiltrados[i];
                          final totalAdmins = state.usuarios
                              .where(
                                (u) =>
                                    u.activo &&
                                    u.rol == RolUsuario.administrador,
                              )
                              .length;
                          final canDelete =
                              !(usuario.rol == RolUsuario.administrador &&
                                  totalAdmins <= 1);
                          return UsuarioCard(
                            usuario: usuario,
                            canDelete: canDelete,
                            onEdit: () => _onEditar(context, ref, usuario),
                            onDelete: () => _onEliminar(context, ref, usuario),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onNuevoUsuario(context, ref),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nuevo usuario'),
      ),
    );
  }

  Future<void> _onNuevoUsuario(BuildContext context, WidgetRef ref) async {
    await UsuarioFormDialog.show(context);
  }

  Future<void> _onEditar(
    BuildContext context,
    WidgetRef ref,
    Usuario usuario,
  ) async {
    await UsuarioFormDialog.show(context, usuario: usuario);
  }

  Future<void> _onEliminar(
    BuildContext context,
    WidgetRef ref,
    Usuario usuario,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
          '¿Estás seguro de eliminar a "${usuario.nombre}"?\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref.read(usuarioProvider.notifier).eliminarUsuario(usuario);
    }
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.totalUsuarios,
    required this.filtroRol,
    required this.onFiltroChanged,
    required this.onNuevoUsuario,
  });

  final int totalUsuarios;
  final RolUsuario? filtroRol;
  final ValueChanged<RolUsuario?> onFiltroChanged;
  final VoidCallback onNuevoUsuario;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.manage_accounts_rounded, size: 24),
              const SizedBox(width: 10),
              Text(
                'Usuarios',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalUsuarios',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          // Filtros de rol en scroll horizontal para pantallas pequeñas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _RolFilterChip(
                  label: 'Todos',
                  selected: filtroRol == null,
                  onTap: () => onFiltroChanged(null),
                ),
                const SizedBox(width: 4),
                ...RolUsuario.values.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _RolFilterChip(
                      label: r.label,
                      selected: filtroRol == r,
                      onTap: () => onFiltroChanged(filtroRol == r ? null : r),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RolFilterChip extends StatelessWidget {
  const _RolFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Estadísticas por rol ───────────────────────────────────────────────────────

class _RolStats extends StatelessWidget {
  const _RolStats({required this.usuarios});

  final List<Usuario> usuarios;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final conteos = {for (var r in RolUsuario.values) r: 0};
    for (final u in usuarios) {
      conteos[u.rol] = (conteos[u.rol] ?? 0) + 1;
    }

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final perRow = width < 700 ? 2 : RolUsuario.values.length;
          const spacing = 8.0;
          final cardWidth = (width - (perRow - 1) * spacing) / perRow;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: RolUsuario.values.map((rol) {
              final count = conteos[rol] ?? 0;
              final rolColor = _colorRol(rol, colors);
              return SizedBox(
                width: cardWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: rolColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: rolColor,
                        ),
                      ),
                      Text(
                        rol.label,
                        style: TextStyle(fontSize: 11, color: colors.outline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
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

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tieneUsuarios, required this.onCrear});

  final bool tieneUsuarios;
  final VoidCallback onCrear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_off_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            tieneUsuarios
                ? 'No hay usuarios con ese rol'
                : 'No hay usuarios registrados',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          if (!tieneUsuarios) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCrear,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Crear primer usuario'),
            ),
          ],
        ],
      ),
    );
  }
}
