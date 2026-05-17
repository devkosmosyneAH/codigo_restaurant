import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/features/caja/presentation/providers/caja_provider.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/domain/services/cliente_service.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:restaurant_app/features/menu/domain/usecases/menu_usecases.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion_item.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';
import 'package:restaurant_app/features/pedidos/presentation/providers/pedidos_provider.dart';
import 'package:restaurant_app/services/facturacion/sri_service.dart';
import 'package:uuid/uuid.dart';

/// Diálogo de cobro de un pedido.
///
/// Muestra el resumen de items, permite seleccionar método de pago,
/// aplicar descuento y confirmar el cobro.
class CobroDialog extends ConsumerStatefulWidget {
  final Pedido? pedido;
  final Cotizacion? cotizacion;

  const CobroDialog({super.key, this.pedido, this.cotizacion});

  /// Muestra el diálogo y retorna la [Venta] creada o null si se canceló.
  static Future<Venta?> show(BuildContext context, {required Pedido pedido}) {
    return showDialog<Venta>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CobroDialog(pedido: pedido),
    );
  }

  /// Total de extras (cargos adicionales) acumulados en el caché para un pedido.
  static double extrasTotalFor(String pedidoId) {
    return _CobroDialogState._extrasCache[pedidoId]?.fold<double>(
          0.0,
          (s, e) => s + e.subtotal,
        ) ??
        0.0;
  }

  /// Descuento (monto) cacheado para una cotización.
  /// Devuelve 0 si el usuario no ha ingresado ningún descuento aún.
  static double descuentoFor(String cotizacionId) =>
      _CobroDialogState._descuentoMontoCache[cotizacionId] ?? 0.0;

  /// Muestra el diálogo de cobro para una [Cotizacion] aceptada,
  /// reutilizando exactamente la misma UX que el cobro de pedidos.
  static Future<Venta?> showForCotizacion(
    BuildContext context, {
    required Cotizacion cotizacion,
  }) {
    return showDialog<Venta>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CobroDialog(cotizacion: cotizacion),
    );
  }

  @override
  ConsumerState<CobroDialog> createState() => _CobroDialogState();
}

class _CobroDialogState extends ConsumerState<CobroDialog> {
  // Extras persisten mientras la app está abierta (keyed por pedidoId o cotizacionId)
  static final Map<String, List<_LineaExtra>> _extrasCache = {};
  // Descuento persiste mientras el diálogo está cerrado pero no cobrado
  static final Map<String, double> _descuentoMontoCache = {};
  static final Map<String, double?> _descuentoPctCache = {};

  /// Identificador único de la fuente (pedido o cotización).
  String get _sourceId => widget.pedido?.id ?? widget.cotizacion!.id;

  MetodoPago _metodoPago = MetodoPago.efectivo;
  TipoComprobante _tipoComprobante = TipoComprobante.ticket;
  final _descuentoCtrl = TextEditingController(text: '0');
  final _descripcionCtrl = TextEditingController();
  final _efectivoCtrl = TextEditingController();
  final _clienteNombreCtrl = TextEditingController();
  final _clienteEmailCtrl = TextEditingController();
  final _clienteTelefonoCtrl = TextEditingController();
  final _clienteDireccionCtrl = TextEditingController();
  final _clienteIdCtrl = TextEditingController();
  bool _buscandoCliente = false;
  bool _clienteEncontrado = false;
  late final Future<SriConnectionStatus> _sriStatusFuture;
  bool _procesando = false;
  final List<_LineaExtra> _lineasExtra = [];

  /// Porcentaje de descuento original de la cotización (0-100).
  /// Null si el descuento es un monto fijo ingresado manualmente.
  double? _descuentoPorcentaje;

  // Sincroniza la lista con el caché y recalcula descuento porcentual si aplica
  void _setLineasExtra(void Function(List<_LineaExtra>) modifier) {
    setState(() {
      modifier(_lineasExtra);
      _extrasCache[_sourceId] = List.of(_lineasExtra);
      _recalcularDescuento();
    });
  }

