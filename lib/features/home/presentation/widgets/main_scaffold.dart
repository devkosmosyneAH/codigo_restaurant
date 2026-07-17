import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurant_app/features/pedidos/presentation/providers/pedidos_provider.dart';
import 'package:restaurant_app/features/pedidos/presentation/widgets/aprobar_pedidos_sheet.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  Timer? _pollingTimer;

  static const _allNavItems = [
    _NavItem(
      icon: Icons.dashboard_rounded,
      label: 'Inicio',
      path: AppRouter.home,
    ),
    _NavItem(
      icon: Icons.table_restaurant_rounded,
      label: 'Mesas',
      path: AppRouter.mesas,
    ),
    _NavItem(
      icon: Icons.receipt_long_rounded,
      label: 'Pedidos',
      path: AppRouter.pedidos,
    ),
    _NavItem(
      icon: Icons.soup_kitchen_rounded,
      label: 'Cocina',
      path: AppRouter.cocina,
    ),
    _NavItem(
      icon: Icons.restaurant_menu_rounded,
      label: 'Menú',
      path: AppRouter.menu,
    ),
    _NavItem(
      icon: Icons.calendar_month_rounded,
      label: 'Reservas',
      path: AppRouter.reservas,
    ),
    _NavItem(
      icon: Icons.request_quote_rounded,
      label: 'Cotizaciones',
      path: AppRouter.cotizaciones,
    ),
    _NavItem(
      icon: Icons.point_of_sale_rounded,
      label: 'Caja',
      path: AppRouter.caja,
    ),
    _NavItem(
      icon: Icons.people_rounded,
      label: 'Clientes',
      path: AppRouter.clientes,
    ),
    _NavItem(
      icon: Icons.analytics_rounded,
      label: 'Reportes',
      path: AppRouter.reportes,
    ),
    _NavItem(
      icon: Icons.manage_accounts_rounded,
      label: 'Usuarios',
      path: AppRouter.usuarios,
    ),
    _NavItem(
      icon: Icons.sync_rounded,
      label: 'Sincronización',
      path: AppRouter.sincronizacion,
    ),
    _NavItem(
      icon: Icons.language_rounded,
      label: 'Página pública',
      path: AppRouter.restauranteConfig,
    ),
    _NavItem(
      icon: Icons.backup_rounded,
      label: 'Respaldos',
      path: AppRouter.driveBackup,
    ),
  ];

  List<_NavItem> _itemsForRole(RolUsuario rol) => _allNavItems
      .where((item) => AppRouter.isRouteAllowedForRole(rol, item.path))
      .toList();

  bool _matchesPath(String currentPath, String itemPath) {
    if (currentPath == itemPath) return true;
    if (itemPath == '/') return currentPath == '/';
    return currentPath.startsWith('$itemPath/');
  }

  int _getSelectedIndex(BuildContext context, List<_NavItem> items) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < items.length; i++) {
      if (_matchesPath(location, items[i].path)) return i;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pedidosProvider.notifier).loadPedidosActivos();
      _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) ref.read(pedidosProvider.notifier).loadPedidosActivos();
      });
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = sl<AuthChangeNotifier>();
    final usuario = auth.usuario;
    final rol = usuario?.rol ?? RolUsuario.mesero;
    final navItems = _itemsForRole(rol);

    final pendientesCount = ref.watch(
      pedidosProvider.select((s) => s.totalPendientesAprobacion),
    );
    final puedeAprobarPedidos = rol == RolUsuario.mesero || rol.esAdmin;

    if (navItems.isEmpty) {
      return Scaffold(body: SafeArea(child: widget.child));
    }

    final selectedIndex = _getSelectedIndex(context, navItems);
    final currentPath = GoRouterState.of(context).uri.path;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isMobile = screenWidth < 640;
    final isWideScreen = screenWidth >= 1000;
    final smallHeight = MediaQuery.of(context).size.height < 700;

    if (isMobile) {
      // ... (mantengo tu navegación móvil sin cambios)
      final quickNavItems = navItems.take(4).toList();
      final showMoreMenu = navItems.length > quickNavItems.length;
      final quickSelectedIndex = quickNavItems.indexWhere(
        (item) => _matchesPath(currentPath, item.path),
      );
      final mobileSelectedIndex = quickSelectedIndex >= 0
          ? quickSelectedIndex
          : (showMoreMenu ? quickNavItems.length : 0);

      return Scaffold(
        body: SafeArea(child: widget.child),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primary.withValues(alpha: 0.14),
          selectedIndex: mobileSelectedIndex,
          height: textScale > 1.15 ? 80 : 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            if (showMoreMenu && index == quickNavItems.length) {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (sheetContext) {
                  return SafeArea(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.sizeOf(sheetContext).height * 0.75,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final item in navItems)
                            ListTile(
                              leading: Icon(
                                item.icon,
                                color: _matchesPath(currentPath, item.path)
                                    ? AppColors.primary
                                    : null,
                              ),
                              title: Text(item.label),
                              selected: _matchesPath(currentPath, item.path),
                              selectedTileColor: AppColors.primary.withValues(
                                alpha: 0.08,
                              ),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                context.go(item.path);
                              },
                            ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.logout_rounded),
                            iconColor: AppColors.secondary,
                            title: const Text('Cerrar sesión'),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              await auth.logout();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
              return;
            }
            context.go(quickNavItems[index].path);
          },
          destinations: [
            ...quickNavItems.map(
              (item) => NavigationDestination(
                icon:
                    item.path == AppRouter.pedidos &&
                        puedeAprobarPedidos &&
                        pendientesCount > 0
                    ? Badge(
                        label: Text('$pendientesCount'),
                        backgroundColor: Colors.orange,
                        child: Icon(item.icon),
                      )
                    : Icon(item.icon),
                selectedIcon: Icon(item.icon, color: AppColors.primary),
                label: item.label,
              ),
            ),
            if (showMoreMenu)
              const NavigationDestination(
                icon: Icon(Icons.menu_rounded),
                label: 'Más',
              ),
          ],
        ),
      );
    }

    // ==================== VERSIÓN DESKTOP / TABLET CON SCROLL ====================
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Barra lateral personalizada con scroll
            Container(
              width: isWideScreen ? 200 : 76,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Colors.black12, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // Leading (Logo + Info usuario) - fijo arriba
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: smallHeight ? 8 : 16,
                      horizontal: isWideScreen ? 16 : 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isWideScreen ? 84 : 48,
                          height: isWideScreen ? 84 : 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/logo_la_pena.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.restaurant_rounded,
                                color: AppColors.primary,
                                size: isWideScreen ? 40 : 28,
                              ),
                            ),
                          ),
                        ),
                        if (isWideScreen) ...[
                          const SizedBox(height: 8),
                          Text(
                            'La Peña',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Bar & House',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          if (usuario != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              usuario.nombre,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              usuario.rol.label,
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Destinos con Scroll
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: navItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final isSelected = index == selectedIndex;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Material(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => context.go(item.path),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWideScreen ? 16 : 0,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: isWideScreen
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        item.icon,
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.black87,
                                        size: isWideScreen ? 26 : 24,
                                      ),
                                      if (isWideScreen) ...[
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            item.label,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : Colors.black87,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      // Badge para pedidos
                                      if (item.path == AppRouter.pedidos &&
                                          puedeAprobarPedidos &&
                                          pendientesCount > 0)
                                        Badge(
                                          label: Text('$pendientesCount'),
                                          backgroundColor: Colors.orange,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Trailing (botones inferiores)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (puedeAprobarPedidos && pendientesCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: IconButton(
                              icon: Badge(
                                label: Text('$pendientesCount'),
                                backgroundColor: Colors.orange,
                                child: const Icon(
                                  Icons.pending_actions_rounded,
                                ),
                              ),
                              color: Colors.orange,
                              tooltip: 'Pedidos por aprobar',
                              onPressed: () =>
                                  AprobarPedidosSheet.show(context),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded),
                          tooltip: 'Cerrar sesión',
                          color: AppColors.secondary,
                          onPressed: () async => await auth.logout(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;

  const _NavItem({required this.icon, required this.label, required this.path});
}
