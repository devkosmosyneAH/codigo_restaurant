import 'package:restaurant_app/Presentation/Models/menu/drive_connection_model.dart';
import 'package:restaurant_app/Presentation/core/database/database_helper.dart';
import 'package:restaurant_app/Presentation/core/errors/exceptions.dart';

/// Acceso local (SQLite) a la tabla `drive_connections`.
///
/// La unicidad por restaurante se mantiene por índice único en
/// `restaurant_id` (definido en `database_tables.dart`).
class DriveConnectionLocalDatasource {
  final DatabaseHelper _dbHelper;

  DriveConnectionLocalDatasource({required DatabaseHelper dbHelper})
    : _dbHelper = dbHelper;

  static const String table = 'drive_connections';

  /// Retorna la conexión activa del restaurante, o null si no existe.
  Future<DriveConnectionModel?> getByRestaurantId(String restaurantId) async {
    try {
      final rows = await _dbHelper.query(
        table,
        where: 'restaurant_id = ?',
        whereArgs: [restaurantId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return DriveConnectionModel.fromMap(rows.first);
    } catch (e) {
      throw DatabaseException(message: 'Error al leer conexión Drive: $e');
    }
  }

  Future<void> upsert(DriveConnectionModel connection) async {
    try {
      await _dbHelper.insert(table, connection.toMap());
    } catch (e) {
      throw DatabaseException(message: 'Error al guardar conexión Drive: $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dbHelper.delete(table, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException(message: 'Error al borrar conexión Drive: $e');
    }
  }
}