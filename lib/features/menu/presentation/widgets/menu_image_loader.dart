import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:restaurant_app/core/utils/local_image_provider.dart';
import 'package:restaurant_app/core/utils/web_indexed_image_cache.dart';

class MenuImageLoader extends StatefulWidget {
  final String? primaryImageValue;
  final String? fallbackImageValue;
  final String? localCachePath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  final Widget placeholder;
  final bool showPlaceholderWhileLoading;
  final bool enableFadeIn;

  const MenuImageLoader({
    super.key,
    this.primaryImageValue,
    this.fallbackImageValue,
    this.localCachePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth = 720,
    this.filterQuality = FilterQuality.low,
    required this.placeholder,
    this.showPlaceholderWhileLoading = true,
    this.enableFadeIn = true,
  });

  @override
  State<MenuImageLoader> createState() => _MenuImageLoaderState();
}

class _MenuImageLoaderState extends State<MenuImageLoader> {
  List<_ImageCandidate> _candidates = const [];
  int _activeIndex = 0;

  /// Convierte URLs de Google Drive a un formato servido por usercontent
  /// para evitar bloqueos CORS en Flutter Web.
  String _fixGoogleDriveUrl(String url) {
    if (url.isEmpty) return url;

    if (url.contains('lh3.googleusercontent.com/d/')) {
      return url;
    }

    final regExp = RegExp(r'(?:id=|/d/|/files/)([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(url);

    if (match != null && match.groupCount > 0) {
      final fileId = match.group(1)!;
      return 'https://lh3.googleusercontent.com/d/$fileId';
    }

    return url;
  }

  @override
  void initState() {
    super.initState();
    _rebuildCandidates();
  }

  @override
  void didUpdateWidget(covariant MenuImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryImageValue != widget.primaryImageValue ||
        oldWidget.fallbackImageValue != widget.fallbackImageValue ||
        oldWidget.localCachePath != widget.localCachePath ||
        oldWidget.cacheWidth != widget.cacheWidth) {
      _rebuildCandidates();
    }
  }

  void _rebuildCandidates() {
    final candidates = <_ImageCandidate>[];
    _appendLocalCandidate(candidates);
    _appendRawImageCandidates(
      widget.primaryImageValue,
      candidates,
      prefix: 'primary',
    );
    _appendRawImageCandidates(
      widget.fallbackImageValue,
      candidates,
      prefix: 'fallback',
    );

    final dedup = <String, _ImageCandidate>{};
    for (final candidate in candidates) {
      dedup.putIfAbsent(candidate.key, () => candidate);
    }

    _candidates = dedup.values.toList(growable: false);
    _activeIndex = 0;
  }

  void _appendLocalCandidate(List<_ImageCandidate> candidates) {
    final path = widget.localCachePath?.trim();
    if (path == null || path.isEmpty) return;

    final provider = buildLocalImageProvider(path);
    if (provider == null) return;

    candidates.add(
      _ImageCandidate(key: 'local:$path', provider: _resized(provider)),
    );
  }

  void _appendRawImageCandidates(
    String? value,
    List<_ImageCandidate> candidates, {
    required String prefix,
  }) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return;

    if (raw.startsWith('data:image')) {
      final commaIndex = raw.indexOf(',');
      if (commaIndex == -1) return;
      try {
        final bytes = base64Decode(raw.substring(commaIndex + 1));
        candidates.add(
          _ImageCandidate(
            key: '$prefix:data:${raw.hashCode}',
            provider: _resized(MemoryImage(bytes)),
          ),
        );
      } catch (_) {
        // No-op: si viene corrupta, se continúa con el siguiente fallback.
      }
      return;
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final fixedUrl = _fixGoogleDriveUrl(raw);
      if (kIsWeb) {
        candidates.add(
          _ImageCandidate(
            key: '$prefix:web-net:$fixedUrl',
            networkUrl: fixedUrl,
          ),
        );
      } else {
        candidates.add(
          _ImageCandidate(
            key: '$prefix:net:$fixedUrl',
            provider: _resized(NetworkImage(fixedUrl)),
          ),
        );
      }
      return;
    }

