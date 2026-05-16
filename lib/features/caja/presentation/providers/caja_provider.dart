import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta_detalle.dart';
import 'package:restaurant_app/features/caja/domain/usecases/caja_usecases.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion_item.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';
import 'package:restaurant_app/services/facturacion/sri_service.dart';
import 'package:uuid/uuid.dart';

/// Estado del módulo de Caja.
class CajaState {
  final List<Pedido> pedidosParaCobrar;
  final List<Cotizacion> cotizacionesParaCobrar;
  final List<Venta> ventasHoy;
  final List<Venta> todasLasVentas;
  final bool isLoading;
  final bool isProcessing;
  final String? errorMessage;
  final Venta? ultimaVenta;

  const CajaState({
    this.pedidosParaCobrar = const [],
    this.cotizacionesParaCobrar = const [],
    this.ventasHoy = const [],
    this.todasLasVentas = const [],
    this.isLoading = false,
    this.isProcessing = false,
    this.errorMessage,
    this.ultimaVenta,
  });

  CajaState copyWith({
    List<Pedido>? pedidosParaCobrar,
    List<Cotizacion>? cotizacionesParaCobrar,
    List<Venta>? ventasHoy,
    List<Venta>? todasLasVentas,
    bool? isLoading,
    bool? isProcessing,
    String? errorMessage,
    Venta? ultimaVenta,
    bool clearError = false,
    bool clearUltimaVenta = false,
  }) {
    return CajaState(
      pedidosParaCobrar: pedidosParaCobrar ?? this.pedidosParaCobrar,
      cotizacionesParaCobrar:
          cotizacionesParaCobrar ?? this.cotizacionesParaCobrar,
      ventasHoy: ventasHoy ?? this.ventasHoy,
      todasLasVentas: todasLasVentas ?? this.todasLasVentas,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      ultimaVenta: clearUltimaVenta ? null : (ultimaVenta ?? this.ultimaVenta),
    );
  }

  // ── Computed ─────────────────────────────────────────────────

  int get totalPedidosPendientes => pedidosParaCobrar.length;

  double get totalVentasHoy => ventasHoy.fold(0.0, (sum, v) => sum + v.total);

  int get cantidadVentasHoy => ventasHoy.length;

  double get ticketPromedioHoy =>
      cantidadVentasHoy == 0 ? 0.0 : totalVentasHoy / cantidadVentasHoy;

  double get totalPendientePorCobrar =>
      pedidosParaCobrar.fold(0.0, (sum, pedido) {
        final totalPedido = pedido.totalCalculado > 0
            ? pedido.totalCalculado
            : pedido.total;
        return sum + totalPedido;
      });

  Map<MetodoPago, double> get ventasPorMetodo {
    final map = <MetodoPago, double>{};
    for (final v in ventasHoy) {
      map[v.metodoPago] = (map[v.metodoPago] ?? 0) + v.total;
    }
    return map;
  }
}

/// Producto extra agregado manualmente desde caja al momento del cobro.
class CajaExtraItem {
  final String nombre;
  final double precio;
  final int cantidad;
  final String? productoId;
  final String? varianteNombre;

  const CajaExtraItem({
    required this.nombre,
    required this.precio,
    this.cantidad = 1,
    this.productoId,
    this.varianteNombre,
  });

  double get subtotal => precio * cantidad;
}

/// Notifier del módulo de Caja.
class CajaNotifier extends StateNotifier<CajaState> {
  final GetPedidosParaCobrar _getPedidosParaCobrar;
  final GetCotizacionesParaCobrar _getCotizacionesParaCobrar;
  final RegistrarVenta _registrarVenta;
  final GetVentas _getVentas;
  final GetVentasByFecha _getVentasByFecha;
  final SriService _sriService;

  CajaNotifier({
    required GetPedidosParaCobrar getPedidosParaCobrar,
    required GetCotizacionesParaCobrar getCotizacionesParaCobrar,
    required RegistrarVenta registrarVenta,
    required GetVentas getVentas,
    required GetVentasByFecha getVentasByFecha,
    required SriService sriService,
  }) : _getPedidosParaCobrar = getPedidosParaCobrar,
       _getCotizacionesParaCobrar = getCotizacionesParaCobrar,
       _registrarVenta = registrarVenta,
       _getVentas = getVentas,
       _getVentasByFecha = getVentasByFecha,
       _sriService = sriService,
       super(const CajaState());

  // ── Carga ──────────────────────────────────────────────────────

  Future<void> loadCaja([String? restaurantId]) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final rid = restaurantId ?? sl<TenantContext>().restaurantId;

