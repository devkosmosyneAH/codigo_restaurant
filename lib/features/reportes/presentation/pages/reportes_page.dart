import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_mesero.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_metodo_pago.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_producto_vendido.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_resumen.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_venta_dia.dart';
import 'package:restaurant_app/features/reportes/presentation/providers/reportes_provider.dart';
import 'package:restaurant_app/services/report_export_access.dart'
    as report_export_access;

/// Página principal de Reportes y Analítica.
///
/// Muestra KPIs, gráfica de ventas por día (BarChart),
/// top productos, métodos de pago (PieChart) y ranking de meseros.
class ReportesPage extends ConsumerStatefulWidget {
  const ReportesPage({super.key});

  @override
  ConsumerState<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends ConsumerState<ReportesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _periodoDescripcion(FiltroFecha filtro) {
    switch (filtro) {
      case FiltroFecha.hoy:
        return 'Resumen del día actual';
      case FiltroFecha.semana:
        return 'Acumulado de los últimos 7 días';
      case FiltroFecha.mes:
        return 'Acumulado de los últimos 30 días';
      case FiltroFecha.trimestre:
        return 'Acumulado del último trimestre';
      case FiltroFecha.personalizado:
        return 'Rango personalizado';
    }
  }

  String _rangoActivoLabel(ReportesState state) {
    final now = DateTime.now();
    final inicio = state.fechaInicioActiva(now);
    final fin = state.fechaFinActiva(now);
    return '${DateFormat('dd/MM/yyyy').format(inicio)} - '
        '${DateFormat('dd/MM/yyyy').format(fin)}';
  }

