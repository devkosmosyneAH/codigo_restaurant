import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/domain/caja/repositories/caja_repository.dart';
import 'package:restaurant_app/Presentation/entities/caja/venta.dart';
import 'package:restaurant_app/Presentation/entities/cotizaciones/cotizacion.dart';
import 'package:restaurant_app/Presentation/entities/pedidos/pedido.dart';

// ═══════════════════════════════════════════════════════════════
// VENTAS
// ═══════════════════════════════════════════════════════════════

class RegistrarVenta {
  final CajaRepository _repo;
  RegistrarVenta(this._repo);
  ResultFuture<void> call(Venta venta, {String? mesaId}) =>
      _repo.registrarVenta(venta, mesaId: mesaId);
}

class GetVentas {
  final CajaRepository _repo;
  GetVentas(this._repo);
  ResultFuture<List<Venta>> call(String restaurantId) =>
      _repo.getVentas(restaurantId);
}

class GetVentasByFecha {
  final CajaRepository _repo;
  GetVentasByFecha(this._repo);
  ResultFuture<List<Venta>> call(String restaurantId, DateTime fecha) =>
      _repo.getVentasByFecha(restaurantId, fecha);
}

class GetVentaById {
  final CajaRepository _repo;
  GetVentaById(this._repo);
  ResultFuture<Venta?> call(String id) => _repo.getVentaById(id);
}

class GetVentaByPedido {
  final CajaRepository _repo;
  GetVentaByPedido(this._repo);
  ResultFuture<Venta?> call(String pedidoId) =>
      _repo.getVentaByPedido(pedidoId);
}

// ═══════════════════════════════════════════════════════════════
// PEDIDOS PARA COBRAR
// ═══════════════════════════════════════════════════════════════

class GetPedidosParaCobrar {
  final CajaRepository _repo;
  GetPedidosParaCobrar(this._repo);
  ResultFuture<List<Pedido>> call(String restaurantId) =>
      _repo.getPedidosParaCobrar(restaurantId);
}

class GetCotizacionesParaCobrar {
  final CajaRepository _repo;
  GetCotizacionesParaCobrar(this._repo);
  ResultFuture<List<Cotizacion>> call(String restaurantId) =>
      _repo.getCotizacionesParaCobrar(restaurantId);
}