    if (raw.startsWith('assets/')) {
      candidates.add(
        _ImageCandidate(
          key: '$prefix:asset:$raw',
          provider: _resized(AssetImage(raw)),
        ),
      );
    }
  }

  ImageProvider<Object> _resized(ImageProvider<Object> provider) {
    return ResizeImage.resizeIfNeeded(widget.cacheWidth, null, provider);
  }

  void _advanceCandidate() {
    if (_activeIndex >= _candidates.length - 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _activeIndex += 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty || _activeIndex >= _candidates.length) {
      return widget.placeholder;
    }

    final candidate = _candidates[_activeIndex];

    if (kIsWeb && candidate.networkUrl != null) {
      return _WebIndexedCachedNetworkImage(
        imageUrl: candidate.networkUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        placeholder: widget.placeholder,
        cacheWidth: widget.cacheWidth,
        showPlaceholderWhileLoading: widget.showPlaceholderWhileLoading,
        enableFadeIn: widget.enableFadeIn,
        onError: _advanceCandidate,
      );
    }

    final provider = candidate.provider;
    if (provider == null) {
      _advanceCandidate();
      return widget.placeholder;
    }

    return Image(
      image: provider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: widget.filterQuality,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (!widget.enableFadeIn || wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
      loadingBuilder: widget.showPlaceholderWhileLoading
          ? (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return widget.placeholder;
            }
          : null,
      errorBuilder: (context, error, stackTrace) {
        _advanceCandidate();
        return widget.placeholder;
      },
    );
  }
}

class _ImageCandidate {
  final String key;
  final ImageProvider<Object>? provider;
  final String? networkUrl;

  const _ImageCandidate({required this.key, this.provider, this.networkUrl});
}

class _WebIndexedCachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  final Widget placeholder;
  final bool showPlaceholderWhileLoading;
  final bool enableFadeIn;
  final VoidCallback onError;

  const _WebIndexedCachedNetworkImage({
    required this.imageUrl,
    required this.fit,
    required this.width,
    required this.height,
    required this.cacheWidth,
    required this.filterQuality,
    required this.placeholder,
    required this.showPlaceholderWhileLoading,
    required this.enableFadeIn,
    required this.onError,
  });

  @override
  State<_WebIndexedCachedNetworkImage> createState() =>
      _WebIndexedCachedNetworkImageState();
}

class _WebIndexedCachedNetworkImageState
    extends State<_WebIndexedCachedNetworkImage> {
  Uint8List? _bytes;
  bool _isLoading = true;
  bool _didNotifyError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void didUpdateWidget(covariant _WebIndexedCachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _bytes = null;
      _isLoading = true;
      _didNotifyError = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _load();
      });
    }
  }

  Future<void> _load() async {
    final cache = WebIndexedImageCache.instance;
    final url = widget.imageUrl.trim();
    if (url.isEmpty || !mounted) {
      _notifyErrorOnce();
      return;
    }

    WebCachedImageRecord? cached;
    try {
      cached = await cache.get(url);
    } catch (_) {
      cached = null;
    }

    if (!mounted) return;

    if (cached != null) {
      final cachedBytes = cached.bytes;
      setState(() {
        _bytes = cachedBytes;
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.bodyBytes.isNotEmpty) {
        final bodyBytes = response.bodyBytes;
        await cache.put(
          url,
          bodyBytes,
          etag: response.headers['etag'],
          lastModified: response.headers['last-modified'],
          ttl: _resolveTtl(response.headers),
        );

        setState(() {
          _bytes = bodyBytes;
          _isLoading = false;
        });
        return;
      }

      _notifyErrorOnce();
    } catch (_) {
      if (!mounted) return;
      _notifyErrorOnce();
    }
  }

  Duration _resolveTtl(Map<String, String> headers) {
    final cacheControl = headers['cache-control']?.toLowerCase() ?? '';
    if (cacheControl.contains('no-store')) {
      return const Duration(minutes: 5);
    }

    final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
    if (maxAgeMatch != null) {
      final parsed = int.tryParse(maxAgeMatch.group(1) ?? '');
      if (parsed != null && parsed > 0) {
        final bounded = parsed.clamp(60, 604800);
        return Duration(seconds: bounded);
      }
    }

    return const Duration(hours: 24);
  }

  void _notifyErrorOnce() {
    if (_didNotifyError) return;
    _didNotifyError = true;
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onError();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _bytes;

    if (data == null) {
      if (_isLoading && widget.showPlaceholderWhileLoading) {
        return widget.placeholder;
      }
      return widget.placeholder;
    }

    return Image.memory(
      data,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      filterQuality: widget.filterQuality,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (!widget.enableFadeIn || wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
      errorBuilder: (_, __, ___) {
        _notifyErrorOnce();
        return widget.placeholder;
      },
    );
  }
}
