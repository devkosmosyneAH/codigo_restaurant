import 'package:restaurant_app/features/clientes/data/models/cliente_model.dart';
import 'package:restaurant_app/features/clientes/domain/repositories/cliente_repository.dart';

/// Contrato del datasource local de Clientes.
abstract class ClienteLocalDataSource {
  Future<List<ClienteModel>> getClientes(String restaurantId);
  Future<ClienteModel?> getClienteByCedula(String restaurantId, String cedula);
  Future<List<ClienteModel>> buscarClientes(String restaurantId, String query);
  Future<ClienteModel> createCliente(ClienteModel cliente);
  Future<ClienteModel> updateCliente(ClienteModel cliente);
  Future<void> deleteCliente(String restaurantId, String cedula);
  Future<ClienteResumen> getResumenCliente(String cedula, String restaurantId);
}
