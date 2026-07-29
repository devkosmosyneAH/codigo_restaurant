import 'package:restaurant_app/Presentation/Models/pagina_publica/public_config_model.dart';

/// Contrato del datasource local de configuración pública.
abstract class PublicConfigDatasource {
  Future<PublicConfigModel?> getConfig(String restaurantId);
  Future<PublicConfigModel> saveConfig(PublicConfigModel config);
}