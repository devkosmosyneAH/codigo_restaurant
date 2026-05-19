import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/config/app_environment.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';

abstract class SyncCloudBackend {
  Future<void> ensureAvailable();

  Future<void> setDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    required bool merge,
  });

  Future<void> deleteDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
  });

  Future<void> writeAudit({
    required String recordId,
    required Map<String, dynamic> data,
  });

  Future<Map<String, Map<String, dynamic>>> listCollection({
    required String restaurantId,
    required String collection,
    String? updatedAfter,
  }) async {
    return const {};
  }

  Object serverTimestamp();
}

class FirebaseRealtimeSyncCloudBackend implements SyncCloudBackend {
  FirebaseRealtimeSyncCloudBackend({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  final http.Client _httpClient;

  String get _baseUrl => AppEnvironment.realtimeDatabaseUrl;

  @override
  Future<void> ensureAvailable() async {
    if (!AppEnvironment.isRealtimeDatabaseConfigured) {
      throw StateError(
        'Realtime Database no esta configurada. Define FIREBASE_DATABASE_URL o REALTIME_DATABASE_URL.',
      );
    }
  }

  @override
  Future<void> setDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    required bool merge,
  }) async {
    final uri = _documentUri(
      restaurantId: restaurantId,
      collection: collection,
      documentId: documentId,
    );

    final payload = _sanitizePayload(data);
    final response = merge
        ? await _httpClient
              .patch(uri, headers: _jsonHeaders, body: jsonEncode(payload))
              .timeout(_requestTimeout)
        : await _httpClient
              .put(uri, headers: _jsonHeaders, body: jsonEncode(payload))
              .timeout(_requestTimeout);

    _ensureSuccess(response, operation: 'setDocument', uri: uri);
  }

  @override
  Future<void> deleteDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
  }) async {
    final uri = _documentUri(
      restaurantId: restaurantId,
      collection: collection,
      documentId: documentId,
    );
    final response = await _httpClient.delete(uri).timeout(_requestTimeout);
    _ensureSuccess(response, operation: 'deleteDocument', uri: uri);
  }

  @override
  Future<void> writeAudit({
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    final safeRecordId = Uri.encodeComponent(recordId);
    final uri = Uri.parse('$_baseUrl/sync_audit/$safeRecordId.json');
    final response = await _httpClient
        .put(
          uri,
          headers: _jsonHeaders,
          body: jsonEncode(_sanitizePayload(data)),
        )
        .timeout(_requestTimeout);
    _ensureSuccess(response, operation: 'writeAudit', uri: uri);
  }

  @override
  Future<Map<String, Map<String, dynamic>>> listCollection({
    required String restaurantId,
    required String collection,
    String? updatedAfter,
  }) async {
    final uri = _collectionUri(
      restaurantId: restaurantId,
      collection: collection,
      updatedAfter: updatedAfter,
    );

    final response = await _httpClient.get(uri).timeout(_requestTimeout);
    _ensureSuccess(response, operation: 'listCollection', uri: uri);

    if (response.body.trim().isEmpty || response.body.trim() == 'null') {
      return const {};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return const {};
    }

    final output = <String, Map<String, dynamic>>{};
    for (final entry in decoded.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is Map) {
        output[key] = Map<String, dynamic>.from(value);
      }
    }

    return output;
  }

  @override
  Object serverTimestamp() => DateTime.now().toIso8601String();

  Uri _documentUri({
    required String restaurantId,
    required String collection,
    required String documentId,
  }) {
    final safeRestaurantId = Uri.encodeComponent(restaurantId);
    final safeCollection = Uri.encodeComponent(collection);
    final safeDocumentId = Uri.encodeComponent(documentId);

    return Uri.parse(
      '$_baseUrl/restaurantes/$safeRestaurantId/$safeCollection/$safeDocumentId.json',
    );
  }

  Uri _collectionUri({
    required String restaurantId,
    required String collection,
    String? updatedAfter,
  }) {
    final safeRestaurantId = Uri.encodeComponent(restaurantId);
    final safeCollection = Uri.encodeComponent(collection);
    final base = Uri.parse(
      '$_baseUrl/restaurantes/$safeRestaurantId/$safeCollection.json',
    );

    final trimmedCursor = updatedAfter?.trim();
    if (trimmedCursor == null || trimmedCursor.isEmpty) {
      return base;
    }

    return base.replace(
      queryParameters: {
        'orderBy': jsonEncode('updated_at'),
        'startAt': jsonEncode(trimmedCursor),
      },
    );
  }

  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> source) {
    final output = <String, dynamic>{};
    for (final entry in source.entries) {
      final value = entry.value;
      if (value == null) continue;

      if (value is DateTime) {
        output[entry.key] = value.toIso8601String();
      } else {
        output[entry.key] = value;
      }
    }
    return output;
  }

  void _ensureSuccess(
    http.Response response, {
    required String operation,
    required Uri uri,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw StateError(
      'Realtime DB $operation fallo (${response.statusCode}) en $uri: ${response.body}',
    );
  }
}

