import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';

/// Contrato del repositorio de Clientes (dominio).
abstract class ClienteRepository {
  /// Devuelve todos los clientes activos del restaurante.
  ResultFuture<List<Cliente>> getClientes(String restaurantId);

  /// Busca un cliente por su cédula exacta.
  ResultFuture<Cliente?> getClienteByCedula(String restaurantId, String cedula);

  /// Búsqueda por texto libre (nombre, apellido, cédula, email, teléfono).
  ResultFuture<List<Cliente>> buscarClientes(String restaurantId, String query);

  /// Crea un cliente nuevo. Lanza excepción si la cédula ya existe.
  ResultFuture<Cliente> createCliente(Cliente cliente);

  /// Actualiza los datos de un cliente existente.
  ResultFuture<Cliente> updateCliente(Cliente cliente);

  /// Soft-delete: marca el cliente como inactivo.
  ResultFuture<void> deleteCliente(String restaurantId, String cedula);

  /// Resumen de ventas asociadas a la cédula.
  ResultFuture<ClienteResumen> getResumenCliente(
    String cedula,
    String restaurantId,
  );
}

/// Datos estadísticos del cliente calculados a partir de ventas.
class ClienteResumen {
  final String cedula;
  final int totalVisitas;
  final double totalGastado;
  final double ticketPromedio;
  final DateTime? primeraVisita;
  final DateTime? ultimaVisita;

  const ClienteResumen({
    required this.cedula,
    required this.totalVisitas,
    required this.totalGastado,
    required this.ticketPromedio,
    this.primeraVisita,
    this.ultimaVisita,
  });
}
