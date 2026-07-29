import 'package:dartz/dartz.dart';
import 'package:restaurant_app/Presentation/Models/caja/venta_model.dart';
import 'package:restaurant_app/Presentation/core/errors/exceptions.dart';
import 'package:restaurant_app/Presentation/core/errors/failures.dart';
import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/data/caja/caja_local_datasource.dart';
import 'package:restaurant_app/Presentation/domain/caja/repositories/caja_repository.dart';
import 'package:restaurant_app/Presentation/entities/caja/venta.dart';
import 'package:restaurant_app/Presentation/entities/cotizaciones/cotizacion.dart';
import 'package:restaurant_app/Presentation/entities/pedidos/pedido.dart';

/// Implementación del [CajaRepository].
class CajaRepositoryImpl implements CajaRepository {
  final CajaLocalDataSource _dataSource;

  CajaRepositoryImpl({required CajaLocalDataSource dataSource})
    : _dataSource = dataSource;

  @override
  ResultFuture<void> registrarVenta(Venta venta, {String? mesaId}) async {
    try {
      await _dataSource.registrarVenta(
        VentaModel.fromEntity(venta),
        mesaId: mesaId,
      );
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Venta>> getVentas(String restaurantId) async {
    try {
      final result = await _dataSource.getVentas(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Venta>> getVentasByFecha(
    String restaurantId,
    DateTime fecha,
  ) async {
    try {
      final result = await _dataSource.getVentasByFecha(restaurantId, fecha);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Venta?> getVentaById(String id) async {
    try {
      final result = await _dataSource.getVentaById(id);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Venta?> getVentaByPedido(String pedidoId) async {
    try {
      final result = await _dataSource.getVentaByPedido(pedidoId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Pedido>> getPedidosParaCobrar(String restaurantId) async {
    try {
      final result = await _dataSource.getPedidosParaCobrar(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<List<Cotizacion>> getCotizacionesParaCobrar(
    String restaurantId,
  ) async {
    try {
      final result = await _dataSource.getCotizacionesParaCobrar(restaurantId);
      return Right(result);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }
}
