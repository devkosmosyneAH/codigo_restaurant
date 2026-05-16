import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Resultado de una selección de imagen procesada.
class PickedImage {
  /// Data URI listo para persistir (`data:image/png;base64,...`).
  final String dataUri;

  /// Bytes ya optimizados (PNG o JPEG, según transparencia).
  final Uint8List bytes;

  /// MIME type efectivo (`image/png` o `image/jpeg`).
  final String mimeType;

  const PickedImage({
    required this.dataUri,
    required this.bytes,
    required this.mimeType,
  });
}

/// Abre el selector de archivos del SO, redimensiona y comprime la imagen en
/// un Isolate (vía [compute]) y la devuelve como [PickedImage] con un data
/// URI listo para guardar en SQLite o transmitir por la red.
///
/// Devuelve `null` si el usuario cancela el diálogo. Lanza [PickedImageError]
/// si la lectura/decodificación falla o si el resultado supera [maxBytes].
///
/// - [maxWidth]: lado mayor objetivo en píxeles (default 512, suficiente para
///   logos de cabecera y tickets).
/// - [jpegQuality]: 0–100 (default 85).
/// - [maxBytes]: tamaño máximo del data URI codificado (default ~300 KB).
Future<PickedImage?> pickAndEncodeImage({
  int maxWidth = 512,
  int jpegQuality = 85,
  int maxBytes = 300 * 1024,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw const PickedImageError('No se pudo leer la imagen seleccionada.');
  }

  final ext = (file.extension ?? 'png').toLowerCase();
  final optimized = await compute(
    _processImageIsolate,
    _ImageInput(
      bytes: bytes,
      extension: ext,
      maxWidth: maxWidth,
      jpegQuality: jpegQuality,
    ),
  );

  if (optimized == null) {
    throw const PickedImageError(
      'No se pudo procesar la imagen. Intenta con otro archivo.',
    );
  }

  final dataUri =
      'data:${optimized.mimeType};base64,${base64Encode(optimized.bytes)}';

  if (dataUri.length > maxBytes) {
    throw PickedImageError(
      'La imagen es demasiado grande tras la compresión '
      '(${(dataUri.length / 1024).round()} KB). '
      'Usa una imagen más pequeña o de menor resolución.',
    );
  }

  return PickedImage(
    dataUri: dataUri,
    bytes: optimized.bytes,
    mimeType: optimized.mimeType,
  );
}

/// Error controlado emitido por [pickAndEncodeImage] con mensaje listo
/// para mostrar al usuario.
class PickedImageError implements Exception {
  final String message;
  const PickedImageError(this.message);

  @override
  String toString() => message;
}

// ── Internals ────────────────────────────────────────────────────────────────

class _ImageInput {
  final Uint8List bytes;
  final String extension;
  final int maxWidth;
  final int jpegQuality;

  const _ImageInput({
    required this.bytes,
    required this.extension,
    required this.maxWidth,
    required this.jpegQuality,
  });
}

class _OptimizedImage {
  final Uint8List bytes;
  final String mimeType;
  const _OptimizedImage({required this.bytes, required this.mimeType});
}

_OptimizedImage? _processImageIsolate(_ImageInput input) {
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) return null;

  final resized = decoded.width > input.maxWidth
      ? img.copyResize(decoded, width: input.maxWidth)
      : decoded;

  final normalizedExt = input.extension.toLowerCase();
  final preserveTransparency =
      resized.hasAlpha || normalizedExt == 'png' || normalizedExt == 'webp';

  if (preserveTransparency) {
    return _OptimizedImage(
      mimeType: 'image/png',
      bytes: Uint8List.fromList(img.encodePng(resized, level: 6)),
    );
  }

  return _OptimizedImage(
    mimeType: 'image/jpeg',
    bytes: Uint8List.fromList(
      img.encodeJpg(resized, quality: input.jpegQuality),
    ),
  );
}
