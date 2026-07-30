import 'package:firebase_database/firebase_database.dart';
import 'package:restaurant_app/Presentation/core/constants/app_constants.dart';

class RealtimeDatabaseService {
  RealtimeDatabaseService({FirebaseDatabase? firebaseDatabase})
    : _firebaseDatabase = firebaseDatabase ?? FirebaseDatabase.instance;

  final FirebaseDatabase _firebaseDatabase;

  DatabaseReference _restaurantRoot(String restaurantId) {
    final safeRestaurantId = restaurantId.trim().isEmpty
        ? AppConstants.defaultRestaurantId
        : restaurantId.trim();
    return _firebaseDatabase
        .ref()
        .child('restaurantes')
        .child(safeRestaurantId);
  }

  DatabaseReference _collectionRef(String restaurantId, String collection) {
    return _restaurantRoot(restaurantId).child(collection);
  }

  DatabaseReference _documentRef(
    String restaurantId,
    String collection,
    String documentId,
  ) {
    return _collectionRef(restaurantId, collection).child(documentId);
  }

  Future<Map<String, Map<String, dynamic>>> listCollection({
    required String restaurantId,
    required String collection,
  }) async {
    final snapshot = await _collectionRef(restaurantId, collection).once();
    return _parseSnapshot(snapshot.snapshot.value);
  }

  Future<Map<String, dynamic>?> getDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
  }) async {
    final snapshot = await _documentRef(
      restaurantId,
      collection,
      documentId,
    ).once();
    if (!snapshot.snapshot.exists) return null;
    return _normalizeMap(snapshot.snapshot.value);
  }

  Future<void> setDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final payload = _sanitizePayload(data);
    await _documentRef(restaurantId, collection, documentId).set(payload);
  }

  Future<void> patchDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final payload = _sanitizePayload(data);
    if (payload.isEmpty) return;
    await _documentRef(restaurantId, collection, documentId).update(payload);
  }

  Future<void> deleteDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
  }) async {
    await _documentRef(restaurantId, collection, documentId).remove();
  }

  Future<void> updateMultiple({
    required String restaurantId,
    required Map<String, Object?> updates,
  }) async {
    if (updates.isEmpty) return;
    final normalized = <String, Object?>{};
    for (final entry in updates.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      final value = entry.value;
      normalized[key] = _normalizeValue(value);
    }
    if (normalized.isEmpty) return;
    await _restaurantRoot(restaurantId).update(normalized);
  }

  Map<String, Map<String, dynamic>> _parseSnapshot(dynamic raw) {
    final output = <String, Map<String, dynamic>>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = _normalizeMap(entry.value);
        if (value != null) {
          output[key] = value;
        }
      }
    }
    return output;
  }

  Map<String, dynamic>? _normalizeMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        normalized[key] = _normalizeValue(value);
      }
      return normalized;
    }
    return null;
  }

  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> source) {
    final output = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) continue;
      final normalized = _normalizeValue(value);
      if (normalized is _DropValue) continue;
      output[key] = normalized;
    }
    return output;
  }

  Object? _normalizeValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is bool || value is num || value is String) return value;
    if (value is Map) {
      final nested = <String, dynamic>{};
      for (final entry in value.entries) {
        final normalized = _normalizeValue(entry.value);
        if (normalized is _DropValue) continue;
        if (normalized != null) {
          nested[entry.key.toString()] = normalized;
        }
      }
      return nested;
    }
    if (value is List) {
      return value
          .map(_normalizeValue)
          .where((element) => element != null && element is! _DropValue)
          .toList();
    }
    return value.toString();
  }
}

class _DropValue {}
