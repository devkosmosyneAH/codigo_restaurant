import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/core/utils/usecase.dart';
import 'package:restaurant_app/Presentation/domain/reservaciones/repositories/reserva_repository.dart';
import 'package:restaurant_app/Presentation/entities/reservaciones/reserva.dart';

class CreateReserva extends UseCase<void, Reserva> {
  final ReservaRepository _repo;
  CreateReserva(this._repo);

  @override
  ResultFuture<void> call(Reserva params) => _repo.createReserva(params);
}

class UpdateReserva extends UseCase<void, Reserva> {
  final ReservaRepository _repo;
  UpdateReserva(this._repo);

  @override
  ResultFuture<void> call(Reserva params) => _repo.updateReserva(params);
}

class GetReservasByMonth extends UseCase<List<Reserva>, List<String>> {
  final ReservaRepository _repo;
  GetReservasByMonth(this._repo);

  @override
  ResultFuture<List<Reserva>> call(List<String> params) =>
      _repo.getReservasByMonth(params[0], params[1], params[2]);
}

class GetReservasByDate extends UseCase<List<Reserva>, List<String>> {
  final ReservaRepository _repo;
  GetReservasByDate(this._repo);

  @override
  ResultFuture<List<Reserva>> call(List<String> params) =>
      _repo.getReservasByDate(params[0], params[1]);
}
