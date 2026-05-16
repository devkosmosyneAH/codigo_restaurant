import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/core/utils/usecase.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';
import 'package:restaurant_app/features/mesas/domain/repositories/mesa_repository.dart';

/// Caso de uso: Obtener todas las mesas de un restaurante.
class GetMesas extends UseCase<List<Mesa>, String> {
  final MesaRepository _repository;

  GetMesas(this._repository);

  @override
  ResultFuture<List<Mesa>> call(String restaurantId) {
    return _repository.getMesas(restaurantId);
  }
}

/// Caso de uso: Obtener una mesa por ID.
class GetMesaById extends UseCase<Mesa, String> {
  final MesaRepository _repository;

  GetMesaById(this._repository);

  @override
  ResultFuture<Mesa> call(String id) {
    return _repository.getMesaById(id);
  }
}

/// Caso de uso: Crear una nueva mesa.
class CreateMesa extends UseCase<void, Mesa> {
  final MesaRepository _repository;

  CreateMesa(this._repository);

  @override
  ResultFuture<void> call(Mesa mesa) {
    return _repository.createMesa(mesa);
  }
}

/// Caso de uso: Actualizar una mesa.
class UpdateMesa extends UseCase<void, Mesa> {
  final MesaRepository _repository;

  UpdateMesa(this._repository);

  @override
  ResultFuture<void> call(Mesa mesa) {
    return _repository.updateMesa(mesa);
  }
}

/// Caso de uso: Eliminar (soft delete) una mesa.
class DeleteMesa extends UseCase<void, String> {
  final MesaRepository _repository;

  DeleteMesa(this._repository);

  @override
  ResultFuture<void> call(String id) {
    return _repository.deleteMesa(id);
  }
}

/// Parámetros para cambiar estado de mesa.
class UpdateEstadoMesaParams {
  final String id;
  final String estado;

  const UpdateEstadoMesaParams({required this.id, required this.estado});
}

/// Caso de uso: Cambiar el estado de una mesa.
class UpdateEstadoMesa extends UseCase<void, UpdateEstadoMesaParams> {
  final MesaRepository _repository;

  UpdateEstadoMesa(this._repository);

  @override
  ResultFuture<void> call(UpdateEstadoMesaParams params) {
    return _repository.updateEstadoMesa(params.id, params.estado);
  }
}

/// Caso de uso: Obtener siguiente número de mesa.
class GetNextNumeroMesa extends UseCase<int, String> {
  final MesaRepository _repository;

  GetNextNumeroMesa(this._repository);

  @override
  ResultFuture<int> call(String restaurantId) {
    return _repository.getNextNumeroMesa(restaurantId);
  }
}