/// Servicio para enviar operaciones del sync_log a Realtime Database.
class SyncCloudService {
  SyncCloudService({SyncCloudBackend? backend, bool? enforcePlatformSupport})
    : _backend = backend ?? FirebaseRealtimeSyncCloudBackend(),
      _enforcePlatformSupport = enforcePlatformSupport ?? backend == null;

  final SyncCloudBackend _backend;
  final bool _enforcePlatformSupport;

  bool get isCloudSyncSupportedPlatform =>
      !_enforcePlatformSupport || AppEnvironment.isRealtimeDatabaseConfigured;

  String get unsupportedPlatformMessage =>
      'Sincronizacion en nube deshabilitada en esta plataforma. '
      'Modo local activo (SQLite sin sync cloud).';

  /// Valida que Realtime Database este configurada y disponible.
  Future<void> ensureAvailable() async {
    if (!isCloudSyncSupportedPlatform) {
      throw UnsupportedError(unsupportedPlatformMessage);
    }

    try {
      await _backend.ensureAvailable();
    } catch (e) {
      throw StateError(
        'Realtime Database no esta configurada para sincronizacion. '
        'Completa la configuracion de FIREBASE_DATABASE_URL e intenta de nuevo.\nDetalle: $e',
      );
    }
  }

  Future<Map<String, Map<String, dynamic>>> listCollection({
    required String restaurantId,
    required String collection,
    String? updatedAfter,
  }) async {
    await ensureAvailable();
    return _backend.listCollection(
      restaurantId: restaurantId,
      collection: collection,
      updatedAfter: updatedAfter,
    );
  }

  Future<void> pushRecord(SyncRecord record) async {
    await ensureAvailable();

    final restaurantId = record.restaurantId.isNotEmpty
        ? record.restaurantId
        : AppConstants.defaultRestaurantId;

    switch (record.operacion) {
      case SyncOperation.insert:
      case SyncOperation.update:
        await _backend.setDocument(
          restaurantId: restaurantId,
          collection: record.tabla,
          documentId: record.registroId,
          data: _buildPayload(record),
          merge: true,
        );
      case SyncOperation.delete:
        await _backend.deleteDocument(
          restaurantId: restaurantId,
          collection: record.tabla,
          documentId: record.registroId,
        );
    }

    await _backend.writeAudit(
      recordId: record.id,
      data: {
        'tabla': record.tabla,
        'registro_id': record.registroId,
        'restaurant_id': restaurantId,
        'operacion': record.operacion.name,
        'created_at_local': record.createdAt.toIso8601String(),
        'synced_at': _backend.serverTimestamp(),
      },
    );
  }

  Map<String, dynamic> _buildPayload(SyncRecord record) {
    final cleanData = <String, dynamic>{...?record.datos};
    if (record.tabla == 'clientes') {
      cleanData.remove('id_cliente');
    }

    final payload = <String, dynamic>{
      ...cleanData,
      '_sync': {
        'record_id': record.id,
        'operation': record.operacion.name,
        'source': 'restaurant_app',
        'created_at_local': record.createdAt.toIso8601String(),
        'synced_at': _backend.serverTimestamp(),
      },
    };

    if (cleanData.isEmpty) {
      payload['id'] = record.registroId;
    }

    return payload;
  }
}