  /// Recalcula el monto de descuento cuando cambia el subtotal,
  /// solo si hay un porcentaje vinculado (de la cotización original).
  void _recalcularDescuento() {
    if (_descuentoPorcentaje == null || _descuentoPorcentaje == 0) return;
    final subtotal =
        _subtotalPedido + _lineasExtra.fold(0.0, (s, e) => s + e.subtotal);
    _descuentoCtrl.text = (subtotal * (_descuentoPorcentaje! / 100))
        .toStringAsFixed(2);
    _persistirDescuento();
  }

  void _persistirDescuento() {
    _descuentoMontoCache[_sourceId] = double.tryParse(_descuentoCtrl.text) ?? 0;
    _descuentoPctCache[_sourceId] = _descuentoPorcentaje;
  }

  /// Agrega un extra y, si viene del menú, lo persiste como [PedidoItem]
  /// para que el mesero y cocina lo vean en tiempo real.
  Future<void> _agregarExtra(_LineaExtra extra) async {
    String? pedidoItemId;
    if (extra.productoId != null && widget.pedido != null) {
      pedidoItemId = const Uuid().v4();
      final now = DateTime.now();
      final item = PedidoItem(
        id: pedidoItemId,
        pedidoId: widget.pedido!.id,
        productoId: extra.productoId!,
        varianteId: extra.varianteId,
        cantidad: extra.cantidad,
        precioUnitario: extra.precio,
        observaciones: null,
        estado: EstadoPedido.creado,
        productoNombre: extra.nombre,
        varianteNombre: extra.varianteNombre,
        createdAt: now,
        updatedAt: now,
      );
      // Fire-and-forget: guarda en DB sin bloquear la UI
      ref.read(pedidosProvider.notifier).agregarItem(item);
    }
    _setLineasExtra(
      (l) =>
          l.add(pedidoItemId != null ? extra.withItemId(pedidoItemId) : extra),
    );
  }

  /// Quita un extra y, si tiene un [PedidoItem] asociado, lo elimina de la DB.
  void _quitarExtra(int idx) {
    final extra = _lineasExtra[idx];
    if (extra.pedidoItemId != null && widget.pedido != null) {
      ref
          .read(pedidosProvider.notifier)
          .eliminarItem(extra.pedidoItemId!, widget.pedido!.id);
    }
    _setLineasExtra((l) => l.removeAt(idx));
  }

  // IVA
  bool _ivaActivo = false;
  final _ivaPorcentajeCtrl = TextEditingController(text: '12');

  double get _subtotalPedido => widget.cotizacion != null
      ? widget.cotizacion!.items.fold(0.0, (s, i) => s + i.subtotal)
      : widget.pedido!.totalCalculado;
  double get _subtotalExtras =>
      _lineasExtra.fold(0.0, (s, e) => s + e.subtotal);
  double get _subtotal => _subtotalPedido + _subtotalExtras;
  double get _descuento => double.tryParse(_descuentoCtrl.text) ?? 0;
  double get _base => (_subtotal - _descuento).clamp(0.0, _subtotal);
  double get _ivaPorcentaje =>
      (double.tryParse(_ivaPorcentajeCtrl.text) ?? 0).clamp(0, 100);
  double get _ivaAmount => _ivaActivo ? _base * (_ivaPorcentaje / 100) : 0;
  double get _total => _base + _ivaAmount;
  bool get _esConsumidorFinal => _tipoComprobante == TipoComprobante.ticket;
  double get _cambio {
    final efectivo = double.tryParse(_efectivoCtrl.text) ?? 0;
    return (efectivo - _total).clamp(0.0, double.maxFinite);
  }

