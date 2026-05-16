import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/cocina/presentation/providers/cocina_provider.dart';
import 'package:restaurant_app/features/cocina/presentation/widgets/cocina_ticket_card.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/public_config_provider.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';

/// Pantalla de Cocina.
///
/// Lista plana de todos los pedidos activos.
/// Por cada pedido: dos acciones - Listo y Rechazar.
/// Auto-refresh cada 30 segundos.
class CocinaPage extends ConsumerStatefulWidget {
  const CocinaPage({super.key});

  @override
  ConsumerState<CocinaPage> createState() => _CocinaPageState();
}

class _CocinaPageState extends ConsumerState<CocinaPage> {
  late CocinaNotifier _notifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifier = ref.read(cocinaProvider.notifier);
      final cfg = ref.read(publicConfigProvider).config;
      if (cfg != null) {
        _notifier.setAutoMode(
          enabled: cfg.cocinaModoAutomatico,
          minutes: cfg.cocinaTiempoAutoMinutos,
        );
      }
      _notifier.start();
    });
  }

  @override
  void dispose() {
    _notifier.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cocinaProvider);
    final config = ref.watch(publicConfigProvider.select((s) => s.config));
    final autoMode = config?.cocinaModoAutomatico ?? false;
    final autoMinutes = config?.cocinaTiempoAutoMinutos ?? 15;

    ref.listen(publicConfigProvider.select((s) => s.config), (prev, next) {
      if (next == null) return;
      ref
          .read(cocinaProvider.notifier)
          .setAutoMode(
            enabled: next.cocinaModoAutomatico,
            minutes: next.cocinaTiempoAutoMinutos,
          );
    });

    return Scaffold(
      appBar: _buildAppBar(state),
      body: Column(
        children: [
          if (autoMode) _buildAutoBanner(autoMinutes),
          Expanded(child: _buildBody(state, autoMode: autoMode)),
        ],
      ),
    );
  }

  Widget _buildAutoBanner(int minutes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(
            Icons.auto_mode_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cocina en modo automático · Avance cada $minutes min',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- AppBar --

  PreferredSizeWidget _buildAppBar(CocinaState state) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 430;
    return AppBar(
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.soup_kitchen_rounded, color: cs.onPrimary, size: 24),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              isCompact ? 'COCINA' : 'PANTALLA DE COCINA',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: isCompact ? 1.1 : 1.5,
                fontSize: isCompact ? 16 : 18,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (!state.isLoading)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.onPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${state.totalPedidos} pedido${state.totalPedidos != 1 ? "s" : ""}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        if (state.lastRefresh != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                _formatHoraMin(state.lastRefresh!),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        IconButton(
          icon: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Actualizar',
          onPressed: state.isLoading
              ? null
              : () => ref.read(cocinaProvider.notifier).refresh(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // -- Body --

  Widget _buildBody(CocinaState state, {required bool autoMode}) {
    if (state.errorMessage != null) {
      return _buildError(state.errorMessage!);
    }

    if (state.isLoading && state.totalPedidos == 0) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.totalPedidos == 0) {
      return _buildEmpty();
    }

    final notifier = ref.read(cocinaProvider.notifier);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.pedidos.length,
      itemBuilder: (context, index) {
        final pedido = state.pedidos[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CocinaTicketCard(
            pedido: pedido,
            onListo: autoMode ? null : () => notifier.marcarListo(pedido),
            onRechazar: autoMode
                ? null
                : () => _confirmarRechazo(pedido, notifier),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.soup_kitchen_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'La cocina esta tranquila',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay pedidos activos en este momento',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(cocinaProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarRechazo(Pedido pedido, CocinaNotifier notifier) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar pedido'),
        content: const Text(
          'Seguro que quieres rechazar este pedido? Se eliminara del sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      notifier.rechazarPedido(pedido);
    }
  }

  String _formatHoraMin(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
