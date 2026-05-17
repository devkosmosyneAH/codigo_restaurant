import 'dart:convert';

/// Enumeración de operaciones de sincronización.
enum SyncOperation { insert, update, delete }

/// Representa un registro pendiente de sincronización.
///
/// Cuando el sistema funciona offline, cada operación CRUD
/// se registra en [sync_log] para sincronizarse con Firebase
/// cuando haya conexión disponible.
class SyncRecord {
  final String id;
  final String tabla;
  final String registroId;
  final SyncOperation operacion;
  final Map<String, dynamic>? datos;
  final bool sincronizado;
  final int intentos;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String restaurantId;

  const SyncRecord({
    required this.id,
    required this.tabla,
    required this.registroId,
    required this.operacion,
    this.datos,
    this.sincronizado = false,
    this.intentos = 0,
    required this.createdAt,
    DateTime? updatedAt,
    required this.restaurantId,
  }) : updatedAt = updatedAt ?? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tabla': tabla,
      'registro_id': registroId,
      'operacion': operacion.name,
      'datos': datos == null ? null : jsonEncode(datos),
      'sincronizado': sincronizado ? 1 : 0,
      'intentos': intentos,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'restaurant_id': restaurantId,
    };
  }

  factory SyncRecord.fromMap(Map<String, dynamic> map) {
    return SyncRecord(
      id: map['id'] as String,
      tabla: map['tabla'] as String,
      registroId: map['registro_id'] as String,
      operacion: SyncOperation.values.firstWhere(
        (e) => e.name == map['operacion'],
      ),
      datos: _parseDatos(map['datos']),
      sincronizado: (map['sincronizado'] as int) == 1,
      intentos: map['intentos'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.parse(map['created_at'] as String),
      restaurantId: map['restaurant_id'] as String? ?? '',
    );
  }

  static Map<String, dynamic>? _parseDatos(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is! String) return null;

    final text = raw.trim();
    if (text.isEmpty || text == 'null') return null;

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      // Compatibilidad con registros legacy guardados como toString().
      return {'_legacy_raw': text};
    }

    return null;
  }
}
