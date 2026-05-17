import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/firebase_options.dart';

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

  Object serverTimestamp();
}

class FirebaseSyncCloudBackend implements SyncCloudBackend {
  FirebaseSyncCloudBackend({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> ensureAvailable() async {
    if (Firebase.apps.isNotEmpty) return;

    if (!DefaultFirebaseOptions.isSupportedPlatform) {
      throw UnsupportedError(
        'Firebase no esta configurado para esta plataforma. '
        'Ejecuta: flutterfire configure para habilitarla.',
      );
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  Future<void> setDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    required bool merge,
  }) async {
    await _db
        .collection('restaurantes')
        .doc(restaurantId)
        .collection(collection)
        .doc(documentId)
        .set(data, SetOptions(merge: merge));
  }

  @override
  Future<void> deleteDocument({
    required String restaurantId,
    required String collection,
    required String documentId,
  }) async {
    await _db
        .collection('restaurantes')
        .doc(restaurantId)
        .collection(collection)
        .doc(documentId)
        .delete();
  }

  @override
  Future<void> writeAudit({
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection('sync_audit').doc(recordId).set(data);
  }

  @override
  Object serverTimestamp() => FieldValue.serverTimestamp();
}

/// Servicio para enviar operaciones del sync_log a Firestore.
class SyncCloudService {
  SyncCloudService({SyncCloudBackend? backend, bool? enforcePlatformSupport})
    : _backend = backend ?? FirebaseSyncCloudBackend(),
      _enforcePlatformSupport = enforcePlatformSupport ?? backend == null;

  final SyncCloudBackend _backend;
  final bool _enforcePlatformSupport;

  bool get isCloudSyncSupportedPlatform =>
      !_enforcePlatformSupport || DefaultFirebaseOptions.isSupportedPlatform;

  String get unsupportedPlatformMessage =>
      'Sincronizacion en nube deshabilitada en esta plataforma. '
      'Modo local activo (SQLite sin sync cloud).';

  /// Valida que Firebase esté inicializado y disponible.
  Future<void> ensureAvailable() async {
    if (!isCloudSyncSupportedPlatform) {
      throw UnsupportedError(unsupportedPlatformMessage);
    }

    try {
      await _backend.ensureAvailable();
    } catch (e) {
      throw StateError(
        'Firebase no está configurado para sincronización. '
        'Completa la configuración de Firebase (apps + archivos de plataforma) e intenta de nuevo.\nDetalle: $e',
      );
    }
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