  @override
  void initState() {
    super.initState();
    _sriStatusFuture = sl<SriService>().getConnectionStatus();
    // Restaurar extras guardados para este pedido/cotización
    final cached = _extrasCache[_sourceId];
    if (cached != null && cached.isNotEmpty) {
      _lineasExtra.addAll(cached);
    }
    // Pre-rellenar datos del cliente si es una cotización
    if (widget.cotizacion != null) {
      final c = widget.cotizacion!;
      _clienteNombreCtrl.text = c.clienteNombre;
      _clienteEmailCtrl.text = c.clienteEmail;
      _clienteTelefonoCtrl.text = c.clienteTelefono;
      if (c.clienteDireccion != null) {
        _clienteDireccionCtrl.text = c.clienteDireccion!;
      }
      if (c.tasaImpuesto > 0) {
        _ivaActivo = true;
        _ivaPorcentajeCtrl.text = c.tasaImpuesto.toStringAsFixed(2);
      }
      // Restaurar descuento: prioridad al caché (usuario cerró y reabrió),
      // si no hay caché usar el % de la cotización.
      if (_descuentoMontoCache.containsKey(_sourceId)) {
        _descuentoPorcentaje = _descuentoPctCache[_sourceId];
        _descuentoCtrl.text = (_descuentoMontoCache[_sourceId] ?? 0)
            .toStringAsFixed(2);
      } else if (c.descuento > 0) {
        _descuentoPorcentaje = c.descuento;
        final base = c.items.fold(0.0, (s, i) => s + i.subtotal);
        _descuentoCtrl.text = (base * (c.descuento / 100)).toStringAsFixed(2);
        _persistirDescuento();
      }
    } else {
      // Restaurar descuento manual cacheado para pedidos
      if (_descuentoMontoCache.containsKey(_sourceId)) {
        _descuentoCtrl.text = (_descuentoMontoCache[_sourceId] ?? 0)
            .toStringAsFixed(2);
      }
    }
  }

  Future<void> _lookupCliente(String cedula) async {
    final clean = cedula.trim();
    if (clean.length != 10 && clean.length != 13) {
      setState(() => _clienteEncontrado = false);
      return;
    }
    setState(() => _buscandoCliente = true);
    final cliente = await sl<ClienteService>().buscarPorCedula(clean);
    if (!mounted) return;
    setState(() {
      _buscandoCliente = false;
      if (cliente != null) {
        _clienteEncontrado = true;
        _clienteNombreCtrl.text = cliente.nombreCompleto;
        if (cliente.email != null) _clienteEmailCtrl.text = cliente.email!;
        if (cliente.telefono != null) {
          _clienteTelefonoCtrl.text = cliente.telefono!;
        }
        if (cliente.direccion != null) {
          _clienteDireccionCtrl.text = cliente.direccion!;
        }
      } else {
        _clienteEncontrado = false;
      }
    });
  }

  void _aplicarConsumidorFinal() {
    _clienteIdCtrl.text = '';
    _clienteNombreCtrl.text = '';
    _clienteEmailCtrl.text = '';
    _clienteTelefonoCtrl.text = '';
    _clienteDireccionCtrl.text = '';
    _clienteEncontrado = false;
  }

  Future<Cliente?> _resolverClienteRegistrado() async {
    final cedula = _clienteIdCtrl.text.trim();
    final nombre = _clienteNombreCtrl.text.trim();
    if (cedula.isEmpty || nombre.isEmpty) {
      return null;
    }
    final cliente = await sl<ClienteService>().buscarOCrear({
      'cedula': cedula,
      'nombres': nombre,
      'telefono': _clienteTelefonoCtrl.text.trim(),
      'direccion': _clienteDireccionCtrl.text.trim(),
      'email': _clienteEmailCtrl.text.trim(),
    });
    return cliente;
  }

  @override
  void dispose() {
    _descuentoCtrl.dispose();
    _descripcionCtrl.dispose();
    _efectivoCtrl.dispose();
    _clienteNombreCtrl.dispose();
    _clienteEmailCtrl.dispose();
    _clienteTelefonoCtrl.dispose();
    _clienteDireccionCtrl.dispose();
    _clienteIdCtrl.dispose();
    _ivaPorcentajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final email = _clienteEmailCtrl.text.trim();
    final clienteNombre = _clienteNombreCtrl.text.trim();
    final clienteId = _clienteIdCtrl.text.trim();
    final clienteTelefono = _clienteTelefonoCtrl.text.trim();
    final clienteDireccion = _clienteDireccionCtrl.text.trim();
    final requiereClienteRegistrado =
        _tipoComprobante == TipoComprobante.factura;
    final clienteIdValido =
        clienteId.isEmpty || Cliente.esCedulaValida(clienteId);

    if (email.isNotEmpty && !_isEmailValid(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo electrónico inválido')),
      );
      return;
    }

    if (!clienteIdValido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cédula/RUC del cliente inválido')),
      );
      return;
    }

