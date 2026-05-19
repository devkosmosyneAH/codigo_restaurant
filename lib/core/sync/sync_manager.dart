import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
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
  final StreamController<void> _pendingChangesController =
      StreamController<void>.broadcast();

  SyncManager({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Emite un evento cada vez que cambia el estado de pendientes en sync_log.
  Stream<void> get onPendingChanges => _pendingChangesController.stream;

  /// Registra una operación para futura sincronización.
  Future<void> registrarOperacion({
    required String tabla,
    required String registroId,
    required SyncOperation operacion,
    required String restaurantId,
    Map<String, dynamic>? datos,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final normalizedDatos = _normalizeDatos(
      tabla: tabla,
      registroId: registroId,
      operacion: operacion,
      restaurantId: restaurantId,
      datos: datos,
      nowIso: nowIso,
    );

    // Dedupe: si ya existe un pendiente para la misma entidad, fusionamos.
    final existentes = await _dbHelper.query(
      'sync_log',
      where: 'sincronizado = ? AND tabla = ? AND registro_id = ?',
      whereArgs: [0, tabla, registroId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (existentes.isNotEmpty) {
      final previo = SyncRecord.fromMap(existentes.first);

      // Compatibilidad: inserts repetidos se mantienen como eventos separados.
      if (!(previo.operacion == SyncOperation.insert &&
          operacion == SyncOperation.insert)) {
        final operacionFusionada = _mergeOperacion(previo.operacion, operacion);

        // Insert seguido de delete => no hay cambio neto para enviar.
        if (operacionFusionada == null) {
          await _dbHelper.delete(
            'sync_log',
            where: 'id = ?',
            whereArgs: [previo.id],
          );
          _notifyPendingChanged();
          return;
        }

        final datosFusionados = _mergeDatos(
          previo.datos,
          normalizedDatos,
          operacionFusionada,
        );

        await _dbHelper.update(
          'sync_log',
          {
            'operacion': operacionFusionada.name,
            'datos': datosFusionados == null
                ? null
                : jsonEncode(datosFusionados),
            'intentos': 0,
            'updated_at': nowIso,
            'restaurant_id': restaurantId,
          },
          where: 'id = ?',
          whereArgs: [previo.id],
        );
        _notifyPendingChanged();
        return;
      }
    }

    final record = SyncRecord(
      id: _uuid.v4(),
      tabla: tabla,
      registroId: registroId,
      operacion: operacion,
      datos: normalizedDatos,
      createdAt: now,
      updatedAt: now,
      restaurantId: restaurantId,
    );

    await _dbHelper.insert('sync_log', record.toMap());
    _notifyPendingChanged();
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

  /// Obtiene pendientes filtrados por tabla.
  Future<List<SyncRecord>> obtenerPendientesPorTabla(String tabla) async {
    final results = await _dbHelper.query(
      'sync_log',
      where: 'sincronizado = ? AND tabla = ?',
      whereArgs: [0, tabla],
      orderBy: 'created_at ASC',
    );

    return results.map((row) => SyncRecord.fromMap(row)).toList();
  }

  /// Valida si ya existe un pendiente para la combinación tabla/registro.
  Future<bool> existePendiente({
    required String tabla,
    required String registroId,
  }) async {
    final results = await _dbHelper.query(
      'sync_log',
      where: 'sincronizado = ? AND tabla = ? AND registro_id = ?',
      whereArgs: [0, tabla, registroId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Obtiene el pendiente más reciente para una entidad específica.
  Future<SyncRecord?> obtenerPendiente({
    required String tabla,
    required String registroId,
  }) async {
    final results = await _dbHelper.query(
      'sync_log',
      where: 'sincronizado = ? AND tabla = ? AND registro_id = ?',
      whereArgs: [0, tabla, registroId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return SyncRecord.fromMap(results.first);
  }

  /// Marca un registro como sincronizado.
  Future<void> marcarSincronizado(String id) async {
    await _dbHelper.update(
      'sync_log',
      {'sincronizado': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyPendingChanged();
  }

  /// Incrementa el contador de intentos de un registro.
  Future<void> incrementarIntentos(String id) async {
    try {
      await _dbHelper.rawQuery(
        'UPDATE sync_log SET intentos = intentos + 1, '
        "updated_at = datetime('now') WHERE id = ?",
        [id],
      );
      return;
    } catch (_) {
      // Fallback para implementaciones donde UPDATE via rawQuery no aplique.
    }

    final rows = await _dbHelper.query(
      'sync_log',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final intentosActuales = (rows.first['intentos'] as int?) ?? 0;
    await _dbHelper.update(
      'sync_log',
      {
        'intentos': intentosActuales + 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Obtiene pendientes listos para enviarse, aplicando backoff exponencial.
  Future<List<SyncRecord>> obtenerPendientesParaEnvio({
    int limit = 100,
    bool forzar = false,
    int? maxRetries,
  }) async {
    final rows = await _dbHelper.query(
      'sync_log',
      where: 'sincronizado = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
      limit: limit * 5,
    );

    final now = DateTime.now();
    final maxIntentos = maxRetries ?? AppConstants.maxSyncRetries;

    final due = rows
        .map(SyncRecord.fromMap)
        .where((record) {
          if (forzar) return true;
          if (record.intentos >= maxIntentos) return false;
          return _isRetryDue(record, now);
        })
        .take(limit)
        .toList();

    return due;
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

  /// Registra auditoría local de sincronización por operación.
  Future<void> registrarAuditoria({
    required String direction,
    required String status,
    required String tabla,
    required String registroId,
    required String restaurantId,
    String? syncRecordId,
    String? detail,
  }) async {
    try {
      await _dbHelper.insert('sync_audit_log', {
        'id': _uuid.v4(),
        'sync_record_id': syncRecordId,
        'direction': direction,
        'status': status,
        'tabla': tabla,
        'registro_id': registroId,
        'restaurant_id': restaurantId,
        'detail': detail,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // La auditoría no debe bloquear el flujo principal de sincronización.
    }
  }

  SyncOperation? _mergeOperacion(SyncOperation previous, SyncOperation next) {
    if (previous == SyncOperation.insert && next == SyncOperation.delete) {
      return null;
    }
    if (next == SyncOperation.delete) return SyncOperation.delete;
    if (previous == SyncOperation.insert && next == SyncOperation.update) {
      return SyncOperation.insert;
    }
    if (previous == SyncOperation.delete && next == SyncOperation.insert) {
      return SyncOperation.update;
    }
    return next;
  }

  Map<String, dynamic>? _normalizeDatos({
    required String tabla,
    required String registroId,
    required SyncOperation operacion,
    required String restaurantId,
    required Map<String, dynamic>? datos,
    required String nowIso,
  }) {
    if (operacion == SyncOperation.delete) return null;

    final payload = <String, dynamic>{...?datos};

    // id_cliente es autonumerico local y no debe viajar como identidad global.
    if (tabla == 'clientes') {
      payload.remove('id_cliente');
    }

    payload['updated_at'] = payload['updated_at'] ?? nowIso;
    payload['restaurant_id'] = payload['restaurant_id'] ?? restaurantId;

    // En tablas con PK string por id, ayudamos a enviar id aunque el cambio sea parcial.
    if (!payload.containsKey('id') &&
        registroId.isNotEmpty &&
        !registroId.contains(':') &&
        tabla != 'clientes') {
      payload['id'] = registroId;
    }

    return payload;
  }

  Map<String, dynamic>? _mergeDatos(
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    SyncOperation finalOperation,
  ) {
    if (finalOperation == SyncOperation.delete) return null;

    return {...?oldData, ...?newData};
  }

  bool _isRetryDue(SyncRecord record, DateTime now) {
    if (record.intentos <= 0) return true;

    final seconds = switch (record.intentos) {
      1 => 15,
      2 => 45,
      3 => 120,
      _ => 300,
    };

    final dueAt = record.updatedAt.add(Duration(seconds: seconds));
    return !now.isBefore(dueAt);
  }

  void _notifyPendingChanged() {
    if (_pendingChangesController.isClosed) return;
    _pendingChangesController.add(null);
  }
}
