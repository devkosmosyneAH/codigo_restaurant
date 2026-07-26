import 'dart:convert';
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

class WebCachedImageRecord {
  final Uint8List bytes;
  final String? etag;
  final String? lastModified;
  final DateTime cachedAt;
  final DateTime expiresAt;

  const WebCachedImageRecord({
    required this.bytes,
    required this.etag,
    required this.lastModified,
    required this.cachedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class WebIndexedImageCache {
  WebIndexedImageCache._();

  static final WebIndexedImageCache instance = WebIndexedImageCache._();

  static const String _databaseName = 'restaurant_app_menu_image_cache';
  static const String _storeName = 'images';

  Database? _database;

  Future<WebCachedImageRecord?> get(String url) async {
    if (url.trim().isEmpty) return null;

    final db = await _openDatabase();
    if (db == null) return null;

    final txn = db.transaction(_storeName, idbModeReadOnly);
    final raw = await txn.objectStore(_storeName).getObject(url.trim());
    await txn.completed;

    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);
    final bytesBase64 = map['bytes_base64']?.toString();
    if (bytesBase64 == null || bytesBase64.isEmpty) return null;

    try {
      final expiresAt = _fromEpochMs(map['expires_at_ms']);
      if (DateTime.now().isAfter(expiresAt)) return null;

      return WebCachedImageRecord(
        bytes: Uint8List.fromList(base64Decode(bytesBase64)),
        etag: map['etag']?.toString(),
        lastModified: map['last_modified']?.toString(),
        cachedAt: _fromEpochMs(map['cached_at_ms']),
        expiresAt: expiresAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> put(
    String url,
    Uint8List bytes, {
    String? etag,
    String? lastModified,
    Duration ttl = const Duration(hours: 24),
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty || bytes.isEmpty) return;

    final db = await _openDatabase();
    if (db == null) return;

    final effectiveTtl = ttl.inSeconds <= 0 ? const Duration(minutes: 5) : ttl;
    final now = DateTime.now();
    final payload = <String, dynamic>{
      'bytes_base64': base64Encode(bytes),
      'etag': etag,
      'last_modified': lastModified,
      'cached_at_ms': now.millisecondsSinceEpoch,
      'expires_at_ms': now.add(effectiveTtl).millisecondsSinceEpoch,
    };

    final txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).put(payload, normalizedUrl);
    await txn.completed;
  }

  Future<Database?> _openDatabase() async {
    if (_database != null) return _database;
    final factory = idbFactoryBrowser;

    _database = await factory.open(
      _databaseName,
      version: 1,
      onUpgradeNeeded: (event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );

    return _database;
  }

  DateTime _fromEpochMs(dynamic value) {
    final ms = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    if (ms <= 0) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
