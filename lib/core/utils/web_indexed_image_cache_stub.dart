import 'dart:typed_data';

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

  Future<WebCachedImageRecord?> get(String url) async {
    return null;
  }

  Future<void> put(
    String url,
    Uint8List bytes, {
    String? etag,
    String? lastModified,
    Duration ttl = const Duration(hours: 24),
  }) async {}
}
