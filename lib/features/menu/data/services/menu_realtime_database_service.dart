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

      if (value is DateTime) {
        output[entry.key] = value.toIso8601String();
        continue;
      }

      output[entry.key] = value;
    }

    return output;
  }
}

enum _HttpMethod { put, patch, delete }
