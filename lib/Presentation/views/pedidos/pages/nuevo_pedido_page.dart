import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';
import 'package:restaurant_app/features/mesas/presentation/providers/mesas_provider.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';
import 'package:restaurant_app/features/pedidos/presentation/providers/pedidos_provider.dart';

// ── Carrito en memoria ─────────────────────────────────────────────────────────

class _CartItem {
  final String tempId;
  final Producto producto;
  final Variante? variante;
  int cantidad;
  String? nota;

  _CartItem({
    required this.tempId,
    required this.producto,
    this.variante,
    this.cantidad = 1,
    this.nota,
  });

  double get subtotal => (variante?.precio ?? producto.precio) * cantidad;

  String get nombre => variante != null
      ? '${producto.nombre} (${variante!.nombre})'
      : producto.nombre;
}

// ── Página principal ───────────────────────────────────────────────────────────

/// Pantalla completa para tomar un nuevo pedido.
///
/// Combina la selección de mesa y la navegación del menú en una
/// sola vista. El mesero arma el pedido completo antes de confirmar.
class NuevoPedidoPage extends ConsumerStatefulWidget {
  const NuevoPedidoPage({super.key});

  @override
  ConsumerState<NuevoPedidoPage> createState() => _NuevoPedidoPageState();
}

class _NuevoPedidoPageState extends ConsumerState<NuevoPedidoPage>
    with TickerProviderStateMixin {
  static const _uuid = Uuid();

  Mesa? _mesaSeleccionada;
  final List<_CartItem> _carrito = [];
  bool _guardando = false;

  TabController? _tabController;
  int _tabCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(menuProvider.notifier).loadMenu();
      ref.read(mesasProvider.notifier).loadMesas();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // ── Carrito ────────────────────────────────────────────────────────────────

  double get _total => _carrito.fold(0.0, (sum, item) => sum + item.subtotal);

  int get _totalItems => _carrito.fold(0, (sum, item) => sum + item.cantidad);

  void _agregarAlCarrito(
    Producto producto,
    Variante? variante,
    int cantidad,
    String? nota,
  ) {
    setState(() {
      // Si ya existe el mismo producto+variante+nota, sumar cantidad
      final idx = _carrito.indexWhere(
        (c) =>
            c.producto.id == producto.id &&
            c.variante?.id == variante?.id &&
            c.nota == nota,
      );
      if (idx != -1) {
        _carrito[idx].cantidad += cantidad;
      } else {
        _carrito.add(
          _CartItem(
            tempId: _uuid.v4(),
            producto: producto,
            variante: variante,
            cantidad: cantidad,
            nota: nota,
          ),
        );
      }
    });
  }

  void _cambiarCantidad(String tempId, int delta) {
    setState(() {
      final idx = _carrito.indexWhere((c) => c.tempId == tempId);
      if (idx == -1) return;
      final nuevaCantidad = _carrito[idx].cantidad + delta;
      if (nuevaCantidad <= 0) {
        _carrito.removeAt(idx);
      } else {
        _carrito[idx].cantidad = nuevaCantidad;
      }
    });
  }

  void _quitarDelCarrito(String tempId) {
    setState(() => _carrito.removeWhere((c) => c.tempId == tempId));
  }

  // ── Tabs ───────────────────────────────────────────────────────────────────

  void _syncTabs(List<Categoria> categorias) {
    final total = categorias.length + 1; // "Todos" + categorías
    if (_tabController == null || _tabCount != total) {
      final oldController = _tabController;
      // Assign new controller before this build completes so widgets see it
      _tabController = TabController(length: total, vsync: this);
      _tabCount = total;
      // Dispose old controller safely after the frame
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => oldController?.dispose(),
      );
    }
  }

  // ── Confirmar pedido ───────────────────────────────────────────────────────

  Future<void> _confirmar() async {
    if (_mesaSeleccionada == null || _carrito.isEmpty || _guardando) return;
    setState(() => _guardando = true);

    final now = DateTime.now();
    final pedidoId = _uuid.v4();

    final pedido = Pedido(
      id: pedidoId,
      restaurantId: sl<TenantContext>().restaurantId,
      mesaId: _mesaSeleccionada!.id,
      estado: EstadoPedido.creado,
      total: _total,
      createdAt: now,
      updatedAt: now,
      mesaNombre: _mesaSeleccionada!.displayName,
    );

    final ok = await ref.read(pedidosProvider.notifier).crearPedido(pedido);
    if (!ok) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al crear el pedido. Intenta de nuevo.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;

    // Agregar cada item al pedido
    bool todosOk = true;
    for (final cartItem in _carrito) {
      final item = PedidoItem(
        id: _uuid.v4(),
        pedidoId: pedidoId,
        productoId: cartItem.producto.id,
        varianteId: cartItem.variante?.id,
        cantidad: cartItem.cantidad,
        precioUnitario: cartItem.variante?.precio ?? cartItem.producto.precio,
        observaciones: cartItem.nota,
        estado: EstadoPedido.creado,
        productoNombre: cartItem.nombre,
        varianteNombre: cartItem.variante?.nombre,
        createdAt: now,
        updatedAt: now,
      );
      final itemOk = await ref.read(pedidosProvider.notifier).agregarItem(item);
      if (!itemOk) todosOk = false;
      if (!mounted) return;
    }

    // Marcar mesa como ocupada
    await ref
        .read(mesasProvider.notifier)
        .cambiarEstado(
          _mesaSeleccionada!.id,
          EstadoMesa.ocupada,
          sl<TenantContext>().restaurantId,
        );

    if (!mounted) return;

    if (!todosOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pedido guardado pero algunos productos no se pudieron agregar.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
    }
    Navigator.pop(context);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);
    final mesasState = ref.watch(mesasProvider);
    final mesasLibres = mesasState.mesas
        .where((m) => m.estado == EstadoMesa.libre && m.activo)
        .toList();

    final categorias = menuState.categorias.where((c) => c.activo).toList();
    _syncTabs(categorias);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: menuState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : menuState.errorMessage != null && menuState.productos.isEmpty
          ? _buildMenuError(menuState.errorMessage!)
          : menuState.productos.isEmpty
          ? _buildMenuVacio()
          : Column(
              children: [
                // ── Selector de mesa ─────────────────────
                _MesaSelector(
                  mesas: mesasLibres,
                  seleccionada: _mesaSeleccionada,
                  onChanged: (m) => setState(() => _mesaSeleccionada = m),
                ),

                // ── Pestañas de categoría ─────────────────
                if (_tabController != null)
                  _CategoriasTabBar(
                    categorias: categorias,
                    controller: _tabController!,
                  ),

                // ── Productos ─────────────────────────────
                Expanded(
                  child: _tabController == null
                      ? const SizedBox()
                      : TabBarView(
                          controller: _tabController!,
                          children: [
                            // Pestaña "Todos"
                            _ProductosList(
                              productos: menuState.productos
                                  .where((p) => p.disponible && p.activo)
                                  .toList(),
                              carrito: _carrito,
                              onAgregar: _mostrarSelectorProducto,
                              onCambiarCantidad: _cambiarCantidad,
                            ),
                            // Una pestaña por categoría
                            for (final cat in categorias)
                              _ProductosList(
                                productos: menuState.productos
                                    .where(
                                      (p) =>
                                          p.disponible &&
                                          p.activo &&
                                          p.categoriaId == cat.id,
                                    )
                                    .toList(),
                                carrito: _carrito,
                                onAgregar: _mostrarSelectorProducto,
                                onCambiarCantidad: _cambiarCantidad,
                              ),
                          ],
                        ),
                ),
              ],
            ),

      // ── Barra de resumen + confirmar ──────────────────────────
      bottomNavigationBar: _carrito.isNotEmpty
          ? _ResumenBar(
              total: _total,
              totalItems: _totalItems,
              guardando: _guardando,
              mesaSeleccionada: _mesaSeleccionada,
              onVerCarrito: () => _mostrarCarrito(context),
              onConfirmar: _confirmar,
            )
          : null,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Nuevo Pedido'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          if (_carrito.isEmpty) {
            Navigator.pop(context);
            return;
          }
          showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('¿Salir?'),
              content: const Text(
                'Tienes productos en el pedido. ¿Salir sin guardar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Salir'),
                ),
              ],
            ),
          ).then((confirmar) {
            if (confirmar == true && mounted) Navigator.pop(context);
          });
        },
      ),
      actions: [
        if (_carrito.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Badge(
              label: Text('$_totalItems'),
              child: IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'Ver carrito',
                onPressed: () => _mostrarCarrito(context),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay productos en el menú',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'El administrador debe agregar productos primero.',
            style: TextStyle(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuError(String mensaje) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar el menú',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(menuProvider.notifier).loadMenu(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet selector de producto ────────────────────────────────────

  void _mostrarSelectorProducto(Producto producto) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ProductoSelector(
        producto: producto,
        onAgregar: (variante, cantidad, nota) {
          _agregarAlCarrito(producto, variante, cantidad, nota);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Bottom sheet carrito ──────────────────────────────────────────────────

  void _mostrarCarrito(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, sc) => Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pedido ($_totalItems items)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: sc,
                    itemCount: _carrito.length,
                    itemBuilder: (_, i) {
                      final item = _carrito[i];
                      return ListTile(
                        title: Text(item.nombre),
                        subtitle: item.nota != null
                            ? Text(
                                item.nota!,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            '${item.cantidad}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${item.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              onPressed: () {
                                _quitarDelCarrito(item.tempId);
                                setModalState(() {});
                                if (_carrito.isEmpty) {
                                  Navigator.pop(ctx);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 360;

                      final totalInfo = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            '\$${_total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      );

                      final confirmButton = ElevatedButton.icon(
                        onPressed: _mesaSeleccionada != null && !_guardando
                            ? () {
                                Navigator.pop(ctx);
                                _confirmar();
                              }
                            : null,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _mesaSeleccionada == null
                              ? 'Selecciona una mesa'
                              : 'Confirmar pedido',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      );

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            totalInfo,
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: confirmButton,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [totalInfo, const Spacer(), confirmButton],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _MesaSelector extends StatelessWidget {
  final List<Mesa> mesas;
  final Mesa? seleccionada;
  final void Function(Mesa?) onChanged;

  const _MesaSelector({
    required this.mesas,
    required this.seleccionada,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DropdownButtonFormField<Mesa>(
        value: seleccionada,
        decoration: InputDecoration(
          labelText: mesas.isEmpty ? 'No hay mesas libres' : 'Mesa',
          prefixIcon: const Icon(Icons.table_restaurant_rounded),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        items: mesas
            .map((m) => DropdownMenuItem(value: m, child: Text(m.displayName)))
            .toList(),
        onChanged: mesas.isEmpty ? null : onChanged,
        hint: Text(
          mesas.isEmpty ? 'Sin mesas disponibles' : 'Selecciona una mesa',
          style: const TextStyle(color: AppColors.textHint),
        ),
      ),
    );
  }
}

class _CategoriasTabBar extends StatelessWidget {
  final List<Categoria> categorias;
  final TabController controller;

  const _CategoriasTabBar({required this.categorias, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        tabs: [
          const Tab(text: 'Todos'),
          for (final cat in categorias) Tab(text: cat.nombre),
        ],
      ),
    );
  }
}

class _ProductosList extends StatelessWidget {
  final List<Producto> productos;
  final List<_CartItem> carrito;
  final void Function(Producto) onAgregar;
  final void Function(String, int) onCambiarCantidad;

  const _ProductosList({
    required this.productos,
    required this.carrito,
    required this.onAgregar,
    required this.onCambiarCantidad,
  });

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) {
      return const Center(
        child: Text(
          'No hay productos en esta categoría',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: productos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = productos[i];
        final itemsEnCarrito = carrito
            .where((c) => c.producto.id == p.id)
            .toList();
        final cantidadEnCarrito = itemsEnCarrito.fold(
          0,
          (s, c) => s + c.cantidad,
        );

        return _ProductoCard(
          producto: p,
          cantidadEnCarrito: cantidadEnCarrito,
          onAgregar: () => onAgregar(p),
          onIncrementar: itemsEnCarrito.isNotEmpty
              ? () => onCambiarCantidad(itemsEnCarrito.last.tempId, 1)
              : null,
          onDecrementar: itemsEnCarrito.isNotEmpty
              ? () => onCambiarCantidad(itemsEnCarrito.last.tempId, -1)
              : null,
        );
      },
    );
  }
}

class _ProductoCard extends StatelessWidget {
  final Producto producto;
  final int cantidadEnCarrito;
  final VoidCallback onAgregar;
  final VoidCallback? onIncrementar;
  final VoidCallback? onDecrementar;

  const _ProductoCard({
    required this.producto,
    required this.cantidadEnCarrito,
    required this.onAgregar,
    this.onIncrementar,
    this.onDecrementar,
  });

  @override
  Widget build(BuildContext context) {
    final enCarrito = cantidadEnCarrito > 0;

    return Card(
      margin: EdgeInsets.zero,
      color: enCarrito ? AppColors.primary.withValues(alpha: 0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: enCarrito
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // ── Info ──────────────────────────────────────────
            Expanded(
              child: InkWell(
                onTap: onAgregar,
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (producto.descripcion != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        producto.descripcion!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      producto.tieneVariantes
                          ? 'Desde \$${producto.precioMinimo.toStringAsFixed(2)}'
                          : '\$${producto.precio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Controles ─────────────────────────────────────
            if (!enCarrito)
              _AddButton(onTap: onAgregar)
            else
              _CounterControl(
                cantidad: cantidadEnCarrito,
                onIncrementar: onIncrementar ?? () {},
                onDecrementar: onDecrementar ?? () {},
                onTapCantidad: onAgregar,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Icon(Icons.add, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CounterControl extends StatelessWidget {
  final int cantidad;
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;
  final VoidCallback onTapCantidad;

  const _CounterControl({
    required this.cantidad,
    required this.onIncrementar,
    required this.onDecrementar,
    required this.onTapCantidad,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleIconBtn(
          icon: Icons.remove,
          onTap: onDecrementar,
          color: AppColors.error,
        ),
        GestureDetector(
          onTap: onTapCantidad,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              '$cantidad',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        _CircleIconBtn(
          icon: Icons.add,
          onTap: onIncrementar,
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _CircleIconBtn({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ── Resumen bar ────────────────────────────────────────────────────────────────

class _ResumenBar extends StatelessWidget {
  final double total;
  final int totalItems;
  final bool guardando;
  final Mesa? mesaSeleccionada;
  final VoidCallback onVerCarrito;
  final VoidCallback onConfirmar;

  const _ResumenBar({
    required this.total,
    required this.totalItems,
    required this.guardando,
    required this.mesaSeleccionada,
    required this.onVerCarrito,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 420;

            final infoCarrito = InkWell(
              onTap: onVerCarrito,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalItems item${totalItems == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );

            final confirmarButton = ElevatedButton.icon(
              onPressed: mesaSeleccionada == null || guardando
                  ? null
                  : onConfirmar,
              icon: guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                mesaSeleccionada == null
                    ? 'Selecciona mesa'
                    : guardando
                    ? 'Guardando...'
                    : 'Confirmar pedido',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  infoCarrito,
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: confirmarButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: infoCarrito),
                confirmarButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Selector de variante/cantidad/nota ─────────────────────────────────────────

class _ProductoSelector extends StatefulWidget {
  final Producto producto;
  final void Function(Variante?, int, String?) onAgregar;

  const _ProductoSelector({required this.producto, required this.onAgregar});

  @override
  State<_ProductoSelector> createState() => _ProductoSelectorState();
}

class _ProductoSelectorState extends State<_ProductoSelector> {
  Variante? _variante;
  int _cantidad = 1;
  final _notaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // No se pre-selecciona variante: el precio base es la opción por defecto.
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  double get _precio => _variante?.precio ?? widget.producto.precio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Título
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.producto.nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '\$${(_precio * _cantidad).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            if (widget.producto.descripcion != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.producto.descripcion!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Variantes
                  if (widget.producto.tieneVariantes) ...[
                    const Text(
                      'Variante',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Chip precio base del producto
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                'Precio base  \$${widget.producto.precio.toStringAsFixed(2)}',
                              ),
                              selected: _variante == null,
                              onSelected: (_) =>
                                  setState(() => _variante = null),
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              labelStyle: TextStyle(
                                color: _variante == null
                                    ? AppColors.primary
                                    : null,
                                fontWeight: _variante == null
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                          ),
                          // Chips de variantes activas
                          ...widget.producto.variantes.where((v) => v.activo).map((
                            v,
                          ) {
                            final sel = _variante?.id == v.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  '${v.nombre}  \$${v.precio.toStringAsFixed(2)}',
                                ),
                                selected: sel,
                                onSelected: (_) =>
                                    setState(() => _variante = v),
                                selectedColor: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                labelStyle: TextStyle(
                                  color: sel ? AppColors.primary : null,
                                  fontWeight: sel ? FontWeight.bold : null,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Cantidad
                  Row(
                    children: [
                      const Text(
                        'Cantidad',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      _CircleIconBtn(
                        icon: Icons.remove,
                        onTap: _cantidad > 1
                            ? () => setState(() => _cantidad--)
                            : () {},
                        color: _cantidad > 1 ? AppColors.error : Colors.grey,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$_cantidad',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _CircleIconBtn(
                        icon: Icons.add,
                        onTap: () => setState(() => _cantidad++),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nota para cocina
                  TextField(
                    controller: _notaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nota para cocina (opcional)',
                      hintText: 'Sin sal, extra picante...',
                      prefixIcon: Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 1,
                    maxLength: 100,
                  ),
                  const SizedBox(height: 8),

                  // Botón agregar
                  ElevatedButton.icon(
                    onPressed: () => widget.onAgregar(
                      _variante,
                      _cantidad,
                      _notaCtrl.text.trim().isEmpty
                          ? null
                          : _notaCtrl.text.trim(),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: Text(
                      'Agregar  •  \$${(_precio * _cantidad).toStringAsFixed(2)}',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
