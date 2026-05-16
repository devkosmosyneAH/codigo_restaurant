import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_mesero.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_metodo_pago.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_producto_vendido.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_resumen.dart';
import 'package:restaurant_app/features/reportes/domain/entities/reporte_venta_dia.dart';
import 'package:restaurant_app/features/reportes/domain/usecases/reportes_usecases.dart';

// ── Filtro de período ──────────────────────────────────────────────────────────

enum FiltroFecha {
  hoy,
  semana,
  mes,
  trimestre,
  personalizado;

  String get label {
    switch (this) {
      case FiltroFecha.hoy:
        return 'Hoy';
      case FiltroFecha.semana:
        return '7 días';
      case FiltroFecha.mes:
        return '30 días';
      case FiltroFecha.trimestre:
        return '3 meses';
      case FiltroFecha.personalizado:
        return 'Personalizado';
    }
  }

  /// Calcula [fechaInicio] relativo a [ahora].
  DateTime fechaInicio(DateTime ahora) {
    switch (this) {
      case FiltroFecha.hoy:
        return DateTime(ahora.year, ahora.month, ahora.day);
      case FiltroFecha.semana:
        return DateTime(
          ahora.year,
          ahora.month,
          ahora.day,
        ).subtract(const Duration(days: 6));
      case FiltroFecha.mes:
        return DateTime(
          ahora.year,
          ahora.month,
          ahora.day,
        ).subtract(const Duration(days: 29));
      case FiltroFecha.trimestre:
        return DateTime(
          ahora.year,
          ahora.month,
          ahora.day,
        ).subtract(const Duration(days: 89));
      case FiltroFecha.personalizado:
        return DateTime(
          ahora.year,
          ahora.month,
          ahora.day,
        ).subtract(const Duration(days: 6));
    }
  }

  DateTime fechaFin(DateTime ahora) =>
      DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59, 999);
}

// ── Estado ─────────────────────────────────────────────────────────────────────

class ReportesState {
  final FiltroFecha filtro;
  final ResumenVentas? resumen;
  final ResumenVentas? resumenPeriodoAnterior;
  final List<VentaPorDia> ventasPorDia;
  final List<ProductoVendido> topProductos;
  final List<VentaPorMetodo> ventasPorMetodo;
  final List<VentaPorMesero> ventasPorMesero;
  final DateTime? fechaInicioPersonalizada;
  final DateTime? fechaFinPersonalizada;
  final bool isLoading;
  final String? error;

  const ReportesState({
    this.filtro = FiltroFecha.semana,
    this.resumen,
    this.resumenPeriodoAnterior,
    this.ventasPorDia = const [],
    this.topProductos = const [],
    this.ventasPorMetodo = const [],
    this.ventasPorMesero = const [],
    this.fechaInicioPersonalizada,
    this.fechaFinPersonalizada,
    this.isLoading = false,
    this.error,
  });

  DateTime fechaInicioActiva(DateTime ahora) {
    if (filtro == FiltroFecha.personalizado &&
        fechaInicioPersonalizada != null) {
      return DateTime(
        fechaInicioPersonalizada!.year,
        fechaInicioPersonalizada!.month,
        fechaInicioPersonalizada!.day,
      );
    }
    return filtro.fechaInicio(ahora);
  }

  DateTime fechaFinActiva(DateTime ahora) {
    if (filtro == FiltroFecha.personalizado && fechaFinPersonalizada != null) {
      return DateTime(
        fechaFinPersonalizada!.year,
        fechaFinPersonalizada!.month,
        fechaFinPersonalizada!.day,
        23,
        59,
        59,
        999,
      );
    }
    return filtro.fechaFin(ahora);
  }

