import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/caja/presentation/providers/caja_provider.dart';
import 'package:restaurant_app/features/caja/presentation/widgets/cobro_dialog.dart';
import 'package:restaurant_app/features/caja/presentation/widgets/configuracion_fiscal_dialog.dart';
import 'package:restaurant_app/features/caja/presentation/widgets/ticket_dialog.dart';
import 'package:restaurant_app/features/caja/presentation/widgets/venta_card.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurant_app/features/pedidos/presentation/providers/pedidos_provider.dart';

/// Página principal del módulo de Caja.
///
/// Tres pestañas:
/// - Cobrar: pedidos finalizados listos para pagar
/// - Eventos: cotizaciones aceptadas pendientes de cobro
/// - Historial: ventas del día / todas las ventas
class CajaPage extends ConsumerStatefulWidget {
  const CajaPage({super.key});

  @override
  ConsumerState<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends ConsumerState<CajaPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  bool _verTodas = false;
  String _searchEventos = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cajaProvider.notifier).loadCaja();
      ref.read(cajaProvider.notifier).loadHistorial();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Cobro de cotización ───────────────────────────────────────

  Future<void> _cobrarCotizacion(Cotizacion cotizacion) async {
    final venta = await CobroDialog.showForCotizacion(
      context,
      cotizacion: cotizacion,
    );
    if (!mounted) return;
    // Refrescar tarjeta para mostrar extras aunque no se haya cobrado
    setState(() {});
    if (venta == null) return;

    await TicketDialog.show(context, venta: venta);

    if (mounted) {
      ref.read(cajaProvider.notifier).clearUltimaVenta();
    }
  }

  // ── Cobro ──────────────────────────────────────────────────────

  Future<void> _cobrarPedido(Pedido pedido) async {
    final venta = await CobroDialog.show(context, pedido: pedido);
    if (!mounted) return;
    // Refrescar tarjeta para mostrar extras aunque no se haya cobrado
    setState(() {});
    if (venta == null) return;

    // Sincronizar pedidosProvider: el pedido ya está 'entregado' en DB
    ref.read(pedidosProvider.notifier).loadPedidosActivos();

    // Mostrar ticket inmediatamente tras el cobro
    await TicketDialog.show(
      context,
      venta: venta,
      mesaNombre: pedido.mesaNombre,
    );

    // Limpiar referencia
    if (mounted) {
      ref.read(cajaProvider.notifier).clearUltimaVenta();
    }
  }

  void _verTicket(BuildContext context, String ventaId) async {
    final state = ref.read(cajaProvider);
    final todas = [...state.ventasHoy, ...state.todasLasVentas];
    final venta = todas.where((v) => v.id == ventaId).firstOrNull;
    if (venta == null || !mounted) return;
    await TicketDialog.show(context, venta: venta);
  }

  void _showError(String? msg) {
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _exportarCierreComercialPdf(CajaState state) async {
    final ahora = DateTime.now();
    final generado = DateFormat('dd/MM/yyyy HH:mm').format(ahora);
    final fileStamp = DateFormat('yyyyMMdd_HHmm').format(ahora);

    pw.Widget metric(String label, String value) {
      return pw.Container(
        width: 120,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'Cierre comercial · La Peña',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Generado: $generado'),
          pw.SizedBox(height: 16),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              metric('Ventas del día', _moneda.format(state.totalVentasHoy)),
              metric('Transacciones', '${state.cantidadVentasHoy}'),
              metric(
                'Ticket promedio',
                _moneda.format(state.ticketPromedioHoy),
              ),
              metric(
                'Pendiente por cobrar',
                _moneda.format(state.totalPendientePorCobrar),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Métodos de pago',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (state.ventasPorMetodo.isEmpty)
            pw.Text('Sin ventas registradas hoy.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Método', 'Monto'],
              data: [
                for (final entry in state.ventasPorMetodo.entries)
                  [entry.key.label, _moneda.format(entry.value)],
              ],
            ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'cierre_comercial_$fileStamp.pdf',
    );
  }

  void _mostrarCierreComercial(CajaState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cierre comercial del día',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_money_rounded),
                  title: const Text('Total vendido hoy'),
                  trailing: Text(
                    _moneda.format(state.totalVentasHoy),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long_rounded),
                  title: const Text('Transacciones'),
                  trailing: Text('${state.cantidadVentasHoy}'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.trending_up_rounded),
                  title: const Text('Ticket promedio'),
                  trailing: Text(_moneda.format(state.ticketPromedioHoy)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pending_actions_rounded),
                  title: const Text('Pendiente por cobrar'),
                  trailing: Text(_moneda.format(state.totalPendientePorCobrar)),
                ),
                if (state.ventasPorMetodo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Métodos de pago',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: state.ventasPorMetodo.entries
                        .map(
                          (entry) => Chip(
                            avatar: Icon(_iconForMetodo(entry.key), size: 16),
                            label: Text(
                              '${entry.key.label}: ${_moneda.format(entry.value)}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cerrar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _exportarCierreComercialPdf(state),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Exportar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cajaProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final esAdmin =
        sl<AuthChangeNotifier>().usuario?.rol == RolUsuario.administrador;

    if (state.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showError(state.errorMessage),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header con resumen ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              color: cs.surface,
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
                              'Caja',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Cierre comercial y control diario de ventas',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cierre del día',
                        onPressed: () => _mostrarCierreComercial(state),
                        icon: const Icon(Icons.summarize_rounded),
                      ),
                      if (esAdmin)
                        IconButton(
                          tooltip: 'Configuración Fiscal (SRI)',
                          onPressed: () =>
                              ConfiguracionFiscalDialog.show(context),
                          icon: const Icon(Icons.receipt_long_rounded),
                        ),
                      IconButton(
                        tooltip: 'Actualizar',
                        onPressed: () {
                          ref.read(cajaProvider.notifier).loadCaja();
                          ref.read(cajaProvider.notifier).loadHistorial();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tarjetas de resumen
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final perRow = width < 700 ? 2 : 4;
                      const spacing = 8.0;
                      final cardWidth =
                          (width - (perRow - 1) * spacing) / perRow;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _ResumenCard(
                              icon: Icons.pending_actions_outlined,
                              label: 'Por cobrar',
                              value: '${state.totalPedidosPendientes}',
                              color: cs.tertiary,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _ResumenCard(
                              icon: Icons.receipt_outlined,
                              label: 'Ventas hoy',
                              value: '${state.cantidadVentasHoy}',
                              color: cs.primary,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _ResumenCard(
                              icon: Icons.trending_up_rounded,
                              label: 'Ticket prom.',
                              value: _moneda.format(state.ticketPromedioHoy),
                              color: Colors.orange,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _ResumenCard(
                              icon: Icons.attach_money,
                              label: 'Total hoy',
                              value: _moneda.format(state.totalVentasHoy),
                              color: Colors.green,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  // Desglose por método
                  if (state.ventasPorMetodo.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: state.ventasPorMetodo.entries
                          .map(
                            (e) => Chip(
                              avatar: Icon(_iconForMetodo(e.key), size: 14),
                              label: Text(
                                '${e.key.label}: ${_moneda.format(e.value)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),

            // ── TabBar ─────────────────────────────────────────
            ColoredBox(
              color: cs.surface,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.point_of_sale_outlined, size: 16),
                        const SizedBox(width: 6),
                        const Text('Por cobrar'),
                        if (state.totalPedidosPendientes > 0) ...[
                          const SizedBox(width: 6),
                          Badge(label: Text('${state.totalPedidosPendientes}')),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_available_outlined, size: 16),
                        const SizedBox(width: 6),
                        const Text('Eventos'),
                        if (state.cotizacionesParaCobrar.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Badge(
                            label: Text(
                              '${state.cotizacionesParaCobrar.length}',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 16),
                        SizedBox(width: 6),
                        Text('Historial'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Contenido ──────────────────────────────────────
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPorCobrar(state),
                        _buildCobroCotizaciones(state),
                        _buildHistorial(state),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Por cobrar ───────────────────────────────────────────

  Widget _buildPorCobrar(CajaState state) {
    if (state.pedidosParaCobrar.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay pedidos pendientes de cobro',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los pedidos "Finalizados" aparecerán aquí',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.pedidosParaCobrar.length,
      itemBuilder: (_, i) {
        final pedido = state.pedidosParaCobrar[i];
        return _PedidoCobrarCard(
          pedido: pedido,
          onCobrar: () => _cobrarPedido(pedido),
          isProcessing: state.isProcessing,
        );
      },
    );
  }

  // ── Tab: Eventos (cotizaciones para cobrar) ───────────────────

  Widget _buildCobroCotizaciones(CajaState state) {
    final todas = state.cotizacionesParaCobrar;
    final filtradas = _searchEventos.isEmpty
        ? todas
        : todas.where((c) {
            final q = _searchEventos.toLowerCase();
            return c.clienteNombre.toLowerCase().contains(q) ||
                (c.fechaEvento?.toLowerCase().contains(q) ?? false) ||
                c.id.toLowerCase().contains(q);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por cliente, fecha…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchEventos = v),
          ),
        ),
        if (filtradas.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    todas.isEmpty
                        ? 'No hay eventos aceptados pendientes de cobro'
                        : 'Sin resultados para "$_searchEventos"',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (todas.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Las cotizaciones "Aceptadas" aparecerán aquí',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtradas.length,
              itemBuilder: (_, i) {
                final cot = filtradas[i];
                return _CotizacionEventoCard(
                  cotizacion: cot,
                  isProcessing: state.isProcessing,
                  onCobrar: () => _cobrarCotizacion(cot),
                  moneda: _moneda,
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Tab: Historial ────────────────────────────────────────────

  Widget _buildHistorial(CajaState state) {
    final ventas = _verTodas ? state.todasLasVentas : state.ventasHoy;

    return Column(
      children: [
        // Toggle hoy / todas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Mostrar:'),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Hoy'),
                  selected: !_verTodas,
                  onSelected: (_) => setState(() => _verTodas = false),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _verTodas,
                  onSelected: (_) => setState(() => _verTodas = true),
                ),
              ],
            ),
          ),
        ),
        if (ventas.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _verTodas
                        ? 'No hay ventas registradas'
                        : 'No hay ventas hoy',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: ventas.length,
              itemBuilder: (_, i) {
                final v = ventas[i];
                return VentaCard(
                  venta: v,
                  onTap: () => _verTicket(context, v.id),
                );
              },
            ),
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
}

// ── Widgets auxiliares ─────────────────────────────────────────

class _ResumenCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ResumenCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PedidoCobrarCard extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onCobrar;
  final bool isProcessing;

  const _PedidoCobrarCard({
    required this.pedido,
    required this.onCobrar,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final minutos = pedido.tiempoTranscurrido.inMinutes;
    final urgente = minutos > 45;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Mesa / número
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: urgente
                    ? Colors.orange.withValues(alpha: 0.15)
                    : cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.table_restaurant_outlined,
                    color: urgente ? Colors.orange : cs.primary,
                    size: 18,
                  ),
                  Text(
                    pedido.mesaNombre ?? 'S/N',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: urgente ? Colors.orange : cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Info del pedido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${pedido.cantidadItems} items',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (urgente)
                        const Chip(
                          label: Text(
                            'Espera larga',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: Colors.orange,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$minutos min transcurridos',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: urgente ? Colors.orange : cs.onSurfaceVariant,
                    ),
                  ),
                  if (pedido.items.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pedido.items
                          .take(2)
                          .map((i) => i.productoNombre ?? '—')
                          .join(', '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Total + botón cobrar
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Builder(
                  builder: (context) {
                    final extrasTotal = CobroDialog.extrasTotalFor(pedido.id);
                    final descuento = CobroDialog.descuentoFor(pedido.id);
                    final totalMostrado =
                        pedido.totalCalculado + extrasTotal - descuento;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${totalMostrado.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (extrasTotal > 0)
                          Text(
                            '+\$${extrasTotal.toStringAsFixed(2)} extras',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        if (descuento > 0)
                          Text(
                            '-\$${descuento.toStringAsFixed(2)} desc.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.error,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: isProcessing ? null : onCobrar,
                  icon: const Icon(Icons.point_of_sale, size: 16),
                  label: const Text('Cobrar'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de cotización (evento) para cobrar ──────────────────

class _CotizacionEventoCard extends StatelessWidget {
  final Cotizacion cotizacion;
  final bool isProcessing;
  final VoidCallback onCobrar;
  final NumberFormat moneda;

  const _CotizacionEventoCard({
    required this.cotizacion,
    required this.isProcessing,
    required this.onCobrar,
    required this.moneda,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = cotizacion;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Ícono del evento
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),

            // Info de la cotización
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.clienteNombre,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (c.fechaEvento != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          c.fechaEvento!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${c.items.length} ítem(s)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Total + botón cobrar
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Builder(
                  builder: (context) {
                    final extrasTotal = CobroDialog.extrasTotalFor(c.id);
                    final descuento = CobroDialog.descuentoFor(c.id);
                    final base = c.items.fold(0.0, (s, i) => s + i.subtotal);
                    final totalMostrado = base + extrasTotal - descuento;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${totalMostrado.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (extrasTotal > 0)
                          Text(
                            '+\$${extrasTotal.toStringAsFixed(2)} extras',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        if (descuento > 0)
                          Text(
                            '-\$${descuento.toStringAsFixed(2)} desc.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.error,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: isProcessing ? null : onCobrar,
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Cobrar'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
