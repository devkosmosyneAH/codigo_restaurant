import 'package:restaurant_app/features/pagina_publica/data/models/public_config_model.dart';

/// Contrato del datasource local de configuración pública.
abstract class PublicConfigDatasource {
  Future<PublicConfigModel?> getConfig(String restaurantId);
  Future<PublicConfigModel> saveConfig(PublicConfigModel config);
}
