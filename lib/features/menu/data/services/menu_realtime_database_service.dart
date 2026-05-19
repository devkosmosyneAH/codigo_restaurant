import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:restaurant_app/core/config/app_environment.dart';
import 'package:restaurant_app/features/menu/data/services/menu_sync_diagnostics_service.dart';

/// Sincroniza productos del menu hacia Firebase Realtime Database via REST.
///
/// El servicio es tolerante a fallos: devuelve `false` si no pudo escribir,
/// sin lanzar errores para no bloquear el flujo local offline-first.
class MenuRealtimeDatabaseService {
  MenuRealtimeDatabaseService({
    http.Client? httpClient,
    MenuSyncDiagnosticsService? diagnosticsService,
  }) : _httpClient = httpClient ?? http.Client(),
       _diagnosticsService = diagnosticsService;

  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };
  static const Set<String> _localOnlyKeys = {
    'imagen_local_cache_path',
    'image_base64',
  };

  final http.Client _httpClient;
  final MenuSyncDiagnosticsService? _diagnosticsService;

  bool get isConfigured => AppEnvironment.isRealtimeDatabaseConfigured;

  Future<bool> upsertProducto({
    required String restaurantId,
    required String productoId,
    required Map<String, dynamic> data,
  }) async {
    if (!isConfigured) return false;

    final payload = _sanitizePayload(data);
    return _request(
      method: _HttpMethod.put,
      uri: _productoUri(restaurantId: restaurantId, productoId: productoId),
      payload: payload,
      operation: 'upsert_producto',
    );
  }

  Future<bool> patchProducto({
    required String restaurantId,
    required String productoId,
    required Map<String, dynamic> data,
  }) async {
    if (!isConfigured) return false;

    final payload = _sanitizePayload(data);
    if (payload.isEmpty) return true;

    return _request(
      method: _HttpMethod.patch,
      uri: _productoUri(restaurantId: restaurantId, productoId: productoId),
      payload: payload,
      operation: 'patch_producto',
    );
  }

  Future<bool> deleteProducto({
    required String restaurantId,
    required String productoId,
  }) async {
    if (!isConfigured) return false;

    return _request(
      method: _HttpMethod.delete,
      uri: _productoUri(restaurantId: restaurantId, productoId: productoId),
      operation: 'delete_producto',
    );
  }

  Uri _productoUri({required String restaurantId, required String productoId}) {
    final baseUrl = AppEnvironment.realtimeDatabaseUrl;
    final safeRestaurantId = Uri.encodeComponent(restaurantId);
    final safeProductoId = Uri.encodeComponent(productoId);

    return Uri.parse(
      '$baseUrl/restaurantes/$safeRestaurantId/productos/$safeProductoId.json',
    );
  }

  Future<bool> _request({
    required _HttpMethod method,
    required Uri uri,
    Map<String, dynamic>? payload,
    required String operation,
  }) async {
    try {
      final response = switch (method) {
        _HttpMethod.put =>
          await _httpClient
              .put(
                uri,
                headers: _jsonHeaders,
                body: jsonEncode(payload ?? const <String, dynamic>{}),
              )
              .timeout(_requestTimeout),
        _HttpMethod.patch =>
          await _httpClient
              .patch(
                uri,
                headers: _jsonHeaders,
                body: jsonEncode(payload ?? const <String, dynamic>{}),
              )
              .timeout(_requestTimeout),
        _HttpMethod.delete =>
          await _httpClient.delete(uri).timeout(_requestTimeout),
      };

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      _diagnosticsService?.recordRealtimeSync(
        success: ok,
        operation: operation,
        details: ok
            ? null
            : 'RTDB respondió ${response.statusCode} para $operation',
      );
      return ok;
    } catch (e) {
      _diagnosticsService?.recordRealtimeSync(
        success: false,
        operation: operation,
        details: 'Error RTDB en $operation: $e',
      );
      return false;
    }
  }

  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> source) {
    final output = <String, dynamic>{};

    for (final entry in source.entries) {
      final value = entry.value;
      if (value == null) continue;

      final sanitized = _sanitizeValue(entry.key, value);
      if (identical(sanitized, _dropValue)) continue;
      output[entry.key] = sanitized;
    }

    final driveUrl = output['drive_public_url'];
    if (driveUrl is String && !_isPublicUrl(driveUrl)) {
      output.remove('drive_public_url');
    }

    final driveFileId = output['drive_file_id'];
    if (driveFileId is String && driveFileId.trim().isEmpty) {
      output.remove('drive_file_id');
    }

    final imageUrl = output['imagen_url'];
    if (imageUrl is String && !_isPublicUrl(imageUrl)) {
      if (driveUrl is String && _isPublicUrl(driveUrl)) {
        output['imagen_url'] = driveUrl;
      } else {
        output.remove('imagen_url');
      }
    }

    if (!output.containsKey('imagen_url') &&
        driveUrl is String &&
        _isPublicUrl(driveUrl)) {
      output['imagen_url'] = driveUrl;
    }

    return output;
  }

  static const Object _dropValue = Object();

  Object _sanitizeValue(String key, dynamic value) {
    if (_localOnlyKeys.contains(key)) {
      return _dropValue;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Map) {
      final nested = <String, dynamic>{};
      for (final entry in value.entries) {
        final nestedKey = entry.key.toString();
        final nestedValue = _sanitizeValue(nestedKey, entry.value);
        if (identical(nestedValue, _dropValue)) continue;
        nested[nestedKey] = nestedValue;
      }
      return nested;
    }

    if (value is List) {
      final nested = <dynamic>[];
      for (final item in value) {
        final sanitized = _sanitizeValue(key, item);
        if (identical(sanitized, _dropValue)) continue;
        nested.add(sanitized);
      }
      return nested;
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return value;
      }
      if (_isDataUri(trimmed)) {
        return _dropValue;
      }
      return value;
    }

    return value;
  }

  bool _isDataUri(String value) {
    return value.toLowerCase().startsWith('data:');
  }

  bool _isPublicUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return uri.hasScheme &&
        (uri.scheme.toLowerCase() == 'https' ||
            uri.scheme.toLowerCase() == 'http');
  }
}

enum _HttpMethod { put, patch, delete }
