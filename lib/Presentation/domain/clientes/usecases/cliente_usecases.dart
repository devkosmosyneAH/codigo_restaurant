import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/domain/clientes/repositories/cliente_repository.dart';
import 'package:restaurant_app/Presentation/entities/clientes/cliente.dart';

class GetClientes {
  const GetClientes(this._repo);
  final ClienteRepository _repo;

  ResultFuture<List<Cliente>> call(String restaurantId) =>
      _repo.getClientes(restaurantId);
}

class GetClienteByCedula {
  const GetClienteByCedula(this._repo);
  final ClienteRepository _repo;

  ResultFuture<Cliente?> call(String restaurantId, String cedula) =>
      _repo.getClienteByCedula(restaurantId, cedula);
}

class BuscarClientes {
  const BuscarClientes(this._repo);
  final ClienteRepository _repo;

  ResultFuture<List<Cliente>> call(String restaurantId, String query) =>
      _repo.buscarClientes(restaurantId, query);
}

class CreateCliente {
  const CreateCliente(this._repo);
  final ClienteRepository _repo;

  ResultFuture<Cliente> call(Cliente cliente) => _repo.createCliente(cliente);
}

class UpdateCliente {
  const UpdateCliente(this._repo);
  final ClienteRepository _repo;

  ResultFuture<Cliente> call(Cliente cliente) => _repo.updateCliente(cliente);
}

class DeleteCliente {
  const DeleteCliente(this._repo);
  final ClienteRepository _repo;

  ResultFuture<void> call(String restaurantId, String cedula) =>
      _repo.deleteCliente(restaurantId, cedula);
}

class GetResumenCliente {
  const GetResumenCliente(this._repo);
  final ClienteRepository _repo;

  ResultFuture<ClienteResumen> call(String cedula, String restaurantId) =>
      _repo.getResumenCliente(cedula, restaurantId);
}
