import 'package:restaurant_app/core/database/database_helper.dart';

/// Gestiona el contador de secuenciales correlativos para comprobantes SRI.
///
/// El SRI exige numeración correlativa sin saltos por cada
/// combinación de establecimiento + punto de emisión.
/// El contador se guarda en SQLite para persistir entre sesiones.
class SriSecuencialService {
  final DatabaseHelper _db;

  SriSecuencialService({DatabaseHelper? db})
    : _db = db ?? DatabaseHelper.instance;

  /// Obtiene el siguiente número secuencial correlativo (ya incrementado)
  /// para la combinación [estab] + [puntoEmision] + [restaurantId].
  ///
  /// Retorna el secuencial como cadena de 9 dígitos con ceros a la izquierda.
  Future<String> siguiente({
    required String estab,
    required String puntoEmision,
    required String restaurantId,
  }) async {
    final key = '${estab.padLeft(3, '0')}_${puntoEmision.padLeft(3, '0')}';
    final db = await _db.database;

    return db.transaction<String>((txn) async {
      final rows = await txn.query(
        'sri_secuenciales',
        where: 'id = ? AND restaurant_id = ?',
        whereArgs: [key, restaurantId],
        limit: 1,
      );

      int siguiente;
      if (rows.isEmpty) {
        siguiente = 1;
        await txn.insert('sri_secuenciales', {
          'id': key,
          'restaurant_id': restaurantId,
          'ultimo_secuencial': siguiente,
        });
      } else {
        siguiente = ((rows.first['ultimo_secuencial'] as int?) ?? 0) + 1;
        await txn.update(
          'sri_secuenciales',
          {'ultimo_secuencial': siguiente},
          where: 'id = ? AND restaurant_id = ?',
          whereArgs: [key, restaurantId],
        );
      }

      return siguiente.toString().padLeft(9, '0');
    });
  }

  /// Devuelve el último secuencial usado sin incrementar (para consultas).
  Future<int> ultimo({
    required String estab,
    required String puntoEmision,
    required String restaurantId,
  }) async {
    final key = '${estab.padLeft(3, '0')}_${puntoEmision.padLeft(3, '0')}';
    final rows = await _db.query(
      'sri_secuenciales',
      where: 'id = ? AND restaurant_id = ?',
      whereArgs: [key, restaurantId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['ultimo_secuencial'] as int?) ?? 0;
  }
}