  Future<void> _exportarReportePdf(ReportesState state) async {
    if (!mounted) return;

    final resumen = state.resumen;
    final hasData =
        (resumen != null && resumen.tieneVentas) ||
        state.ventasPorDia.isNotEmpty ||
        state.topProductos.isNotEmpty;

    if (!hasData) {
      _showSnackBar('No hay datos suficientes para exportar el reporte.');
      return;
    }

    final pdf = pw.Document();
    final ahora = DateTime.now();
    final generado = DateFormat('dd/MM/yyyy HH:mm').format(ahora);
    final fileStamp = DateFormat('yyyyMMdd_HHmm').format(ahora);
    final mejorDia = state.ventasPorDia.isEmpty
        ? null
        : state.ventasPorDia.reduce((a, b) => a.total >= b.total ? a : b);
    final topProducto = state.topProductos.isEmpty
        ? null
        : state.topProductos.first;
    final topMetodo = state.ventasPorMetodo.isEmpty
        ? null
        : state.ventasPorMetodo.reduce((a, b) => a.total >= b.total ? a : b);
    final topMesero = state.ventasPorMesero.isEmpty
        ? null
        : state.ventasPorMesero.reduce((a, b) => a.total >= b.total ? a : b);

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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'Reporte ejecutivo · La Peña',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${_periodoDescripcion(state.filtro)} · ${_rangoActivoLabel(state)}',
          ),
          pw.Text('Generado: $generado'),
          pw.SizedBox(height: 16),
          if (resumen != null && resumen.tieneVentas)
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                metric('Ventas', _moneda.format(resumen.totalVentas)),
                metric('Transacciones', '${resumen.cantidadVentas}'),
                metric('Ticket prom.', _moneda.format(resumen.promedioTicket)),
                metric('Máximo', _moneda.format(resumen.ticketMaximo)),
              ],
            ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Insights rápidos',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (mejorDia != null)
            pw.Bullet(
              text:
                  'Mejor día: ${mejorDia.fecha} · ${_moneda.format(mejorDia.total)}',
            ),
          if (topProducto != null)
            pw.Bullet(
              text:
                  'Producto líder: ${topProducto.nombre} · ${topProducto.cantidadVendida} uds.',
            ),
          if (topMetodo != null)
            pw.Bullet(
              text:
                  'Método dominante: ${topMetodo.metodoPago.label} · ${_moneda.format(topMetodo.total)}',
            ),
          if (topMesero != null)
            pw.Bullet(
              text:
                  'Mejor desempeño: ${topMesero.nombre} · ${_moneda.format(topMesero.total)}',
            ),
          if (state.topProductos.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Top productos',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Producto', 'Cantidad', 'Total'],
              data: [
                for (final entry
                    in state.topProductos.take(8).toList().asMap().entries)
                  [
                    '${entry.key + 1}',
                    entry.value.nombre,
                    '${entry.value.cantidadVendida}',
                    _moneda.format(entry.value.totalIngresado),
                  ],
              ],
            ),
          ],
          if (state.ventasPorMetodo.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Métodos de pago',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Método', 'Tx', 'Total'],
              data: [
                for (final metodo in state.ventasPorMetodo)
                  [
                    metodo.metodoPago.label,
                    '${metodo.cantidad}',
                    _moneda.format(metodo.total),
                  ],
              ],
            ),
          ],
        ],
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'reporte_${state.filtro.name}_$fileStamp.pdf',
      );
    } catch (_) {
      _showSnackBar('No se pudo exportar el PDF del reporte.');
    }
  }

  Future<void> _exportarReporteCsv(ReportesState state) async {
    final resumen = state.resumen;
    final hasData =
        (resumen != null && resumen.tieneVentas) ||
        state.ventasPorDia.isNotEmpty ||
        state.topProductos.isNotEmpty;

    if (!hasData) {
      _showSnackBar('No hay datos suficientes para exportar el CSV.');
      return;
    }

    String esc(Object? value) {
      final text = (value ?? '').toString().replaceAll('"', '""');
      return '"$text"';
    }

    final ahora = DateTime.now();
    final fileStamp = DateFormat('yyyyMMdd_HHmm').format(ahora);
    final csv = StringBuffer()
      ..writeln(esc('La Peña - Reporte ejecutivo'))
      ..writeln('${esc('Período')};${esc(_periodoDescripcion(state.filtro))}')
      ..writeln('${esc('Rango')};${esc(_rangoActivoLabel(state))}')
      ..writeln(
        '${esc('Generado')};${esc(DateFormat('dd/MM/yyyy HH:mm').format(ahora))}',
      )
      ..writeln();

    if (resumen != null && resumen.tieneVentas) {
      csv
        ..writeln('${esc('Resumen')};${esc('Valor')}')
        ..writeln(
          '${esc('Total ventas')};${esc(resumen.totalVentas.toStringAsFixed(2))}',
        )
        ..writeln('${esc('Transacciones')};${esc(resumen.cantidadVentas)}')
        ..writeln(
          '${esc('Ticket promedio')};${esc(resumen.promedioTicket.toStringAsFixed(2))}',
        )
        ..writeln(
          '${esc('Ticket máximo')};${esc(resumen.ticketMaximo.toStringAsFixed(2))}',
        )
        ..writeln(
          '${esc('Ticket mínimo')};${esc(resumen.ticketMinimo.toStringAsFixed(2))}',
        )
        ..writeln();
    }

    if (state.ventasPorDia.isNotEmpty) {
      csv
        ..writeln(esc('Ventas por día'))
        ..writeln('${esc('Fecha')};${esc('Total')};${esc('Ventas')}');
      for (final item in state.ventasPorDia) {
        csv.writeln(
          '${esc(item.fecha)};${esc(item.total.toStringAsFixed(2))};${esc(item.cantidadVentas)}',
        );
      }
      csv.writeln();
    }

    if (state.topProductos.isNotEmpty) {
      csv
        ..writeln(esc('Productos'))
        ..writeln(
          '${esc('Producto')};${esc('Categoría')};${esc('Cantidad')};${esc('Total')}',
        );
      for (final item in state.topProductos) {
        csv.writeln(
          '${esc(item.nombre)};${esc(item.categoriaNombre ?? 'Sin categoría')};${esc(item.cantidadVendida)};${esc(item.totalIngresado.toStringAsFixed(2))}',
        );
      }
      csv.writeln();
    }

    if (state.ventasPorMetodo.isNotEmpty) {
      csv
        ..writeln(esc('Métodos de pago'))
        ..writeln(
          '${esc('Método')};${esc('Transacciones')};${esc('Total')};${esc('Porcentaje')}',
        );
      for (final item in state.ventasPorMetodo) {
        csv.writeln(
          '${esc(item.metodoPago.label)};${esc(item.cantidad)};${esc(item.total.toStringAsFixed(2))};${esc(item.porcentaje.toStringAsFixed(2))}',
        );
      }
      csv.writeln();
    }

    if (state.ventasPorMesero.isNotEmpty) {
      csv
        ..writeln(esc('Meseros'))
        ..writeln('${esc('Nombre')};${esc('Pedidos')};${esc('Total')}');
      for (final item in state.ventasPorMesero) {
        csv.writeln(
          '${esc(item.nombre)};${esc(item.cantidadPedidos)};${esc(item.total.toStringAsFixed(2))}',
        );
      }
    }

    final result = await report_export_access.exportCsvReport(
      fileName: 'reporte_${state.filtro.name}_$fileStamp.csv',
      csvContent: csv.toString(),
    );

    if (result['cancelled'] == true) return;

    _showSnackBar(
      result['message']?.toString() ?? 'No se pudo exportar el reporte CSV.',
    );
  }

  Future<void> _seleccionarRangoPersonalizado(ReportesState state) async {
    final now = DateTime.now();
    final initialStart = state.fechaInicioActiva(now);
    final initialEnd = state.fechaFinActiva(now);

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Selecciona el rango del reporte',
      confirmText: 'Aplicar',
      cancelText: 'Cancelar',
      locale: const Locale('es', 'ES'),
    );

    if (range == null || !mounted) return;

    await ref
        .read(reportesProvider.notifier)
        .cambiarRangoPersonalizado(range.start, range.end);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportesProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: Column(
        children: [
          _Header(
            filtro: state.filtro,
            isLoading: state.isLoading,
            rangoActivoLabel: _rangoActivoLabel(state),
            onFiltroChanged: (f) =>
                ref.read(reportesProvider.notifier).cambiarFiltro(f),
            onRefresh: () =>
                ref.read(reportesProvider.notifier).cargarReportes(),
            onSelectCustomRange: () => _seleccionarRangoPersonalizado(state),
            onExportPdf: state.isLoading
                ? null
                : () => _exportarReportePdf(state),
            onExportCsv: state.isLoading
                ? null
                : () => _exportarReporteCsv(state),
          ),
          ColoredBox(
            color: colors.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_rounded), text: 'Resumen'),
                Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Ventas'),
                Tab(
                  icon: Icon(Icons.restaurant_menu_rounded),
                  text: 'Productos',
                ),
                Tab(icon: Icon(Icons.credit_card_rounded), text: 'Métodos'),
                Tab(icon: Icon(Icons.backup_rounded), text: 'Respaldos'),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                ? _ErrorView(
                    error: state.error!,
                    onRetry: () =>
                        ref.read(reportesProvider.notifier).cargarReportes(),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TabResumen(
                        resumen: state.resumen,
                        ventasPorDia: state.ventasPorDia,
                        productos: state.topProductos,
                        metodos: state.ventasPorMetodo,
                        meseros: state.ventasPorMesero,
                        filtro: state.filtro,
                        moneda: _moneda,
                        resumenAnterior: state.resumenPeriodoAnterior,
                      ),
                      _TabVentas(
                        ventasPorDia: state.ventasPorDia,
                        moneda: _moneda,
                        resumenAnterior: state.resumenPeriodoAnterior,
                      ),
                      _TabProductos(
                        productos: state.topProductos,
                        moneda: _moneda,
                      ),
                      _TabMetodos(
                        metodos: state.ventasPorMetodo,
                        meseros: state.ventasPorMesero,
                        moneda: _moneda,
                      ),
                      _TabRespaldos(onShowMessage: _showSnackBar),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.filtro,
    required this.isLoading,
    required this.rangoActivoLabel,
    required this.onFiltroChanged,
    required this.onRefresh,
    required this.onSelectCustomRange,
    this.onExportPdf,
    this.onExportCsv,
  });

  final FiltroFecha filtro;
  final bool isLoading;
  final String rangoActivoLabel;
  final ValueChanged<FiltroFecha> onFiltroChanged;
  final VoidCallback onRefresh;
  final VoidCallback onSelectCustomRange;
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportCsv;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reportes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Vista ejecutiva de ventas, productos, métodos y respaldos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Exportar reporte',
                enabled: !isLoading,
                onSelected: (value) {
                  if (value == 'pdf') {
                    onExportPdf?.call();
                  } else if (value == 'csv') {
                    onExportCsv?.call();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'pdf',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Exportar PDF'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'csv',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.table_view_rounded),
                      title: Text('Exportar CSV'),
                    ),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.ios_share_rounded),
                ),
              ),
              IconButton(
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed: isLoading ? null : onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...FiltroFecha.values.map(
                (f) => ChoiceChip(
                  label: Text(f.label),
                  selected: filtro == f,
                  onSelected: (_) => onFiltroChanged(f),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(rangoActivoLabel),
                onPressed: onSelectCustomRange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Error View ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

// ── Tab Resumen ────────────────────────────────────────────────────────────────

class _TabResumen extends StatelessWidget {
  const _TabResumen({
    required this.resumen,
    required this.ventasPorDia,
    required this.productos,
    required this.metodos,
    required this.meseros,
    required this.filtro,
    required this.moneda,
    this.resumenAnterior,
  });

  final ResumenVentas? resumen;
  final ResumenVentas? resumenAnterior;
  final List<VentaPorDia> ventasPorDia;
  final List<ProductoVendido> productos;
  final List<VentaPorMetodo> metodos;
  final List<VentaPorMesero> meseros;
  final FiltroFecha filtro;
  final NumberFormat moneda;

  @override
  Widget build(BuildContext context) {
    if (resumen == null || !resumen!.tieneVentas) {
      return const _EmptyState(
        mensaje: 'Sin ventas en el período seleccionado',
      );
    }

    final r = resumen!;
    final mejorDia = ventasPorDia.isEmpty
        ? null
        : ventasPorDia.reduce((a, b) => a.total >= b.total ? a : b);
    final topProducto = productos.isEmpty ? null : productos.first;
    final topMetodo = metodos.isEmpty
        ? null
        : metodos.reduce((a, b) => a.total >= b.total ? a : b);
    final meserosReales = meseros
        .where((m) => m.nombre != 'Sin asignar')
        .toList();
    final topMesero = meserosReales.isEmpty
        ? null
        : meserosReales.reduce((a, b) => a.total >= b.total ? a : b);
    final diasConVentas = ventasPorDia.isEmpty ? 1 : ventasPorDia.length;
    final promedioDiario = r.totalVentas / diasConVentas;
    double? variacionVsAnterior;
    if (resumenAnterior != null && resumenAnterior!.totalVentas > 0) {
      variacionVsAnterior =
          ((r.totalVentas - resumenAnterior!.totalVentas) /
              resumenAnterior!.totalVentas) *
          100;
    }
    final totalUnidades = productos.fold<int>(
      0,
      (sum, item) => sum + item.cantidadVendida,
    );
    final participacionTopProducto = topProducto == null || totalUnidades == 0
        ? 0.0
        : (topProducto.cantidadVendida / totalUnidades) * 100;
    final participacionTopMetodo = topMetodo == null
        ? 0.0
        : topMetodo.porcentaje;
    final rangoLabel =
        '${DateFormat('dd/MM').format(r.fechaInicio)} - ${DateFormat('dd/MM').format(r.fechaFin)}';

    String saludLabel;
    Color saludColor;
    String saludDetalle;

    if (r.totalVentas >= 1500 || r.promedioTicket >= 28) {
      saludLabel = 'Excelente ritmo';
      saludColor = Colors.green;
      saludDetalle = 'Buen volumen y ticket promedio saludable.';
    } else if (r.totalVentas >= 700 || r.promedioTicket >= 18) {
      saludLabel = 'Buen desempeño';
      saludColor = Colors.orange;
      saludDetalle = 'Hay movimiento sólido con margen para subir el ticket.';
    } else {
      saludLabel = 'Atención comercial';
      saludColor = Colors.redAccent;
      saludDetalle = 'Conviene empujar combos y ventas sugeridas.';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: saludColor.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: saludColor.withValues(alpha: 0.16),
                      child: Icon(Icons.insights_rounded, color: saludColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumen ejecutivo del período',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$saludLabel · $saludDetalle',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(rangoLabel),
                    ),
                    Chip(
                      avatar: const Icon(
                        Icons.calendar_view_week_rounded,
                        size: 18,
                      ),
                      label: Text('$diasConVentas día(s) con ventas'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.speed_rounded, size: 18),
                      label: Text(
                        'Promedio diario ${moneda.format(promedioDiario)}',
                      ),
                    ),
                    if (variacionVsAnterior != null)
                      Chip(
                        avatar: Icon(
                          variacionVsAnterior >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 18,
                          color: variacionVsAnterior >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                        label: Text(
                          'vs anterior: '
                          '${variacionVsAnterior >= 0 ? '+' : ''}'
                          '${variacionVsAnterior.toStringAsFixed(1)}%',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InsightTile(
                  title: 'Período',
                  value: filtro.label,
                  subtitle: 'Rango activo del reporte',
                  icon: Icons.date_range_rounded,
                  color: Colors.indigo,
                ),
                _InsightTile(
                  title: 'Ritmo diario',
                  value: moneda.format(promedioDiario),
                  subtitle: 'Promedio por día con ventas',
                  icon: Icons.timeline_rounded,
                  color: Colors.cyan,
                ),
                if (mejorDia != null)
                  _InsightTile(
                    title: 'Mejor día',
                    value: moneda.format(mejorDia.total),
                    subtitle: mejorDia.fecha,
                    icon: Icons.calendar_month_rounded,
                    color: Colors.teal,
                  ),
                if (topProducto != null)
                  _InsightTile(
                    title: 'Top producto',
                    value: '${topProducto.cantidadVendida} uds.',
                    subtitle: topProducto.nombre,
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.deepOrange,
                  ),
                if (topMetodo != null)
                  _InsightTile(
                    title: 'Pago dominante',
                    value: '${participacionTopMetodo.toStringAsFixed(0)}%',
                    subtitle: topMetodo.metodoPago.label,
                    icon: Icons.payments_rounded,
                    color: Colors.green,
                  ),
                if (topMesero != null)
                  _InsightTile(
                    title: 'Mejor desempeño',
                    value: topMesero.nombre,
                    subtitle: moneda.format(topMesero.total),
                    icon: Icons.workspace_premium_rounded,
                    color: Colors.purple,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final maxExtent = width < 520
                ? 260.0
                : width < 900
                ? 300.0
                : 360.0;
            final aspect = width < 520 ? 1.35 : 2.0;
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: maxExtent,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: aspect,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (_, i) {
                final cards = [
                  _KpiCard(
                    title: 'Total ventas',
                    value: moneda.format(r.totalVentas),
                    icon: Icons.attach_money_rounded,
                    color: Colors.green,
                  ),
                  _KpiCard(
                    title: 'Transacciones',
                    value: r.cantidadVentas.toString(),
                    icon: Icons.receipt_long_rounded,
                    color: Colors.blue,
                  ),
                  _KpiCard(
                    title: 'Ticket promedio',
                    value: moneda.format(r.promedioTicket),
                    icon: Icons.trending_up_rounded,
                    color: Colors.orange,
                  ),
                  _KpiCard(
                    title: 'Ticket máximo',
                    value: moneda.format(r.ticketMaximo),
                    icon: Icons.star_rounded,
                    color: Colors.purple,
                  ),
                ];
                return cards[i];
              },
            );
          },
        ),
        const SizedBox(height: 16),
        const _SectionHeader(
          title: 'Radar de decisiones',
          subtitle: 'Señales rápidas para saber qué reforzar o mantener.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _RecommendationTile(
                  icon: Icons.favorite_rounded,
                  color: saludColor,
                  title: saludLabel,
                  subtitle: saludDetalle,
                ),
                if (variacionVsAnterior != null)
                  _RecommendationTile(
                    icon: variacionVsAnterior >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: variacionVsAnterior >= 0
                        ? Colors.green
                        : Colors.redAccent,
                    title: variacionVsAnterior >= 0
                        ? 'Crecimiento vs período anterior: +${variacionVsAnterior.toStringAsFixed(1)}%'
                        : 'Caída vs período anterior: ${variacionVsAnterior.toStringAsFixed(1)}%',
                    subtitle: variacionVsAnterior >= 0
                        ? 'El período actual supera al equivalente anterior. Buen ritmo.'
                        : 'Caída respecto al período anterior. Revisa ofertas o turnos.',
                  ),
                if (diasConVentas <
                        (r.fechaFin.difference(r.fechaInicio).inDays + 1) / 2 &&
                    (r.fechaFin.difference(r.fechaInicio).inDays + 1) > 3)
                  _RecommendationTile(
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                    title: 'Baja frecuencia de ventas',
                    subtitle:
                        'Solo $diasConVentas de '
                        '${r.fechaFin.difference(r.fechaInicio).inDays + 1} '
                        'días tuvieron actividad. '
                        'Analiza días sin ventas para detectar patrones.',
                  ),
                _RecommendationTile(
                  icon: Icons.restaurant_menu_rounded,
                  color: Colors.deepOrange,
                  title: topProducto == null
                      ? 'Menú sin líder claro'
                      : participacionTopProducto > 70
                      ? 'Alta dependencia de ${topProducto.nombre}'
                      : '${topProducto.nombre} lidera el período',
                  subtitle: topProducto == null
                      ? 'Todavía no hay suficiente movimiento para detectar un producto estrella.'
                      : participacionTopProducto > 70
                      ? 'Concentra ${participacionTopProducto.toStringAsFixed(0)}% de las unidades. Diversifica el menú.'
                      : 'Aporta ${participacionTopProducto.toStringAsFixed(0)}% de las unidades registradas.',
                ),
                _RecommendationTile(
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.green,
                  title: topMetodo == null
                      ? 'Sin método dominante'
                      : participacionTopMetodo > 80
                      ? 'Concentración en ${topMetodo.metodoPago.label}'
                      : '${topMetodo.metodoPago.label} lidera los cobros',
                  subtitle: topMetodo == null
                      ? 'Aún no hay reparto por métodos de pago.'
                      : participacionTopMetodo > 80
                      ? 'Representa ${participacionTopMetodo.toStringAsFixed(1)}% del total. Incentiva métodos alternativos.'
                      : 'Representa ${participacionTopMetodo.toStringAsFixed(1)}% del total cobrado.',
                ),
                _RecommendationTile(
                  icon: Icons.receipt_long_rounded,
                  color: r.promedioTicket < 15 ? Colors.orange : Colors.teal,
                  title: r.promedioTicket < 15
                      ? 'Ticket promedio bajo: ${moneda.format(r.promedioTicket)}'
                      : 'Ticket promedio: ${moneda.format(r.promedioTicket)}',
                  subtitle: r.promedioTicket < 15
                      ? 'Considera combos, adicionales o ventas sugeridas para subir el ticket.'
                      : 'Ticket saludable. Mínimo registrado: ${moneda.format(r.ticketMinimo)}.',
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab Ventas ─────────────────────────────────────────────────────────────────

class _TabVentas extends StatelessWidget {
  const _TabVentas({
    required this.ventasPorDia,
    required this.moneda,
    this.resumenAnterior,
  });

  final List<VentaPorDia> ventasPorDia;
  final NumberFormat moneda;
  final ResumenVentas? resumenAnterior;

  @override
  Widget build(BuildContext context) {
    if (ventasPorDia.isEmpty) {
      return const _EmptyState(
        mensaje: 'Sin ventas en el período seleccionado',
      );
    }

    final maxVal = ventasPorDia
        .map((v) => v.total)
        .reduce((a, b) => a > b ? a : b);
    final colors = Theme.of(context).colorScheme;
    final mejorDia = ventasPorDia.reduce((a, b) => a.total >= b.total ? a : b);
    final diaMasBajo = ventasPorDia.reduce(
      (a, b) => a.total <= b.total ? a : b,
    );
    final totalPeriodo = ventasPorDia.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final totalVentas = ventasPorDia.fold<int>(
      0,
      (sum, item) => sum + item.cantidadVentas,
    );
    final promedioDiario = totalPeriodo / ventasPorDia.length;
    final ticketPromedio = totalVentas == 0 ? 0.0 : totalPeriodo / totalVentas;
    double? variacionVsAnterior;
    if (resumenAnterior != null && resumenAnterior!.totalVentas > 0) {
      variacionVsAnterior =
          ((totalPeriodo - resumenAnterior!.totalVentas) /
              resumenAnterior!.totalVentas) *
          100;
    }
    // Tendencia interna: último vs. primer día del período
    final primero = ventasPorDia.first.total;
    final ultimo = ventasPorDia.last.total;
    final variacionInterna = primero == 0
        ? 0.0
        : ((ultimo - primero) / primero) * 100;

    final ventasReversed = ventasPorDia.reversed.toList();
    // 9 items estáticos antes de la lista dinámica de días.
    const staticCount = 9;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: staticCount + ventasReversed.length,
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return const _SectionHeader(
              title: 'Comportamiento de ventas',
              subtitle:
                  'Detecta días fuertes, valles y ritmo comercial del período.',
            );
          case 1:
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InsightTile(
                  title: 'Total del período',
                  value: moneda.format(totalPeriodo),
                  subtitle: '${ventasPorDia.length} día(s) analizados',
                  icon: Icons.ssid_chart_rounded,
                  color: Colors.green,
                ),
                _InsightTile(
                  title: 'Promedio diario',
                  value: moneda.format(promedioDiario),
                  subtitle: 'Volumen diario esperado',
                  icon: Icons.timeline_rounded,
                  color: Colors.blue,
                ),
                _InsightTile(
                  title: 'Mejor día',
                  value: moneda.format(mejorDia.total),
                  subtitle: mejorDia.fecha,
                  icon: Icons.arrow_upward_rounded,
                  color: Colors.teal,
                ),
                if (variacionVsAnterior != null)
                  _InsightTile(
                    title: 'Vs período anterior',
                    value:
                        '${variacionVsAnterior >= 0 ? '+' : ''}${variacionVsAnterior.toStringAsFixed(1)}%',
                    subtitle:
                        '${moneda.format(resumenAnterior!.totalVentas)} período ant.',
                    icon: variacionVsAnterior >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: variacionVsAnterior >= 0
                        ? Colors.green
                        : Colors.deepOrange,
                  )
                else
                  _InsightTile(
                    title: 'Tendencia',
                    value:
                        '${variacionInterna >= 0 ? '+' : ''}${variacionInterna.toStringAsFixed(1)}%',
                    subtitle: 'Último vs. primer día',
                    icon: variacionInterna >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: variacionInterna >= 0
                        ? Colors.green
                        : Colors.deepOrange,
                  ),
              ],
            );
          case 2:
            return const SizedBox(height: 12);
          case 3:
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ventas por día',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'El gráfico ayuda a detectar picos y días con menor movimiento.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          maxY: maxVal * 1.2,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: colors.outlineVariant,
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 56,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    '\$${_compactVal(value)}',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= ventasPorDia.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final parts = ventasPorDia[idx].fecha.split(
                                    '-',
                                  );
                                  final label = parts.length == 3
                                      ? '${parts[2]}/${parts[1]}'
                                      : ventasPorDia[idx].fecha;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(ventasPorDia.length, (i) {
                            final venta = ventasPorDia[i];
                            final isPeak = venta.fecha == mejorDia.fecha;
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: venta.total,
                                  color: isPeak
                                      ? colors.tertiary
                                      : colors.primary,
                                  width: ventasPorDia.length > 20 ? 6 : 14,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          }),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                    final v = ventasPorDia[group.x];
                                    return BarTooltipItem(
                                      '${v.fecha}\n${moneda.format(rod.toY)}\n'
                                      '${v.cantidadVentas} venta(s)',
                                      const TextStyle(fontSize: 12),
                                    );
                                  },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          case 4:
            return const SizedBox(height: 12);
          case 5:
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _RecommendationTile(
                      icon: Icons.workspace_premium_rounded,
                      color: Colors.teal,
                      title: 'Mejor jornada: ${mejorDia.fecha}',
                      subtitle:
                          '${moneda.format(mejorDia.total)} en ${mejorDia.cantidadVentas} venta(s).',
                    ),
                    _RecommendationTile(
                      icon: Icons.trending_down_rounded,
                      color: Colors.deepOrange,
                      title: 'Día más bajo: ${diaMasBajo.fecha}',
                      subtitle:
                          'Úsalo para revisar promociones o turnos flojos (${moneda.format(diaMasBajo.total)}).',
                    ),
                    _RecommendationTile(
                      icon: Icons.receipt_rounded,
                      color: Colors.indigo,
                      title: 'Ticket operativo promedio',
                      subtitle:
                          '${moneda.format(ticketPromedio)} por transacción en este período.',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            );
          case 6:
            return const SizedBox(height: 16);
          case 7:
            return Text(
              'Detalle diario',
              style: Theme.of(context).textTheme.titleSmall,
            );
          case 8:
            return const SizedBox(height: 8);
          default:
            final v = ventasReversed[index - staticCount];
            final esPico = v.fecha == mejorDia.fecha;
            final esBajo = v.fecha == diaMasBajo.fecha;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: esPico
                    ? Colors.teal.withValues(alpha: 0.16)
                    : esBajo
                    ? Colors.deepOrange.withValues(alpha: 0.14)
                    : colors.surfaceContainerHigh,
                child: Icon(
                  esPico
                      ? Icons.arrow_upward_rounded
                      : esBajo
                      ? Icons.arrow_downward_rounded
                      : Icons.calendar_today_rounded,
                  size: 14,
                  color: esPico
                      ? Colors.teal
                      : esBajo
                      ? Colors.deepOrange
                      : colors.onSurfaceVariant,
                ),
              ),
              title: Text(v.fecha),
              subtitle: Text('${v.cantidadVentas} venta(s)'),
              trailing: Text(
                moneda.format(v.total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            );
        }
      },
    );
  }

  String _compactVal(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }
}

// ── Tab Productos ──────────────────────────────────────────────────────────────

class _TabProductos extends StatelessWidget {
  const _TabProductos({required this.productos, required this.moneda});

  final List<ProductoVendido> productos;
  final NumberFormat moneda;

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) {
      return const _EmptyState(mensaje: 'Sin productos vendidos en el período');
    }

    final maxCantidad = productos.first.cantidadVendida.toDouble();
    final colors = Theme.of(context).colorScheme;
    final totalUnidades = productos.fold<int>(
      0,
      (sum, item) => sum + item.cantidadVendida,
    );
    final totalIngresos = productos.fold<double>(
      0,
      (sum, item) => sum + item.totalIngresado,
    );
    final topProducto = productos.first;
    final top3Unidades = productos
        .take(3)
        .fold<int>(0, (sum, item) => sum + item.cantidadVendida);
    final concentracionTop3 = totalUnidades == 0
        ? 0.0
        : (top3Unidades / totalUnidades) * 100;

    // 7 items estáticos antes de la lista dinámica de productos.
    const staticCount = 7;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: staticCount + productos.length,
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return const _SectionHeader(
              title: 'Mix del menú',
              subtitle:
                  'Identifica productos líderes y detecta dependencia de pocos platos.',
            );
          case 1:
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InsightTile(
                  title: 'Productos analizados',
                  value: '${productos.length}',
                  subtitle: 'Top del período',
                  icon: Icons.inventory_2_rounded,
                  color: Colors.indigo,
                ),
                _InsightTile(
                  title: 'Unidades',
                  value: '$totalUnidades',
                  subtitle: 'Vendidas en el top actual',
                  icon: Icons.sell_rounded,
                  color: Colors.teal,
                ),
                _InsightTile(
                  title: 'Ingresos top',
                  value: moneda.format(totalIngresos),
                  subtitle: 'Aporte del top mostrado',
                  icon: Icons.attach_money_rounded,
                  color: Colors.green,
                ),
                _InsightTile(
                  title: 'Concentración top 3',
                  value: '${concentracionTop3.toStringAsFixed(0)}%',
                  subtitle: 'Participación en unidades',
                  icon: Icons.pie_chart_rounded,
                  color: Colors.deepOrange,
                ),
              ],
            );
          case 2:
            return const SizedBox(height: 12);
          case 3:
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Producto líder del período',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ShareBarTile(
                      label: topProducto.nombre,
                      percentage: totalUnidades == 0
                          ? 0
                          : (topProducto.cantidadVendida / totalUnidades) * 100,
                      value: '${topProducto.cantidadVendida} uds.',
                      subtitle: moneda.format(topProducto.totalIngresado),
                      color: Colors.deepOrange,
                    ),
                  ],
                ),
              ),
            );
          case 4:
            return const SizedBox(height: 16);
          case 5:
            return Text(
              'Top ${productos.length} productos más vendidos',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            );
          case 6:
            return const SizedBox(height: 12);
          default:
            final i = index - staticCount;
            final p = productos[i];
            final pct = maxCantidad > 0 ? p.cantidadVendida / maxCantidad : 0.0;
            final share = totalUnidades == 0
                ? 0.0
                : (p.cantidadVendida / totalUnidades) * 100;
            final ingresoPromedio = p.cantidadVendida == 0
                ? 0.0
                : p.totalIngresado / p.cantidadVendida;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colors.primaryContainer,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (p.categoriaNombre != null)
                                Text(
                                  p.categoriaNombre!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.outline,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${p.cantidadVendida} uds.',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              moneda.format(p.totalIngresado),
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: pct,
                            borderRadius: BorderRadius.circular(4),
                            backgroundColor: colors.surfaceContainerHigh,
                            color: i == 0
                                ? colors.primary
                                : i == 1
                                ? colors.secondary
                                : colors.tertiary,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${share.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingreso promedio por unidad: ${moneda.format(ingresoPromedio)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}

// ── Tab Métodos ────────────────────────────────────────────────────────────────

class _TabMetodos extends StatefulWidget {
  const _TabMetodos({
    required this.metodos,
    required this.meseros,
    required this.moneda,
  });

  final List<VentaPorMetodo> metodos;
  final List<VentaPorMesero> meseros;
  final NumberFormat moneda;

  @override
  State<_TabMetodos> createState() => _TabMetodosState();
}

class _TabMetodosState extends State<_TabMetodos> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.metodos.isEmpty) {
      return const _EmptyState(
        mensaje: 'Sin ventas en el período seleccionado',
      );
    }

    final colors = Theme.of(context).colorScheme;
    final metodoColors = [
      colors.primary,
      colors.secondary,
      colors.tertiary,
      colors.error,
    ];
    final dominante = widget.metodos.reduce(
      (a, b) => a.total >= b.total ? a : b,
    );
    final meserosReales = widget.meseros
        .where((m) => m.nombre != 'Sin asignar')
        .toList();
    final topMesero = meserosReales.isEmpty
        ? null
        : meserosReales.reduce((a, b) => a.total >= b.total ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(
          title: 'Cobros y equipo',
          subtitle:
              'Revisa cómo pagan los clientes y quién lidera el desempeño.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _InsightTile(
              title: 'Método dominante',
              value: _labelMetodo(dominante.metodoPago),
              subtitle: '${dominante.porcentaje.toStringAsFixed(1)}% del total',
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.green,
            ),
            _InsightTile(
              title: 'Métodos activos',
              value: '${widget.metodos.length}',
              subtitle: 'Canales de cobro usados',
              icon: Icons.credit_card_rounded,
              color: Colors.indigo,
            ),
            if (topMesero != null)
              _InsightTile(
                title: 'Mejor mesero',
                value: topMesero.nombre,
                subtitle: widget.moneda.format(topMesero.total),
                icon: Icons.emoji_events_rounded,
                color: Colors.purple,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  height: 180,
                  width: 180,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!mounted) return;

                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: List.generate(widget.metodos.length, (i) {
                        final m = widget.metodos[i];
                        final isTouched = _touchedIndex == i;
                        return PieChartSectionData(
                          value: m.total,
                          color: metodoColors[i % metodoColors.length],
                          radius: isTouched ? 70 : 60,
                          title: '${m.porcentaje.toStringAsFixed(1)}%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(widget.metodos.length, (i) {
                      final m = widget.metodos[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: metodoColors[i % metodoColors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _labelMetodo(m.metodoPago),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${m.cantidad} tx  •  '
                                    '${widget.moneda.format(m.total)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distribución de cobros',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...widget.metodos.asMap().entries.map((entry) {
                  final i = entry.key;
                  final metodo = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ShareBarTile(
                      label: _labelMetodo(metodo.metodoPago),
                      percentage: metodo.porcentaje,
                      value: widget.moneda.format(metodo.total),
                      subtitle: '${metodo.cantidad} transacción(es)',
                      color: metodoColors[i % metodoColors.length],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        if (widget.meseros.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Ranking por mesero',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...widget.meseros.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: i == 0
                    ? Colors.amber
                    : i == 1
                    ? Colors.grey.shade400
                    : colors.surfaceContainerHigh,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: i < 2 ? Colors.white : colors.onSurface,
                  ),
                ),
              ),
              title: Text(m.nombre),
              subtitle: Text('${m.cantidadPedidos} pedido(s)'),
              trailing: Text(
                widget.moneda.format(m.total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  String _labelMetodo(MetodoPago m) {
    switch (m) {
      case MetodoPago.efectivo:
        return 'Efectivo';
      case MetodoPago.tarjeta:
        return 'Tarjeta';
      case MetodoPago.transferencia:
        return 'Transferencia';
    }
  }
}

// ignore: unused_element
class _TabRespaldosRedirect extends StatelessWidget {
  const _TabRespaldosRedirect();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.backup_rounded, size: 64, color: Color(0xFF1B7A8A)),
          const SizedBox(height: 16),
          const Text(
            'Respaldos del sistema',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Accede a la gestión completa de respaldos locales\ny Google Drive desde la sección dedicada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B6561)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go(AppRouter.driveBackup),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir Respaldos'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B7A8A),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabRespaldos extends StatefulWidget {
  const _TabRespaldos({required this.onShowMessage});

  final ValueChanged<String> onShowMessage;

  @override
  State<_TabRespaldos> createState() => _TabRespaldosState();
}

class _TabRespaldosState extends State<_TabRespaldos> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.backup_rounded, size: 64, color: Color(0xFF1B7A8A)),
          const SizedBox(height: 16),
          const Text(
            'Respaldos del sistema',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Accede a la gestión completa de respaldos locales\n'
            'y Google Drive desde la sección dedicada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B6561), height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go(AppRouter.driveBackup),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir Respaldos'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B7A8A),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareBarTile extends StatelessWidget {
  const _ShareBarTile({
    required this.label,
    required this.percentage,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String label;
  final double percentage;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (percentage / 100).clamp(0, 1),
          minHeight: 7,
          borderRadius: BorderRadius.circular(999),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          '$value · $subtitle',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: colors.outline),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            mensaje,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
