import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizacion_cart_provider.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/widgets/cotizacion_sheet.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/public_producto_card.dart';
import 'package:restaurant_app/features/mesas/presentation/providers/llamados_provider.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/public_config_provider.dart';

/// Menu publico accesible por QR.
///
/// Solo muestra categorias, productos disponibles e imagenes.
class MenuPublicPage extends ConsumerStatefulWidget {
  final String? mesaId;

  const MenuPublicPage({super.key, this.mesaId});

  @override
  ConsumerState<MenuPublicPage> createState() => _MenuPublicPageState();
}

class _MenuPublicPageState extends ConsumerState<MenuPublicPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _tabCount = 0;
  bool _menuLoadRequested = false;

  @override
  void initState() {
    super.initState();
  }

  void _requestMenuLoadIfNeeded({required bool canLoadMenu}) {
    if (!canLoadMenu || _menuLoadRequested) return;
    _menuLoadRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(menuProvider.notifier).loadMenu();
    });
  }

  void _resetTabs() {
    _tabController?.dispose();
    _tabController = null;
    _tabCount = 0;
  }

  void _syncTabController(int categoriaCount) {
    final totalTabs = categoriaCount + 1;
    if (_tabController == null || _tabCount != totalTabs) {
      _tabController?.dispose();
      _tabController = TabController(length: totalTabs, vsync: this);
      _tabCount = totalTabs;
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          final notifier = ref.read(menuProvider.notifier);
          final state = ref.read(menuProvider);
          if (_tabController!.index == 0) {
            notifier.seleccionarCategoria(null);
          } else {
            final cat = state.categorias[_tabController!.index - 1];
            notifier.seleccionarCategoria(cat.id);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Widget _buildLeadingButton(BuildContext context) {
    return IconButton(
      tooltip: 'Regresar',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.maybePop();
          return;
        }
        context.go(AppRouter.restaurantePublico);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(menuProvider);
    final publicConfigState = ref.watch(publicConfigProvider);
    final hasResolvedPublicConfig =
        !publicConfigState.isLoading || publicConfigState.hasConfig;
    final isMenuEnabled = publicConfigState.config?.mostrarBotonMenu ?? true;
    final canLoadMenu = hasResolvedPublicConfig && isMenuEnabled;

    _requestMenuLoadIfNeeded(canLoadMenu: canLoadMenu);

    if (isMenuEnabled) {
      _syncTabController(state.categorias.length);
    } else {
      _resetTabs();
    }

    final cart = ref.watch(cotizacionCartProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F6B76),
        foregroundColor: Colors.white,
        leading: _buildLeadingButton(context),
        title: _buildHeaderTitle(context),
        actions: [
          if (isMenuEnabled)
            IconButton(
              tooltip: 'Cotizar',
              onPressed: () =>
                  CotizacionSheet.show(context, mesaId: widget.mesaId),
              icon: _CartActionIcon(totalItems: cart.totalItems),
            ),
          IconButton(
            tooltip: 'Fechas disponibles',
            onPressed: () => context.go(AppRouter.reservasPublico),
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          if (widget.mesaId != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Chip(
                  avatar: const Icon(Icons.table_restaurant_rounded, size: 16),
                  label: Text(widget.mesaId!),
                ),
              ),
            ),
        ],
        bottom: _tabController == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Container(
                  color: const Color(0xFF0B5A63),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    dividerColor: Colors.transparent,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      const Tab(text: 'Todos'),
                      ...state.categorias.map((c) => Tab(text: c.nombre)),
                    ],
                  ),
                ),
              ),
      ),
      body: !hasResolvedPublicConfig
          ? const Center(child: CircularProgressIndicator())
          : !isMenuEnabled
          ? _buildMenuDisabledBody(context)
          : state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, state),
      bottomNavigationBar: isMenuEnabled ? _buildBottomBar(context) : null,
      floatingActionButton: isMenuEnabled && cart.totalItems > 0
          ? _buildCartFab(context, totalItems: cart.totalItems)
          : null,
    );
  }

  Widget _buildMenuDisabledBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'El menú público no está disponible en este momento.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta nuevamente más tarde o visita la página principal del restaurante.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.go(AppRouter.restaurantePublico),
              icon: const Icon(Icons.storefront_rounded),
              label: const Text('Ir a la página pública'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MenuState state) {
    if (state.errorMessage != null) {
      return Center(
        child: Text(
          state.errorMessage!,
          style: const TextStyle(color: AppColors.error),
        ),
      );
    }

    final productos = state.categoriaSeleccionadaId == null
        ? state.productosDisponibles
        : state.productosDisponibles
              .where((p) => p.categoriaId == state.categoriaSeleccionadaId)
              .toList();

    final cart = ref.watch(cotizacionCartProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _MenuReveal(child: _buildHeroCard(context)),
        const SizedBox(height: 10),
        _MenuReveal(
          delay: const Duration(milliseconds: 70),
          child: _buildPromoBanner(context),
        ),
        const SizedBox(height: 14),
        _MenuReveal(
          delay: const Duration(milliseconds: 100),
          child: Row(
            children: [
              Text(
                'Menu',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE7DDD0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    '${productos.length} items',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (productos.isEmpty)
          Text(
            'No hay productos disponibles',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (productos.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final maxExtent = width < 520
                  ? 210.0
                  : width < 900
                  ? 250.0
                  : 285.0;
              final aspect = width < 520 ? 0.71 : 0.75;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.025),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: GridView.builder(
                  key: ValueKey(state.categoriaSeleccionadaId ?? 'all'),
                  itemCount: productos.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxExtent,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: aspect,
                  ),
                  itemBuilder: (_, i) {
                    final producto = productos[i];
                    final count = cart.items
                        .where((it) => it.producto.id == producto.id)
                        .fold(0, (sum, it) => sum + it.cantidad);
                    return PublicProductoCard(
                      producto: producto,
                      cantidad: count,
                      onOpenOptions: () =>
                          _openProductoOptions(context, producto),
                      onAdd: () => ref
                          .read(cotizacionCartProvider.notifier)
                          .addProducto(producto),
                      onIncrement: () => ref
                          .read(cotizacionCartProvider.notifier)
                          .incrementProducto(producto),
                      onDecrement: () => ref
                          .read(cotizacionCartProvider.notifier)
                          .decrementProducto(producto.id),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildHeaderTitle(BuildContext context) {
    final config = ref.watch(publicConfigProvider);
    final nombreNegocio =
        (config.hasConfig && config.config!.nombreNegocio.isNotEmpty)
        ? config.config!.nombreNegocio
        : AppConstants.appFullName;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/logo_la_pena.jpg',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.restaurant_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nombreNegocio,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Menu digital',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F6B76), Color(0xFF0B5A63), Color(0xFF174C51)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0B5A63),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/logo_la_pena.jpg',
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.restaurant_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido a ${AppConstants.appName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Explora nuestros platos y arma tu cotizacion en un minuto.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E1D7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFFD18B2C),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Promociones del dia: pregunta por combos y bebidas.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final canCall = widget.mesaId != null;
    final cart = ref.watch(cotizacionCartProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () =>
                  CotizacionSheet.show(context, mesaId: widget.mesaId),
              icon: const Icon(Icons.shopping_cart_checkout_rounded),
              label: Text(
                cart.totalItems > 0
                    ? 'Resumen (${cart.totalItems})'
                    : 'Resumen del pedido',
              ),
            ),
          ),
          if (canCall) ...[
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _callWaiter,
                icon: const Icon(Icons.campaign_rounded),
                label: const Text('Llamar mesero'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartFab(BuildContext context, {required int totalItems}) {
    return FloatingActionButton.extended(
      onPressed: () => CotizacionSheet.show(context, mesaId: widget.mesaId),
      icon: const Icon(Icons.shopping_cart_rounded),
      label: Text('🛒 $totalItems productos'),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    );
  }

  Future<void> _openProductoOptions(
    BuildContext context,
    Producto producto,
  ) async {
    final variantesActivas = producto.variantes.where((v) => v.activo).toList();
    if (variantesActivas.isEmpty) {
      ref.read(cotizacionCartProvider.notifier).addProducto(producto);
      return;
    }

    final seleccionada = await showModalBottomSheet<Variante>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (producto.descripcion != null &&
                    producto.descripcion!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    producto.descripcion!,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Elige una opcion para agregarla al pedido.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                ...variantesActivas.map(
                  (variante) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE6DDCF)),
                    ),
                    child: ListTile(
                      title: Text(
                        variante.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${AppConstants.currencySymbol}${variante.precio.toStringAsFixed(2)}',
                      ),
                      trailing: FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(variante),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (seleccionada == null) return;
    ref
        .read(cotizacionCartProvider.notifier)
        .addProducto(
          producto,
          variante: seleccionada,
          precioUnitario: seleccionada.precio,
        );
  }

  Future<void> _callWaiter() async {
    final mesaId = widget.mesaId;
    if (mesaId == null) return;

    final ok = await ref
        .read(llamadosProvider.notifier)
        .crearLlamado(
          restaurantId: sl<TenantContext>().restaurantId,
          mesaId: mesaId,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Mesero solicitado. En breve se acercara.'
              : 'No se pudo enviar el llamado',
        ),
      ),
    );
  }
}

class _CartActionIcon extends StatelessWidget {
  const _CartActionIcon({required this.totalItems});

  final int totalItems;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(totalItems),
      tween: Tween(begin: totalItems > 0 ? 0.88 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: totalItems > 0
          ? Badge(
              label: Text('$totalItems'),
              child: const Icon(Icons.request_quote_outlined),
            )
          : const Icon(Icons.request_quote_outlined),
    );
  }
}

class _MenuReveal extends StatelessWidget {
  const _MenuReveal({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    const duration = Duration(milliseconds: 300);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        final totalMs = (duration + delay).inMilliseconds;
        final delayFraction = totalMs <= 0
            ? 0.0
            : delay.inMilliseconds / totalMs;
        final progress = delayFraction >= 1
            ? 1.0
            : ((value - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - eased)),
            child: child,
          ),
        );
      },
    );
  }
}
