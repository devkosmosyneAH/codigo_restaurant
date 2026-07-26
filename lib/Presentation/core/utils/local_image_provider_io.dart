import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider<Object>? buildLocalImageProvider(String path) {
  final raw = path.trim();
  if (raw.isEmpty) return null;

  final normalizedPath = raw.startsWith('file://')
      ? (Uri.tryParse(raw)?.toFilePath(windows: Platform.isWindows) ?? raw)
      : raw;

  return FileImage(File(normalizedPath));
}
