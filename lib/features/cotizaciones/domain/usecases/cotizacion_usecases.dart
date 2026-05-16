import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/core/utils/usecase.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';
import 'package:restaurant_app/features/cotizaciones/domain/repositories/cotizacion_repository.dart';

/// Caso de uso: crear cotizacion.
class CreateCotizacion extends UseCase<void, Cotizacion> {
  final CotizacionRepository _repo;
  CreateCotizacion(this._repo);

  @override
  ResultFuture<void> call(Cotizacion params) => _repo.createCotizacion(params);
}

/// Caso de uso: listar cotizaciones por restaurante.
class GetCotizaciones extends UseCase<List<Cotizacion>, String> {
  final CotizacionRepository _repo;
  GetCotizaciones(this._repo);

  @override
  ResultFuture<List<Cotizacion>> call(String params) =>
      _repo.getCotizaciones(params);
}

class UpdateCotizacionEstadoParams {
  final String cotizacionId;
  final String estado;

  const UpdateCotizacionEstadoParams({
    required this.cotizacionId,
    required this.estado,
  });
}

/// Caso de uso: actualizar estado de cotizacion.
class UpdateCotizacionEstado
    extends UseCase<void, UpdateCotizacionEstadoParams> {
  final CotizacionRepository _repo;
  UpdateCotizacionEstado(this._repo);

  @override
  ResultFuture<void> call(UpdateCotizacionEstadoParams params) =>
      _repo.updateEstado(params.cotizacionId, params.estado);
}

/// Caso de uso: actualizar todos los campos de una cotizacion.
class UpdateCotizacion extends UseCase<void, Cotizacion> {
  final CotizacionRepository _repo;
  UpdateCotizacion(this._repo);

  @override
  ResultFuture<void> call(Cotizacion params) => _repo.updateCotizacion(params);
}

/// Caso de uso: eliminar una cotizacion.
class DeleteCotizacion extends UseCase<void, String> {
  final CotizacionRepository _repo;
  DeleteCotizacion(this._repo);

  @override
  ResultFuture<void> call(String params) => _repo.deleteCotizacion(params);
}
