import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/presentation/providers/cliente_provider.dart';
import 'package:restaurant_app/features/clientes/presentation/widgets/cliente_card.dart';
import 'package:restaurant_app/features/clientes/presentation/widgets/cliente_form_dialog.dart';

/// Página principal de gestión de Clientes.
class ClientesPage extends ConsumerStatefulWidget {
  const ClientesPage({super.key});

  @override
  ConsumerState<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends ConsumerState<ClientesPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    ref.read(clienteProvider.notifier).buscar(query);
  }

  Future<void> _onNuevoCliente() async {
    final ok = await ClienteFormDialog.show(context);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente registrado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _onEditarCliente(Cliente cliente) async {
    final ok = await ClienteFormDialog.show(context, cliente: cliente);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente actualizado.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _onEliminarCliente(Cliente cliente) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(
          '¿Eliminar a ${cliente.nombreCompleto} (${cliente.cedula})?\n'
          'El historial de ventas no se borrará.',
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
    if (confirm != true || !mounted) return;
    await ref.read(clienteProvider.notifier).eliminarCliente(cliente.cedula);
  }

  void _onVerResumen(Cliente cliente) {
    ref.read(clienteProvider.notifier).cargarResumen(cliente.cedula);
    showDialog<void>(
      context: context,
      builder: (_) => _ResumenDialog(cliente: cliente),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clienteProvider);
    final cs = Theme.of(context).colorScheme;

    // Snackbar de errores
    ref.listen(clienteProvider.select((s) => s.error), (_, err) {
      if (err != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err), backgroundColor: cs.error));
        ref.read(clienteProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────
          _Header(
            total: state.clientes.length,
            searchCtrl: _searchCtrl,
            onSearch: _onSearch,
            onNuevo: _onNuevoCliente,
            onRefresh: () {
              _searchCtrl.clear();
              ref.read(clienteProvider.notifier).limpiarBusqueda();
              ref.read(clienteProvider.notifier).loadClientes();
            },
          ),
          // ── Lista ────────────────────────────────────────────────
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.listaVisible.isEmpty
                ? _EmptyState(
                    hayClientes: state.clientes.isNotEmpty,
                    onCrear: _onNuevoCliente,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: state.listaVisible.length,
                    itemBuilder: (_, i) {
                      final c = state.listaVisible[i];
                      return ClienteCard(
                        cliente: c,
                        onEdit: () => _onEditarCliente(c),
                        onDelete: () => _onEliminarCliente(c),
                        onVerResumen: () => _onVerResumen(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.searchCtrl,
    required this.onSearch,
    required this.onNuevo,
    required this.onRefresh,
  });

  final int total;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onNuevo;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_rounded, size: 24),
              const SizedBox(width: 10),
              Text(
                'Clientes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed: onRefresh,
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: onNuevo,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Nuevo'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Buscar por cédula, nombre, email o teléfono...',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearch('');
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hayClientes, required this.onCrear});

  final bool hayClientes;
  final VoidCallback onCrear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hayClientes
                ? Icons.search_off_rounded
                : Icons.people_outline_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            hayClientes
                ? 'Sin resultados para esa búsqueda'
                : 'Aún no hay clientes registrados',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          if (!hayClientes) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCrear,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Registrar primer cliente'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Diálogo de resumen ────────────────────────────────────────────────────────

class _ResumenDialog extends ConsumerWidget {
  const _ResumenDialog({required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(clienteProvider.select((s) => s.resumenActual));
    final moneda = NumberFormat.currency(locale: 'es_EC', symbol: '\$');
    final cs = Theme.of(context).colorScheme;
    final fmtFecha = DateFormat('dd/MM/yyyy');

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text(
              cliente.iniciales,
              style: TextStyle(color: cs.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente.nombreCompleto,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  cliente.cedula,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: resumen == null
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ResumenTile(
                    icon: Icons.receipt_long_rounded,
                    label: 'Total de visitas',
                    value: '${resumen.totalVisitas}',
                    color: cs.primary,
                  ),
                  _ResumenTile(
                    icon: Icons.attach_money_rounded,
                    label: 'Total gastado',
                    value: moneda.format(resumen.totalGastado),
                    color: Colors.green.shade700,
                  ),
                  _ResumenTile(
                    icon: Icons.bar_chart_rounded,
                    label: 'Ticket promedio',
                    value: moneda.format(resumen.ticketPromedio),
                    color: Colors.orange.shade700,
                  ),
                  if (resumen.primeraVisita != null)
                    _ResumenTile(
                      icon: Icons.calendar_today_rounded,
                      label: 'Primera visita',
                      value: fmtFecha.format(resumen.primeraVisita!),
                    ),
                  if (resumen.ultimaVisita != null)
                    _ResumenTile(
                      icon: Icons.update_rounded,
                      label: 'Última visita',
                      value: fmtFecha.format(resumen.ultimaVisita!),
                    ),
                  if (resumen.totalVisitas == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Sin ventas registradas con esta cédula todavía.',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _ResumenTile extends StatelessWidget {
  const _ResumenTile({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