    final pedidosResult = await _getPedidosParaCobrar(rid);
    pedidosResult.fold(
      (f) => state = state.copyWith(isLoading: false, errorMessage: f.message),
      (pedidos) async {
        final ventasResult = await _getVentasByFecha(rid, DateTime.now());
        ventasResult.fold(
          (f) => state = state.copyWith(
            isLoading: false,
            pedidosParaCobrar: pedidos,
            errorMessage: f.message,
          ),
          (ventas) => state = state.copyWith(
            isLoading: false,
            pedidosParaCobrar: pedidos,
            ventasHoy: ventas,
          ),
        );
      },
    );
    // Cargar cotizaciones aceptadas en paralelo (sin bloquear)
    loadCotizacionesParaCobrar(rid);
  }

  Future<void> loadCotizacionesParaCobrar([String? restaurantId]) async {
    final rid = restaurantId ?? sl<TenantContext>().restaurantId;
    final result = await _getCotizacionesParaCobrar(rid);
    result.fold(
      (f) => state = state.copyWith(errorMessage: f.message),
      (cotizaciones) =>
          state = state.copyWith(cotizacionesParaCobrar: cotizaciones),
    );
  }

  Future<void> loadHistorial([String? restaurantId]) async {
    final rid = restaurantId ?? sl<TenantContext>().restaurantId;
    final result = await _getVentas(rid);
    result.fold(
      (f) => state = state.copyWith(errorMessage: f.message),
      (ventas) => state = state.copyWith(todasLasVentas: ventas),
    );
  }

  // ── Cobro ──────────────────────────────────────────────────────

  /// Procesa el cobro de un pedido.
  ///
  /// Retorna la [Venta] creada si fue exitoso, o null en caso de error.
  Future<Venta?> cobrarPedido({
    required Pedido pedido,
    required MetodoPago metodoPago,
    TipoComprobante tipoComprobante = TipoComprobante.ticket,
    double descuento = 0,
    String? descripcion,
    int? idCliente,
    String tipoCliente = 'consumidor_final',
    String? identificacionCliente,
    String? nombreCliente,
    String? telefonoCliente,
    String? direccionCliente,
    String? clienteNombre,
    String? clienteEmail,
    String? clienteIdentificacion,
    String? cajeroId,
    List<CajaExtraItem> extraItems = const [],
    double impuestos = 0,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true);

    // Construir detalles desde los items del pedido
    final ventaId = const Uuid().v4();
    final detalles = pedido.items.map((item) {
      return VentaDetalle(
        id: const Uuid().v4(),
        ventaId: ventaId,
        productoId: item.productoId,
        varianteId: item.varianteId,
        cantidad: item.cantidad,
        precioUnitario: item.precioUnitario,
        subtotal: item.subtotal,
        productoNombre: item.productoNombre,
        varianteNombre: item.varianteNombre,
      );
    }).toList();

    // Agregar ítems extra ingresados en caja
    for (final extra in extraItems) {
      detalles.add(
        VentaDetalle(
          id: const Uuid().v4(),
          ventaId: ventaId,
          productoId: extra.productoId ?? 'manual',
          cantidad: extra.cantidad,
          precioUnitario: extra.precio,
          subtotal: extra.subtotal,
          productoNombre: extra.nombre,
          varianteNombre: extra.varianteNombre,
        ),
      );
    }

    final subtotal =
        pedido.totalCalculado + extraItems.fold(0.0, (s, e) => s + e.subtotal);
    final totalConDescuento = (subtotal - descuento).clamp(0.0, subtotal);

    final ventaBase = Venta(
      id: ventaId,
      restaurantId: pedido.restaurantId,
      pedidoId: pedido.id,
      cajeroId: cajeroId,
      idCliente: idCliente,
      tipoCliente: tipoCliente,
      identificacionCliente: identificacionCliente,
      nombreCliente: nombreCliente,
      telefonoCliente: telefonoCliente,
      direccionCliente: direccionCliente,
      clienteNombre: clienteNombre,
      clienteEmail: clienteEmail,
      clienteIdentificacion: clienteIdentificacion,
      metodoPago: metodoPago,
      tipoComprobante: tipoComprobante,
      subtotal: subtotal,
      impuestos: impuestos,
      total: totalConDescuento + impuestos,
      descripcionPago: descripcion,
      createdAt: DateTime.now(),
      detalles: detalles,
    );

    final sriDraft = tipoComprobante == TipoComprobante.factura
        ? await _sriService.buildInvoiceDraft(ventaBase)
        : null;
    final sriComprobanteId = sriDraft == null ? null : const Uuid().v4();

    final venta = ventaBase.copyWith(
      estadoSri: tipoComprobante == TipoComprobante.factura
          ? ((sriDraft?.status.canPrepareInvoice ?? false)
                ? EstadoComprobanteSri.pendienteEnvio
                : EstadoComprobanteSri.noConfigurado)
          : EstadoComprobanteSri.noAplica,
      sriClaveAcceso: sriDraft?.accessKey,
      sriComprobanteId: sriComprobanteId,
      sriXmlHash: sriDraft?.xmlHash,
      sriMensaje: tipoComprobante == TipoComprobante.factura
          ? sriDraft?.status.message ?? 'Factura preparada localmente.'
          : 'Comprobante interno generado sin envío fiscal.',
    );

    final result = await _registrarVenta(venta, mesaId: pedido.mesaId);

    return result.fold(
      (f) {
        state = state.copyWith(isProcessing: false, errorMessage: f.message);
        return null;
      },
      (_) {
        _scheduleSriSubmission(venta, sriDraft);
        // Recargar datos
        loadCaja();
        state = state.copyWith(isProcessing: false, ultimaVenta: venta);
        return venta;
      },
    );
  }

  void clearUltimaVenta() {
    state = state.copyWith(clearUltimaVenta: true);
  }

  // ── Cobro de Cotización ───────────────────────────────────────

  /// Procesa el cobro de una cotización aceptada.
  ///
  /// Los [items] son los ítems editados en el diálogo (pueden diferir
  /// de los originales de la cotización por cambios de última hora).
  /// Retorna la [Venta] creada si fue exitoso, o null en caso de error.
  Future<Venta?> cobrarCotizacion({
    required Cotizacion cotizacion,
    required List<CotizacionItem> items,
    required MetodoPago metodoPago,
    TipoComprobante tipoComprobante = TipoComprobante.ticket,
    double descuento = 0,
    double impuestos = 0,
    String? cajeroId,
    int? idCliente,
    String tipoCliente = 'consumidor_final',
    String? identificacionCliente,
    String? nombreCliente,
    String? telefonoCliente,
    String? direccionCliente,
    String? descripcion,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true);

    final ventaId = const Uuid().v4();

    final detalles = items.map((item) {
      return VentaDetalle(
        id: const Uuid().v4(),
        ventaId: ventaId,
        productoId: item.productoId ?? 'cotizacion_item',
        cantidad: item.cantidad,
        precioUnitario: item.precioUnitario,
        subtotal: item.subtotal,
        productoNombre: item.productoNombre,
      );
    }).toList();

    final subtotal = items.fold(0.0, (sum, it) => sum + it.subtotal);
    final totalConDescuento = (subtotal - descuento).clamp(0.0, subtotal);

    final restaurantId = cotizacion.restaurantId;

    final ventaBase = Venta(
      id: ventaId,
      restaurantId: restaurantId,
      pedidoId: cotizacion.id,
      cajeroId: cajeroId,
      idCliente: idCliente ?? cotizacion.idCliente,
      tipoCliente: tipoCliente,
      identificacionCliente: identificacionCliente,
      nombreCliente: nombreCliente ?? cotizacion.clienteNombre,
      telefonoCliente: telefonoCliente ?? cotizacion.clienteTelefono,
      direccionCliente: direccionCliente ?? cotizacion.clienteDireccion,
      clienteEmail: cotizacion.clienteEmail,
      metodoPago: metodoPago,
      tipoComprobante: tipoComprobante,
      subtotal: subtotal,
      impuestos: impuestos,
      total: totalConDescuento + impuestos,
      descripcionPago: descripcion,
      createdAt: DateTime.now(),
      detalles: detalles,
      sourceCotizacionId: cotizacion.id,
    );

    final sriDraft = tipoComprobante == TipoComprobante.factura
        ? await _sriService.buildInvoiceDraft(ventaBase)
        : null;
    final sriComprobanteId = sriDraft == null ? null : const Uuid().v4();

    final venta = ventaBase.copyWith(
      estadoSri: tipoComprobante == TipoComprobante.factura
          ? ((sriDraft?.status.canPrepareInvoice ?? false)
                ? EstadoComprobanteSri.pendienteEnvio
                : EstadoComprobanteSri.noConfigurado)
          : EstadoComprobanteSri.noAplica,
      sriClaveAcceso: sriDraft?.accessKey,
      sriComprobanteId: sriComprobanteId,
      sriXmlHash: sriDraft?.xmlHash,
      sriMensaje: tipoComprobante == TipoComprobante.factura
          ? sriDraft?.status.message ?? 'Factura preparada localmente.'
          : 'Comprobante interno generado sin envío fiscal.',
    );

    final result = await _registrarVenta(venta);

    return result.fold(
      (f) {
        state = state.copyWith(isProcessing: false, errorMessage: f.message);
        return null;
      },
      (_) {
        _scheduleSriSubmission(venta, sriDraft);
        loadCaja();
        state = state.copyWith(isProcessing: false, ultimaVenta: venta);
        return venta;
      },
    );
  }

  void _scheduleSriSubmission(Venta venta, SriInvoiceDraft? draft) {
    if (draft == null || !draft.status.canPrepareInvoice) return;
    unawaited(
      _sriService
          .submitInvoiceDraft(venta: venta, draft: draft)
          .catchError((_) => <String, dynamic>{}),
    );
  }
}

/// Provider global del módulo de Caja.
final cajaProvider = StateNotifierProvider<CajaNotifier, CajaState>((ref) {
  return CajaNotifier(
    getPedidosParaCobrar: sl(),
    getCotizacionesParaCobrar: sl(),
    registrarVenta: sl(),
    getVentas: sl(),
    getVentasByFecha: sl(),
    sriService: sl(),
  );
});
