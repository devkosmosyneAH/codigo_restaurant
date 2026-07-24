import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/config/app_environment.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/menu/data/services/drive_image_sync_queue_service.dart';
import 'package:restaurant_app/features/menu/data/services/drive_menu_connection_service.dart';
import 'package:restaurant_app/features/menu/presentation/providers/drive_connection_provider.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/categoria_form_dialog.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/menu_sync_diagnostics_dialog.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/drive_help_dialog.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/producto_card.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/producto_form_dialog.dart';
import 'package:restaurant_app/widgets/skeleton_loader.dart';

/// Página principal del Menú.
///
/// Muestra categorías como pestañas (TabBar) y los productos de cada categoría
/// en un grid con opciones de CRUD y toggle de disponibilidad.
class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({super.key});

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _tabCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(menuProvider.notifier).loadMenu();
      // Verificar sesión Drive silenciosamente al entrar al panel de menú.
      // Si no hay sesión previa, mostrará el banner de "Conectar Drive".
      if (AppEnvironment.isDriveConfigured) {
        ref.read(driveConnectionProvider.notifier).checkSilently();
      }
    });
  }

  void _syncTabController(int categoriaCount) {
    // Incluye pestaña "Todos" al inicio
    final totalTabs = categoriaCount + 1;
    if (_tabController == null || _tabCount != totalTabs) {
      _tabController?.dispose();
      _tabController = TabController(
        length: totalTabs,
        vsync: this,
        initialIndex: 0,
      );
      _tabCount = totalTabs;
      _tabController!.addListener(() {
        if (_tabController == null || _tabController!.indexIsChanging) {
          return;
        }

        final notifier = ref.read(menuProvider.notifier);
        final state = ref.read(menuProvider);
        final tabIndex = _tabController!.index;

        if (tabIndex <= 0) {
          notifier.seleccionarCategoria(null);
          return;
        }

        final categoryIndex = tabIndex - 1;
        if (categoryIndex >= state.categorias.length) {
          notifier.seleccionarCategoria(null);
          return;
        }

        final cat = state.categorias[categoryIndex];
        notifier.seleccionarCategoria(cat.id);
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // ── Acciones de Categoría ──────────────────────────────────────

  Future<void> _crearCategoria() async {
    final cat = await CategoriaFormDialog.show(context);
    if (cat == null || !mounted) return;
    final ok = await ref.read(menuProvider.notifier).crearCategoria(cat);
    if (!ok && mounted) {
      _showError(ref.read(menuProvider).errorMessage);
    }
  }

  Future<void> _editarCategoria(int categoriaIndex) async {
    final state = ref.read(menuProvider);
    if (categoriaIndex >= state.categorias.length) return;
    final cat = state.categorias[categoriaIndex];
    final updated = await CategoriaFormDialog.show(context, categoria: cat);
    if (updated == null || !mounted) return;
    final ok = await ref
        .read(menuProvider.notifier)
        .actualizarCategoria(updated);
    if (!ok && mounted) {
      _showError(ref.read(menuProvider).errorMessage);
    }
  }

  Future<void> _eliminarCategoria(int categoriaIndex) async {
    final state = ref.read(menuProvider);
    if (categoriaIndex >= state.categorias.length) return;
    final cat = state.categorias[categoriaIndex];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text(
          '¿Eliminar "${cat.nombre}"? Los productos de esta categoría quedarán sin categoría.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await ref.read(menuProvider.notifier).eliminarCategoria(cat.id);
    if (!ok && mounted) {
      _showError(ref.read(menuProvider).errorMessage);
    }
  }

  // ── Acciones de Producto ───────────────────────────────────────

  Future<void> _crearProducto() async {
    final state = ref.read(menuProvider);
    if (state.categorias.isEmpty) {
      _showSnackbar('Crea al menos una categoría primero.');
      return;
    }
    final producto = await ProductoFormDialog.show(
      context,
      categorias: state.categorias,
    );
    if (producto == null || !mounted) return;
    final ok = await ref.read(menuProvider.notifier).crearProducto(producto);
    if (!ok && mounted) {
      _showError(ref.read(menuProvider).errorMessage);
    }
  }

  Future<void> _editarProducto(String productoId) async {
    final state = ref.read(menuProvider);
    final producto = state.productos
        .where((p) => p.id == productoId)
        .firstOrNull;
    if (producto == null) return;
    final updated = await ProductoFormDialog.show(
      context,
      producto: producto,
      categorias: state.categorias,
    );
    if (updated == null || !mounted) return;
    final ok = await ref
        .read(menuProvider.notifier)
        .actualizarProducto(updated);
    if (!ok && mounted) {
      _showError(ref.read(menuProvider).errorMessage);
    }
  }

  Future<void> _eliminarProducto(String productoId, String nombre) async {
    final producto = ref
        .read(menuProvider)
        .productos
        .where((p) => p.id == productoId)
        .firstOrNull;
    final driveFileId = producto?.driveFileId;
    final restaurantId = producto?.restaurantId ?? sl<TenantContext>().restaurantId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Eliminar "$nombre" del menú?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    if (driveFileId != null && driveFileId.isNotEmpty) {
      try {
        final driveService = sl<DriveMenuConnectionService>();
        final driveQueue = sl<DriveImageSyncQueueService>();
        final signedIn = await driveService.signIn();

        var deleted = false;
        if (signedIn) {
          deleted = await driveService.tryDeleteProductImage(driveFileId);
        }

        if (!deleted) {
          await driveQueue.enqueueDeleteImage(
            restaurantId: restaurantId,
            fileId: driveFileId,
          );
          await driveQueue.processPendingOperations();
        }
      } catch (error, stackTrace) {
        debugPrint('ERROR EN DELETE PRODUCTO DRIVE');
        debugPrint(error.toString());
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final ok = await ref
        .read(menuProvider.notifier)
        .eliminarProducto(productoId);
    if (!ok && mounted) {
      _showError(ref.read(menuProvider).errorMessage);
    }
  }

  // ── Helpers de UI ──────────────────────────────────────────────

  void _showError(String? msg) {
    if (msg == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openPublicPreview() {
    context.push(AppRouter.menuPublico);
  }

  Future<void> _openSyncDiagnostics() {
    return MenuSyncDiagnosticsDialog.show(context);
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(menuProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _syncTabController(state.categorias.length);

    return Scaffold(
      body: state.isLoading
          ? const SkeletonListPlaceholder()
          : Column(
              children: [
                // ── Header ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  color: colorScheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Menú',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${state.totalProductos} productos · '
                                  '${state.totalCategorias} categorías',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _openPublicPreview,
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                              ),
                              label: const Text('Vista cliente'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _openSyncDiagnostics,
                              icon: const Icon(
                                Icons.health_and_safety_outlined,
                                size: 18,
                              ),
                              label: const Text('Diagnóstico'),
                            ),
                            const SizedBox(width: 8),
                            // Botón nueva categoría
                            OutlinedButton.icon(
                              onPressed: _crearCategoria,
                              icon: const Icon(
                                Icons.create_new_folder_outlined,
                                size: 18,
                              ),
                              label: const Text('Categoría'),
                            ),
                            const SizedBox(width: 8),
                            // Botón nuevo producto
                            FilledButton.icon(
                              onPressed: _crearProducto,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Producto'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Banner de estado Drive ──────────────────────────
                if (AppEnvironment.isDriveConfigured)
                  _buildDriveBanner(context, ref),

                // ── TabBar ─────────────────────────────────────────
                if (_tabController != null)
                  ColoredBox(
                    color: colorScheme.surface,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        const Tab(text: 'Todos'),
                        ...state.categorias.map(
                          (cat) => Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(cat.nombre),
                                const SizedBox(width: 4),
                                // Menú contextual de la categoría
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTapDown: (details) {
                                    final idx = state.categorias.indexOf(cat);
                                    _showCategoriaMenu(
                                      context,
                                      details.globalPosition,
                                      idx,
                                    );
                                  },
                                  child: Icon(
                                    Icons.more_vert,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Grid de productos ──────────────────────────────
                Expanded(
                  child: _tabController == null
                      ? const SizedBox.shrink()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // Pestaña "Todos"
                            _buildProductGrid(state.productos, state),
                            // Una pestaña por categoría
                            ...state.categorias.map(
                              (cat) => _buildProductGrid(
                                state.productos
                                    .where((p) => p.categoriaId == cat.id)
                                    .toList(),
                                state,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearProducto,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
        tooltip: 'Agregar producto al menú',
      ),
    );
  }

  Widget _buildProductGrid(List<dynamic> productos, MenuState state) {
    if (productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fastfood_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay productos en esta categoría',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _crearProducto,
              icon: const Icon(Icons.add),
              label: const Text('Agregar producto'),
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
          final maxExtent = width < 520
              ? 220.0
              : width < 900
              ? 260.0
              : 290.0;
          final aspect = width < 520 ? 0.78 : 0.84;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxExtent,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: aspect,
            ),
            itemCount: productos.length,
            itemBuilder: (_, i) {
              if (i < 0 || i >= productos.length) {
                return const SizedBox.shrink();
              }

              final p = productos[i];
              final catNombre = state.categorias
                  .where((c) => c.id == p.categoriaId)
                  .map((c) => c.nombre)
                  .firstOrNull;
              return ProductoCard(
                producto: p,
                categoriaNombre: catNombre,
                onEdit: () => _editarProducto(p.id),
                onDelete: () => _eliminarProducto(p.id, p.nombre),
              );
            },
          );
        },
      ),
    );
  }

  void _showCategoriaMenu(
    BuildContext context,
    Offset position,
    int categoriaIndex,
  ) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Eliminar', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((val) {
      if (val == 'edit') _editarCategoria(categoriaIndex);
      if (val == 'delete') _eliminarCategoria(categoriaIndex);
    });
  }
  // ── Banner de Drive ────────────────────────────────────────────

  Widget _buildDriveBanner(BuildContext context, WidgetRef ref) {
    final drive = ref.watch(driveConnectionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (drive.isConnected) {
      return Container(
        width: double.infinity,
        color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.cloud_done_outlined,
              size: 16,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Google Drive conectado${drive.email != null ? ' · ${drive.email}' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (drive.isChecking || drive.isUnknown) {
      return Container(
        width: double.infinity,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Verificando conexión Google Drive...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Desconectado o error.
    final isPopupBlocked =
        drive.isPopupBlocked &&
        drive.status == DriveConnectionStatus.disconnected;
    return Container(
      width: double.infinity,
      color: colorScheme.errorContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isPopupBlocked
                  ? 'Google Drive: popup bloqueado. Permite popups en este navegador y vuelve a intentarlo.'
                  : (drive.error != null
                        ? 'Drive no conectado: ${drive.error}'
                        : 'Google Drive no conectado. Las fotos de productos no se subirán.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              foregroundColor: colorScheme.onErrorContainer,
            ),
            onPressed: () => _connectDriveFromBanner(ref),
            child: const Text('Conectar', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              foregroundColor: colorScheme.onErrorContainer,
            ),
            onPressed: () => DriveHelpDialog.show(context, ref),
            child: const Text('Ayuda', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _connectDriveFromBanner(WidgetRef ref) async {
    final connected = await ref
        .read(driveConnectionProvider.notifier)
        .connectInteractively();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? 'Google Drive conectado correctamente.'
                : 'No se pudo conectar Google Drive. Verifica los permisos.',
          ),
          backgroundColor: connected
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
