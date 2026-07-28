import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/entities/pagina_publica/public_config.dart';

/// Contrato del repositorio de configuración pública.
abstract class PublicConfigRepository {
  /// Carga la configuración vigente (o los defaults si no existe).
  ResultFuture<PublicConfig> getConfig(String restaurantId);

  /// Guarda (inserta o reemplaza) la configuración.
  ResultFuture<PublicConfig> saveConfig(PublicConfig config);
}
