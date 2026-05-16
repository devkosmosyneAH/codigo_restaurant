import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/mesas/presentation/providers/mesas_provider.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/presentation/providers/pedidos_provider.dart';
import 'package:restaurant_app/features/pedidos/presentation/widgets/pedido_card.dart';
import 'package:restaurant_app/features/pedidos/presentation/widgets/agregar_item_sheet.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:go_router/go_router.dart';

/// Página principal del módulo de Pedidos.
///
/// Muestra pedidos activos organizados por estado.
/// Permite crear pedidos, cambiar estados, y ver detalles.
class PedidosPage extends ConsumerStatefulWidget {
  const PedidosPage({super.key});

  @override
  ConsumerState<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends ConsumerState<PedidosPage> {
  EstadoPedido? _filtroEstado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pedidosProvider.notifier).loadPedidosActivos();
      ref.read(mesasProvider.notifier).loadMesas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pedidosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Pedidos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () {
              ref.read(pedidosProvider.notifier).loadPedidosActivos();
              ref.read(mesasProvider.notifier).loadMesas();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildTopBarContent(state),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(AppRouter.nuevoPedido);
          if (mounted) {
            ref.read(pedidosProvider.notifier).loadPedidosActivos();
            ref.read(mesasProvider.notifier).loadMesas();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo Pedido'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildFilterChip(EstadoPedido? estado, String label, int count) {
    final isSelected = _filtroEstado == estado;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        selected: isSelected,
        label: Text('$label ($count)'),
        onSelected: (_) {
          setState(() => _filtroEstado = estado);
        },
        selectedColor: estado != null
            ? _getColorByEstado(estado).withValues(alpha: 0.2)
            : AppColors.primary.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildTopBarContent(PedidosState state) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          children: [
            _buildFilterChip(null, 'Todos', state.totalPedidos),
            _buildFilterChip(EstadoPedido.creado, 'Nuevos', state.totalCreados),
            _buildFilterChip(
              EstadoPedido.enPreparacion,
              'En prep.',
              state.totalEnPreparacion,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(PedidosState state) {
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
              onPressed: () =>
                  ref.read(pedidosProvider.notifier).loadPedidosActivos(),
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

    // ── Sin pedidos ────────────────────────────────────────────
    if (state.pedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No hay pedidos activos',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Presiona "Nuevo Pedido" para crear uno',
              style: TextStyle(color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    // ── Lista de pedidos ───────────────────────────────────────
    final pedidosFiltrados = _filtroEstado == null
        ? state.pedidos
        : state.pedidos.where((p) => p.estado == _filtroEstado).toList();

    if (pedidosFiltrados.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(pedidosProvider.notifier).loadPedidosActivos(),
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
                'No hay pedidos con este filtro',
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

    return RefreshIndicator(
      onRefresh: () => ref.read(pedidosProvider.notifier).loadPedidosActivos(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: pedidosFiltrados.length,
        itemBuilder: (context, index) {
          final pedido = pedidosFiltrados[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PedidoCard(
              pedido: pedido,
              onTap: () => _showPedidoOptions(context, pedido),
            ),
          );
        },
      ),
    );
  }

  // ── Acciones ─────────────────────────────────────────────────

  Future<void> _agregarItem(BuildContext context, Pedido pedido) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AgregarItemSheet(
        pedidoId: pedido.id,
        restaurantId: pedido.restaurantId,
      ),
    );

    if (!mounted) return;
    // Reload to reflect any items added
    ref.read(pedidosProvider.notifier).loadPedidosActivos();
  }

  void _showPedidoOptions(BuildContext context, Pedido pedido) {
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
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pedido.mesaNombre ?? 'Pedido',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${pedido.cantidadItems} items · \$${pedido.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getColorByEstado(
                          pedido.estado,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pedido.estado.label,
                        style: TextStyle(
                          color: _getColorByEstado(pedido.estado),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // ── Items del pedido ────────────────────────────
              if (pedido.items.isNotEmpty)
                ...pedido.items.map(
                  (item) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.fastfood_rounded, size: 20),
                    title: Text(item.productoNombre ?? 'Producto'),
                    subtitle: item.observaciones != null
                        ? Text(
                            item.observaciones!,
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                    trailing: Text(
                      '${item.cantidad}x \$${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

              if (pedido.items.isNotEmpty) const Divider(),

              // ── Agregar producto ────────────────────────────
              if (pedido.puedeAgregarItems)
                ListTile(
                  leading: const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Agregar producto'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _agregarItem(context, pedido);
                  },
                ),

              // ── Cambiar estado (flujo secuencial) ──────────
              ..._getNextStates(pedido.estado).map(
                (estado) => ListTile(
                  leading: Icon(
                    _getIconByEstado(estado),
                    color: _getColorByEstado(estado),
                  ),
                  title: Text('Cambiar a: ${estado.label}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _cambiarEstado(pedido, estado);
                  },
                ),
              ),

              const Divider(),

              // ── Eliminar ────────────────────────────────────
              if (pedido.esEditable)
                ListTile(
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: AppColors.error,
                  ),
                  title: const Text('Eliminar pedido'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context, pedido);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(Pedido pedido, EstadoPedido nuevoEstado) async {
    final success = await ref
        .read(pedidosProvider.notifier)
        .cambiarEstado(pedido.id, nuevoEstado, pedido.restaurantId);

    if (!success) return;

    // Si se entrega, liberar la mesa
    if (nuevoEstado == EstadoPedido.entregado && pedido.mesaId != null) {
      await ref
          .read(mesasProvider.notifier)
          .cambiarEstado(pedido.mesaId!, EstadoMesa.libre, pedido.restaurantId);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pedido actualizado a ${nuevoEstado.label}')),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Pedido pedido) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar pedido'),
        content: const Text(
          '¿Estás seguro de eliminar este pedido y todos sus items?',
        ),
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
      final success = await ref
          .read(pedidosProvider.notifier)
          .eliminarPedido(pedido.id, pedido.restaurantId);

      if (!success) return;

      // Liberar mesa
      if (pedido.mesaId != null) {
        await ref
            .read(mesasProvider.notifier)
            .cambiarEstado(
              pedido.mesaId!,
              EstadoMesa.libre,
              pedido.restaurantId,
            );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pedido eliminado')));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────

  /// Retorna los estados siguientes lógicos para un pedido.
  List<EstadoPedido> _getNextStates(EstadoPedido current) {
    switch (current) {
      case EstadoPedido.pendienteAprobacion:
        return [EstadoPedido.creado];
      case EstadoPedido.creado:
        return [EstadoPedido.aceptado];
      case EstadoPedido.aceptado:
        return [EstadoPedido.enPreparacion];
      case EstadoPedido.enPreparacion:
        return [EstadoPedido.finalizado];
      case EstadoPedido.finalizado:
        // Solo Caja puede pasar a "entregado" al cobrar
        return [];
      case EstadoPedido.entregado:
        return [];
    }
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
        return AppColors.pedidoEntregado;
    }
  }

  IconData _getIconByEstado(EstadoPedido estado) {
    switch (estado) {
      case EstadoPedido.pendienteAprobacion:
        return Icons.pending_actions_rounded;
      case EstadoPedido.creado:
        return Icons.fiber_new_rounded;
      case EstadoPedido.aceptado:
        return Icons.check_circle_outline;
      case EstadoPedido.enPreparacion:
        return Icons.restaurant_rounded;
      case EstadoPedido.finalizado:
        return Icons.done_all_rounded;
      case EstadoPedido.entregado:
        return Icons.delivery_dining_rounded;
    }
  }
}
