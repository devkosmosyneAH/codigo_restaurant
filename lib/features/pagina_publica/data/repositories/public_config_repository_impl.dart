import 'package:dartz/dartz.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/errors/failures.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/pagina_publica/data/datasources/public_config_datasource.dart';
import 'package:restaurant_app/features/pagina_publica/data/models/public_config_model.dart';
import 'package:restaurant_app/features/pagina_publica/domain/entities/public_config.dart';
import 'package:restaurant_app/features/pagina_publica/domain/repositories/public_config_repository.dart';

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
