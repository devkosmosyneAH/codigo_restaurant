import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/features/sincronizacion/presentation/providers/sync_provider.dart';

/// Página de Sincronización.
///
/// Muestra el estado del log offline-first:
/// - Tarjetas de resumen (pendientes / sincronizados)
/// - Lista de operaciones pendientes con tabla y tipo
/// - Historial de operaciones ya sincronizadas
/// - Botón de sincronización manual (listo para Firebase)
class SincronizacionPage extends ConsumerStatefulWidget {
  const SincronizacionPage({super.key});

  @override
  ConsumerState<SincronizacionPage> createState() => _SincronizacionPageState();
}

class _SincronizacionPageState extends ConsumerState<SincronizacionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dtFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syncProvider);
    final colors = Theme.of(context).colorScheme;

    ref.listen(syncProvider.select((s) => s.successMessage), (_, msg) {
      if (msg != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700),
        );
        ref.read(syncProvider.notifier).clearMessages();
      }
    });

    ref.listen(syncProvider.select((s) => s.error), (_, err) {
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: colors.error),
        );
        ref.read(syncProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          _Header(
            state: state,
            dtFmt: _dtFmt,
            onSync: () => ref.read(syncProvider.notifier).sincronizarAhora(),
            onRefresh: () {
              final notifier = ref.read(syncProvider.notifier);
              notifier.loadRegistros();
              notifier.checkCloudAvailability();
            },
            onLimpiar: () => _onLimpiar(context),
          ),
          // ── Resumen ──────────────────────────────────────────────────
          _ResumenCards(state: state),
          // ── Tabs ─────────────────────────────────────────────────────
          ColoredBox(
            color: colors.surface,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: Badge(
                    label: Text('${state.totalPendientes}'),
                    isLabelVisible: state.tienePendientes,
                    child: const Icon(Icons.pending_actions_rounded),
                  ),
                  text: 'Pendientes',
                ),
                Tab(
                  icon: const Icon(Icons.done_all_rounded),
                  text: 'Historial',
                ),
              ],
            ),
          ),
          // ── Contenido ────────────────────────────────────────────────
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _ListaRegistros(
                        registros: state.pendientes,
                        sincronizado: false,
                        dtFmt: _dtFmt,
                        emptyMsg:
                            '¡Todo sincronizado! Sin operaciones pendientes.',
                        emptyIcon: Icons.cloud_done_rounded,
                      ),
                      _ListaRegistros(
                        registros: state.sincronizados,
                        sincronizado: true,
                        dtFmt: _dtFmt,
                        emptyMsg: 'No hay historial de sincronizaciones aún.',
                        emptyIcon: Icons.history_rounded,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _onLimpiar(BuildContext context) async {
    final dias = await showDialog<int>(
      context: context,
      builder: (ctx) => _LimpiarDialog(),
    );
    if (!mounted) return;
    if (dias != null) {
      await ref.read(syncProvider.notifier).limpiarHistorial(dias: dias);
    }
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.dtFmt,
    required this.onSync,
    required this.onRefresh,
    required this.onLimpiar,
  });

  final SyncState state;
  final DateFormat dtFmt;
  final VoidCallback onSync;
  final VoidCallback onRefresh;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canSync =
        !state.isSyncing &&
        !state.isCheckingCloud &&
        state.cloudAvailable != false;
    final syncBlockedByCloud = !state.isSyncing && !canSync;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.sync_rounded, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sincronización',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (state.ultimaSync != null)
                      Text(
                        'Última sync: ${dtFmt.format(state.ultimaSync!)}',
                        style: TextStyle(fontSize: 11, color: colors.outline),
                      ),
                  ],
                ),
              ),
              // Limpiar historial
              IconButton(
                icon: const Icon(Icons.cleaning_services_rounded),
                tooltip: 'Limpiar historial',
                onPressed: onLimpiar,
              ),
              // Refrescar
              IconButton(
                icon: state.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed: state.isLoading ? null : onRefresh,
              ),
              const SizedBox(width: 4),
              // Sincronizar ahora
              FilledButton.icon(
                onPressed: canSync ? onSync : null,
                icon: state.isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(state.isSyncing ? 'Sincronizando…' : 'Sincronizar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CloudStatusPill(state: state),
          if (syncBlockedByCloud) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                state.isCheckingCloud
                    ? 'Espera a que termine la verificación de nube.'
                    : 'Sincronizar está deshabilitado hasta conectar Firebase.',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CloudStatusPill extends StatelessWidget {
  const _CloudStatusPill({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final bool checking = state.isCheckingCloud;
    final bool ready = state.cloudAvailable == true;
    final bool unavailable = state.cloudAvailable == false;

    final bgColor = checking
        ? colors.primary.withValues(alpha: 0.08)
        : ready
        ? Colors.green.withValues(alpha: 0.12)
        : unavailable
        ? colors.error.withValues(alpha: 0.12)
        : colors.surfaceContainerHighest;

    final fgColor = checking
        ? colors.primary
        : ready
        ? Colors.green.shade700
        : unavailable
        ? colors.error
        : colors.onSurfaceVariant;

    final label = checking
        ? 'Verificando conexión con nube...'
        : ready
        ? 'Nube conectada'
        : unavailable
        ? 'Nube desconectada'
        : 'Estado de nube no verificado';

    final detail = checking
        ? null
        : state.cloudStatusMessage != null
        ? ' · ${state.cloudStatusMessage}'
        : null;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (checking)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fgColor,
                ),
              )
            else
              Icon(
                ready
                    ? Icons.cloud_done_rounded
                    : unavailable
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_queue_rounded,
                size: 14,
                color: fgColor,
              ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                detail == null ? label : '$label$detail',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Resumen Cards ──────────────────────────────────────────────────────────────

class _ResumenCards extends StatelessWidget {
  const _ResumenCards({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final perRow = width < 700 ? 2 : 3;
          const spacing = 12.0;
          final cardWidth = (width - (perRow - 1) * spacing) / perRow;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              SizedBox(
                width: cardWidth,
                child: _StatCard(
                  label: 'Pendientes',
                  value: '${state.totalPendientes}',
                  icon: Icons.pending_actions_rounded,
                  color: state.tienePendientes ? colors.error : Colors.green,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _StatCard(
                  label: 'Sincronizados',
                  value: '${state.sincronizados.length}',
                  icon: Icons.done_all_rounded,
                  color: colors.primary,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _StatCard(
                  label: 'Total en log',
                  value: '${state.registros.length}',
                  icon: Icons.list_alt_rounded,
                  color: colors.secondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: colors.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Lista de Registros ─────────────────────────────────────────────────────────

class _ListaRegistros extends StatelessWidget {
  const _ListaRegistros({
    required this.registros,
    required this.sincronizado,
    required this.dtFmt,
    required this.emptyMsg,
    required this.emptyIcon,
  });

  final List<SyncRecord> registros;
  final bool sincronizado;
  final DateFormat dtFmt;
  final String emptyMsg;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (registros.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              emptyMsg,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: registros.length,
      itemBuilder: (context, i) {
        return _SyncRecordCard(
          record: registros[i],
          sincronizado: sincronizado,
          dtFmt: dtFmt,
        );
      },
    );
  }
}

class _SyncRecordCard extends StatelessWidget {
  const _SyncRecordCard({
    required this.record,
    required this.sincronizado,
    required this.dtFmt,
  });

  final SyncRecord record;
  final bool sincronizado;
  final DateFormat dtFmt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final opColor = _colorOp(record.operacion, colors);
    final opIcon = _iconOp(record.operacion);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: opColor.withValues(alpha: 0.15),
          child: Icon(opIcon, color: opColor, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                record.tabla,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: opColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _labelOp(record.operacion),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: opColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'ID: ${record.registroId.length > 16 ? '${record.registroId.substring(0, 16)}…' : record.registroId}',
              style: TextStyle(fontSize: 11, color: colors.outline),
            ),
            Text(
              dtFmt.format(record.createdAt),
              style: TextStyle(fontSize: 11, color: colors.outline),
            ),
            if (record.intentos > 0)
              Text(
                'Intentos: ${record.intentos}',
                style: TextStyle(
                  fontSize: 11,
                  color: record.intentos >= 3 ? colors.error : colors.outline,
                ),
              ),
          ],
        ),
        trailing: sincronizado
            ? const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 20,
              )
            : Icon(Icons.schedule_rounded, color: colors.outline, size: 20),
      ),
    );
  }

  Color _colorOp(SyncOperation op, ColorScheme colors) {
    switch (op) {
      case SyncOperation.insert:
        return Colors.green.shade700;
      case SyncOperation.update:
        return Colors.blue.shade700;
      case SyncOperation.delete:
        return colors.error;
    }
  }

  IconData _iconOp(SyncOperation op) {
    switch (op) {
      case SyncOperation.insert:
        return Icons.add_circle_rounded;
      case SyncOperation.update:
        return Icons.edit_rounded;
      case SyncOperation.delete:
        return Icons.delete_rounded;
    }
  }

  String _labelOp(SyncOperation op) {
    switch (op) {
      case SyncOperation.insert:
        return 'INSERT';
      case SyncOperation.update:
        return 'UPDATE';
      case SyncOperation.delete:
        return 'DELETE';
    }
  }
}

// ── Limpiar Dialog ─────────────────────────────────────────────────────────────

class _LimpiarDialog extends StatefulWidget {
  @override
  State<_LimpiarDialog> createState() => _LimpiarDialogState();
}

class _LimpiarDialogState extends State<_LimpiarDialog> {
  int _dias = 7;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Limpiar historial'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Eliminar registros ya sincronizados con más de:'),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1 día')),
              ButtonSegment(value: 7, label: Text('7 días')),
              ButtonSegment(value: 30, label: Text('30 días')),
            ],
            selected: {_dias},
            onSelectionChanged: (s) => setState(() => _dias = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_dias),
          icon: const Icon(Icons.cleaning_services_rounded),
          label: const Text('Limpiar'),
        ),
      ],
    );
  }
}
