import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/categoria_form_dialog.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/producto_card.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/producto_form_dialog.dart';

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
    });
  }

  void _syncTabController(int categoriaCount) {
    // Incluye pestaña "Todos" al inicio
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

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(menuProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _syncTabController(state.categorias.length);

    return Scaffold(
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
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
}
