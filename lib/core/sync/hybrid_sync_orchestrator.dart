import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/sync/sync_cloud_service.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';

/// Orquestador de sincronizacion hibrida (SQLite local + Firestore central).
///
/// Mantiene:
/// - Push incremental de pendientes locales hacia la nube.
/// - Pull en tiempo real desde Firestore a SQLite.
/// - Comportamiento offline-safe cuando no hay conectividad.
class HybridSyncOrchestrator {
  HybridSyncOrchestrator({
    required SyncManager syncManager,
    required SyncCloudService cloudService,
    required DatabaseHelper dbHelper,
    required TenantContext tenantContext,
    Connectivity? connectivity,
  }) : _syncManager = syncManager,
       _cloudService = cloudService,
       _dbHelper = dbHelper,
       _tenantContext = tenantContext,
       _connectivity = connectivity ?? Connectivity();

  static const Duration _pulseInterval = Duration(seconds: 30);
  static const int _pushBatchSize = 100;

  static const List<String> _realtimeTables = [
    'categorias',
    'productos',
    'variantes',
    'pedidos',
    'pedido_items',
    'mesas',
    'llamados_mesero',
    'cotizaciones',
    'cotizacion_items',
    'reservaciones',
    'clientes',
    'ventas',
    'usuarios',
    'public_config',
  ];

  final SyncManager _syncManager;
  final SyncCloudService _cloudService;
  final DatabaseHelper _dbHelper;
  final TenantContext _tenantContext;
  final Connectivity _connectivity;

  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _remoteSubs = {};
  final Map<String, Set<String>> _tableColumnsCache = {};

  Timer? _pulseTimer;
  StreamSubscription<dynamic>? _connectivitySub;

  bool _started = false;
  bool _online = false;
  bool _syncInProgress = false;
  bool _cloudSyncEnabled = true;
  String? _listeningTenantId;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _cloudSyncEnabled = _cloudService.isCloudSyncSupportedPlatform;

    // Estrategia explícita: sin soporte Firebase en plataforma => solo local.
    if (!_cloudSyncEnabled) {
      return;
    }

    try {
      await _refreshConnectivity();
    } catch (_) {
      // Fallback conservador cuando el plugin no esta disponible.
      _online = true;
    }

    try {
      _connectivitySub = _connectivity.onConnectivityChanged.listen((event) {
        final wasOnline = _online;
        _online = _hasConnectivity(event);
        if (!wasOnline && _online) {
          unawaited(_runCycle(reason: 'connectivity-restored'));
        }
        if (wasOnline && !_online) {
          unawaited(_stopRealtimeListeners());
        }
      });
    } catch (_) {
      _connectivitySub = null;
    }

    _pulseTimer = Timer.periodic(
      _pulseInterval,
      (_) => unawaited(_runCycle(reason: 'pulse')),
    );

