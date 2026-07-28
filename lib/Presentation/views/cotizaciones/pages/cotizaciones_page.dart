import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/usecases/cotizacion_usecases.dart';
import 'package:restaurant_app/features/reservaciones/presentation/providers/reservas_provider.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizaciones_provider.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/pages/cotizacion_manual_form_page.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/widgets/cotizacion_editor_dialog.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/public_config_provider.dart';

class CotizacionesPage extends ConsumerStatefulWidget {
  const CotizacionesPage({super.key});

  @override
  ConsumerState<CotizacionesPage> createState() => _CotizacionesPageState();
}

class _CotizacionesPageState extends ConsumerState<CotizacionesPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cotizacionesAsync = ref.watch(cotizacionesFiltadasProvider);
    final estadoFiltro = ref.watch(cotizacionEstadoFiltroProvider);
    final cfgState = ref.watch(publicConfigProvider);
    final nombreNegocio =
        (cfgState.hasConfig && cfgState.config!.nombreNegocio.isNotEmpty)
        ? cfgState.config!.nombreNegocio
        : AppConstants.appFullName;
    final currencyFormat = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRouter.cotizacionNueva),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva cotización'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver al menú',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).maybePop();
              return;
            }
            context.go(AppRouter.menu);
          },
        ),
        title: const Text('Cotizaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(cotizacionesProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Barra de búsqueda ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ref.read(cotizacionSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, teléfono, empresa...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(cotizacionSearchProvider.notifier).state =
                              '';
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // ── Chips de estado ─────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final entry in const {
                  'todos': 'Todos',
                  'pendiente': 'Pendiente',
                  'borrador': 'Borrador',
                  'aceptada': 'Aceptada',
                  'rechazada': 'Rechazada',
                  'finalizada': 'Finalizada',
                  'cobrada': 'Cobrada',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: estadoFiltro == entry.key,
                      onSelected: (_) =>
                          ref
                                  .read(cotizacionEstadoFiltroProvider.notifier)
                                  .state =
                              entry.key,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      showCheckmark: true,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                        color: estadoFiltro == entry.key
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // ── Lista filtrada ──────────────────────────────────────
          Expanded(
            child: cotizacionesAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ref.read(cotizacionSearchProvider).isNotEmpty ||
                                  estadoFiltro != 'todos'
                              ? 'No hay resultados para este filtro'
                              : 'No hay cotizaciones registradas.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    final fecha = DateFormat('dd/MM/yyyy').format(c.createdAt);
                    final evento =
                        c.fechaEvento == null || c.fechaEvento!.isEmpty
                        ? null
                        : DateFormat(
                            'dd/MM/yyyy',
                          ).format(DateTime.parse(c.fechaEvento!));
                    return Card(
                      elevation: 1,
                      clipBehavior: Clip.hardEdge,
                      child: InkWell(
                        onTap: () =>
                            _showDetalle(context, ref, c, nombreNegocio),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: c.reservaLocal
                                      ? AppColors.secondary.withValues(
                                          alpha: 0.12,
                                        )
                                      : AppColors.info.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  c.reservaLocal
                                      ? Icons.celebration_outlined
                                      : Icons.request_quote_outlined,
                                  color: c.reservaLocal
                                      ? AppColors.secondary
                                      : AppColors.info,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.clienteNombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Fecha: $fecha · Tel: ${c.clienteTelefono}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (evento != null) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.event_outlined,
                                            size: 12,
                                            color: c.reservaLocal
                                                ? AppColors.secondary
                                                : AppColors.info,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Evento: $evento',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: c.reservaLocal
                                                  ? AppColors.secondary
                                                  : AppColors.info,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (c.personas != null &&
                                              c.personas! > 0) ...[
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.group_outlined,
                                              size: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${c.personas} pers.',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _statusChipMini(c.estado),
                                        if (c.reservaLocal) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.secondary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Reserva local',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.secondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (_buildResumenComidaReserva(c) !=
                                        null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '🍽 ${_buildResumenComidaReserva(c)!}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormat.format(c.total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (c.items.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.items.length} ítem${c.items.length == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              error: (e, __) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  String _labelEstado(String estado) {
    return switch (estado) {
      'borrador' => 'Borrador',
      'aceptada' => 'Aceptada',
      'rechazada' => 'Rechazada',
      'finalizada' => 'Finalizada',
      'cobrada' => 'Cobrada',
      _ => 'Pendiente',
    };
  }

  Color _colorEstado(String estado) {
    return switch (estado) {
      'borrador' => Colors.blueGrey,
      'aceptada' => Colors.green,
      'rechazada' => AppColors.error,
      'finalizada' => AppColors.primary,
      'cobrada' => Colors.teal,
      _ => AppColors.textSecondary,
    };
  }

  Widget _statusChipMini(String estado) {
    final color = _colorEstado(estado);
    final label = _labelEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showDetalle(
    BuildContext context,
    WidgetRef ref,
    Cotizacion c,
    String nombreNegocio,
  ) async {
    final currencyFormat = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );
    final fechaCreacion = DateFormat('dd/MM/yyyy').format(c.createdAt);
    final evento = c.fechaEvento == null || c.fechaEvento!.isEmpty
        ? null
        : DateFormat('dd/MM/yyyy').format(DateTime.parse(c.fechaEvento!));

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // ── Encabezado ─────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: c.reservaLocal
                              ? AppColors.secondary.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.12),
                          child: Icon(
                            c.reservaLocal
                                ? Icons.celebration_outlined
                                : Icons.request_quote_outlined,
                            color: c.reservaLocal
                                ? AppColors.secondary
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.clienteNombre,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Solicitada el $fechaCreacion',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Chips de tipo y estado ─────────────────────
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            c.reservaLocal
                                ? Icons.home_outlined
                                : Icons.receipt_long_outlined,
                            size: 14,
                            color: c.reservaLocal
                                ? AppColors.secondary
                                : AppColors.info,
                          ),
                          label: Text(
                            c.reservaLocal ? 'Reserva del local' : 'Cotización',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: c.reservaLocal
                              ? AppColors.secondary.withValues(alpha: 0.1)
                              : AppColors.info.withValues(alpha: 0.1),
                          side: BorderSide.none,
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            _iconEstado(c.estado),
                            size: 14,
                            color: _colorEstado(c.estado),
                          ),
                          label: Text(
                            _labelEstado(c.estado),
                            style: TextStyle(
                              fontSize: 12,
                              color: _colorEstado(c.estado),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: _colorEstado(
                            c.estado,
                          ).withValues(alpha: 0.1),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _tieneDetalleComida(c)
                            ? AppColors.info.withValues(alpha: 0.08)
                            : AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _tieneDetalleComida(c)
                              ? AppColors.info.withValues(alpha: 0.25)
                              : AppColors.warning.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.restaurant_menu_outlined,
                                size: 16,
                                color: _tieneDetalleComida(c)
                                    ? AppColors.info
                                    : AppColors.warning,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Pedido solicitado',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_tieneDetalleComida(c)) ...[
                            if ((c.comidaPreferida ?? '').trim().isNotEmpty)
                              Text(
                                'Preferencia: ${c.comidaPreferida!.trim()}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            if (c.items.isNotEmpty) ...[
                              if ((c.comidaPreferida ?? '').trim().isNotEmpty)
                                const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: c.items
                                    .map(
                                      (item) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          '${item.cantidad}x ${item.productoNombre}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ] else
                            const Text(
                              'Esta solicitud todavía no tiene comida detallada. Pide confirmación antes de aceptarla.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (c.estado == 'pendiente') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final confirmed = await _confirmarAccion(
                                  context,
                                  titulo: 'Aceptar cotización',
                                  mensaje: c.reservaLocal
                                      ? 'Se aprobará la cotización y se creará la reserva del local para la fecha indicada.'
                                      : 'Se aprobará la cotización y quedará lista para seguimiento comercial.',
                                  confirmText: 'Aceptar',
                                );
                                if (!context.mounted || !confirmed) return;
                                if (sheetCtx.mounted) {
                                  Navigator.of(sheetCtx).pop();
                                }
                                if (context.mounted) {
                                  await _aceptarCotizacion(context, ref, c);
                                }
                              },
                              child: const Text('Aceptar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final confirmed = await _confirmarAccion(
                                  context,
                                  titulo: 'Rechazar cotización',
                                  mensaje:
                                      'La cotización quedará marcada como rechazada y ya no aparecerá como pendiente.',
                                  confirmText: 'Rechazar',
                                  isDestructive: true,
                                );
                                if (!context.mounted || !confirmed) return;
                                if (sheetCtx.mounted) {
                                  Navigator.of(sheetCtx).pop();
                                }
                                if (context.mounted) {
                                  await _rechazarCotizacion(context, ref, c);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                              ),
                              child: const Text('Rechazar'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // ── Contacto ───────────────────────────────────
                    _sectionHeader(Icons.person_outline, 'Datos de contacto'),
                    const SizedBox(height: 10),
                    _contactTile(
                      Icons.phone_outlined,
                      'Teléfono',
                      c.clienteTelefono,
                    ),
                    _contactTile(
                      Icons.email_outlined,
                      'Correo',
                      c.clienteEmail,
                    ),

                    // ── Evento (si aplica) ─────────────────────────
                    if (evento != null ||
                        (c.personas != null && c.personas! > 0) ||
                        c.reservaLocal) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.reservaLocal
                              ? AppColors.secondary.withValues(alpha: 0.07)
                              : AppColors.info.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: c.reservaLocal
                                ? AppColors.secondary.withValues(alpha: 0.25)
                                : AppColors.info.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  c.reservaLocal
                                      ? Icons.celebration_outlined
                                      : Icons.event_outlined,
                                  size: 16,
                                  color: c.reservaLocal
                                      ? AppColors.secondary
                                      : AppColors.info,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  c.reservaLocal
                                      ? 'Detalles del evento'
                                      : 'Fecha del evento',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: c.reservaLocal
                                        ? AppColors.secondary
                                        : AppColors.info,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (evento != null)
                              _infoRowCompact(
                                Icons.calendar_today_outlined,
                                'Fecha',
                                evento,
                              ),
                            if (c.personas != null && c.personas! > 0)
                              _infoRowCompact(
                                Icons.group_outlined,
                                'Personas',
                                '${c.personas} personas',
                              ),
                            if (c.comidaPreferida != null &&
                                c.comidaPreferida!.isNotEmpty)
                              _infoRowCompact(
                                Icons.restaurant_menu_outlined,
                                'Preferencia de comida',
                                c.comidaPreferida!,
                              ),
                          ],
                        ),
                      ),
                    ],

                    // ── Items cotizados ────────────────────────────
                    if (c.items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionHeader(
                        Icons.shopping_bag_outlined,
                        'Productos cotizados',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < c.items.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  color: Colors.grey[200],
                                  indent: 12,
                                  endIndent: 12,
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${c.items[i].cantidad}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        c.items[i].productoNombre,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      currencyFormat.format(
                                        c.items[i].subtotal,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // ── Totales ────────────────────────────────────
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (c.subtotal != c.total) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Subtotal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(c.subtotal),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Impuestos',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(c.total - c.subtotal),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            const Divider(height: 14),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                currencyFormat.format(c.total),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Notas ──────────────────────────────────────
                    if (c.notas != null && c.notas!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.sticky_note_2_outlined,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Notas del cliente',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.notas!,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // ── Generar PDF ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          CotizacionEditorDialog.show(context, ref, c);
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text(
                          'Generar y compartir cotización PDF',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          context.push(AppRouter.cotizacionPublicaUrl(c.id));
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Ver vista del cliente'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Acciones de contacto ───────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _launchWhatsApp(context, c, nombreNegocio),
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _callPhone(context, c.clienteTelefono),
                            icon: const Icon(Icons.call_outlined, size: 18),
                            label: const Text('Llamar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: c.clienteTelefono),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Teléfono copiado'),
                                ),
                              );
                            }
                          },
                          child: const Icon(Icons.copy_rounded, size: 18),
                        ),
                      ],
                    ),

                    // ── Acciones admin (Aceptar / Rechazar) ────────
                    if (c.estado == 'pendiente') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () async {
                                final confirmed = await _confirmarAccion(
                                  context,
                                  titulo: 'Aceptar cotización',
                                  mensaje: c.reservaLocal
                                      ? 'Se aprobará la cotización y se creará la reserva del local para la fecha indicada.'
                                      : 'Se aprobará la cotización y quedará lista para seguimiento comercial.',
                                  confirmText: 'Aceptar',
                                );
                                if (!context.mounted || !confirmed) return;
                                if (sheetCtx.mounted) {
                                  Navigator.of(sheetCtx).pop();
                                }
                                if (context.mounted) {
                                  await _aceptarCotizacion(context, ref, c);
                                }
                              },
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Aceptar'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final confirmed = await _confirmarAccion(
                                  context,
                                  titulo: 'Rechazar cotización',
                                  mensaje:
                                      'La cotización quedará marcada como rechazada y ya no aparecerá como pendiente.',
                                  confirmText: 'Rechazar',
                                  isDestructive: true,
                                );
                                if (!context.mounted || !confirmed) return;
                                if (sheetCtx.mounted) {
                                  Navigator.of(sheetCtx).pop();
                                }
                                if (context.mounted) {
                                  await _rechazarCotizacion(context, ref, c);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                              ),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Rechazar'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: _colorEstado(c.estado).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _colorEstado(
                              c.estado,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _iconEstado(c.estado),
                              size: 16,
                              color: _colorEstado(c.estado),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cotización ${_labelEstado(c.estado).toLowerCase()}',
                              style: TextStyle(
                                color: _colorEstado(c.estado),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // ── Editar / Eliminar ──────────────────────────
                    if (c.estado == 'borrador' || c.estado == 'pendiente') ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (sheetCtx.mounted) {
                              Navigator.of(sheetCtx).pop();
                            }
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CotizacionManualFormPage(cotizacion: c),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar cotización'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await _confirmarAccion(
                            context,
                            titulo: 'Eliminar cotización',
                            mensaje:
                                'Esta acción no se puede deshacer. ¿Deseas eliminar esta cotización?',
                            confirmText: 'Eliminar',
                            isDestructive: true,
                          );
                          if (!context.mounted || !confirmed) return;
                          if (sheetCtx.mounted) {
                            Navigator.of(sheetCtx).pop();
                          }
                          if (context.mounted) {
                            await _eliminarCotizacion(context, ref, c);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Eliminar cotización'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _contactTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _infoRowCompact(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  bool _tieneDetalleComida(Cotizacion c) {
    return (c.comidaPreferida?.trim().isNotEmpty ?? false) ||
        c.items.isNotEmpty;
  }

  String? _buildResumenComidaReserva(Cotizacion c) {
    final partes = <String>[];
    final preferida = c.comidaPreferida?.trim();
    if (preferida != null && preferida.isNotEmpty) {
      partes.add('Preferencia: $preferida');
    }
    if (c.items.isNotEmpty) {
      final items = c.items
          .map((item) => '${item.cantidad}x ${item.productoNombre}')
          .join(', ');
      if (items.isNotEmpty) {
        partes.add('Pedido tentativo: $items');
      }
    }
    if (partes.isEmpty) return null;
    return partes.join(' · ');
  }

  IconData _iconEstado(String estado) {
    return switch (estado) {
      'borrador' => Icons.edit_note_rounded,
      'aceptada' => Icons.check_circle_outline,
      'rechazada' => Icons.cancel_outlined,
      'finalizada' => Icons.done_all_rounded,
      'cobrada' => Icons.payments_rounded,
      _ => Icons.hourglass_empty_rounded,
    };
  }

  Future<void> _aceptarCotizacion(
    BuildContext context,
    WidgetRef ref,
    Cotizacion c,
  ) async {
    bool ok = true;

    if (c.reservaLocal) {
      if (c.fechaEvento == null || c.fechaEvento!.isEmpty) {
        _showMessage(
          context,
          'Falta la fecha del evento para crear la reserva.',
        );
        return;
      }

      final fecha = DateTime.parse(c.fechaEvento!);
      await ref.read(reservasProvider.notifier).loadMes(fecha);

      ok = await ref
          .read(reservasProvider.notifier)
          .crearReserva(
            tipo: TipoReserva.local,
            fecha: fecha,
            horaInicio: '19:00',
            horaFin: '21:00',
            numeroPersonas: c.personas ?? 10,
            clienteNombre: c.clienteNombre,
            clienteTelefono: c.clienteTelefono,
            clienteEmail: c.clienteEmail,
            notas: c.notas,
            estado: EstadoReserva.confirmada,
            tipoEvento: 'Evento privado',
            requerimientos: _buildResumenComidaReserva(c),
            cotizacionId: c.id,
          );

      if (!ok) {
        if (context.mounted) {
          final msg = ref.read(reservasProvider).errorMessage;
          _showMessage(context, msg ?? 'No se pudo agendar la reserva.');
        }
        return;
      }
    }

    final result = await sl<UpdateCotizacionEstado>()(
      UpdateCotizacionEstadoParams(cotizacionId: c.id, estado: 'aceptada'),
    );

    if (!context.mounted) return;

    result.fold(
      (f) => _showMessage(context, f.message),
      (_) => _showMessage(
        context,
        c.reservaLocal
            ? 'Cotización aceptada y reserva creada'
            : 'Cotización aceptada',
      ),
    );
    ref.invalidate(cotizacionesProvider);
  }

  Future<void> _eliminarCotizacion(
    BuildContext context,
    WidgetRef ref,
    Cotizacion c,
  ) async {
    final result = await sl<DeleteCotizacion>()(c.id);
    if (!context.mounted) return;
    result.fold(
      (f) => _showMessage(context, f.message),
      (_) => _showMessage(context, 'Cotización eliminada'),
    );
    ref.invalidate(cotizacionesProvider);
  }

  Future<void> _rechazarCotizacion(
    BuildContext context,
    WidgetRef ref,
    Cotizacion c,
  ) async {
    final result = await sl<UpdateCotizacionEstado>()(
      UpdateCotizacionEstadoParams(cotizacionId: c.id, estado: 'rechazada'),
    );

    if (!context.mounted) return;

    result.fold(
      (f) => _showMessage(context, f.message),
      (_) => _showMessage(context, 'Cotización rechazada'),
    );
    ref.invalidate(cotizacionesProvider);
  }

  void _showMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmarAccion(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _launchWhatsApp(
    BuildContext context,
    Cotizacion c,
    String nombreNegocio,
  ) async {
    final phone = _sanitizePhone(c.clienteTelefono);
    if (phone.isEmpty) return;
    final message = _buildWhatsappMessage(c, nombreNegocio);
    final uri = Uri.https('wa.me', '/$phone', {'text': message});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  Future<void> _callPhone(BuildContext context, String telefono) async {
    final phone = _sanitizePhone(telefono);
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar llamada')),
      );
    }
  }

  String _sanitizePhone(String telefono) {
    return telefono.replaceAll(RegExp(r'\D'), '');
  }

  String _buildWhatsappMessage(Cotizacion c, String nombreNegocio) {
    final evento = c.fechaEvento == null || c.fechaEvento!.isEmpty
        ? 'sin fecha definida'
        : c.fechaEvento!;
    final personas = c.personas != null && c.personas! > 0
        ? 'Personas: ${c.personas}'
        : 'Personas: por confirmar';
    final tipo = c.reservaLocal ? 'reserva de local' : 'cotizacion';
    return 'Hola, somos $nombreNegocio. '
        'Nos comunicamos contigo por tu solicitud de $tipo. '
        'Evento: $evento. $personas.';
  }
}
