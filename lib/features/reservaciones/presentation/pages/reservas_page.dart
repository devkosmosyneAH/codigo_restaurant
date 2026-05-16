import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';
import 'package:restaurant_app/features/clientes/domain/services/cliente_service.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/providers/cotizaciones_provider.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';
import 'package:restaurant_app/features/mesas/presentation/providers/mesas_provider.dart';
import 'package:restaurant_app/features/reservaciones/domain/entities/reserva.dart';
import 'package:restaurant_app/features/reservaciones/presentation/providers/reservas_provider.dart';
import 'package:restaurant_app/features/reservaciones/presentation/widgets/reserva_form_dialog.dart';
import 'package:table_calendar/table_calendar.dart';

/// Pantalla de reservaciones (admin).
class ReservasPage extends ConsumerStatefulWidget {
  const ReservasPage({super.key});

  @override
  ConsumerState<ReservasPage> createState() => _ReservasPageState();
}

class _ReservasPageState extends ConsumerState<ReservasPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _mostrarHorario = false;
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
    final state = ref.watch(reservasProvider);
    final mesasState = ref.watch(mesasProvider);
    final cotizacionesAsync = ref.watch(cotizacionesProvider);
    final cotizacionesPendientes = cotizacionesAsync.maybeWhen(
      data: (items) => _cotizacionesPendientesDelDia(_selectedDay, items),
      orElse: () => const <Cotizacion>[],
    );
    final alertasPendientes = cotizacionesAsync.maybeWhen(
      data: (items) => items
          .where((c) => c.reservaLocal && c.estado == 'pendiente')
          .toList(),
      orElse: () => const <Cotizacion>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservaciones'),
        actions: [
          IconButton(
            onPressed: () => _nuevaReserva(context, mesasState.mesas),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Nueva reservación',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<void>(
        future: _localeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              TableCalendar(
                locale: 'es_ES',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarFormat: CalendarFormat.month,
                rowHeight: 38,
                daysOfWeekHeight: 20,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                eventLoader: (day) => _eventsForDay(
                  day,
                  state,
                  cotizacionesAsync.maybeWhen(
                    data: (items) => items,
                    orElse: () => const <Cotizacion>[],
                  ),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  ref.read(reservasProvider.notifier).loadDia(selectedDay);
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                  ref.read(reservasProvider.notifier).loadMes(focusedDay);
                },
                calendarStyle: CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              if (alertasPendientes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.request_quote_outlined,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cotización pendiente',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                alertasPendientes.first.clienteNombre,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  children: [
                    _buildResumen(state, cotizacionesPendientes),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Lista'),
                          selected: !_mostrarHorario,
                          onSelected: (_) =>
                              setState(() => _mostrarHorario = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Por horas'),
                          selected: _mostrarHorario,
                          onSelected: (_) =>
                              setState(() => _mostrarHorario = true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _mostrarHorario
                    ? _buildHorarioDia(state)
                    : _buildListaDia(state, cotizacionesPendientes),
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

  Widget _buildResumen(
    ReservasState state,
    List<Cotizacion> cotizacionesPendientes,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final perRow = width < 500 ? 2 : 3;
        const spacing = 8.0;
        final cardWidth = (width - (perRow - 1) * spacing) / perRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _ResumenCard(
                label: 'Hoy',
                value: '${state.totalHoy}',
                color: AppColors.primary,
                icon: Icons.event_available_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ResumenCard(
                label: 'Pendientes',
                value: '${state.pendientesHoy + cotizacionesPendientes.length}',
                color: AppColors.warning,
                icon: Icons.hourglass_bottom_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ResumenCard(
                label: 'Eventos',
                value: '${state.eventosHoy}',
                color: AppColors.secondary,
                icon: Icons.celebration_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListaDia(
    ReservasState state,
    List<Cotizacion> cotizacionesPendientes,
  ) {
    if (state.reservasDia.isEmpty && cotizacionesPendientes.isEmpty) {
      return const Center(
        child: Text('No hay reservaciones ni cotizaciones este día.'),
      );
    }

    final reservas = [...state.reservasDia]
      ..sort(
        (a, b) => _horaToMinutes(
          a.horaInicio,
        ).compareTo(_horaToMinutes(b.horaInicio)),
      );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (cotizacionesPendientes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Cotizaciones pendientes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ...cotizacionesPendientes.map(
            (c) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A1976D2),
                  child: Icon(Icons.event_note_rounded, color: AppColors.info),
                ),
                title: const Text('Solicitud de evento'),
                subtitle: Text(_resumenPendienteCotizacion(c)),
                isThreeLine: _cotizacionTieneComida(c),
                trailing: const Chip(label: Text('Pendiente')),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        ...reservas.map(
          (r) => Card(
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              onTap: () => _showDetalleReserva(r),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: _colorEstado(
                        r.estado,
                      ).withValues(alpha: 0.12),
                      child: Icon(
                        r.esEventoPrivado
                            ? Icons.celebration_outlined
                            : Icons.table_restaurant_rounded,
                        color: r.esEventoPrivado
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
                            r.clienteNombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${r.horaInicio} - ${r.horaFin} · ${r.numeroPersonas} personas',
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.esEventoPrivado
                                ? 'Evento privado${r.tipoEvento != null ? ' · ${r.tipoEvento}' : ''}'
                                : (r.mesaNombre ?? 'Mesa asignada'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if ((r.requerimientos ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '🍽 ${_previewTexto(r.requerimientos!)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if ((r.notas ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _previewTexto(r.notas!),
                              maxLines: 1,
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
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _chipEstado(r.estado),
                        const SizedBox(height: 6),
                        _chipTipo(r.tipo),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorarioDia(ReservasState state) {
    final reservas = [...state.reservasDia]
      ..sort(
        (a, b) => _horaToMinutes(
          a.horaInicio,
        ).compareTo(_horaToMinutes(b.horaInicio)),
      );
    final horas = List.generate(
      AppConstants.restaurantClosingHour - AppConstants.restaurantOpeningHour,
      (index) => AppConstants.restaurantOpeningHour + index,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: horas.length,
      itemBuilder: (context, index) {
        final hour = horas[index];
        final slotStart = '${hour.toString().padLeft(2, '0')}:00';
        final slotEnd = '${(hour + 1).toString().padLeft(2, '0')}:00';
        final items = reservas.where((r) => _ocurreEnFranja(r, hour)).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  '$slotStart\n$slotEnd',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: items.isEmpty
                    ? const Text(
                        'Disponible',
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: items
                            .map(
                              (r) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (r.esEventoPrivado
                                              ? AppColors.secondary
                                              : AppColors.primary)
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${r.clienteNombre} · ${r.esEventoPrivado ? 'Evento' : (r.mesaNombre ?? 'Mesa')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDetalleReserva(Reserva r) async {
    final mesas = ref.read(mesasProvider).mesas;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _colorEstado(
                        r.estado,
                      ).withValues(alpha: 0.12),
                      child: Icon(
                        r.esEventoPrivado
                            ? Icons.celebration_outlined
                            : Icons.table_restaurant_rounded,
                        color: r.esEventoPrivado
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
                            r.clienteNombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_selectedDay),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _chipEstado(r.estado),
                  ],
                ),
                const SizedBox(height: 14),
                // ── Botones de acción rápida según estado ──────────
                _botonesAccionEstado(sheetContext, r),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _editarReserva(context, r, mesas);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _detalleItem(Icons.schedule_rounded, 'Horario', r.horarioLabel),
                _detalleItem(
                  Icons.group_outlined,
                  'Personas',
                  '${r.numeroPersonas}',
                ),
                _detalleItem(
                  r.esEventoPrivado
                      ? Icons.celebration_outlined
                      : Icons.table_restaurant_rounded,
                  'Tipo',
                  r.esEventoPrivado
                      ? 'Evento privado${r.tipoEvento != null ? ' · ${r.tipoEvento}' : ''}'
                      : (r.mesaNombre ?? 'Mesa'),
                ),
                _detalleItem(
                  Icons.call_outlined,
                  'Contacto',
                  r.clienteTelefono,
                ),
                if (r.clienteEmail.trim().isNotEmpty)
                  _detalleItem(Icons.email_outlined, 'Correo', r.clienteEmail),
                if ((r.notas ?? '').isNotEmpty)
                  _detalleItem(Icons.notes_rounded, 'Observaciones', r.notas!),
                if ((r.requerimientos ?? '').isNotEmpty)
                  _detalleItem(
                    Icons.restaurant_menu_outlined,
                    'Comida / requerimientos',
                    r.requerimientos!,
                  ),
                // ── Sección Mantelería y detalles del evento ───────
                if (r.esEventoPrivado &&
                    (r.nombreLocalEvento != null ||
                        r.manteles != null ||
                        r.colorManteleria != null ||
                        r.precioEstimado != null)) ...[
                  const Divider(height: 20),
                  const Text(
                    'Detalles del evento',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if ((r.nombreLocalEvento ?? '').isNotEmpty)
                    _detalleItem(
                      Icons.store_outlined,
                      'Nombre del local',
                      r.nombreLocalEvento!,
                    ),
                  if ((r.manteles ?? '').isNotEmpty)
                    _detalleItem(
                      Icons.table_bar_outlined,
                      'Mantelería',
                      r.manteles!,
                    ),
                  if ((r.colorManteleria ?? '').isNotEmpty)
                    _detalleItem(
                      Icons.palette_outlined,
                      'Color mantelería',
                      r.colorManteleria!,
                    ),
                  if (r.precioEstimado != null)
                    _detalleItem(
                      Icons.attach_money_rounded,
                      'Precio estimado',
                      '\$${r.precioEstimado!.toStringAsFixed(2)}',
                    ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botones de transición de estado.
  ///
  /// - pendiente   → Confirmar (verde) | Cancelar (rojo)
  /// - confirmada  → Completar (azul) | No asistió (morado) | Cancelar (rojo)
  /// - completada / cancelada / noAsistio → sin acciones rápidas
  Widget _botonesAccionEstado(BuildContext sheetContext, Reserva r) {
    Future<void> cambiar(EstadoReserva nuevo) async {
      Navigator.pop(sheetContext);
      final ok = await ref
          .read(reservasProvider.notifier)
          .cambiarEstado(r, nuevo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Estado actualizado a: ${nuevo.label}'
                  : ref.read(reservasProvider).errorMessage ??
                        'Error al actualizar',
            ),
            backgroundColor: ok ? AppColors.primary : AppColors.error,
          ),
        );
      }
    }

    if (r.estado == EstadoReserva.pendiente) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mesaLibre,
                ),
                onPressed: () => cambiar(EstadoReserva.confirmada),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => cambiar(EstadoReserva.cancelada),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      );
    }

    if (r.estado == EstadoReserva.confirmada) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => cambiar(EstadoReserva.completada),
              icon: const Icon(Icons.event_available_outlined, size: 16),
              label: const Text('Completar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
              onPressed: () => cambiar(EstadoReserva.noAsistio),
              icon: const Icon(Icons.person_off_outlined, size: 16),
              label: const Text('No asistió'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => cambiar(EstadoReserva.cancelada),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancelar'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  bool _cotizacionTieneComida(Cotizacion c) {
    return (c.comidaPreferida?.trim().isNotEmpty ?? false) ||
        c.items.isNotEmpty;
  }

  String _resumenPendienteCotizacion(Cotizacion c) {
    final base = '${c.clienteNombre} · ${c.personas ?? 0} personas';
    final partes = <String>[];
    final comida = c.comidaPreferida?.trim();
    if (comida != null && comida.isNotEmpty) {
      partes.add(comida);
    }
    if (c.items.isNotEmpty) {
      final items = c.items
          .take(2)
          .map((item) => '${item.cantidad}x ${item.productoNombre}')
          .join(', ');
      if (items.isNotEmpty) {
        partes.add(items);
      }
    }
    if (partes.isEmpty) return base;
    return '$base\n🍽 ${partes.join(' · ')}';
  }

  String _previewTexto(String value, [int max = 70]) {
    final limpio = value.replaceAll('\n', ' ').trim();
    if (limpio.length <= max) return limpio;
    return '${limpio.substring(0, max).trimRight()}…';
  }

  Widget _detalleItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipEstado(EstadoReserva estado) {
    final color = _colorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _chipTipo(TipoReserva tipo) {
    final esEvento = tipo == TipoReserva.local;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (esEvento ? AppColors.secondary : AppColors.info).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        esEvento ? 'Evento' : 'Mesa',
        style: TextStyle(
          color: esEvento ? AppColors.secondary : AppColors.info,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _colorEstado(EstadoReserva estado) {
    return switch (estado) {
      EstadoReserva.confirmada => Colors.green,
      EstadoReserva.cancelada => AppColors.error,
      EstadoReserva.completada => AppColors.info,
      EstadoReserva.noAsistio => Colors.deepPurple,
      EstadoReserva.pendiente => AppColors.warning,
    };
  }

  bool _ocurreEnFranja(Reserva reserva, int hour) {
    final slotStart = hour * 60;
    final slotEnd = (hour + 1) * 60;
    final start = _horaToMinutes(reserva.horaInicio);
    final end = _horaToMinutes(reserva.horaFin);
    return start < slotEnd && end > slotStart;
  }

  int _horaToMinutes(String value) {
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (hour * 60) + minute;
  }

  Future<void> _nuevaReserva(BuildContext context, List<Mesa> mesas) async {
    final result = await ReservaFormDialog.show(
      context,
      fecha: _selectedDay,
      mesas: mesas,
    );

    if (result == null || !context.mounted) return;

    final cliente = await _resolverClienteDesdeResultado(context, result);
    if (cliente == null) return;

    final ok = await ref
        .read(reservasProvider.notifier)
        .crearReserva(
          idCliente: cliente.idCliente,
          tipo: result.tipo,
          fecha: _selectedDay,
          horaInicio: result.horaInicio,
          horaFin: result.horaFin,
          numeroPersonas: result.numeroPersonas,
          mesaId: result.mesaId,
          mesaNombre: result.mesaNombre,
          clienteNombre: result.clienteNombre,
          clienteTelefono: result.clienteTelefono,
          clienteEmail: result.clienteEmail,
          notas: result.notas,
          estado: result.estado,
          tipoEvento: result.tipoEvento,
          requerimientos: result.requerimientos,
          nombreLocalEvento: result.nombreLocalEvento,
          manteles: result.manteles,
          colorManteleria: result.colorManteleria,
          precioEstimado: result.precioEstimado,
        );

    if (!context.mounted) return;
    if (!ok) {
      final msg = ref.read(reservasProvider).errorMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg ?? 'Error al reservar')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reservacion creada')));
  }

  Future<void> _editarReserva(
    BuildContext context,
    Reserva reserva,
    List<Mesa> mesas,
  ) async {
    final fecha = DateTime.tryParse(reserva.fecha) ?? _selectedDay;
    final result = await ReservaFormDialog.show(
      context,
      fecha: fecha,
      mesas: mesas,
      initialReserva: reserva,
    );

    if (result == null || !context.mounted) return;

    final cliente = await _resolverClienteDesdeResultado(context, result);
    if (cliente == null) return;

    final ok = await ref
        .read(reservasProvider.notifier)
        .actualizarReserva(
          reservaId: reserva.id,
          idCliente: cliente.idCliente,
          tipo: result.tipo,
          fecha: fecha,
          horaInicio: result.horaInicio,
          horaFin: result.horaFin,
          numeroPersonas: result.numeroPersonas,
          mesaId: result.mesaId,
          mesaNombre: result.mesaNombre,
          clienteNombre: result.clienteNombre,
          clienteTelefono: result.clienteTelefono,
          clienteEmail: result.clienteEmail,
          notas: result.notas,
          estado: result.estado,
          tipoEvento: result.tipoEvento,
          requerimientos: result.requerimientos,
          nombreLocalEvento: result.nombreLocalEvento,
          manteles: result.manteles,
          colorManteleria: result.colorManteleria,
          precioEstimado: result.precioEstimado,
        );

    if (!context.mounted) return;
    if (!ok) {
      final msg = ref.read(reservasProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? 'No se pudo actualizar la reservación')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reservación actualizada')));
  }

  Future<Cliente?> _resolverClienteDesdeResultado(
    BuildContext context,
    ReservaFormResult result,
  ) async {
    try {
      return await sl<ClienteService>().buscarOCrear({
        'cedula': result.clienteCedula,
        'nombres': result.clienteNombre,
        'telefono': result.clienteTelefono,
        'email': result.clienteEmail,
        'direccion': '',
      });
    } on BusinessException catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return null;
    } catch (e) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar cliente: $e')),
      );
      return null;
    }
  }
}

class _ResumenCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ResumenCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