    await _runCycle(reason: 'startup');
  }

  Future<void> stop() async {
    _pulseTimer?.cancel();
    _pulseTimer = null;

    await _connectivitySub?.cancel();
    _connectivitySub = null;

    await _stopRealtimeListeners();
    _started = false;
  }

  Future<void> _runCycle({required String reason}) async {
    if (!_started || !_cloudSyncEnabled || _syncInProgress) return;

    if (!_online) {
      await _stopRealtimeListeners();
      return;
    }

    _syncInProgress = true;
    try {
      await _cloudService.ensureAvailable();
      await _ensureRealtimeListeners();
      await _pushPendingRecords();
    } catch (_) {
      // Si la nube falla (auth/config/transitorio), mantenemos modo local.
      await _stopRealtimeListeners();
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _pushPendingRecords() async {
    final pendientes = await _syncManager.obtenerPendientesParaEnvio(
      limit: _pushBatchSize,
    );

    for (final record in pendientes) {
      try {
        await _cloudService.pushRecord(record);
        await _syncManager.marcarSincronizado(record.id);
        await _syncManager.registrarAuditoria(
          direction: 'push',
          status: 'success',
          tabla: record.tabla,
          registroId: record.registroId,
          restaurantId: record.restaurantId,
          syncRecordId: record.id,
        );
      } catch (_) {
        await _syncManager.incrementarIntentos(record.id);
        await _syncManager.registrarAuditoria(
          direction: 'push',
          status: 'error',
          tabla: record.tabla,
          registroId: record.registroId,
          restaurantId: record.restaurantId,
          syncRecordId: record.id,
          detail: 'push_failed',
        );
      }
    }
  }

  Future<void> _ensureRealtimeListeners() async {
    final tenantId = _tenantContext.restaurantId;
    if (tenantId.isEmpty) return;

    final alreadyListeningSameTenant =
        _listeningTenantId == tenantId &&
        _remoteSubs.length == _realtimeTables.length;
    if (alreadyListeningSameTenant) return;

    await _stopRealtimeListeners();
    _listeningTenantId = tenantId;

    for (final table in _realtimeTables) {
      final query = await _buildRealtimeQuery(table: table, tenantId: tenantId);
      final sub = query.snapshots().listen(
        (snapshot) => unawaited(
          _handleRemoteSnapshot(
            table: table,
            tenantId: tenantId,
            snapshot: snapshot,
          ),
        ),
        onError: (error) {
          unawaited(
            _syncManager.registrarAuditoria(
              direction: 'pull',
              status: 'stream_error',
              tabla: table,
              registroId: '*',
              restaurantId: tenantId,
              detail: error.toString(),
            ),
          );
          // Mantener resiliencia: siguiente pulso intentara restablecer.
        },
      );
      _remoteSubs[table] = sub;
    }
  }

  Future<void> _stopRealtimeListeners() async {
    for (final sub in _remoteSubs.values) {
      await sub.cancel();
    }
    _remoteSubs.clear();
    _listeningTenantId = null;
  }

  Future<void> _handleRemoteSnapshot({
    required String table,
    required String tenantId,
    required QuerySnapshot<Map<String, dynamic>> snapshot,
  }) async {
    for (final change in snapshot.docChanges) {
      final docId = change.doc.id;
      try {
        if (change.type == DocumentChangeType.removed) {
          await _applyRemoteDelete(
            table: table,
            tenantId: tenantId,
            docId: docId,
          );
          continue;
        }

        final data = change.doc.data();
        if (data == null) continue;

        await _applyRemoteUpsert(
          table: table,
          tenantId: tenantId,
          docId: docId,
          rawData: data,
        );
      } catch (_) {
        await _syncManager.registrarAuditoria(
          direction: 'pull',
          status: 'error',
          tabla: table,
          registroId: docId,
          restaurantId: tenantId,
          detail: 'pull_apply_failed',
        );
      }
    }
  }

  Future<void> _applyRemoteDelete({
    required String table,
    required String tenantId,
    required String docId,
  }) async {
    final lookup = await _lookupForRow(
      table: table,
      tenantId: tenantId,
      docId: docId,
    );
    if (lookup == null) {
      await _syncManager.registrarAuditoria(
        direction: 'pull',
        status: 'ignored',
        tabla: table,
        registroId: docId,
        restaurantId: tenantId,
        detail: 'lookup_not_supported_for_delete',
      );
      return;
    }

    await _dbHelper.delete(
      table,
      where: lookup.where,
      whereArgs: lookup.whereArgs,
    );
    await _syncManager.registrarAuditoria(
      direction: 'pull',
      status: 'deleted',
      tabla: table,
      registroId: docId,
      restaurantId: tenantId,
    );
  }

  Future<void> _applyRemoteUpsert({
    required String table,
    required String tenantId,
    required String docId,
    required Map<String, dynamic> rawData,
  }) async {
    final payload = await _sanitizePayload(
      table: table,
      tenantId: tenantId,
      docId: docId,
      rawData: rawData,
    );
    if (payload.isEmpty) {
      await _syncManager.registrarAuditoria(
        direction: 'pull',
        status: 'ignored',
        tabla: table,
        registroId: docId,
        restaurantId: tenantId,
        detail: 'empty_payload',
      );
      return;
    }

    final registroId = table == 'clientes'
        ? _registroIdClientes(tenantId: tenantId, docId: docId, data: payload)
        : docId;

    final pendingRecord = await _syncManager.obtenerPendiente(
      tabla: table,
      registroId: registroId,
    );

    // Protección ante desfase de reloj: si existe cambio local pendiente,
    // solo aceptamos el eco remoto del mismo sync_record.
    if (pendingRecord != null) {
      final remoteRecordId = _extractRemoteSyncRecordId(rawData);
      final isLocalEcho =
          remoteRecordId != null && remoteRecordId == pendingRecord.id;

      if (!isLocalEcho) {
        await _syncManager.registrarAuditoria(
          direction: 'pull',
          status: 'deferred',
          tabla: table,
          registroId: registroId,
          restaurantId: tenantId,
          syncRecordId: pendingRecord.id,
          detail: 'local_pending_wins',
        );
        return;
      }
    }

    final local = await _loadLocalRow(
      table: table,
      tenantId: tenantId,
      docId: docId,
      payload: payload,
    );

    if (!_shouldApplyRemote(local: local, remotePayload: payload)) {
      await _syncManager.registrarAuditoria(
        direction: 'pull',
        status: 'stale_remote',
        tabla: table,
        registroId: registroId,
        restaurantId: tenantId,
      );
      return;
    }

    await _upsertLocalRow(
      table: table,
      tenantId: tenantId,
      docId: docId,
      payload: payload,
      localRow: local,
    );

    await _syncManager.registrarAuditoria(
      direction: 'pull',
      status: 'applied',
      tabla: table,
      registroId: registroId,
      restaurantId: tenantId,
      syncRecordId: _extractRemoteSyncRecordId(rawData),
    );
  }

  Future<Map<String, dynamic>?> _loadLocalRow({
    required String table,
    required String tenantId,
    required String docId,
    required Map<String, dynamic> payload,
  }) async {
    final lookup = await _lookupForRow(
      table: table,
      tenantId: tenantId,
      docId: docId,
      payload: payload,
    );
    if (lookup == null) return null;

    final rows = await _dbHelper.query(
      table,
      where: lookup.where,
      whereArgs: lookup.whereArgs,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _upsertLocalRow({
    required String table,
    required String tenantId,
    required String docId,
    required Map<String, dynamic> payload,
    required Map<String, dynamic>? localRow,
  }) async {
    if (table == 'clientes') {
      final cedula = _extractCedula(docId: docId, data: payload);
      if (cedula == null) return;

      final data = <String, dynamic>{...payload};
      final nowIso = DateTime.now().toIso8601String();

      data['restaurant_id'] = tenantId;
      data['cedula'] = cedula;
      data['nombre'] = (data['nombre']?.toString().trim().isNotEmpty ?? false)
          ? data['nombre']
          : (data['nombres']?.toString().trim().isNotEmpty ?? false)
          ? data['nombres']
          : 'Cliente';
      data['nombres'] = (data['nombres']?.toString().trim().isNotEmpty ?? false)
          ? data['nombres']
          : data['nombre'];
      data['activo'] = data['activo'] ?? 1;
      data['estado'] = data['estado'] ?? 1;
      data['created_at'] = data['created_at'] ?? nowIso;
      data['updated_at'] = data['updated_at'] ?? nowIso;

      if (localRow == null) {
        await _dbHelper.insert(table, data);
      } else {
        await _dbHelper.update(
          table,
          data,
          where: 'restaurant_id = ? AND cedula = ?',
          whereArgs: [tenantId, cedula],
        );
      }
      return;
    }

    final lookup = await _lookupForRow(
      table: table,
      tenantId: tenantId,
      docId: docId,
      payload: payload,
    );
    if (lookup == null) return;

    if (localRow == null) {
      await _dbHelper.insert(table, payload);
    } else {
      await _dbHelper.update(
        table,
        payload,
        where: lookup.where,
        whereArgs: lookup.whereArgs,
      );
    }
  }

  Future<_TableLookup?> _lookupForRow({
    required String table,
    required String tenantId,
    required String docId,
    Map<String, dynamic>? payload,
  }) async {
    if (table == 'clientes') {
      final cedula = _extractCedula(docId: docId, data: payload);
      if (cedula == null) return null;
      return _TableLookup(
        where: 'restaurant_id = ? AND cedula = ?',
        whereArgs: [tenantId, cedula],
      );
    }

    final columns = await _getTableColumns(table);
    if (columns.contains('id')) {
      return _TableLookup(where: 'id = ?', whereArgs: [docId]);
    }

    if (columns.contains('restaurant_id')) {
      return _TableLookup(where: 'restaurant_id = ?', whereArgs: [tenantId]);
    }

    return null;
  }

  Future<Map<String, dynamic>> _sanitizePayload({
    required String table,
    required String tenantId,
    required String docId,
    required Map<String, dynamic> rawData,
  }) async {
    final allowedColumns = await _getTableColumns(table);

    final payload = <String, dynamic>{};
    for (final entry in rawData.entries) {
      if (entry.key == '_sync') continue;
      if (!allowedColumns.contains(entry.key)) continue;
      payload[entry.key] = _normalizeValue(entry.value);
    }

    final nowIso = DateTime.now().toIso8601String();

    if (allowedColumns.contains('restaurant_id')) {
      payload['restaurant_id'] = tenantId;
    }

    if (table != 'clientes' && allowedColumns.contains('id')) {
      payload['id'] = payload['id'] ?? docId;
    }

    if (allowedColumns.contains('created_at')) {
      final createdAt = _toIsoString(payload['created_at']);
      payload['created_at'] = createdAt ?? nowIso;
    }

    if (allowedColumns.contains('updated_at')) {
      final updatedAt = _toIsoString(payload['updated_at']);
      payload['updated_at'] = updatedAt ?? nowIso;
    }

    if (table == 'clientes') {
      final cedula = _extractCedula(docId: docId, data: payload);
      if (cedula == null) return const {};
      payload.remove('id_cliente');
      payload['cedula'] = cedula;
    }

    return payload;
  }

  bool _shouldApplyRemote({
    required Map<String, dynamic>? local,
    required Map<String, dynamic> remotePayload,
  }) {
    if (local == null) return true;

    final remoteTs =
        _parseDateTime(remotePayload['updated_at']) ??
        _parseDateTime(remotePayload['created_at']);
    final localTs =
        _parseDateTime(local['updated_at']) ??
        _parseDateTime(local['created_at']);

    if (remoteTs == null || localTs == null) {
      return true;
    }

    return !remoteTs.isBefore(localTs);
  }

  Future<Query<Map<String, dynamic>>> _buildRealtimeQuery({
    required String table,
    required String tenantId,
  }) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('restaurantes')
        .doc(tenantId)
        .collection(table);

    final cursor = await _loadLocalRealtimeCursor(
      table: table,
      tenantId: tenantId,
    );
    if (cursor == null) return query;

    return query
        .where('updated_at', isGreaterThan: cursor)
        .orderBy('updated_at');
  }

  Future<String?> _loadLocalRealtimeCursor({
    required String table,
    required String tenantId,
  }) async {
    final columns = await _getTableColumns(table);
    final supportsCursor =
        columns.contains('updated_at') && columns.contains('restaurant_id');
    if (!supportsCursor) return null;

    final rows = await _dbHelper.rawQuery(
      'SELECT MAX(updated_at) as max_updated_at FROM $table WHERE restaurant_id = ?',
      [tenantId],
    );

    if (rows.isEmpty) return null;
    final cursor = _toIsoString(rows.first['max_updated_at']);
    if (cursor == null || cursor.isEmpty) return null;
    return cursor;
  }

  Future<Set<String>> _getTableColumns(String table) async {
    final cached = _tableColumnsCache[table];
    if (cached != null) return cached;

    final rows = await _dbHelper.rawQuery('PRAGMA table_info($table)');
    final columns = rows
        .map((row) => (row['name'] as String?) ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();

    _tableColumnsCache[table] = columns;
    return columns;
  }

  Future<void> _refreshConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _online = _hasConnectivity(result);
  }

  bool _hasConnectivity(dynamic event) {
    if (event is ConnectivityResult) {
      return event != ConnectivityResult.none;
    }
    if (event is List<ConnectivityResult>) {
      return event.any((item) => item != ConnectivityResult.none);
    }
    if (event is Iterable) {
      return event.any(
        (item) => item is ConnectivityResult && item != ConnectivityResult.none,
      );
    }

    return true;
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is bool) return value ? 1 : 0;
    if (value is Map || value is List) return jsonEncode(value);
    return value;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  String? _toIsoString(dynamic value) {
    final dt = _parseDateTime(value);
    return dt?.toIso8601String();
  }

  String _registroIdClientes({
    required String tenantId,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final cedula = _extractCedula(docId: docId, data: data);
    if (cedula == null) return docId;
    return '$tenantId:$cedula';
  }

  String? _extractRemoteSyncRecordId(Map<String, dynamic> rawData) {
    final sync = rawData['_sync'];
    if (sync is! Map) return null;

    final recordId = sync['record_id'];
    if (recordId == null) return null;
    final normalized = recordId.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _extractCedula({required String docId, Map<String, dynamic>? data}) {
    final fromPayload = data?['cedula']?.toString().trim();
    if (fromPayload != null && fromPayload.isNotEmpty) {
      return fromPayload;
    }

    final separator = docId.indexOf(':');
    if (separator < 0 || separator >= docId.length - 1) {
      return null;
    }

    final candidate = docId.substring(separator + 1).trim();
    return candidate.isEmpty ? null : candidate;
  }
}

class _TableLookup {
  _TableLookup({required this.where, required this.whereArgs});

  final String where;
  final List<Object?> whereArgs;
}
