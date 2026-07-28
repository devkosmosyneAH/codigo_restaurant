import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';
import 'package:restaurant_app/features/mesas/presentation/providers/mesas_provider.dart';
import 'package:restaurant_app/features/mesas/presentation/providers/llamados_provider.dart';
import 'package:restaurant_app/features/mesas/presentation/widgets/mesa_card.dart';
import 'package:restaurant_app/features/mesas/presentation/widgets/mesa_form_dialog.dart';
import 'package:restaurant_app/features/mesas/presentation/widgets/mesa_qr_dialog.dart';

/// Página principal del módulo de Mesas.
///
/// Muestra un grid de mesas con colores por estado.
/// Permite crear, editar, eliminar y cambiar estado.
class MesasPage extends ConsumerStatefulWidget {
  const MesasPage({super.key});

  @override
  ConsumerState<MesasPage> createState() => _MesasPageState();
}

class _MesasPageState extends ConsumerState<MesasPage> {
  static const _uuid = Uuid();
  EstadoMesa? _filtroEstado;

  @override
  void initState() {
    super.initState();
    // Cargar mesas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mesasProvider.notifier).loadMesas();
      ref.read(llamadosProvider.notifier).loadPendientes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mesasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Mesas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () {
              ref.read(mesasProvider.notifier).loadMesas();
              ref.read(llamadosProvider.notifier).loadPendientes();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(124),
          child: _buildTopBarContent(context, state),
        ),
      ),
      // ── FAB: Crear mesa ─────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Mesa'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildFilterChip(EstadoMesa? estado, String label, int count) {
    final isSelected = _filtroEstado == estado;
    final stateColor = estado != null
        ? _getColorByEstado(estado)
        : Colors.white;

    final bgColor = isSelected
        ? (estado != null ? stateColor : Colors.white)
        : Colors.white.withValues(alpha: 0.12);

    final textColor = isSelected
        ? (estado != null ? Colors.white : AppColors.primary)
        : Colors.white;

