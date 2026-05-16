import 'package:restaurant_app/features/mesas/data/models/mesa_model.dart';

/// Contrato del datasource local para Mesas.
///
/// Define las operaciones CRUD contra SQLite.
abstract class MesaLocalDataSource {
  /// Obtiene todas las mesas activas de un restaurante.
  Future<List<MesaModel>> getMesas(String restaurantId);

  /// Obtiene una mesa por su ID.
  Future<MesaModel?> getMesaById(String id);

  /// Crea una nueva mesa.
  Future<void> createMesa(MesaModel mesa);

  /// Actualiza una mesa existente.
  Future<void> updateMesa(MesaModel mesa);

  /// Elimina (soft delete) una mesa.
  Future<void> deleteMesa(String id);

  /// Cambia el estado de una mesa.
  Future<void> updateEstadoMesa(String id, String estado);

  /// Une dos o más mesas bajo un mismo ID de unión.
  Future<void> unirMesas(List<String> mesaIds, String unionId);

  /// Separa mesas que estaban unidas.
  Future<void> separarMesas(String unionId);

  /// Obtiene el siguiente número de mesa disponible.
  Future<int> getNextNumeroMesa(String restaurantId);
}
