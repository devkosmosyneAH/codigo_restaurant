import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/pagina_publica/domain/entities/public_config.dart';
import 'package:restaurant_app/features/pagina_publica/domain/repositories/public_config_repository.dart';

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
