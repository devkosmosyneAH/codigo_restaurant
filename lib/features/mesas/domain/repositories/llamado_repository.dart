import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/mesas/domain/entities/llamado_mesero.dart';

/// Contrato del repositorio de llamados a mesero.
abstract class LlamadoRepository {
  /// Crea un llamado nuevo.
  ResultFuture<void> createLlamado(LlamadoMesero llamado);

  /// Obtiene los llamados pendientes.
  ResultFuture<List<LlamadoMesero>> getPendientes(String restaurantId);

  /// Marca un llamado como atendido.
  ResultFuture<void> marcarAtendido(String id);
}
