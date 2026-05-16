import 'package:restaurant_app/features/mesas/data/models/llamado_mesero_model.dart';

/// Contrato del datasource local para llamados a mesero.
abstract class LlamadoLocalDataSource {
  /// Crea un nuevo llamado.
  Future<void> createLlamado(LlamadoMeseroModel llamado);

  /// Obtiene los llamados pendientes del restaurante.
  Future<List<LlamadoMeseroModel>> getPendientes(String restaurantId);

  /// Marca un llamado como atendido.
  Future<void> marcarAtendido(String id);
}