    if (requiereClienteRegistrado) {
      if (clienteNombre.isEmpty || clienteId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Para cliente registrado completa nombre e identificación/RUC.',
            ),
          ),
        );
        return;
      }
    }

    Cliente? cliente;
    final debeResolverCliente =
        requiereClienteRegistrado ||
        (clienteId.isNotEmpty && clienteNombre.isNotEmpty);
    if (debeResolverCliente) {
      try {
        cliente = await _resolverClienteRegistrado();
      } on BusinessException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo registrar cliente: $e')),
        );
        return;
      }
    }

    final clienteIdentificacion = clienteId.isEmpty ? null : clienteId;
    final tipoClienteVenta = clienteIdentificacion == null
        ? 'consumidor_final'
        : 'registrado';

    setState(() => _procesando = true);
    final Venta? venta;
    if (widget.cotizacion != null) {
      // ── Modo cotización ──────────────────────────────────────
      final cotizacion = widget.cotizacion!;
      final allItems = [
        ...cotizacion.items,
        ..._lineasExtra.map(
          (e) => CotizacionItem(
            id: const Uuid().v4(),
            cotizacionId: cotizacion.id,
            productoId: e.productoId,
            productoNombre: e.nombre,
            cantidad: e.cantidad,
            precioUnitario: e.precio,
            descuento: 0,
            subtotal: e.subtotal,
          ),
        ),
      ];
      venta = await ref
          .read(cajaProvider.notifier)
          .cobrarCotizacion(
            cotizacion: cotizacion,
            items: allItems,
            metodoPago: _metodoPago,
            tipoComprobante: _tipoComprobante,
            descuento: _descuento,
            descripcion: _descripcionCtrl.text.trim().isEmpty
                ? null
                : _descripcionCtrl.text.trim(),
            idCliente: cliente?.idCliente,
            tipoCliente: tipoClienteVenta,
            identificacionCliente: clienteIdentificacion,
            nombreCliente: clienteNombre.isEmpty ? null : clienteNombre,
            telefonoCliente: clienteTelefono.isEmpty ? null : clienteTelefono,
            direccionCliente: clienteDireccion.isEmpty
                ? null
                : clienteDireccion,
            impuestos: _ivaAmount,
          );
    } else {
      // ── Modo pedido (sin cambios) ─────────────────────────────
      venta = await ref
          .read(cajaProvider.notifier)
          .cobrarPedido(
            pedido: widget.pedido!,
            metodoPago: _metodoPago,
            tipoComprobante: _tipoComprobante,
            descuento: _descuento,
            descripcion: _descripcionCtrl.text.trim().isEmpty
                ? null
                : _descripcionCtrl.text.trim(),
            idCliente: cliente?.idCliente,
            tipoCliente: tipoClienteVenta,
            identificacionCliente: clienteIdentificacion,
            nombreCliente: clienteNombre.isEmpty ? null : clienteNombre,
            telefonoCliente: clienteTelefono.isEmpty ? null : clienteTelefono,
            direccionCliente: clienteDireccion.isEmpty
                ? null
                : clienteDireccion,
            clienteNombre: clienteNombre.isEmpty ? null : clienteNombre,
            clienteEmail: email.isEmpty ? null : email,
            clienteIdentificacion: clienteIdentificacion,
            extraItems: _lineasExtra
                .map(
                  (e) => CajaExtraItem(
                    nombre: e.nombre,
                    precio: e.precio,
                    cantidad: e.cantidad,
                    productoId: e.productoId,
                    varianteNombre: e.varianteNombre,
                  ),
                )
                .toList(),
            impuestos: _ivaAmount,
          );
    }
    if (!mounted) return;
    setState(() => _procesando = false);
    // Cobro exitoso: limpiar caché de extras y descuento para este pedido/cotización
    _extrasCache.remove(_sourceId);
    _descuentoMontoCache.remove(_sourceId);
    _descuentoPctCache.remove(_sourceId);
    Navigator.of(context).pop(venta);
  }

  bool _isEmailValid(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  Widget _buildResumenRow(
    BuildContext context,
    String label,
    double amount, {
    TextStyle? style,
  }) {
    final theme = Theme.of(context);
    final defaultStyle = style ?? theme.textTheme.bodySmall;
    final prefix = amount < 0 ? '-\$' : '\$';
    return Row(
      children: [
        Expanded(child: Text(label, style: defaultStyle)),
        Text(
          '$prefix${amount.abs().toStringAsFixed(2)}',
          style: defaultStyle?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewport = MediaQuery.sizeOf(context);
    final contentWidth = (viewport.width * 0.92).clamp(280.0, 520.0);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.point_of_sale_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.cotizacion != null
                  ? 'Cobrar Evento · ${widget.cotizacion!.clienteNombre}'
                  : 'Cobrar Pedido${widget.pedido?.mesaNombre != null ? ' · ${widget.pedido!.mesaNombre}' : ''}',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: contentWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Resumen de items ──────────────────────────────
              Text(
                widget.cotizacion != null
                    ? 'Detalle del evento'
                    : 'Detalle del pedido',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    ...(widget.cotizacion != null
                        ? widget.cotizacion!.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${item.cantidad}×',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: item.descripcion != null
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.productoNombre,
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                              Text(
                                                item.descripcion!,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            item.productoNombre,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                  ),
                                  Text(
                                    '\$${item.subtotal.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                        : widget.pedido!.items.map((item) {
                            final nombre = item.varianteNombre != null
                                ? '${item.productoNombre ?? 'Producto'} (${item.varianteNombre})'
                                : (item.productoNombre ?? 'Producto');
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${item.cantidad}×',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      nombre,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  Text(
                                    '\$${item.subtotal.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })),
                    Divider(height: 1, color: cs.outlineVariant),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Spacer(),
                          Text('Subtotal: ', style: theme.textTheme.bodyMedium),
                          Text(
                            '\$${_subtotalPedido.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Cargos adicionales ────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cargos adicionales',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _mostrarAgregarProducto,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (_lineasExtra.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Sin cargos adicionales',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _lineasExtra.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final extra = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${extra.cantidad}×',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                extra.varianteNombre != null
                                    ? '${extra.nombre} (${extra.varianteNombre})'
                                    : extra.nombre,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              '\$${extra.subtotal.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _quitarExtra(idx),
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close, size: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),

              // ── Descuento ─────────────────────────────────────
              TextFormField(
                controller: _descuentoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _descuentoPorcentaje != null
                      ? 'Descuento (${_descuentoPorcentaje!.toStringAsFixed(0)}%)'
                      : 'Descuento',
                  prefixText: '\$ ',
                  hintText: '0.00',
                  isDense: true,
                  prefixIcon: const Icon(Icons.discount_outlined),
                ),
                onChanged: (_) => setState(() {
                  // El usuario editó manualmente → desvincula el porcentaje
                  _descuentoPorcentaje = null;
                  _persistirDescuento();
                }),
              ),
              const SizedBox(height: 12),

              // ── Desglose de totales ───────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildResumenRow(
                      context,
                      'Subtotal',
                      _subtotal,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_descuento > 0) ...[
                      const SizedBox(height: 4),
                      _buildResumenRow(
                        context,
                        'Descuento',
                        -_descuento,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildResumenRow(
                        context,
                        'Base imponible',
                        _base,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (_ivaActivo) ...[
                      const SizedBox(height: 4),
                      _buildResumenRow(
                        context,
                        'IVA (${_ivaPorcentaje.toStringAsFixed(0)}%)',
                        _ivaAmount,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const Divider(height: 12),
                    _buildResumenRow(
                      context,
                      'TOTAL A COBRAR',
                      _total,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── IVA ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IVA',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _ivaActivo
                              ? 'Se mostrará en ticket y factura'
                              : 'No se aplica IVA',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _ivaActivo,
                    onChanged: (v) => setState(() => _ivaActivo = v),
                  ),
                ],
              ),
              if (_ivaActivo) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: TextFormField(
                        controller: _ivaPorcentajeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Porcentaje IVA',
                          suffixText: '%',
                          isDense: true,
                          prefixIcon: Icon(Icons.percent_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // ── Tipo de comprobante ──────────────────────────
              Text(
                'Tipo de comprobante',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: TipoComprobante.values.map((tipo) {
                  final selected = _tipoComprobante == tipo;
                  return ChoiceChip(
                    label: Text(tipo.label),
                    avatar: Icon(
                      tipo == TipoComprobante.factura
                          ? Icons.receipt_long_rounded
                          : Icons.receipt_outlined,
                      size: 16,
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _tipoComprobante = tipo;
                      if (tipo == TipoComprobante.ticket) {
                        _aplicarConsumidorFinal();
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _esConsumidorFinal
                      ? cs.primaryContainer.withValues(alpha: 0.45)
                      : Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _esConsumidorFinal ? cs.primary : Colors.orange,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _esConsumidorFinal
                          ? Icons.receipt_outlined
                          : Icons.receipt_long_rounded,
                      size: 18,
                      color: _esConsumidorFinal ? cs.primary : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _esConsumidorFinal
                            ? 'Ticket: los datos del cliente son opcionales.'
                            : 'Factura: se requiere nombre y cédula/RUC del cliente.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _esConsumidorFinal
                              ? cs.primary
                              : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Datos del cliente ─────────────────────────────
              Text(
                _esConsumidorFinal
                    ? 'Datos del cliente (opcional)'
                    : 'Datos del cliente para factura',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _clienteIdCtrl,
                decoration: InputDecoration(
                  labelText: _esConsumidorFinal
                      ? 'Cédula / RUC (opcional)'
                      : 'Cédula / RUC *',
                  helperText:
                      'Si existe se autocompletará; si no existe se registra al cobrar',
                  isDense: true,
                  prefixIcon: const Icon(Icons.badge_outlined),
                  suffixIcon: _buscandoCliente
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _clienteEncontrado
                      ? Icon(
                          Icons.verified_user_rounded,
                          color: Colors.green.shade600,
                        )
                      : null,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                onChanged: _lookupCliente,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _clienteNombreCtrl,
                      decoration: InputDecoration(
                        labelText: _esConsumidorFinal
                            ? 'Nombre del cliente (opcional)'
                            : 'Nombre del cliente *',
                        isDense: true,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _clienteEmailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        isDense: true,
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _clienteTelefonoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        isDense: true,
                        prefixIcon: Icon(Icons.call_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _clienteDireccionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        isDense: true,
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              if (_tipoComprobante == TipoComprobante.factura) ...[
                const SizedBox(height: 12),
                FutureBuilder<SriConnectionStatus>(
                  future: _sriStatusFuture,
                  builder: (context, snapshot) {
                    final status = snapshot.data;
                    final isReady = status?.canPrepareInvoice ?? false;
                    final borderColor = isReady ? Colors.green : Colors.orange;
                    final bgColor = isReady
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.orange.withValues(alpha: 0.08);
                    final message =
                        snapshot.connectionState == ConnectionState.waiting
                        ? 'Verificando configuración SRI…'
                        : status == null
                        ? 'No se pudo evaluar el estado SRI.'
                        : '${status.message}\nAmbiente: ${status.environment} · Endpoint listo\nConexión real: comentada/desactivada.';

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isReady
                                ? Icons.verified_outlined
                                : Icons.settings_ethernet_rounded,
                            size: 18,
                            color: borderColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: borderColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),

              // ── Método de pago ────────────────────────────────
              Text(
                'Método de pago',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: MetodoPago.values.map((m) {
                  final selected = _metodoPago == m;
                  return ChoiceChip(
                    label: Text(m.label),
                    avatar: Icon(_iconForMetodo(m), size: 16),
                    selected: selected,
                    onSelected: (_) => setState(() => _metodoPago = m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // ── Efectivo recibido (solo si es efectivo) ───────
              if (_metodoPago == MetodoPago.efectivo) ...[
                TextFormField(
                  controller: _efectivoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Efectivo recibido',
                    prefixText: '\$ ',
                    hintText: '0.00',
                    isDense: true,
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if ((double.tryParse(_efectivoCtrl.text) ?? 0) >= _total) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.change_circle_outlined,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cambio: \$${_cambio.toStringAsFixed(2)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],

              // ── Descripción opcional ─────────────────────────
              TextFormField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notas del pago (opcional)',
                  hintText: 'Ej: Referencia transferencia, etc.',
                  isDense: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        TextButton(
          onPressed: _procesando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _procesando ? null : _confirmar,
          icon: _procesando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(_procesando ? 'Procesando…' : 'Confirmar cobro'),
        ),
      ],
    );
  }

  IconData _iconForMetodo(MetodoPago m) {
    return switch (m) {
      MetodoPago.efectivo => Icons.payments_outlined,
      MetodoPago.tarjeta => Icons.credit_card_outlined,
      MetodoPago.transferencia => Icons.account_balance_outlined,
    };
  }

  // ── Selector de productos extra ─────────────────────────────

  Future<void> _mostrarAgregarProducto() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AgregarProductoSheet(
        onAgregar: (extra) {
          _agregarExtra(extra);
        },
      ),
    );
  }
}

// ── Hoja para agregar producto extra ─────────────────────────────────────────

class _AgregarProductoSheet extends StatefulWidget {
  final void Function(_LineaExtra extra) onAgregar;

  const _AgregarProductoSheet({required this.onAgregar});

  @override
  State<_AgregarProductoSheet> createState() => _AgregarProductoSheetState();
}

class _AgregarProductoSheetState extends State<_AgregarProductoSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Tab menú
  late final Future<List<Producto>> _productosFuture;
  String _busqueda = '';

  // Tab manual
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  int _cantidad = 1;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _productosFuture = _cargarProductos();
  }

  Future<List<Producto>> _cargarProductos() async {
    final result = await sl<GetProductos>().call(
      sl<TenantContext>().restaurantId,
    );
    return result.fold(
      (_) => [],
      (list) => list.where((p) => p.activo && p.disponible).toList(),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  void _agregarDesdeMenu(Producto p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _VarianteSelectorSheet(
        producto: p,
        onAgregar: (linea) {
          widget.onAgregar(linea);
          // Cerramos ambas hojas: la de variante y la de agregar
          Navigator.of(context)
            ..pop() // cierra _VarianteSelectorSheet
            ..pop(); // cierra _AgregarProductoSheet
        },
      ),
    );
  }

  void _agregarManual() {
    if (!_formKey.currentState!.validate()) return;
    widget.onAgregar(
      _LineaExtra(
        nombre: _nombreCtrl.text.trim(),
        precio: double.parse(_precioCtrl.text.trim()),
        cantidad: _cantidad,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.add_shopping_cart_outlined),
                const SizedBox(width: 8),
                Text(
                  'Agregar cargo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(icon: Icon(Icons.restaurant_menu_outlined), text: 'Del menú'),
              Tab(icon: Icon(Icons.edit_outlined), text: 'Manual'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ── Tab menú ──────────────────────────────────
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Buscar producto…',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _busqueda = v.trim()),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<Producto>>(
                        future: _productosFuture,
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final todos = snap.data ?? [];
                          final filtrados = _busqueda.isEmpty
                              ? todos
                              : todos
                                    .where(
                                      (p) => p.nombre.toLowerCase().contains(
                                        _busqueda.toLowerCase(),
                                      ),
                                    )
                                    .toList();
                          if (filtrados.isEmpty) {
                            return Center(
                              child: Text(
                                'Sin resultados',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scrollCtrl,
                            itemCount: filtrados.length,
                            itemBuilder: (_, i) {
                              final p = filtrados[i];
                              final precioLabel = p.tieneVariantes
                                  ? 'Desde \$${p.precioMinimo.toStringAsFixed(2)}'
                                  : '\$${p.precio.toStringAsFixed(2)}';
                              return ListTile(
                                title: Text(p.nombre),
                                subtitle: p.tieneVariantes
                                    ? Text(
                                        '${p.variantes.where((v) => v.activo).length} variante(s) disponible(s)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.primary,
                                        ),
                                      )
                                    : (p.descripcion != null
                                          ? Text(
                                              p.descripcion!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : null),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      precioLabel,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: cs.primary,
                                          ),
                                    ),
                                    if (p.tieneVariantes) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.expand_more,
                                        size: 18,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () => _agregarDesdeMenu(p),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // ── Tab manual ────────────────────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del producto / servicio',
                            prefixIcon: Icon(Icons.label_outline),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa un nombre'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _precioCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Precio unitario',
                            prefixText: '\$ ',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) {
                              return 'Ingresa un precio válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Cantidad', style: theme.textTheme.bodyMedium),
                            const Spacer(),
                            IconButton(
                              onPressed: _cantidad > 1
                                  ? () => setState(() => _cantidad--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            SizedBox(
                              width: 32,
                              child: Text(
                                '$_cantidad',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _cantidad++),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _agregarManual,
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar cargo'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selector de variante/cantidad para agregar desde menú ────────────────────

class _VarianteSelectorSheet extends StatefulWidget {
  final Producto producto;
  final void Function(_LineaExtra) onAgregar;

  const _VarianteSelectorSheet({
    required this.producto,
    required this.onAgregar,
  });

  @override
  State<_VarianteSelectorSheet> createState() => _VarianteSelectorSheetState();
}

class _VarianteSelectorSheetState extends State<_VarianteSelectorSheet> {
  Variante? _variante;
  int _cantidad = 1;
  final _notaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Por defecto selecciona la primera variante activa (si existe)
    final activas = widget.producto.variantes.where((v) => v.activo).toList();
    if (activas.isNotEmpty) _variante = activas.first;
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  double get _precio => _variante?.precio ?? widget.producto.precio;

  @override
  Widget build(BuildContext context) {
    final variantesActivas = widget.producto.variantes
        .where((v) => v.activo)
        .toList();

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

            // Título + precio dinámico
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

            if (widget.producto.descripcion != null &&
                widget.producto.descripcion!.isNotEmpty)
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
                  // ── Variantes ────────────────────────────────
                  if (variantesActivas.isNotEmpty) ...[
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
                          // Chip precio estándar (sin variante)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                'Estándar  \$${widget.producto.precio.toStringAsFixed(2)}',
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
                          // Chips de variantes
                          ...variantesActivas.map((v) {
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

                  // ── Cantidad ──────────────────────────────────
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
                      _CircleBtn(
                        icon: Icons.remove,
                        color: _cantidad > 1 ? AppColors.error : Colors.grey,
                        onTap: _cantidad > 1
                            ? () => setState(() => _cantidad--)
                            : null,
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
                      _CircleBtn(
                        icon: Icons.add,
                        color: AppColors.primary,
                        onTap: () => setState(() => _cantidad++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Nota ──────────────────────────────────────
                  TextField(
                    controller: _notaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                      hintText: 'Sin sal, extra picante...',
                      prefixIcon: Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 1,
                    maxLength: 100,
                  ),
                  const SizedBox(height: 8),

                  // ── Botón agregar ─────────────────────────────
                  ElevatedButton.icon(
                    onPressed: () {
                      // Primero llamar el callback (hace el setState en CobroDialog),
                      // luego el callback cierra ambas hojas desde un contexto válido.
                      widget.onAgregar(
                        _LineaExtra(
                          nombre: widget.producto.nombre,
                          precio: _precio,
                          cantidad: _cantidad,
                          productoId: widget.producto.id,
                          varianteId: _variante?.id,
                          varianteNombre: _variante?.nombre,
                        ),
                      );
                    },
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

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.onTap,
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
        child: Icon(icon, size: 18, color: onTap != null ? color : Colors.grey),
      ),
    );
  }
}

// ── Modelo interno de línea extra ────────────────────────────────────────────

class _LineaExtra {
  final String nombre;
  final double precio;
  final int cantidad;
  final String? productoId;
  final String? varianteId;
  final String? varianteNombre;

  /// ID del [PedidoItem] creado en DB cuando el extra viene del menú.
  final String? pedidoItemId;

  const _LineaExtra({
    required this.nombre,
    required this.precio,
    this.cantidad = 1,
    this.productoId,
    this.varianteId,
    this.varianteNombre,
    this.pedidoItemId,
  });

  double get subtotal => precio * cantidad;

  _LineaExtra withItemId(String id) => _LineaExtra(
    nombre: nombre,
    precio: precio,
    cantidad: cantidad,
    productoId: productoId,
    varianteId: varianteId,
    varianteNombre: varianteNombre,
    pedidoItemId: id,
  );
}
