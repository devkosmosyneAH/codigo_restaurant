import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/core/utils/usecase.dart';
import 'package:restaurant_app/features/mesas/domain/entities/llamado_mesero.dart';
import 'package:restaurant_app/features/mesas/domain/repositories/llamado_repository.dart';

/// Caso de uso: crear un llamado.
class CreateLlamado extends UseCase<void, LlamadoMesero> {
  final LlamadoRepository _repo;
  CreateLlamado(this._repo);

  @override
  ResultFuture<void> call(LlamadoMesero params) => _repo.createLlamado(params);
}

/// Caso de uso: obtener llamados pendientes.
class GetLlamadosPendientes extends UseCase<List<LlamadoMesero>, String> {
  final LlamadoRepository _repo;
  GetLlamadosPendientes(this._repo);

  @override
  ResultFuture<List<LlamadoMesero>> call(String restaurantId) =>
      _repo.getPendientes(restaurantId);
}

/// Caso de uso: marcar llamado atendido.
class MarcarLlamadoAtendido extends UseCase<void, String> {
  final LlamadoRepository _repo;
  MarcarLlamadoAtendido(this._repo);

  @override
  ResultFuture<void> call(String id) => _repo.marcarAtendido(id);
}
