import 'package:uuid/uuid.dart';
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';

/// Gestor de sincronización offline-first.
///
/// Registra todas las operaciones CRUD en [sync_log] para que
/// puedan sincronizarse con Firebase cuando haya conexión.
///
/// El envío remoto se ejecuta desde [SyncCloudService] y luego se marca
/// cada registro como sincronizado usando este manager.
class SyncManager {
  final DatabaseHelper _dbHelper;
  static const _uuid = Uuid();

  SyncManager({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Registra una operación para futura sincronización.
  Future<void> registrarOperacion({
    required String tabla,
    required String registroId,
    required SyncOperation operacion,
    required String restaurantId,
    Map<String, dynamic>? datos,
  }) async {
    final record = SyncRecord(
      id: _uuid.v4(),
      tabla: tabla,
      registroId: registroId,
      operacion: operacion,
      datos: datos,
      createdAt: DateTime.now(),
      restaurantId: restaurantId,
    );

    await _dbHelper.insert('sync_log', record.toMap());
  }

  /// Obtiene todos los registros pendientes de sincronización.
  Future<List<SyncRecord>> obtenerPendientes() async {
    final results = await _dbHelper.query(
      'sync_log',
      where: 'sincronizado = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );

    return results.map((row) => SyncRecord.fromMap(row)).toList();
  }

  /// Marca un registro como sincronizado.
  Future<void> marcarSincronizado(String id) async {
    await _dbHelper.update(
      'sync_log',
      {'sincronizado': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Incrementa el contador de intentos de un registro.
  Future<void> incrementarIntentos(String id) async {
    await _dbHelper.rawQuery(
      'UPDATE sync_log SET intentos = intentos + 1, '
      "updated_at = datetime('now') WHERE id = ?",
      [id],
    );
  }

  /// Limpia registros ya sincronizados con más de [dias] días.
  Future<void> limpiarSincronizados({int dias = 30}) async {
    await _dbHelper.delete(
      'sync_log',
      where: 'sincronizado = 1 AND created_at < ?',
      whereArgs: [
        DateTime.now().subtract(Duration(days: dias)).toIso8601String(),
      ],
    );
  }

  /// Obtiene los registros ya sincronizados (historial reciente, límite 100).
  Future<List<SyncRecord>> obtenerSincronizados({int limit = 100}) async {
    final results = await _dbHelper.query(
      'sync_log',
      where: 'sincronizado = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return results.map((row) => SyncRecord.fromMap(row)).toList();
  }

  /// Obtiene el conteo de registros pendientes.
  Future<int> contarPendientes() async {
    final result = await _dbHelper.rawQuery(
      'SELECT COUNT(*) as count FROM sync_log WHERE sincronizado = 0',
    );
    return result.first['count'] as int? ?? 0;
  }
}
