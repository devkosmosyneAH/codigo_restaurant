import 'package:dartz/dartz.dart';
import 'package:restaurant_app/Presentation/Models/pagina_publica/public_config_model.dart';
import 'package:restaurant_app/Presentation/core/errors/exceptions.dart';
import 'package:restaurant_app/Presentation/core/errors/failures.dart';
import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/data/pagina_publica/public_config_datasource.dart';
import 'package:restaurant_app/Presentation/domain/pagina_publica/repositories/public_config_repository.dart';
import 'package:restaurant_app/Presentation/entities/pagina_publica/public_config.dart';

class PublicConfigRepositoryImpl implements PublicConfigRepository {
  const PublicConfigRepositoryImpl({required PublicConfigDatasource datasource})
    : _datasource = datasource;

  final PublicConfigDatasource _datasource;

  @override
  ResultFuture<PublicConfig> getConfig(String restaurantId) async {
    try {
      final model = await _datasource.getConfig(restaurantId);
      return Right(model ?? PublicConfig.defaults(restaurantId));
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }

  @override
  ResultFuture<PublicConfig> saveConfig(PublicConfig config) async {
    try {
      final model = PublicConfigModel.fromEntity(
        config.copyWith(updatedAt: DateTime.now()),
      );
      final saved = await _datasource.saveConfig(model);
      return Right(saved);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(message: e.message));
    }
  }
}