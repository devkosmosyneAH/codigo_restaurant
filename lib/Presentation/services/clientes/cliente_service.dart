import 'package:restaurant_app/Presentation/entities/clientes/cliente.dart';

/// Servicio central para lookup/creación rápida de clientes desde módulos externos.
abstract class ClienteService {
  Future<Cliente?> buscarPorCedula(String cedula);

  Future<Cliente> crearCliente(Map<String, dynamic> datos);

  Future<Cliente> buscarOCrear(Map<String, dynamic> datos);
}