import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/caja/domain/entities/venta.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido.dart';

/// Contrato del repositorio de Caja (dominio).
abstract class CajaRepository {
  /// Registra una venta y actualiza pedido/mesa de forma atómica.
  ResultFuture<void> registrarVenta(Venta venta, {String? mesaId});

  /// Obtiene todas las ventas del restaurante.
  ResultFuture<List<Venta>> getVentas(String restaurantId);

  /// Obtiene las ventas de una fecha específica.
  ResultFuture<List<Venta>> getVentasByFecha(
    String restaurantId,
    DateTime fecha,
  );

  /// Obtiene una venta por su ID.
  ResultFuture<Venta?> getVentaById(String id);

  /// Obtiene la venta de un pedido (si ya fue cobrado).
  ResultFuture<Venta?> getVentaByPedido(String pedidoId);

  /// Obtiene los pedidos listos para cobrar (estado = finalizado).
  ResultFuture<List<Pedido>> getPedidosParaCobrar(String restaurantId);

  /// Obtiene las cotizaciones con estado 'aceptada' pendientes de cobro.
  ResultFuture<List<Cotizacion>> getCotizacionesParaCobrar(String restaurantId);
}
