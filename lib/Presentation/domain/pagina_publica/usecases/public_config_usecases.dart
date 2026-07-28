import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/domain/pagina_publica/repositories/public_config_repository.dart';
import 'package:restaurant_app/Presentation/entities/pagina_publica/public_config.dart';

class GetPublicConfig {
  const GetPublicConfig(this._repository);
  final PublicConfigRepository _repository;

  ResultFuture<PublicConfig> call(String restaurantId) =>
      _repository.getConfig(restaurantId);
}

class SavePublicConfig {
  const SavePublicConfig(this._repository);
  final PublicConfigRepository _repository;

  ResultFuture<PublicConfig> call(PublicConfig config) =>
      _repository.saveConfig(config);
}