  ReportesState copyWith({
    FiltroFecha? filtro,
    ResumenVentas? resumen,
    ResumenVentas? resumenPeriodoAnterior,
    List<VentaPorDia>? ventasPorDia,
    List<ProductoVendido>? topProductos,
    List<VentaPorMetodo>? ventasPorMetodo,
    List<VentaPorMesero>? ventasPorMesero,
    DateTime? fechaInicioPersonalizada,
    DateTime? fechaFinPersonalizada,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ReportesState(
      filtro: filtro ?? this.filtro,
      resumen: resumen ?? this.resumen,
      resumenPeriodoAnterior:
          resumenPeriodoAnterior ?? this.resumenPeriodoAnterior,
      ventasPorDia: ventasPorDia ?? this.ventasPorDia,
      topProductos: topProductos ?? this.topProductos,
      ventasPorMetodo: ventasPorMetodo ?? this.ventasPorMetodo,
      ventasPorMesero: ventasPorMesero ?? this.ventasPorMesero,
      fechaInicioPersonalizada:
          fechaInicioPersonalizada ?? this.fechaInicioPersonalizada,
      fechaFinPersonalizada:
          fechaFinPersonalizada ?? this.fechaFinPersonalizada,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class ReportesNotifier extends StateNotifier<ReportesState> {
  ReportesNotifier({
    required GetResumenVentas getResumenVentas,
    required GetVentasPorDia getVentasPorDia,
    required GetTopProductos getTopProductos,
    required GetVentasPorMetodo getVentasPorMetodo,
    required GetVentasPorMesero getVentasPorMesero,
  }) : _getResumenVentas = getResumenVentas,
       _getVentasPorDia = getVentasPorDia,
       _getTopProductos = getTopProductos,
       _getVentasPorMetodo = getVentasPorMetodo,
       _getVentasPorMesero = getVentasPorMesero,
       super(const ReportesState()) {
    cargarReportes();
  }

  final GetResumenVentas _getResumenVentas;
  final GetVentasPorDia _getVentasPorDia;
  final GetTopProductos _getTopProductos;
  final GetVentasPorMetodo _getVentasPorMetodo;
  final GetVentasPorMesero _getVentasPorMesero;

  /// Cambia el filtro de período y recarga automáticamente.
  Future<void> cambiarFiltro(FiltroFecha filtro) async {
    if (filtro == FiltroFecha.personalizado) {
      final ahora = DateTime.now();
      state = state.copyWith(
        filtro: filtro,
        fechaInicioPersonalizada:
            state.fechaInicioPersonalizada ?? filtro.fechaInicio(ahora),
        fechaFinPersonalizada:
            state.fechaFinPersonalizada ?? filtro.fechaFin(ahora),
      );
    } else {
      state = state.copyWith(filtro: filtro);
    }
    await cargarReportes();
  }

  Future<void> cambiarRangoPersonalizado(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    state = state.copyWith(
      filtro: FiltroFecha.personalizado,
      fechaInicioPersonalizada: DateTime(
        fechaInicio.year,
        fechaInicio.month,
        fechaInicio.day,
      ),
      fechaFinPersonalizada: DateTime(
        fechaFin.year,
        fechaFin.month,
        fechaFin.day,
        23,
        59,
        59,
        999,
      ),
    );
    await cargarReportes();
  }

  /// Carga todos los datos del reporte en paralelo.
  Future<void> cargarReportes() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final ahora = DateTime.now();
    final inicio = state.fechaInicioActiva(ahora);
    final fin = state.fechaFinActiva(ahora);
    final restaurantId = sl<TenantContext>().restaurantId;

    final params = FiltroReporteParams(
      restaurantId: restaurantId,
      fechaInicio: inicio,
      fechaFin: fin,
    );

    // Período anterior: misma duración, inmediatamente antes del actual.
    final duracionDias = fin.difference(inicio).inDays;
    final finAnterior = inicio.subtract(const Duration(days: 1));
    final inicioAnterior = finAnterior.subtract(Duration(days: duracionDias));
    final paramsAnterior = FiltroReporteParams(
      restaurantId: restaurantId,
      fechaInicio: inicioAnterior,
      fechaFin: finAnterior,
    );

    final results = await Future.wait([
      _getResumenVentas(params),
      _getVentasPorDia(params),
      _getTopProductos(
        FiltroTopProductosParams(
          restaurantId: restaurantId,
          fechaInicio: inicio,
          fechaFin: fin,
          limit: 10,
        ),
      ),
      _getVentasPorMetodo(params),
      _getVentasPorMesero(params),
      _getResumenVentas(paramsAnterior),
    ]);

    final resumenResult = results[0];
    final diasResult = results[1];
    final productosResult = results[2];
    final metodosResult = results[3];
    final meserosResult = results[4];
    final resumenAnteriorResult = results[5];

    final errores = <String>[
      resumenResult.fold((f) => f.message, (_) => ''),
      diasResult.fold((f) => f.message, (_) => ''),
      productosResult.fold((f) => f.message, (_) => ''),
      metodosResult.fold((f) => f.message, (_) => ''),
      meserosResult.fold((f) => f.message, (_) => ''),
    ].where((m) => m.isNotEmpty).toSet().toList();

    state = state.copyWith(
      isLoading: false,
      error: errores.isEmpty ? null : errores.join('\n'),
      resumen: resumenResult.fold((_) => null, (r) => r as ResumenVentas),
      resumenPeriodoAnterior: resumenAnteriorResult.fold(
        (_) => null,
        (r) => r as ResumenVentas,
      ),
      ventasPorDia: diasResult.fold((_) => [], (r) => r as List<VentaPorDia>),
      topProductos: productosResult.fold(
        (_) => [],
        (r) => r as List<ProductoVendido>,
      ),
      ventasPorMetodo: metodosResult.fold(
        (_) => [],
        (r) => r as List<VentaPorMetodo>,
      ),
      ventasPorMesero: meserosResult.fold(
        (_) => [],
        (r) => r as List<VentaPorMesero>,
      ),
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final reportesProvider = StateNotifierProvider<ReportesNotifier, ReportesState>(
  (ref) {
    return ReportesNotifier(
      getResumenVentas: sl(),
      getVentasPorDia: sl(),
      getTopProductos: sl(),
      getVentasPorMetodo: sl(),
      getVentasPorMesero: sl(),
    );
  },
);