    final borderColor = isSelected
        ? (estado != null ? stateColor : Colors.white)
        : Colors.white.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = estado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: stateColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 14, color: textColor),
              const SizedBox(width: 4),
            ] else if (estado != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: stateColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              '$label ($count)',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarContent(BuildContext context, MesasState state) {
    final actionStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila de acciones
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildLlamadosBadge(actionStyle),
              OutlinedButton.icon(
                style: actionStyle,
                onPressed: () => _showReservarLocalDialog(context),
                icon: const Icon(Icons.event_available_rounded, size: 16),
                label: const Text('Reservar local'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Fila de filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(null, 'Todas', state.totalMesas),
                const SizedBox(width: 8),
                _buildFilterChip(EstadoMesa.libre, 'Libres', state.totalLibres),
                const SizedBox(width: 8),
                _buildFilterChip(
                  EstadoMesa.ocupada,
                  'Ocupadas',
                  state.totalOcupadas,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(MesasState state) {
    // ── Error ──────────────────────────────────────────────────
    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(state.errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(mesasProvider.notifier).loadMesas(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    // ── Cargando ───────────────────────────────────────────────
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── Sin mesas ──────────────────────────────────────────────
    if (state.mesas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay mesas configuradas',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Presiona "Nueva Mesa" para agregar la primera',
              style: TextStyle(color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    // ── Grid de mesas ──────────────────────────────────────────
    final mesasFiltradas = _filtroEstado == null
        ? state.mesas
        : state.mesas.where((m) => m.estado == _filtroEstado).toList();

    if (mesasFiltradas.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await ref.read(mesasProvider.notifier).loadMesas();
          await ref.read(llamadosProvider.notifier).loadPendientes();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 96, 24, 120),
          children: const [
            Icon(
              Icons.filter_alt_off_rounded,
              size: 56,
              color: AppColors.textHint,
            ),
            SizedBox(height: 14),
            Center(
              child: Text(
                'No hay mesas con este filtro',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 6),
            Center(
              child: Text(
                'Prueba otro estado o actualiza para recargar.',
                style: TextStyle(color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final maxExtent = width < 480
              ? 170.0
              : width < 800
              ? 190.0
              : 220.0;
          final aspect = width < 480
              ? 0.72
              : width < 800
              ? 0.8
              : 0.92;

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(mesasProvider.notifier).loadMesas();
              await ref.read(llamadosProvider.notifier).loadPendientes();
            },
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: maxExtent,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: aspect,
              ),
              itemCount: mesasFiltradas.length,
              itemBuilder: (context, index) {
                final mesa = mesasFiltradas[index];
                return MesaCard(
                  mesa: mesa,
                  onTap: () => _showMesaOptions(context, mesa),
                  onLongPress: () => _showEditDialog(context, mesa),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ── Acciones ─────────────────────────────────────────────────

  Future<void> _showCreateDialog(BuildContext context) async {
    final nextNum = await ref.read(mesasProvider.notifier).nextNumero();

    if (!context.mounted) return;

    final result = await showDialog<Mesa>(
      context: context,
      builder: (_) => MesaFormDialog(
        nextNumero: nextNum,
        restaurantId: sl<TenantContext>().restaurantId,
      ),
    );

    if (result != null) {
      final mesa = result.copyWith(id: _uuid.v4());
      await ref.read(mesasProvider.notifier).crearMesa(mesa);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mesa ${mesa.numero} creada')));
    }
  }

  Future<void> _showEditDialog(BuildContext context, Mesa mesa) async {
    final result = await showDialog<Mesa>(
      context: context,
      builder: (_) => MesaFormDialog(
        mesa: mesa,
        nextNumero: mesa.numero,
        restaurantId: mesa.restaurantId,
      ),
    );

    if (result != null) {
      await ref.read(mesasProvider.notifier).actualizarMesa(result);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesa ${result.numero} actualizada')),
      );
    }
  }

  void _showMesaOptions(BuildContext context, Mesa mesa) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.table_restaurant_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        mesa.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getColorByEstado(
                          mesa.estado,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        mesa.estado.label,
                        style: TextStyle(
                          color: _getColorByEstado(mesa.estado),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // ── Cambiar estado ──────────────────────────────
              ...EstadoMesa.values
                  .where((e) => e != mesa.estado && e != EstadoMesa.reservada)
                  .map(
                    (estado) => ListTile(
                      leading: Icon(
                        Icons.circle,
                        color: _getColorByEstado(estado),
                        size: 20,
                      ),
                      title: Text('Marcar como ${estado.label}'),
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(mesasProvider.notifier)
                            .cambiarEstado(mesa.id, estado, mesa.restaurantId);
                      },
                    ),
                  ),

              // ── QR del menu ─────────────────────────────────
              ListTile(
                leading: const Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Ver QR del menú'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showQrDialog(mesa);
                },
              ),

              // ── Reservar / Liberar ──────────────────────────
              if (mesa.estado != EstadoMesa.reservada)
                ListTile(
                  leading: const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.mesaReservada,
                  ),
                  title: const Text('Reservar mesa'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReservarDialog(context, mesa);
                  },
                ),
              if (mesa.estado == EstadoMesa.reservada)
                ListTile(
                  leading: const Icon(
                    Icons.event_busy_rounded,
                    color: AppColors.mesaLibre,
                  ),
                  title: Text(
                    mesa.nombreReserva != null
                        ? 'Liberar reserva (${mesa.nombreReserva})'
                        : 'Liberar reserva',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _liberarReserva(context, mesa);
                  },
                ),

              const Divider(),

              // ── Editar ──────────────────────────────────────
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.info),
                title: const Text('Editar mesa'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditDialog(context, mesa);
                },
              ),

              // ── Eliminar ────────────────────────────────────
              ListTile(
                leading: const Icon(
                  Icons.delete_rounded,
                  color: AppColors.error,
                ),
                title: const Text('Eliminar mesa'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, mesa);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQrDialog(Mesa mesa) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      MesaQrDialog.show(rootContext, mesa: mesa);
    });
  }

  Widget _buildLlamadosBadge(ButtonStyle style) {
    final llamados = ref.watch(llamadosProvider);
    final count = llamados.totalPendientes;

    return Tooltip(
      message: 'Llamados a mesero',
      child: OutlinedButton.icon(
        style: style,
        onPressed: () => _showLlamadosSheet(context),
        icon: count > 0
            ? Badge(
                label: Text('$count'),
                child: const Icon(Icons.campaign_rounded, size: 18),
              )
            : const Icon(Icons.campaign_outlined, size: 18),
        label: Text(count > 0 ? 'Llamados' : 'Avisos'),
      ),
    );
  }

  void _showLlamadosSheet(BuildContext context) {
    final state = ref.read(llamadosProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    leading: Icon(Icons.campaign_rounded),
                    title: Text('Llamados a mesero'),
                  ),
                  const Divider(),
                  if (state.pendientes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay llamados pendientes.'),
                    ),
                  if (state.pendientes.isNotEmpty)
                    ...state.pendientes.map(
                      (l) => ListTile(
                        leading: const Icon(Icons.table_restaurant_rounded),
                        title: Text(l.mesaNombre ?? l.mesaId ?? 'Mesa'),
                        subtitle: Text(
                          'Solicitado: ${_formatHora(l.createdAt)}',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            await ref
                                .read(llamadosProvider.notifier)
                                .marcarAtendido(
                                  l.id,
                                  sl<TenantContext>().restaurantId,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Atender'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatHora(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _confirmDelete(BuildContext context, Mesa mesa) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar mesa'),
        content: Text('¿Estás seguro de eliminar ${mesa.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(mesasProvider.notifier)
          .eliminarMesa(mesa.id, mesa.restaurantId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${mesa.displayName} eliminada')));
    }
  }

  // ── Diálogos de reserva ─────────────────────────────────────

  Future<void> _showReservarDialog(BuildContext context, Mesa mesa) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reservar ${mesa.displayName}'),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(context).height * 0.80,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la reserva',
                  hintText: 'Ej: Familia García',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa un nombre'
                    : null,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Reservar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final nombre = controller.text.trim();
      final ok = await ref
          .read(mesasProvider.notifier)
          .reservarMesa(mesa, nombre, mesa.restaurantId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '${mesa.displayName} reservada para "$nombre"'
                : 'Error al reservar la mesa',
          ),
        ),
      );
    }
    controller.dispose();
  }

  Future<void> _showReservarLocalDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reservar todo el local'),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(context).height * 0.80,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre del grupo o institución',
                  hintText: 'Ej: Corporación ACME',
                  prefixIcon: Icon(Icons.groups_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa un nombre'
                    : null,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Reservar Local'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final nombre = controller.text.trim();
      final count = await ref
          .read(mesasProvider.notifier)
          .reservarTodoElLocal(nombre, sl<TenantContext>().restaurantId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '$count mesas reservadas para "$nombre"'
                : 'No hay mesas libres para reservar',
          ),
        ),
      );
    }
    controller.dispose();
  }

  Future<void> _liberarReserva(BuildContext context, Mesa mesa) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(mesasProvider.notifier).liberarReserva(mesa);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? '${mesa.displayName} liberada' : 'Error al liberar la reserva',
        ),
      ),
    );
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
