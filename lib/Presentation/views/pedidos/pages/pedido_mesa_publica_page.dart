import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';
import 'package:restaurant_app/features/pedidos/presentation/providers/pedidos_provider.dart';
import 'package:uuid/uuid.dart';

/// Modelo local del carrito en esta pantalla.
class _CartItem {
  final Producto producto;
  final Variante? variante;
  int cantidad;
  String? nota;

  _CartItem({required this.producto, this.variante, required this.cantidad});

  double get precio => variante?.precio ?? producto.precio;
  double get subtotal => precio * cantidad;
  String get nombre => variante != null
      ? '${producto.nombre} (${variante!.nombre})'
      : producto.nombre;
}

/// Página pública accesible desde el QR de la mesa.
///
/// El cliente elige sus platos, los agrega al carrito y envía el pedido.
/// El pedido llega al sistema con estado [EstadoPedido.pendienteAprobacion]
/// para que el mesero lo revise antes de enviarlo a cocina.
class PedidoMesaPublicaPage extends ConsumerStatefulWidget {
  final String mesaId;
  final String mesaNombre;

  const PedidoMesaPublicaPage({
    super.key,
    required this.mesaId,
    required this.mesaNombre,
  });

  @override
  ConsumerState<PedidoMesaPublicaPage> createState() =>
      _PedidoMesaPublicaPageState();
}

