import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/reservaciones/domain/entities/reserva.dart';
import 'package:restaurant_app/features/reservaciones/domain/usecases/reserva_usecases.dart';
import 'package:uuid/uuid.dart';

/// Estado de reservaciones.
class ReservasState {
  final List<Reserva> reservasMes;
  final List<Reserva> reservasDia;
  final bool isLoading;
  final String? errorMessage;

  const ReservasState({
    this.reservasMes = const [],
    this.reservasDia = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get totalHoy => reservasDia.length;
  int get pendientesHoy =>
      reservasDia.where((r) => r.estado == EstadoReserva.pendiente).length;
  int get eventosHoy => reservasDia.where((r) => r.esEventoPrivado).length;

  ReservasState copyWith({
    List<Reserva>? reservasMes,
    List<Reserva>? reservasDia,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ReservasState(
      reservasMes: reservasMes ?? this.reservasMes,
      reservasDia: reservasDia ?? this.reservasDia,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ReservasNotifier extends StateNotifier<ReservasState> {
  final CreateReserva _createReserva;
  final UpdateReserva _updateReserva;
  final GetReservasByMonth _getByMonth;
  final GetReservasByDate _getByDate;

  ReservasNotifier({
    required CreateReserva createReserva,
    required UpdateReserva updateReserva,
    required GetReservasByMonth getByMonth,
    required GetReservasByDate getByDate,
  }) : _createReserva = createReserva,
       _updateReserva = updateReserva,
       _getByMonth = getByMonth,
       _getByDate = getByDate,
       super(const ReservasState());

  Future<void> loadMes(DateTime month, [String? restaurantId]) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final rid = restaurantId ?? sl<TenantContext>().restaurantId;
    final start = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime(month.year, month.month, 1));
    final end = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime(month.year, month.month + 1, 0));

    final result = await _getByMonth([rid, start, end]);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, errorMessage: f.message),
      (items) => state = state.copyWith(
        isLoading: false,
        reservasMes: _ordenarPorHora(items),
      ),
    );
  }

  Future<void> loadDia(DateTime day, [String? restaurantId]) async {
    final rid = restaurantId ?? sl<TenantContext>().restaurantId;
    final date = DateFormat('yyyy-MM-dd').format(day);
    final result = await _getByDate([rid, date]);
    result.fold(
      (f) => state = state.copyWith(errorMessage: f.message),
      (items) => state = state.copyWith(reservasDia: _ordenarPorHora(items)),
    );
  }

  Future<bool> crearReserva({
    int? idCliente,
    required TipoReserva tipo,
    required DateTime fecha,
    required String horaInicio,
    String? horaFin,
    required int numeroPersonas,
    String? mesaId,
    String? mesaNombre,
    required String clienteNombre,
    required String clienteTelefono,
    required String clienteEmail,
    String? notas,
    EstadoReserva estado = EstadoReserva.pendiente,
    String? tipoEvento,
    String? requerimientos,
    String? nombreLocalEvento,
    String? manteles,
    String? colorManteleria,
    double? precioEstimado,
    String? cotizacionId,
  }) {
    return _guardarReserva(
      idCliente: idCliente,
      tipo: tipo,
      fecha: fecha,
      horaInicio: horaInicio,
      horaFin: horaFin,
      numeroPersonas: numeroPersonas,
      mesaId: mesaId,
      mesaNombre: mesaNombre,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      clienteEmail: clienteEmail,
      notas: notas,
      estado: estado,
      tipoEvento: tipoEvento,
      requerimientos: requerimientos,
      nombreLocalEvento: nombreLocalEvento,
      manteles: manteles,
      colorManteleria: colorManteleria,
      precioEstimado: precioEstimado,
      cotizacionId: cotizacionId,
    );
  }

  Future<bool> actualizarReserva({
    required String reservaId,
    int? idCliente,
    required TipoReserva tipo,
    required DateTime fecha,
    required String horaInicio,
    String? horaFin,
    required int numeroPersonas,
    String? mesaId,
    String? mesaNombre,
    required String clienteNombre,
    required String clienteTelefono,
    required String clienteEmail,
    String? notas,
    EstadoReserva estado = EstadoReserva.pendiente,
    String? tipoEvento,
    String? requerimientos,
    String? nombreLocalEvento,
    String? manteles,
    String? colorManteleria,
    double? precioEstimado,
  }) {
    return _guardarReserva(
      reservaId: reservaId,
      idCliente: idCliente,
      tipo: tipo,
      fecha: fecha,
      horaInicio: horaInicio,
      horaFin: horaFin,
      numeroPersonas: numeroPersonas,
      mesaId: mesaId,
      mesaNombre: mesaNombre,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      clienteEmail: clienteEmail,
      notas: notas,
      estado: estado,
      tipoEvento: tipoEvento,
      requerimientos: requerimientos,
      nombreLocalEvento: nombreLocalEvento,
      manteles: manteles,
      colorManteleria: colorManteleria,
      precioEstimado: precioEstimado,
    );
  }

  Future<bool> _guardarReserva({
    String? reservaId,
    int? idCliente,
    required TipoReserva tipo,
    required DateTime fecha,
    required String horaInicio,
    String? horaFin,
    required int numeroPersonas,
    String? mesaId,
    String? mesaNombre,
    required String clienteNombre,
    required String clienteTelefono,
    required String clienteEmail,
    String? notas,
    EstadoReserva estado = EstadoReserva.pendiente,
    String? tipoEvento,
    String? requerimientos,
    String? nombreLocalEvento,
    String? manteles,
    String? colorManteleria,
    double? precioEstimado,
    String? cotizacionId,
  }) async {
    state = state.copyWith(errorMessage: null);

    final dateStr = DateFormat('yyyy-MM-dd').format(fecha);
    final finalHoraFin = (horaFin == null || horaFin.isEmpty)
        ? _sumarMinutos(horaInicio, AppConstants.reservaDuracionMinutos)
        : horaFin;

    if (numeroPersonas <= 0) {
      state = state.copyWith(
        errorMessage: 'Ingresa un número válido de personas',
      );
      return false;
    }

    if (!_rangoHorarioValido(horaInicio, finalHoraFin)) {
      state = state.copyWith(
        errorMessage: 'La hora final debe ser mayor a la hora de inicio',
      );
      return false;
    }

    if (!_estaDentroHorario(horaInicio, finalHoraFin)) {
      state = state.copyWith(
        errorMessage:
            'La reserva debe estar dentro del horario del restaurante (${AppConstants.restaurantOpeningHour}:00 - ${AppConstants.restaurantClosingHour}:00)',
      );
      return false;
    }

    final reservas = state.reservasMes
        .where(
          (r) =>
              r.fecha == dateStr &&
              _reservaBloqueaHorario(r.estado) &&
              r.id != reservaId,
        )
        .toList();

    final conflictos = reservas.where((r) {
      return _hayCruceHorario(
        r.horaInicio,
        r.horaFin,
        horaInicio,
        finalHoraFin,
      );
    }).toList();

    if (tipo == TipoReserva.local && conflictos.isNotEmpty) {
      state = state.copyWith(
        errorMessage:
            'Ya existen reservas en ese horario. No se puede bloquear todo el local.',
      );
      return false;
    }

    if (tipo == TipoReserva.mesa) {
      if (mesaId == null || mesaId.isEmpty) {
        state = state.copyWith(errorMessage: 'Selecciona una mesa');
        return false;
      }

      final localReservado = conflictos.any((r) => r.tipo == TipoReserva.local);
      if (localReservado) {
        state = state.copyWith(
          errorMessage:
              'El local ya está reservado como evento privado en ese horario',
        );
        return false;
      }

      final mesaReservada = conflictos.any(
        (r) => r.tipo == TipoReserva.mesa && r.mesaId == mesaId,
      );
      if (mesaReservada) {
        state = state.copyWith(
          errorMessage: 'La mesa ya está reservada en ese horario',
        );
        return false;
      }
    }

    final reserva = Reserva(
      id: reservaId ?? const Uuid().v4(),
      restaurantId: sl<TenantContext>().restaurantId,
      tipo: tipo,
      mesaId: mesaId,
      mesaNombre: mesaNombre,
      idCliente: idCliente,
      fecha: dateStr,
      horaInicio: horaInicio,
      horaFin: finalHoraFin,
      numeroPersonas: numeroPersonas,
      estado: estado,
      tipoEvento: tipo == TipoReserva.local ? tipoEvento : null,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      clienteEmail: clienteEmail,
      notas: notas,
      requerimientos: requerimientos,
      createdAt: DateTime.now(),
      cotizacionId: cotizacionId,
      nombreLocalEvento: nombreLocalEvento,
      manteles: manteles,
      colorManteleria: colorManteleria,
      precioEstimado: precioEstimado,
    );

    final result = reservaId == null
        ? await _createReserva(reserva)
        : await _updateReserva(reserva);
    var ok = false;

    await result.fold<Future<void>>(
      (f) async {
        state = state.copyWith(errorMessage: f.message);
      },
      (_) async {
        await loadMes(fecha);
        await loadDia(fecha);
        ok = true;
      },
    );

    return ok;
  }

  /// Cambia el estado de una reserva existente sin modificar ningún otro campo.
  Future<bool> cambiarEstado(Reserva reserva, EstadoReserva nuevoEstado) async {
    final actualizada = reserva.copyWith(estado: nuevoEstado);
    var ok = false;
    final result = await _updateReserva(actualizada);
    await result.fold<Future<void>>(
      (f) async => state = state.copyWith(errorMessage: f.message),
      (_) async {
        final fecha = DateTime.parse(reserva.fecha);
        await loadMes(fecha);
        await loadDia(fecha);
        ok = true;
      },
    );
    return ok;
  }

  List<Reserva> _ordenarPorHora(List<Reserva> items) {
    final copy = [...items];
    copy.sort(
      (a, b) => _aMinutos(a.horaInicio).compareTo(_aMinutos(b.horaInicio)),
    );
    return copy;
  }

  bool _reservaBloqueaHorario(EstadoReserva estado) {
    return estado != EstadoReserva.cancelada &&
        estado != EstadoReserva.noAsistio &&
        estado != EstadoReserva.completada;
  }

  bool _hayCruceHorario(
    String inicioA,
    String finA,
    String inicioB,
    String finB,
  ) {
    final aInicio = _aMinutos(inicioA);
    final aFin = _aMinutos(finA);
    final bInicio = _aMinutos(inicioB);
    final bFin = _aMinutos(finB);
    return aInicio < bFin && bInicio < aFin;
  }

  bool _rangoHorarioValido(String inicio, String fin) {
    return _aMinutos(fin) > _aMinutos(inicio);
  }

  bool _estaDentroHorario(String inicio, String fin) {
    final apertura = AppConstants.restaurantOpeningHour * 60;
    final cierre = AppConstants.restaurantClosingHour * 60;
    return _aMinutos(inicio) >= apertura && _aMinutos(fin) <= cierre;
  }

  int _aMinutos(String value) {
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (hour * 60) + minute;
  }

  String _sumarMinutos(String value, int minutes) {
    final total = _aMinutos(value) + minutes;
    final hour = (total ~/ 60).toString().padLeft(2, '0');
    final minute = (total % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

final reservasProvider = StateNotifierProvider<ReservasNotifier, ReservasState>(
  (ref) {
    return ReservasNotifier(
      createReserva: sl<CreateReserva>(),
      updateReserva: sl<UpdateReserva>(),
      getByMonth: sl<GetReservasByMonth>(),
      getByDate: sl<GetReservasByDate>(),
    );
  },
);
