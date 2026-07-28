import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizaciones_provider.dart';
import 'package:restaurant_app/features/mesas/presentation/providers/mesas_provider.dart';
import 'package:restaurant_app/features/reservaciones/presentation/providers/reservas_provider.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/public_config_provider.dart';

/// Calendario publico de disponibilidad.
class ReservasPublicPage extends ConsumerStatefulWidget {
  const ReservasPublicPage({super.key});

  @override
  ConsumerState<ReservasPublicPage> createState() => _ReservasPublicPageState();
}

class _ReservasPublicPageState extends ConsumerState<ReservasPublicPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  late final Future<void> _localeFuture;

  @override
  void initState() {
    super.initState();
    _localeFuture = initializeDateFormatting('es_ES');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reservasProvider.notifier).loadMes(_focusedDay);
      ref.read(reservasProvider.notifier).loadDia(_selectedDay);
      ref.read(mesasProvider.notifier).loadMesas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reservas = ref.watch(reservasProvider);
    final cotizacionesAsync = ref.watch(cotizacionesProvider);
    final mesas = ref.watch(mesasProvider).mesas;
    final cotizacionesMes = cotizacionesAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <Cotizacion>[],
    );
    final cotizacionesPendientes = cotizacionesAsync.maybeWhen(
      data: (items) => _cotizacionesPendientesDelDia(_selectedDay, items),
      orElse: () => const <Cotizacion>[],
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Regresar',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).maybePop();
              return;
            }
            context.go(AppRouter.restaurantePublico);
          },
        ),
        title: const Text('Fechas disponibles'),
      ),
      body: FutureBuilder<void>(
        future: _localeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // ── Banner instructivo ─────────────────────────────
              _InstructivoBanner(selectedDay: _selectedDay),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selecciona una fecha',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Revisa disponibilidad por fecha y estado del local.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        TableCalendar(
                          locale: 'es_ES',
                          firstDay: DateTime(
                            DateTime.now().year,
                            DateTime.now().month,
                            DateTime.now().day,
                          ),
                          lastDay: DateTime.utc(2035, 12, 31),
                          focusedDay: _focusedDay,
                          enabledDayPredicate: (day) {
                            final today = DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                            );
                            return !day.isBefore(today);
                          },
                          selectedDayPredicate: (day) =>
                              isSameDay(day, _selectedDay),
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          calendarFormat: CalendarFormat.month,
                          rowHeight: 38,
                          daysOfWeekHeight: 20,
                          availableCalendarFormats: const {
                            CalendarFormat.month: 'Mes',
                          },
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            markerDecoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(
                                alpha: 0.5,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              final estado = _estadoDelDia(
                                day,
                                reservas,
                                cotizacionesMes,
                              );
                              if (estado == _EstadoDiaCalendario.libre) {
                                return null;
                              }
                              return Positioned(
                                bottom: 5,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _colorEstadoDia(estado),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            },
                          ),
                          eventLoader: (day) =>
                              _eventsForDay(day, reservas, cotizacionesMes),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                            ref
                                .read(reservasProvider.notifier)
                                .loadDia(selectedDay);
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                            ref
                                .read(reservasProvider.notifier)
                                .loadMes(focusedDay);
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildLegend(),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _buildDisponibilidad(
                  reservas,
                  mesas,
                  cotizacionesPendientes,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Cotizacion> _cotizacionesPendientesDelDia(
    DateTime day,
    List<Cotizacion> cotizaciones,
  ) {
    final date = DateFormat('yyyy-MM-dd').format(day);
    return cotizaciones.where((c) {
      return c.reservaLocal &&
          c.estado == 'pendiente' &&
          c.fechaEvento != null &&
          c.fechaEvento == date;
    }).toList();
  }

  List<dynamic> _eventsForDay(
    DateTime day,
    ReservasState state,
    List<Cotizacion> cotizaciones,
  ) {
    final date = DateFormat('yyyy-MM-dd').format(day);
    final items = state.reservasMes.where((r) => r.fecha == date).toList();
    final pendientes = _cotizacionesPendientesDelDia(day, cotizaciones);
    return [...items, ...pendientes];
  }

  _EstadoDiaCalendario _estadoDelDia(
    DateTime day,
    ReservasState reservas,
    List<Cotizacion> cotizaciones,
  ) {
    final date = DateFormat('yyyy-MM-dd').format(day);
    final items = reservas.reservasMes.where((r) => r.fecha == date).toList();
    final local = items.any(
      (r) => r.tipo == TipoReserva.local && r.estado != EstadoReserva.cancelada,
    );
    if (local) return _EstadoDiaCalendario.ocupado;

    final pendienteEvento = cotizaciones.any(
      (c) =>
          c.reservaLocal &&
          c.estado == 'pendiente' &&
          c.fechaEvento != null &&
          c.fechaEvento == date,
    );
    if (pendienteEvento) return _EstadoDiaCalendario.pendiente;

    final reservado = items.any((r) => r.estado != EstadoReserva.cancelada);
    if (reservado) return _EstadoDiaCalendario.parcial;

    return _EstadoDiaCalendario.libre;
  }

  Color _colorEstadoDia(_EstadoDiaCalendario estado) {
    return switch (estado) {
      _EstadoDiaCalendario.libre => Colors.green,
      _EstadoDiaCalendario.parcial => AppColors.primary,
      _EstadoDiaCalendario.pendiente => Colors.orange,
      _EstadoDiaCalendario.ocupado => AppColors.error,
    };
  }

  String _labelEstadoDia(_EstadoDiaCalendario estado) {
    return switch (estado) {
      _EstadoDiaCalendario.libre => 'Libre',
      _EstadoDiaCalendario.parcial => 'Parcial',
      _EstadoDiaCalendario.pendiente => 'Pendiente',
      _EstadoDiaCalendario.ocupado => 'Ocupado',
    };
  }

  String _mensajeEstadoDia(
    _EstadoDiaCalendario estado,
    int disponibles,
    int reservadas,
  ) {
    return switch (estado) {
      _EstadoDiaCalendario.libre =>
        'Hay $disponibles mesa(s) disponibles para esta fecha.',
      _EstadoDiaCalendario.parcial =>
        'Todavía hay cupo. Reservadas: $reservadas · Disponibles: $disponibles.',
      _EstadoDiaCalendario.pendiente =>
        'Existe una solicitud de evento por confirmar. Revisa antes de reservar.',
      _EstadoDiaCalendario.ocupado =>
        'El local completo está reservado para esta fecha.',
    };
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cómo leer el calendario',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _LegendChip(label: 'Libre', color: Colors.green),
            _LegendChip(label: 'Parcial', color: AppColors.primary),
            _LegendChip(label: 'Pendiente', color: Colors.orange),
            _LegendChip(label: 'Ocupado', color: AppColors.error),
          ],
        ),
      ],
    );
  }

  Widget _buildDisponibilidad(
    ReservasState reservas,
    List mesas,
    List<Cotizacion> cotizacionesPendientes,
  ) {
    final date = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final fechaLabel = DateFormat('dd/MM/yyyy').format(_selectedDay);
    final items = reservas.reservasMes.where((r) => r.fecha == date).toList();
    final reservedMesaIds = items
        .where((r) => r.mesaId != null && r.estado != EstadoReserva.cancelada)
        .map((r) => r.mesaId)
        .toSet();
    final disponibles = (mesas.length - reservedMesaIds.length).clamp(
      0,
      mesas.length,
    );
    final estado = items.any((r) => r.tipo == TipoReserva.local)
        ? _EstadoDiaCalendario.ocupado
        : cotizacionesPendientes.isNotEmpty
        ? _EstadoDiaCalendario.pendiente
        : reservedMesaIds.isNotEmpty
        ? _EstadoDiaCalendario.parcial
        : _EstadoDiaCalendario.libre;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fecha seleccionada · $fechaLabel',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _colorEstadoDia(estado).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _labelEstadoDia(estado),
                  style: TextStyle(
                    color: _colorEstadoDia(estado),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _mensajeEstadoDia(estado, disponibles, reservedMesaIds.length),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 360;
                  final cardDisponibles = _ResumenDisponibilidadCard(
                    title: 'Disponibles',
                    value: '$disponibles',
                    icon: Icons.event_seat_outlined,
                    color: Colors.green,
                  );
                  final cardReservadas = _ResumenDisponibilidadCard(
                    title: 'Reservadas',
                    value: '${reservedMesaIds.length}',
                    icon: Icons.lock_outline_rounded,
                    color: AppColors.primary,
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        cardDisponibles,
                        const SizedBox(height: 10),
                        cardReservadas,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: cardDisponibles),
                      const SizedBox(width: 10),
                      Expanded(child: cardReservadas),
                    ],
                  );
                },
              ),
              if (cotizacionesPendientes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Hay ${cotizacionesPendientes.length} solicitud(es) de evento pendiente(s) para este día. Confirma disponibilidad antes de reservar.',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Botón CTA reservar ─────────────────────────────────
        _ReservarCTAButton(
          selectedDay: _selectedDay,
          disponibles: disponibles,
          estado: estado,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

enum _EstadoDiaCalendario { libre, parcial, pendiente, ocupado }

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ResumenDisponibilidadCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ResumenDisponibilidadCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner con instrucciones para reservar
// ─────────────────────────────────────────────────────────────────────────────

class _InstructivoBanner extends StatelessWidget {
  final DateTime selectedDay;

  const _InstructivoBanner({required this.selectedDay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cómo hacer una reserva',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '1. Elige una fecha disponible en el calendario.\n'
                  '2. Revisa las mesas disponibles abajo.\n'
                  '3. Toca "Reservar esta fecha" y contáctanos por WhatsApp o teléfono.',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón CTA para solicitar la reserva
// ─────────────────────────────────────────────────────────────────────────────

class _ReservarCTAButton extends ConsumerWidget {
  final DateTime selectedDay;
  final int disponibles;
  final _EstadoDiaCalendario estado;

  const _ReservarCTAButton({
    required this.selectedDay,
    required this.disponibles,
    required this.estado,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final selectedNormalized = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final isPasado = selectedNormalized.isBefore(today);
    final isOcupado = estado == _EstadoDiaCalendario.ocupado;
    final isDisabled = isOcupado || isPasado;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: isDisabled ? Colors.grey : AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: isDisabled ? null : () => _mostrarContacto(context, ref),
          icon: Icon(
            isPasado
                ? Icons.history_rounded
                : isOcupado
                ? Icons.event_busy_rounded
                : Icons.calendar_month_rounded,
            size: 20,
          ),
          label: Text(
            isPasado
                ? 'Fecha en el pasado'
                : isOcupado
                ? 'Fecha no disponible'
                : 'Reservar esta fecha',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }

  void _mostrarContacto(BuildContext context, WidgetRef ref) {
    // Usar datos de contacto desde la config de empresa (con fallback a constantes)
    final cfg = ref.read(publicConfigProvider);
    final telefono = (cfg.hasConfig && cfg.config!.telefono.isNotEmpty)
        ? cfg.config!.telefono
        : AppConstants.contactPhone;
    final whatsapp = (cfg.hasConfig && cfg.config!.whatsapp.isNotEmpty)
        ? cfg.config!.whatsapp
        : AppConstants.contactWhatsapp;
    final fechaLabel = DateFormat(
      "EEEE d 'de' MMMM",
      'es_ES',
    ).format(selectedDay);
    final mensaje = Uri.encodeComponent(
      'Hola! Quisiera reservar una mesa para el $fechaLabel. ¿Tienen disponibilidad?',
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reservar para el $fechaLabel',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Contáctanos para confirmar tu mesa. '
              'Nuestro equipo te atenderá de inmediato.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),
            // WhatsApp
            if (whatsapp.isNotEmpty)
              _ContactButton(
                iconWidget: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Colors.white,
                  size: 20,
                ),
                color: const Color(0xFF25D366),
                label: 'WhatsApp',
                subtitle: telefono,
                onTap: () async {
                  final uri = Uri.parse(
                    'https://wa.me/593${whatsapp.replaceFirst(RegExp(r'^0'), '')}?text=$mensaje',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            const SizedBox(height: 10),
            // Llamada
            if (telefono.isNotEmpty)
              _ContactButton(
                icon: Icons.phone_rounded,
                color: AppColors.primary,
                label: 'Llamar',
                subtitle: telefono,
                onTap: () async {
                  final uri = Uri.parse('tel:${telefono.replaceAll(' ', '')}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Indica el número de personas y tu nombre al contactarnos para agilizar tu reserva.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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

class _ContactButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactButton({
    this.icon,
    this.iconWidget,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  iconWidget ??
                  Icon(
                    icon ?? Icons.phone_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}
