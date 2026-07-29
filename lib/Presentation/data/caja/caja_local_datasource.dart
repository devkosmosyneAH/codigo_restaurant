import 'package:restaurant_app/Presentation/Models/caja/venta_model.dart';
import 'package:restaurant_app/Presentation/Models/cotizaciones/cotizacion_model.dart';
import 'package:restaurant_app/Presentation/Models/pedidos/pedido_model.dart';

/// Contrato del datasource local para el módulo de Caja.
abstract class CajaLocalDataSource {
  /// Registra una venta nueva de forma atómica:
  /// crea la venta, los detalles, actualiza el pedido a [entregado]
  /// y libera la mesa si [mesaId] está presente.
  Future<void> registrarVenta(VentaModel venta, {String? mesaId});

  /// Obtiene todas las ventas del restaurante ordenadas por fecha desc.
  Future<List<VentaModel>> getVentas(String restaurantId);

  /// Obtiene las ventas de una fecha específica.
  Future<List<VentaModel>> getVentasByFecha(
    String restaurantId,
    DateTime fecha,
  );

  /// Obtiene una venta por su ID incluyendo los detalles.
  Future<VentaModel?> getVentaById(String id);

  /// Obtiene la venta asociada a un pedido (si existe).
  Future<VentaModel?> getVentaByPedido(String pedidoId);

  /// Obtiene los pedidos listos para cobrar (estado = finalizado).
  Future<List<PedidoModel>> getPedidosParaCobrar(String restaurantId);

  /// Obtiene las cotizaciones con estado 'aceptada' pendientes de cobro.
  Future<List<CotizacionModel>> getCotizacionesParaCobrar(String restaurantId);
}