class _PedidoMesaPublicaPageState extends ConsumerState<PedidoMesaPublicaPage> {
  final List<_CartItem> _cart = [];
  bool _pedidoEnviado = false;
  bool _sending = false;
  String? _errorMsg;
  String? _categoriaSeleccionada; // null = todas

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(menuProvider.notifier).loadMenu();
    });
  }

  double get _total => _cart.fold(0, (sum, item) => sum + item.subtotal);

  int get _cantidadTotal => _cart.fold(0, (sum, item) => sum + item.cantidad);

  void _addToCart(Producto producto, Variante? variante) {
    setState(() {
      final existing = _cart.firstWhere(
        (c) => c.producto.id == producto.id && c.variante?.id == variante?.id,
        orElse: () {
          final item = _CartItem(
            producto: producto,
            variante: variante,
            cantidad: 1,
          );
          _cart.add(item);
          return item;
        },
      );
      existing.cantidad++;
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      if (_cart[index].cantidad > 1) {
        _cart[index].cantidad--;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  void _deleteFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  Future<void> _enviarPedido() async {
    if (_cart.isEmpty) return;
    setState(() {
      _sending = true;
      _errorMsg = null;
    });

    final uuid = const Uuid();
    final now = DateTime.now();
    final pedidoId = uuid.v4();
    final items = _cart.map((c) {
      return PedidoItem(
        id: uuid.v4(),
        pedidoId: pedidoId,
        productoId: c.producto.id,
        varianteId: c.variante?.id,
        cantidad: c.cantidad,
        precioUnitario: c.precio,
        observaciones: c.nota,
        estado: EstadoPedido.pendienteAprobacion,
        createdAt: now,
        updatedAt: now,
        productoNombre: c.producto.nombre,
        varianteNombre: c.variante?.nombre,
      );
    }).toList();

    final pedido = Pedido(
      id: pedidoId,
      restaurantId: sl<TenantContext>().restaurantId,
      mesaId: widget.mesaId.isNotEmpty ? widget.mesaId : null,
      meseroId: null,
      estado: EstadoPedido.pendienteAprobacion,
      observaciones: null,
      total: _total,
      createdAt: now,
      updatedAt: now,
      items: items,
      mesaNombre: widget.mesaNombre.isNotEmpty ? widget.mesaNombre : null,
    );

    final ok = await ref.read(pedidosProvider.notifier).crearPedido(pedido);

    setState(() {
      _sending = false;
      if (ok) {
        _pedidoEnviado = true;
      } else {
        _errorMsg = 'No se pudo enviar el pedido. Intenta nuevamente.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pedidoEnviado) return _ConfirmacionView(mesaNombre: widget.mesaNombre);

    final menuState = ref.watch(menuProvider);
    final categorias = menuState.categorias;
    final productos = menuState.productosDisponibles
        .where(
          (p) =>
              _categoriaSeleccionada == null ||
              p.categoriaId == _categoriaSeleccionada,
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.mesaNombre.isNotEmpty
              ? 'Pedir — ${widget.mesaNombre}'
              : 'Carta Digital',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          if (_cantidadTotal > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: Badge(
                  label: Text('$_cantidadTotal'),
                  child: const Icon(Icons.shopping_cart_rounded),
                ),
                label: Text(
                  '${AppConstants.currencySymbol}${_total.toStringAsFixed(2)}',
                ),
                onPressed: () => _showCart(context),
              ),
            ),
        ],
      ),
      body: menuState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (categorias.isNotEmpty) _buildCategoryBar(categorias),
                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: productos.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay platos disponibles en este momento.',
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 280,
                                mainAxisExtent: 220,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                          itemCount: productos.length,
                          itemBuilder: (_, i) => _ProductoCard(
                            producto: productos[i],
                            onAgregar: _addToCart,
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: _cantidadTotal > 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showCart(context),
              icon: const Icon(Icons.shopping_cart_rounded),
              label: Text(
                'Ver carrito ($_cantidadTotal)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildCategoryBar(List<dynamic> categorias) {
    return Container(
      color: Colors.white,
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          _CategoryChip(
            label: 'Todos',
            selected: _categoriaSeleccionada == null,
            onTap: () => setState(() => _categoriaSeleccionada = null),
          ),
          for (final cat in categorias)
            _CategoryChip(
              label: cat.nombre as String,
              selected: _categoriaSeleccionada == cat.id,
              onTap: () => setState(() => _categoriaSeleccionada = cat.id),
            ),
        ],
      ),
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.95,
            minChildSize: 0.3,
            builder: (_, controller) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Tu pedido',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${AppConstants.currencySymbol}${_total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: _cart.length,
                        itemBuilder: (_, i) {
                          final item = _cart[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.nombre),
                            subtitle: Text(
                              '${AppConstants.currencySymbol}${item.precio.toStringAsFixed(2)} c/u',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    _removeFromCart(i);
                                    setModalState(() {});
                                  },
                                ),
                                Text(
                                  '${item.cantidad}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    setState(() => item.cantidad++);
                                    setModalState(() {});
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    _deleteFromCart(i);
                                    setModalState(() {});
                                    if (_cart.isEmpty) Navigator.pop(ctx);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _sending || _cart.isEmpty
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _enviarPedido();
                              },
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _sending ? 'Enviando...' : 'Enviar pedido al mesero',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        checkmarkColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

class _ProductoCard extends StatefulWidget {
  final Producto producto;
  final void Function(Producto, Variante?) onAgregar;

  const _ProductoCard({required this.producto, required this.onAgregar});

  @override
  State<_ProductoCard> createState() => _ProductoCardState();
}

class _ProductoCardState extends State<_ProductoCard> {
  Variante? _varianteSeleccionada;

  @override
  void initState() {
    super.initState();
    if (widget.producto.variantes.isNotEmpty) {
      _varianteSeleccionada = widget.producto.variantes.first;
    }
  }

  double get _precio => _varianteSeleccionada?.precio ?? widget.producto.precio;

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          Expanded(
            flex: 3,
            child: p.imagenUrl != null && p.imagenUrl!.isNotEmpty
                ? _buildImage(p.imagenUrl!)
                : Container(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    child: const Center(
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  ),
          ),
          // Info
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (p.variantes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    DropdownButton<Variante>(
                      value: _varianteSeleccionada,
                      isDense: true,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: theme.textTheme.bodySmall,
                      items: p.variantes
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                '${v.nombre} — ${AppConstants.currencySymbol}${v.precio.toStringAsFixed(2)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _varianteSeleccionada = v),
                    ),
                  ] else
                    const SizedBox(height: 4),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${AppConstants.currencySymbol}${_precio.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(
                        height: 30,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () =>
                              widget.onAgregar(p, _varianteSeleccionada),
                          child: const Icon(Icons.add, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.startsWith('data:')) {
      // base64
      final comma = imageUrl.indexOf(',');
      if (comma != -1) {
        try {
          final bytes = base64Decode(imageUrl.substring(comma + 1));
          return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity);
        } catch (_) {}
      }
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla de confirmación
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmacionView extends StatelessWidget {
  final String mesaNombre;

  const _ConfirmacionView({required this.mesaNombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              Text(
                '¡Pedido enviado!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'El mesero revisará tu pedido en un momento.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              if (mesaNombre.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  mesaNombre,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.restaurant_menu_rounded),
                label: const Text('Ver carta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
