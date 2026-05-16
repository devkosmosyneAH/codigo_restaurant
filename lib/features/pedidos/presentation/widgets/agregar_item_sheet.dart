import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';
import 'package:restaurant_app/features/pedidos/presentation/providers/pedidos_provider.dart';
import 'package:restaurant_app/core/domain/enums.dart';

/// Bottom sheet para agregar un producto del menú a un pedido.
///
/// Carga las categorías y productos disponibles, permite
/// filtrar por categoría, elegir variante (si hay), cantidad
/// y observaciones por ítem antes de confirmar.
class AgregarItemSheet extends ConsumerStatefulWidget {
  final String pedidoId;
  final String restaurantId;

  const AgregarItemSheet({
    super.key,
    required this.pedidoId,
    required this.restaurantId,
  });

  @override
  ConsumerState<AgregarItemSheet> createState() => _AgregarItemSheetState();
}

class _AgregarItemSheetState extends ConsumerState<AgregarItemSheet>
    with SingleTickerProviderStateMixin {
  static const _uuid = Uuid();

  late final TabController _tabCtrl;

  // ── Tab menú ──────────────────────────────────────
  String? _categoriaFiltro;
  Producto? _productoSeleccionado;
  Variante? _varianteSeleccionada;
  int _cantidad = 1;
  final _obsController = TextEditingController();

  // ── Tab manual ────────────────────────────────────
  final _manualFormKey = GlobalKey<FormState>();
  final _manualNombreCtrl = TextEditingController();
  final _manualPrecioCtrl = TextEditingController();
  int _manualCantidad = 1;

  // ── Compartido ────────────────────────────────────
  int _itemsAgregados = 0;
  bool _agregando = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    Future.microtask(
      () => ref.read(menuProvider.notifier).loadMenu(widget.restaurantId),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _obsController.dispose();
    _manualNombreCtrl.dispose();
    _manualPrecioCtrl.dispose();
    super.dispose();
  }

  double get _precio {
    if (_varianteSeleccionada != null) return _varianteSeleccionada!.precio;
    return _productoSeleccionado?.precio ?? 0;
  }

  List<Producto> _productosFiltrados(MenuState menu) {
    return menu.productos
        .where((p) => p.disponible && p.activo)
        .where(
          (p) => _categoriaFiltro == null || p.categoriaId == _categoriaFiltro,
        )
        .toList();
  }

  void _seleccionarProducto(Producto p) {
    setState(() {
      _productoSeleccionado = p;
      // null = precio estándar (base del producto)
      _varianteSeleccionada = null;
      _cantidad = 1;
      _obsController.clear();
    });
  }

  void _resetSeleccion() {
    setState(() {
      _productoSeleccionado = null;
      _varianteSeleccionada = null;
      _cantidad = 1;
      _obsController.clear();
    });
  }

  Future<void> _confirmar() async {
    if (_productoSeleccionado == null || _agregando) return;
    setState(() => _agregando = true);

    final now = DateTime.now();
    final item = PedidoItem(
      id: _uuid.v4(),
      pedidoId: widget.pedidoId,
      productoId: _productoSeleccionado!.id,
      varianteId: _varianteSeleccionada?.id,
      cantidad: _cantidad,
      precioUnitario: _precio,
      observaciones: _obsController.text.trim().isEmpty
          ? null
          : _obsController.text.trim(),
      estado: EstadoPedido.creado,
      productoNombre: _varianteSeleccionada != null
          ? '${_productoSeleccionado!.nombre} (${_varianteSeleccionada!.nombre})'
          : _productoSeleccionado!.nombre,
      varianteNombre: _varianteSeleccionada?.nombre,
      createdAt: now,
      updatedAt: now,
    );

    final success = await ref.read(pedidosProvider.notifier).agregarItem(item);

    if (!mounted) return;

    if (success) {
      setState(() {
        _itemsAgregados++;
        _agregando = false;
      });
      _resetSeleccion();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.productoNombre} agregado'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
    } else {
      setState(() => _agregando = false);
    }
  }

  Future<void> _confirmarManual() async {
    if (!_manualFormKey.currentState!.validate() || _agregando) return;
    setState(() => _agregando = true);

    final nombre = _manualNombreCtrl.text.trim();
    final precio = double.parse(_manualPrecioCtrl.text.trim());
    final now = DateTime.now();
    final item = PedidoItem(
      id: _uuid.v4(),
      pedidoId: widget.pedidoId,
      productoId: 'manual',
      cantidad: _manualCantidad,
      precioUnitario: precio,
      estado: EstadoPedido.creado,
      productoNombre: nombre,
      createdAt: now,
      updatedAt: now,
    );

    final success = await ref.read(pedidosProvider.notifier).agregarItem(item);
    if (!mounted) return;

    if (success) {
      setState(() {
        _itemsAgregados++;
        _agregando = false;
        _manualNombreCtrl.clear();
        _manualPrecioCtrl.clear();
        _manualCantidad = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nombre agregado'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );
    } else {
      setState(() => _agregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Column(
          children: [
            // ── Handle ────────────────────────────────────────
            const _SheetHandle(),

            // ── Header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Agregar al pedido',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  if (_itemsAgregados > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_itemsAgregados agregado${_itemsAgregados == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Listo'),
                    style: TextButton.styleFrom(
                      foregroundColor: _itemsAgregados > 0
                          ? AppColors.primary
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Tabs: Del menú / Manual ────────────────────────
            TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(
                  icon: Icon(Icons.restaurant_menu_outlined),
                  text: 'Del menú',
                ),
                Tab(icon: Icon(Icons.edit_outlined), text: 'Manual'),
              ],
            ),
            const Divider(height: 1),

            // ── Contenido de tabs ──────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Tab 1: Del menú ──────────────────────────
                  _buildTabMenu(menu, scrollController),

                  // ── Tab 2: Manual ────────────────────────────
                  _buildTabManual(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabMenu(MenuState menu, ScrollController scrollController) {
    if (menu.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (menu.productos.isEmpty) {
      return const Center(
        child: Text(
          'No hay productos en el menú.\nAgrega productos desde la sección Menú.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return Column(
      children: [
        // ── Filtros de categoría ────────────────────────────
        _CategoriasTabs(
          categorias: menu.categorias.where((c) => c.activo).toList(),
          seleccionada: _categoriaFiltro,
          onSelect: (id) => setState(() => _categoriaFiltro = id),
        ),
        const Divider(height: 1),

        // ── Lista de productos ──────────────────────────────
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(12),
            children: [
              ..._productosFiltrados(menu).map((p) {
                final selected = _productoSeleccionado?.id == p.id;
                return _ProductoTile(
                  producto: p,
                  selected: selected,
                  onTap: () => _seleccionarProducto(p),
                );
              }),
              if (_productosFiltrados(menu).isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No hay productos disponibles en esta categoría',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Panel de configuración ──────────────────────────
        if (_productoSeleccionado != null)
          _ItemConfigPanel(
            producto: _productoSeleccionado!,
            varianteSeleccionada: _varianteSeleccionada,
            cantidad: _cantidad,
            precio: _precio,
            obsController: _obsController,
            agregando: _agregando,
            onVarianteChange: (v) => setState(() => _varianteSeleccionada = v),
            onCantidadChange: (c) => setState(() => _cantidad = c),
            onConfirmar: _confirmar,
            onCancelar: _resetSeleccion,
          ),
      ],
    );
  }

  Widget _buildTabManual() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _manualFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Agrega un ítem con nombre y precio libre, sin necesidad de que esté en el menú.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _manualNombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto / servicio',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _manualPrecioCtrl,
              decoration: const InputDecoration(
                labelText: 'Precio unitario',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Ingresa un precio válido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Cantidad',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _manualCantidad > 1
                      ? () => setState(() => _manualCantidad--)
                      : null,
                  color: AppColors.primary,
                ),
                Text(
                  '$_manualCantidad',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _manualCantidad++),
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _agregando ? null : _confirmarManual,
              icon: _agregando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_agregando ? 'Agregando...' : 'Agregar al pedido'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subwidgets ─────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _CategoriasTabs extends StatelessWidget {
  final List<Categoria> categorias;
  final String? seleccionada;
  final void Function(String?) onSelect;

  const _CategoriasTabs({
    required this.categorias,
    required this.seleccionada,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _Tab(
            label: 'Todos',
            selected: seleccionada == null,
            onTap: () => onSelect(null),
          ),
          for (final cat in categorias)
            _Tab(
              label: cat.nombre,
              selected: seleccionada == cat.id,
              onTap: () => onSelect(cat.id),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : null,
          fontWeight: selected ? FontWeight.bold : null,
        ),
      ),
    );
  }
}

class _ProductoTile extends StatelessWidget {
  final Producto producto;
  final bool selected;
  final VoidCallback onTap;

  const _ProductoTile({
    required this.producto,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: selected
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          producto.nombre,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: producto.descripcion != null
            ? Text(
                producto.descripcion!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              )
            : null,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${producto.precioMinimo.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            if (producto.tieneVariantes)
              const Text(
                'variantes',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
          ],
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(
            Icons.fastfood_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _ItemConfigPanel extends StatelessWidget {
  final Producto producto;
  final Variante? varianteSeleccionada;
  final int cantidad;
  final double precio;
  final TextEditingController obsController;
  final bool agregando;
  final void Function(Variante?) onVarianteChange;
  final void Function(int) onCantidadChange;
  final VoidCallback onConfirmar;
  final VoidCallback onCancelar;

  const _ItemConfigPanel({
    required this.producto,
    required this.varianteSeleccionada,
    required this.cantidad,
    required this.precio,
    required this.obsController,
    required this.agregando,
    required this.onVarianteChange,
    required this.onCantidadChange,
    required this.onConfirmar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Variantes ─────────────────────────────────────
          if (producto.tieneVariantes) ...[
            const Text(
              'Variante',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Chip "Estándar" = precio base del producto
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        'Estándar  \$${producto.precio.toStringAsFixed(2)}',
                      ),
                      selected: varianteSeleccionada == null,
                      onSelected: (_) => onVarianteChange(null),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: varianteSeleccionada == null
                            ? AppColors.primary
                            : null,
                        fontWeight: varianteSeleccionada == null
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ),
                  // Chips por variante activa
                  ...producto.variantes.where((v) => v.activo).map((v) {
                    final sel = varianteSeleccionada?.id == v.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          '${v.nombre}  \$${v.precio.toStringAsFixed(2)}',
                        ),
                        selected: sel,
                        onSelected: (_) => onVarianteChange(v),
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
            const SizedBox(height: 10),
          ],

          // ── Cantidad ──────────────────────────────────────
          Row(
            children: [
              const Text(
                'Cantidad',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: cantidad > 1
                    ? () => onCantidadChange(cantidad - 1)
                    : null,
                color: AppColors.primary,
              ),
              Text(
                '$cantidad',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onCantidadChange(cantidad + 1),
                color: AppColors.primary,
              ),
            ],
          ),

          // ── Observaciones ─────────────────────────────────
          TextField(
            controller: obsController,
            decoration: const InputDecoration(
              labelText: 'Nota para cocina (opcional)',
              hintText: 'Sin sal, sin picante...',
              prefixIcon: Icon(Icons.notes_rounded),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 1,
            maxLength: 100,
          ),
          const SizedBox(height: 8),

          // ── Botones ────────────────────────────────────────
          Row(
            children: [
              OutlinedButton(
                onPressed: agregando ? null : onCancelar,
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: agregando ? null : onConfirmar,
                  icon: agregando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(
                    agregando
                        ? 'Agregando...'
                        : 'Agregar  •  \$${(precio * cantidad).toStringAsFixed(2)}',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
