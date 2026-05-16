import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';

/// Contrato del repositorio de Mesas (capa de dominio).
///
/// Define las operaciones que la capa de presentación puede
/// solicitar sin conocer la fuente de datos.
abstract class MesaRepository {
  /// Obtiene todas las mesas activas de un restaurante.
  ResultFuture<List<Mesa>> getMesas(String restaurantId);

  /// Obtiene una mesa por su ID.
  ResultFuture<Mesa> getMesaById(String id);

  /// Crea una nueva mesa.
  ResultFuture<void> createMesa(Mesa mesa);

  /// Actualiza una mesa existente.
  ResultFuture<void> updateMesa(Mesa mesa);

  /// Elimina (soft delete) una mesa.
  ResultFuture<void> deleteMesa(String id);

  /// Cambia el estado de una mesa.
  ResultFuture<void> updateEstadoMesa(String id, String estado);

  /// Une dos o más mesas.
  ResultFuture<void> unirMesas(List<String> mesaIds, String unionId);

  /// Separa mesas unidas.
  ResultFuture<void> separarMesas(String unionId);

  /// Obtiene el siguiente número de mesa disponible.
  ResultFuture<int> getNextNumeroMesa(String restaurantId);
}
