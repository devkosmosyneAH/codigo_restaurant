import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:restaurant_app/core/config/app_environment.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/menu/data/services/drive_image_sync_queue_service.dart';
import 'package:restaurant_app/features/menu/data/services/drive_menu_connection_service.dart';
import 'package:restaurant_app/features/menu/data/services/menu_sync_diagnostics_service.dart';
import 'package:restaurant_app/features/menu/domain/entities/categoria.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/domain/entities/variante.dart';
import 'package:uuid/uuid.dart';

/// Diálogo para crear o editar un producto del menú.
///
/// Incluye nombre, descripción, precio base, categoría, disponibilidad
/// y gestión de variantes inline.
class ProductoFormDialog extends StatefulWidget {
  final Producto? producto;
  final List<Categoria> categorias;

  const ProductoFormDialog({
    super.key,
    this.producto,
    required this.categorias,
  });

  static Future<Producto?> show(
    BuildContext context, {
    Producto? producto,
    required List<Categoria> categorias,
  }) {
    return showDialog<Producto>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ProductoFormDialog(producto: producto, categorias: categorias),
    );
  }

  @override
  State<ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<ProductoFormDialog> {
  static const int _previewCacheWidth = 720;
  static const int _maxUploadImageWidth = 1200;
  static const int _jpegQuality = 84;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _imagenUrlCtrl;
  String? _selectedImageData;
  Uint8List? _selectedImageBytes;
  String? _selectedImageMimeType;
  String? _selectedImageExtension;
  late String _categoriaId;
  bool _disponible = true;
  bool _activo = true;
  bool _pickingImage = false;
  bool _submitting = false;
  bool _checkingDriveSession = false;
  bool _driveSessionReady = false;
  String? _driveOwnerEmail;
  _ImageWorkflowStage _imageStage = _ImageWorkflowStage.idle;
  int? _lastOriginalBytes;
  int? _lastCompressedBytes;
  double? _lastReductionPercent;
  Duration? _lastCompressionElapsed;
  Duration? _lastUploadElapsed;
  String? _imageStageMessage;
  List<_VarianteEditable> _variantes = [];

  bool get _isEditing => widget.producto != null;
  bool get _isBusy => _pickingImage || _submitting;
  bool get _supportsDriveUpload {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _precioCtrl = TextEditingController(
      text: p != null ? p.precio.toStringAsFixed(2) : '',
    );
    final initialImage = (p?.drivePublicUrl ?? p?.imagenUrl)?.trim() ?? '';
    _selectedImageData = initialImage.startsWith('data:image')
        ? initialImage
        : null;
    _hydrateSelectedImageMetaFromDataUri();
    _imagenUrlCtrl = TextEditingController(
      text: _selectedImageData == null ? initialImage : '',
    );
    _categoriaId =
        p?.categoriaId ??
        (widget.categorias.isNotEmpty ? widget.categorias.first.id : '');
    _disponible = p?.disponible ?? true;
    _activo = p?.activo ?? true;
    _variantes = (p?.variantes ?? [])
        .map((v) => _VarianteEditable.fromEntity(v))
        .toList();
    _restoreDriveSession();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _imagenUrlCtrl.dispose();
    for (final v in _variantes) {
      v.dispose();
    }
    super.dispose();
  }

  void _addVariante() {
    setState(() {
      _variantes.add(_VarianteEditable());
    });
  }

  void _removeVariante(int index) {
    setState(() {
      _variantes[index].dispose();
      _variantes.removeAt(index);
    });
  }

  Future<void> _restoreDriveSession() async {
    if (!AppEnvironment.isDriveConfigured || !_supportsDriveUpload) return;

    setState(() => _checkingDriveSession = true);
    final driveService = sl<DriveMenuConnectionService>();
    // Restauración silenciosa usando el método central de autenticación.
    final result = await driveService.ensureDriveAuthenticated(
      interactive: false,
    );

    if (!mounted) return;
    setState(() {
      _checkingDriveSession = false;
      _driveSessionReady = result.isConnected;
      _driveOwnerEmail = result.email ?? driveService.currentEmail;
    });
  }

  Future<void> _connectDriveNow() async {
    if (_checkingDriveSession) return;

    if (!_supportsDriveUpload) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Drive no está disponible en esta plataforma para el menú.',
          ),
        ),
      );
      return;
    }

    setState(() => _checkingDriveSession = true);
    final driveService = sl<DriveMenuConnectionService>();
    // Flujo OAuth interactivo: este método se llama desde un botón directo
    // del usuario (gesto directo), por lo que el popup no será bloqueado.
    final result = await driveService.ensureDriveAuthenticated(
      interactive: true,
    );

    if (!mounted) return;
    setState(() {
      _checkingDriveSession = false;
      _driveSessionReady = result.isConnected;
      _driveOwnerEmail = result.email ?? driveService.currentEmail;
    });

    String message;
    if (result.isConnected) {
      message = 'Google Drive conectado correctamente.';
    } else if (result.isPopupBlocked) {
      message =
          'El navegador bloqueó el popup de Google. '
          'Permite popups para este sitio y vuelve a intentarlo.';
    } else if (result.message != null) {
      message = 'No se pudo conectar Google Drive: ${result.message}';
    } else {
      message = 'No se pudo conectar con Google Drive. Intenta de nuevo.';
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String get _imageValue {
    final selected = _selectedImageData?.trim();
    if (selected != null && selected.isNotEmpty) return selected;
    return _imagenUrlCtrl.text.trim();
  }

  void _hydrateSelectedImageMetaFromDataUri() {
    final raw = _selectedImageData;
    if (raw == null || !raw.startsWith('data:image')) return;
    final commaIndex = raw.indexOf(',');
    if (commaIndex == -1) return;

    final header = raw.substring(0, commaIndex);
    final mimeType = header
        .replaceFirst('data:', '')
        .replaceFirst(';base64', '');
    try {
      _selectedImageBytes = base64Decode(raw.substring(commaIndex + 1));
      _selectedImageMimeType = mimeType;
      _selectedImageExtension = _extensionFromMime(mimeType);
    } catch (_) {
      _selectedImageBytes = null;
      _selectedImageMimeType = null;
      _selectedImageExtension = null;
    }
  }

  String _extensionFromMime(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      default:
        return 'jpg';
    }
  }

  String _mimeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'png':
      default:
        return 'image/png';
    }
  }

  void _setImageStage(_ImageWorkflowStage stage, {String? message}) {
    if (!mounted) return;
    setState(() {
      _imageStage = stage;
      _imageStageMessage = message;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  bool _isDataLikeImageValue(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('data:image') || lower.contains(';base64,');
  }

  bool _isLocalImageValue(String value) {
    final lower = value.toLowerCase();
    if (lower.startsWith('file://') ||
        lower.startsWith('blob:') ||
        lower.startsWith('content://')) {
      return true;
    }

    if (value.startsWith('/') ||
        value.startsWith('./') ||
        value.startsWith('../')) {
      return true;
    }

    return RegExp(r'^[a-zA-Z]:\\').hasMatch(value);
  }

  bool _isValidPublicImageUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (_isDataLikeImageValue(trimmed) || _isLocalImageValue(trimmed)) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return false;

    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  String _busyOverlayLabel() {
    if (_imageStage == _ImageWorkflowStage.compressing) {
      return 'Comprimiendo imagen...';
    }
    if (_imageStage == _ImageWorkflowStage.uploading) {
      return 'Subiendo imagen...';
    }
    return _submitting
        ? 'Guardando producto y sincronizando imagen...'
        : 'Procesando imagen...';
  }

  String? _imageStatusLabel() {
    if (_imageStageMessage != null && _imageStageMessage!.trim().isNotEmpty) {
      return _imageStageMessage;
    }

    return switch (_imageStage) {
      _ImageWorkflowStage.compressing => 'Comprimiendo imagen...',
      _ImageWorkflowStage.uploading => 'Subiendo imagen...',
      _ImageWorkflowStage.optimized => 'Imagen optimizada correctamente',
      _ImageWorkflowStage.uploadError => 'Error al subir imagen',
      _ImageWorkflowStage.idle => null,
    };
  }

  Future<_OptimizedImage?> _optimizeImage(
    Uint8List bytes,
    String extension,
  ) async {
    final normalizedExt = extension.toLowerCase();
    final preserveTransparency =
        normalizedExt == 'png' ||
        normalizedExt == 'webp' ||
        normalizedExt == 'gif';

    final targetFormat = preserveTransparency
        ? CompressFormat.png
        : CompressFormat.jpeg;

    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxUploadImageWidth,
        minHeight: _maxUploadImageWidth,
        quality: _jpegQuality,
        format: targetFormat,
        autoCorrectionAngle: true,
        keepExif: false,
      );

      if (compressed.isNotEmpty) {
        final compressedBytes = Uint8List.fromList(compressed);
        if (compressedBytes.length >= bytes.length) {
          return _OptimizedImage(
            bytes: bytes,
            mimeType: _mimeFromExtension(normalizedExt),
          );
        }
        return _OptimizedImage(
          bytes: compressedBytes,
          mimeType: targetFormat == CompressFormat.png
              ? 'image/png'
              : 'image/jpeg',
        );
      }
    } catch (e, st) {
      debugPrint('flutter_image_compress fallback: $e\n$st');
    }

    return compute(
      _processImageIsolate,
      _ImageInput(
        bytes: bytes,
        extension: normalizedExt,
        maxWidth: _maxUploadImageWidth,
        jpegQuality: _jpegQuality,
      ),
    );
  }

  /// Convierte URLs de Google Drive al formato usercontent para evitar CORS
  /// al renderizar en Flutter Web.
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

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() {
      _pickingImage = true;
      _imageStage = _ImageWorkflowStage.compressing;
      _imageStageMessage = 'Comprimiendo imagen...';
    });

    // Permite que Flutter renderice el estado "procesando" antes de abrir
    // el diálogo nativo del OS (en Windows, GetOpenFileName usa su propio
    // message loop y puede interferir con el render de Flutter).
    await Future<void>.delayed(const Duration(milliseconds: 80));

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _setImageStage(
          _ImageWorkflowStage.uploadError,
          message: 'Error al procesar imagen seleccionada',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo leer la imagen seleccionada'),
          ),
        );
        return;
      }

      final ext = (file.extension ?? 'png').toLowerCase();
      final compressionStopwatch = Stopwatch()..start();
      final optimized = await _optimizeImage(bytes, ext);
      compressionStopwatch.stop();

      if (!mounted) return;

      final imageBytes = optimized?.bytes ?? bytes;
      final originalBytes = bytes.length;
      final compressedBytes = imageBytes.length;
      final reductionPercent = originalBytes <= 0
          ? 0.0
          : ((originalBytes - compressedBytes) * 100 / originalBytes)
                .clamp(0.0, 100.0)
                .toDouble();

      final mimeType = optimized?.mimeType ?? _mimeFromExtension(ext);

      debugPrint(
        'menu.image.compress '
        'original=${_formatBytes(originalBytes)} '
        'compressed=${_formatBytes(compressedBytes)} '
        'reduction=${reductionPercent.toStringAsFixed(1)}% '
        'elapsedMs=${compressionStopwatch.elapsedMilliseconds}',
      );

      setState(() {
        _selectedImageData =
            'data:$mimeType;base64,${base64Encode(imageBytes)}';
        _selectedImageBytes = imageBytes;
        _selectedImageMimeType = mimeType;
        _selectedImageExtension = _extensionFromMime(mimeType);
        _imagenUrlCtrl.clear();
        _lastOriginalBytes = originalBytes;
        _lastCompressedBytes = compressedBytes;
        _lastReductionPercent = reductionPercent;
        _lastCompressionElapsed = compressionStopwatch.elapsed;
        _imageStage = _ImageWorkflowStage.optimized;
        _imageStageMessage = 'Imagen optimizada correctamente';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imagen optimizada correctamente '
            '(${_formatBytes(originalBytes)} → ${_formatBytes(compressedBytes)}).',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _setImageStage(
        _ImageWorkflowStage.uploadError,
        message: 'Error al procesar imagen seleccionada',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar la foto. Intenta con otra imagen.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Widget _buildImagePreview(ColorScheme cs) {
    final raw = _imageValue;
    if (raw.isEmpty) {
      return _buildImagePlaceholder(cs, message: 'Sin foto de referencia');
    }

    if (raw.startsWith('data:image')) {
      final commaIndex = raw.indexOf(',');
      if (commaIndex == -1) {
        return _buildImagePlaceholder(
          cs,
          message: 'Formato de imagen inválido',
        );
      }

      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(raw.substring(commaIndex + 1)),
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: _previewCacheWidth,
            filterQuality: FilterQuality.low,
          ),
        );
      } catch (_) {
        return _buildImagePlaceholder(
          cs,
          message: 'No se pudo mostrar la imagen',
        );
      }
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final fixedUrl = _fixGoogleDriveUrl(raw);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          fixedUrl,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 160,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cargando imagen...',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(
            cs,
            message:
                'No se pudo cargar la URL.\n'
                'En web, algunas imágenes bloquean\n'
                'el acceso externo (CORS).\n'
                'Usa el botón "Seleccionar foto".',
          ),
        ),
      );
    }

    if (raw.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          raw,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          cacheWidth: _previewCacheWidth,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(
            cs,
            message: 'No se pudo cargar el recurso local',
          ),
        ),
      );
    }

    return _buildImagePlaceholder(
      cs,
      message: 'Pega una URL válida o selecciona una imagen',
    );
  }

  Widget _buildImagePlaceholder(ColorScheme cs, {required String message}) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_outlined, size: 36, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveStatus(ThemeData theme) {
    final cs = theme.colorScheme;

    if (!AppEnvironment.isDriveConfigured) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.errorContainer),
        ),
        child: Text(
          'Drive no está configurado en este entorno. '
          'Podrás guardar URL manual, pero no subir foto directa.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onErrorContainer,
            height: 1.35,
          ),
        ),
      );
    }

    if (!_supportsDriveUpload) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.secondaryContainer),
        ),
        child: Text(
          'En esta plataforma la foto se guarda localmente junto al producto. '
          'Para publicarla automáticamente en Drive (QR público), usa Android, iOS, macOS, Windows o Linux.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSecondaryContainer,
            height: 1.35,
          ),
        ),
      );
    }

    final statusText = _driveSessionReady
        ? 'Conectado${_driveOwnerEmail != null ? ': $_driveOwnerEmail' : ''}'
        : 'Sin conectar';
    final statusColor = _driveSessionReady
        ? Colors.green.shade700
        : cs.tertiary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_done_outlined, size: 18, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estado Google Drive: $statusText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_checkingDriveSession)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Las fotos seleccionadas desde el dispositivo se publicarán '
            'en Drive para que sean visibles en el menú QR.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (!_driveSessionReady) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _checkingDriveSession ? null : _connectDriveNow,
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('Conectar Google Drive'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;

    final manualImageUrl = _imagenUrlCtrl.text.trim();
    if (_selectedImageBytes == null &&
        manualImageUrl.isNotEmpty &&
        !_isValidPublicImageUrl(manualImageUrl)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La URL de imagen es inválida. Usa una URL pública http/https.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
      if (_selectedImageBytes != null) {
        _imageStage = _ImageWorkflowStage.uploading;
        _imageStageMessage = 'Subiendo imagen...';
      }
    });

    final now = DateTime.now();
    final tenant = sl<TenantContext>();
    final restaurantId = widget.producto?.restaurantId ?? tenant.restaurantId;
    final userId = tenant.userId ?? 'system';
    final productoId = widget.producto?.id ?? const Uuid().v4();

    final variantesEntidades = _variantes.map((v) {
      return Variante(
        id: v.id ?? const Uuid().v4(),
        productoId: productoId,
        nombre: v.nombreCtrl.text.trim(),
        precio: double.tryParse(v.precioCtrl.text.trim()) ?? 0.0,
        activo: true,
        createdAt: v.createdAt ?? now,
        updatedAt: now,
      );
    }).toList();

    String? imagenUrl = _imagenUrlCtrl.text.trim();
    if (imagenUrl.isEmpty) imagenUrl = null;
    String? driveFileId = widget.producto?.driveFileId;
    String? drivePublicUrl = widget.producto?.drivePublicUrl;
    String? imagenLocalCachePath = widget.producto?.imagenLocalCachePath;
    String? driveWarning;

    try {
      final driveService = sl<DriveMenuConnectionService>();
      final driveQueue = sl<DriveImageSyncQueueService>();
      final diagnostics = sl<MenuSyncDiagnosticsService>();

      // Si la imagen proviene del selector local, se sube a Drive para
      // garantizar acceso público sin autenticación (QR / página pública).
      if (_selectedImageBytes != null && _selectedImageMimeType != null) {
        var uploadedToDrive = false;

        if (AppEnvironment.isDriveConfigured && _supportsDriveUpload) {
          // Bloquear guardado si Drive no está conectado y hay imagen pendiente.
          // El usuario debe usar el botón "Conectar Google Drive" antes de guardar.
          if (!_driveSessionReady) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Para subir la foto, primero conecta Google Drive '
                  'con el botón "Conectar Google Drive" en la sección de imagen.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
            setState(() => _submitting = false);
            return;
          }

          // Refrescar token silenciosamente por si la sesión expiró.
          final authRefresh = await driveService.ensureDriveAuthenticated(
            interactive: false,
          );
          if (!authRefresh.isConnected) {
            driveWarning =
                'Sesión Drive expirada. Reconecta Drive y vuelve a guardar.';
            diagnostics.recordError(driveWarning);
            setState(() {
              _submitting = false;
              _driveSessionReady = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(driveWarning)));
            }
            return;
          }
          _driveOwnerEmail = authRefresh.email ?? driveService.currentEmail;

          try {
            _setImageStage(
              _ImageWorkflowStage.uploading,
              message: 'Subiendo imagen...',
            );
            final uploadStopwatch = Stopwatch()..start();
            final upload = await driveService.uploadProductImage(
              restaurantId: restaurantId,
              userId: userId,
              productoId: productoId,
              bytes: _selectedImageBytes!,
              mimeType: _selectedImageMimeType!,
              fileExtension: _selectedImageExtension ?? 'jpg',
            );
            uploadStopwatch.stop();
            _lastUploadElapsed = uploadStopwatch.elapsed;
            debugPrint(
              'menu.image.upload '
              'productoId=$productoId '
              'elapsedMs=${uploadStopwatch.elapsedMilliseconds} '
              'fileId=${upload.fileId} '
              'url=${upload.publicUrl}',
            );

            if (driveFileId != null && driveFileId != upload.fileId) {
              final deleted = await driveService.tryDeleteProductImage(
                driveFileId,
              );
              if (!deleted) {
                await driveQueue.enqueueDeleteImage(
                  restaurantId: restaurantId,
                  fileId: driveFileId,
                );
              }
            }

            imagenUrl = upload.publicUrl;
            driveFileId = upload.fileId;
            drivePublicUrl = upload.publicUrl;
            imagenLocalCachePath = upload.localCachePath;
            uploadedToDrive = true;
            _setImageStage(
              _ImageWorkflowStage.optimized,
              message: 'Imagen optimizada correctamente',
            );
          } catch (e, st) {
            uploadedToDrive = false;
            driveWarning = 'Falló la subida de imagen a Drive: $e';
            diagnostics.recordError(driveWarning);
            debugPrint('Drive upload error for producto $productoId: $e\n$st');
            _setImageStage(
              _ImageWorkflowStage.uploadError,
              message: 'Error al subir imagen',
            );
          }
        }

        if (!uploadedToDrive) {
          final canQueueDriveUpload =
              AppEnvironment.isDriveConfigured && _supportsDriveUpload;
          final previousDriveFileId = driveFileId;

          if (canQueueDriveUpload) {
            await driveQueue.enqueueUploadImage(
              restaurantId: restaurantId,
              userId: userId,
              productoId: productoId,
              bytes: _selectedImageBytes!,
              mimeType: _selectedImageMimeType!,
              fileExtension: _selectedImageExtension ?? 'jpg',
              previousDriveFileId: previousDriveFileId,
            );

            final queueResult = await driveQueue.processPendingOperations(
              allowInteractiveSignIn: true,
              maxToProcess: 2,
            );

            if (queueResult.succeeded == 0) {
              final pendingCount = await driveQueue.countPendingOperations();
              final baseWarning =
                  driveWarning ??
                  'La imagen quedó en cola de Drive y se reintentará automáticamente.';
              driveWarning = '$baseWarning Pendientes: $pendingCount.';
              diagnostics.recordError(driveWarning);
              _setImageStage(
                _ImageWorkflowStage.uploadError,
                message: 'Error al subir imagen',
              );
            } else {
              _setImageStage(
                _ImageWorkflowStage.optimized,
                message: 'Imagen optimizada correctamente',
              );
            }
          } else {
            throw StateError(
              'Drive no está disponible para subir la imagen seleccionada.',
            );
          }

          final previousImagenUrl = widget.producto?.imagenUrl?.trim();
          if (previousImagenUrl != null &&
              previousImagenUrl.isNotEmpty &&
              !previousImagenUrl.startsWith('data:')) {
            imagenUrl = previousImagenUrl;
          } else {
            imagenUrl = drivePublicUrl;
          }
        }
      }

      // Si el admin cambia a una URL manual externa, limpiar metadatos
      // de Drive para evitar referencias inconsistentes.
      if (_selectedImageBytes == null &&
          imagenUrl != null &&
          imagenUrl.isNotEmpty &&
          drivePublicUrl != null &&
          imagenUrl != drivePublicUrl) {
        final previousDriveFileId = driveFileId;
        if (previousDriveFileId != null && previousDriveFileId.isNotEmpty) {
          final signedIn = _driveSessionReady
              ? true
              : await driveService.restoreSessionSilently();
          var deleted = false;
          if (signedIn) {
            deleted = await driveService.tryDeleteProductImage(
              previousDriveFileId,
            );
          }
          if (!deleted) {
            await driveQueue.enqueueDeleteImage(
              restaurantId: restaurantId,
              fileId: previousDriveFileId,
            );
          }
        }

        driveFileId = null;
        drivePublicUrl = null;
        imagenLocalCachePath = null;
      }

      // Si se quitó la imagen en edición, limpiar metadatos Drive.
      if ((imagenUrl == null || imagenUrl.isEmpty) && driveFileId != null) {
        final signedIn = _driveSessionReady
            ? true
            : await driveService.restoreSessionSilently();
        var deleted = false;
        if (signedIn) {
          deleted = await driveService.tryDeleteProductImage(driveFileId);
        }
        if (!deleted) {
          await driveQueue.enqueueDeleteImage(
            restaurantId: restaurantId,
            fileId: driveFileId,
          );
        }
        driveFileId = null;
        drivePublicUrl = null;
        imagenLocalCachePath = null;
      }

      // Drenado oportunista sin prompt interactivo.
      await driveQueue.processPendingOperations();

      if (imagenUrl != null && !_isValidPublicImageUrl(imagenUrl)) {
        debugPrint(
          'menu.image.persist blocked invalid imagen_url for $productoId: $imagenUrl',
        );
        imagenUrl = null;
      }
      if (drivePublicUrl != null && !_isValidPublicImageUrl(drivePublicUrl)) {
        debugPrint(
          'menu.image.persist blocked invalid drive_public_url for $productoId: $drivePublicUrl',
        );
        drivePublicUrl = null;
      }
      if (driveFileId != null && driveFileId.trim().isEmpty) {
        driveFileId = null;
      }
      if ((imagenUrl == null || imagenUrl.isEmpty) &&
          drivePublicUrl != null &&
          _isValidPublicImageUrl(drivePublicUrl)) {
        imagenUrl = drivePublicUrl;
      }

      final producto = Producto(
        id: productoId,
        restaurantId: restaurantId,
        categoriaId: _categoriaId,
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        precio: double.tryParse(_precioCtrl.text.trim()) ?? 0.0,
        imagenUrl: imagenUrl,
        driveFileId: driveFileId,
        drivePublicUrl: drivePublicUrl,
        imagenLocalCachePath: imagenLocalCachePath,
        disponible: _disponible,
        activo: _activo,
        createdAt: widget.producto?.createdAt ?? now,
        updatedAt: now,
        variantes: variantesEntidades,
      );

      if (!mounted) return;
      if (driveWarning != null && driveWarning.trim().isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(driveWarning)));
      }
      Navigator.of(context).pop(producto);
    } catch (e, st) {
      final diagnostics = sl<MenuSyncDiagnosticsService>();
      final message = 'No se pudo guardar producto/imagen en Drive: $e';
      diagnostics.recordError(message);
      debugPrint('$message\n$st');
      _setImageStage(
        _ImageWorkflowStage.uploadError,
        message: 'Error al subir imagen',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewport = MediaQuery.sizeOf(context);

    // Altura segura: clamp evita que MediaQuery devuelva 0 brevemente
    // cuando el OS dialog (FilePicker en Windows) interrumpe el render.
    final safeMaxHeight = (MediaQuery.sizeOf(context).height * 0.80).clamp(
      420.0,
      700.0,
    );
    final safeMaxWidth = (viewport.width * 0.92).clamp(280.0, 500.0);

    return AlertDialog(
      title: Text(_isEditing ? 'Editar Producto' : 'Nuevo Producto'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: safeMaxWidth,
        height: safeMaxHeight,
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Nombre ──────────────────────────────────────
                    TextFormField(
                      controller: _nombreCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        hintText: 'Ej: Hamburguesa Clásica',
                        prefixIcon: Icon(Icons.fastfood_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'El nombre es obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // ── Descripción ──────────────────────────────────
                    TextFormField(
                      controller: _descripcionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Ingredientes, alérgenos, etc. (opcional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Foto de referencia ───────────────────────────
                    Text(
                      'Foto de referencia (opcional)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDriveStatus(theme),
                    const SizedBox(height: 8),
                    _buildImagePreview(theme.colorScheme),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _imagenUrlCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'URL de la foto',
                        hintText:
                            'Pega un enlace o usa el botón para elegir una imagen',
                        prefixIcon: Icon(Icons.link_outlined),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) {
                        setState(() {
                          if (_selectedImageData != null) {
                            _selectedImageData = null;
                            _selectedImageBytes = null;
                            _selectedImageMimeType = null;
                            _selectedImageExtension = null;
                          }
                          _imageStage = _ImageWorkflowStage.idle;
                          _imageStageMessage = null;
                        });
                      },
                    ),
                    if (_selectedImageData != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Imagen seleccionada desde el dispositivo.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (_imageStatusLabel() != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _imageStatusLabel()!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: switch (_imageStage) {
                            _ImageWorkflowStage.optimized =>
                              Colors.green.shade700,
                            _ImageWorkflowStage.uploadError =>
                              theme.colorScheme.error,
                            _ => theme.colorScheme.onSurfaceVariant,
                          },
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_lastOriginalBytes != null &&
                        _lastCompressedBytes != null &&
                        _lastReductionPercent != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Original: ${_formatBytes(_lastOriginalBytes!)} · '
                        'Comprimida: ${_formatBytes(_lastCompressedBytes!)} · '
                        'Reducción: ${_lastReductionPercent!.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (_lastCompressionElapsed != null ||
                        _lastUploadElapsed != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Tiempo compresión: '
                        '${_lastCompressionElapsed?.inMilliseconds ?? 0} ms · '
                        'Tiempo subida: ${_lastUploadElapsed?.inMilliseconds ?? 0} ms',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickingImage ? null : _pickImage,
                          icon: Icon(
                            _pickingImage
                                ? Icons.hourglass_top
                                : Icons.photo_library_outlined,
                          ),
                          label: Text(
                            _pickingImage
                                ? 'Comprimiendo imagen...'
                                : (_imageValue.isEmpty
                                      ? 'Seleccionar foto'
                                      : 'Cambiar foto'),
                          ),
                        ),
                        if (_imageValue.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              _selectedImageData = null;
                              _selectedImageBytes = null;
                              _selectedImageMimeType = null;
                              _selectedImageExtension = null;
                              _imagenUrlCtrl.clear();
                              setState(() {
                                _imageStage = _ImageWorkflowStage.idle;
                                _imageStageMessage = null;
                              });
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Quitar foto'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Precio + Categoría ───────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _precioCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Precio *',
                              prefixText: '\$ ',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Requerido';
                              }
                              final parsed = double.tryParse(v.trim());
                              if (parsed == null || parsed < 0) {
                                return 'Precio inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categoriaId.isEmpty ? null : _categoriaId,
                            decoration: const InputDecoration(
                              labelText: 'Categoría *',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: widget.categorias
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.nombre),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _categoriaId = v);
                              }
                            },
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Selecciona una categoría'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Disponible ───────────────────────────────────
                    SwitchListTile.adaptive(
                      title: const Text('Disponible ahora'),
                      subtitle: Text(
                        _disponible
                            ? 'Visible para los pedidos'
                            : 'No se puede pedir',
                        style: theme.textTheme.bodySmall,
                      ),
                      value: _disponible,
                      onChanged: (v) => setState(() => _disponible = v),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const Divider(height: 24),

                    // ── Variantes ────────────────────────────────────
                    Row(
                      children: [
                        Text(
                          'Variantes (opcional)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addVariante,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Añadir'),
                        ),
                      ],
                    ),
                    if (_variantes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Sin variantes — el precio base aplica para todos.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < _variantes.length; i++)
                            Builder(
                              key: ValueKey(_variantes[i].id ?? i),
                              builder: (_) {
                                final v = _variantes[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: v.nombreCtrl,
                                          decoration: InputDecoration(
                                            labelText:
                                                'Nombre variante ${i + 1}',
                                            hintText: 'Ej: Grande',
                                            isDense: true,
                                          ),
                                          validator: (val) {
                                            if (val == null ||
                                                val.trim().isEmpty) {
                                              return 'Requerido';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: v.precioCtrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: const InputDecoration(
                                            labelText: 'Precio',
                                            prefixText: '\$ ',
                                            isDense: true,
                                          ),
                                          validator: (val) {
                                            if (val == null ||
                                                val.trim().isEmpty) {
                                              return 'Requerido';
                                            }
                                            final p = double.tryParse(
                                              val.trim(),
                                            );
                                            if (p == null || p < 0) {
                                              return 'Inválido';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        color: theme.colorScheme.error,
                                        onPressed: () => _removeVariante(i),
                                        tooltip: 'Eliminar variante',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            // ── Overlay de carga durante selección de imagen ──────
            if (_isBusy)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _busyOverlayLabel(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isBusy ? null : _submit,
          child: Text(_isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

/// Datos de entrada para el procesamiento de imagen en un Isolate.
enum _ImageWorkflowStage {
  idle,
  compressing,
  uploading,
  optimized,
  uploadError,
}

/// Datos de entrada para el procesamiento de imagen en un Isolate.
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

/// Función top-level para procesar/redimensionar una imagen en un Isolate
/// separado via [compute], evitando bloquear el hilo principal de la UI.
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
    final encoded = Uint8List.fromList(img.encodePng(resized, level: 6));
    if (encoded.length >= input.bytes.length) {
      return _OptimizedImage(
        mimeType: _mimeTypeFromExtension(input.extension),
        bytes: input.bytes,
      );
    }
    return _OptimizedImage(mimeType: 'image/png', bytes: encoded);
  }

  final encoded = Uint8List.fromList(
    img.encodeJpg(resized, quality: input.jpegQuality),
  );
  if (encoded.length >= input.bytes.length) {
    return _OptimizedImage(
      mimeType: _mimeTypeFromExtension(input.extension),
      bytes: input.bytes,
    );
  }

  return _OptimizedImage(mimeType: 'image/jpeg', bytes: encoded);
}

String _mimeTypeFromExtension(String extension) {
  switch (extension.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'png':
    default:
      return 'image/png';
  }
}

/// Modelo editable de una variante dentro del formulario.
class _VarianteEditable {
  final String? id;
  final DateTime? createdAt;
  final TextEditingController nombreCtrl;
  final TextEditingController precioCtrl;

  _VarianteEditable({
    this.id,
    this.createdAt,
    TextEditingController? nombreCtrl,
    TextEditingController? precioCtrl,
  }) : nombreCtrl = nombreCtrl ?? TextEditingController(),
       precioCtrl = precioCtrl ?? TextEditingController();

  factory _VarianteEditable.fromEntity(Variante v) {
    return _VarianteEditable(
      id: v.id,
      createdAt: v.createdAt,
      nombreCtrl: TextEditingController(text: v.nombre),
      precioCtrl: TextEditingController(text: v.precio.toStringAsFixed(2)),
    );
  }

  void dispose() {
    nombreCtrl.dispose();
    precioCtrl.dispose();
  }
}
