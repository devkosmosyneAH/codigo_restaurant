import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
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

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _imagenUrlCtrl;
  String? _selectedImageData;
  late String _categoriaId;
  bool _disponible = true;
  bool _activo = true;
  bool _pickingImage = false;
  List<_VarianteEditable> _variantes = [];

  bool get _isEditing => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _precioCtrl = TextEditingController(
      text: p != null ? p.precio.toStringAsFixed(2) : '',
    );
    final initialImage = p?.imagenUrl?.trim() ?? '';
    _selectedImageData = initialImage.startsWith('data:image')
        ? initialImage
        : null;
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

  String get _imageValue {
    final selected = _selectedImageData?.trim();
    if (selected != null && selected.isNotEmpty) return selected;
    return _imagenUrlCtrl.text.trim();
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo leer la imagen seleccionada'),
          ),
        );
        return;
      }

      final ext = (file.extension ?? 'png').toLowerCase();
      final optimized = await compute(
        _processImageIsolate,
        _ImageInput(bytes: bytes, extension: ext),
      );

      if (!mounted) return;

      final imageBytes = optimized?.bytes ?? bytes;
      final mimeType =
          optimized?.mimeType ??
          switch (ext) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'gif' => 'image/gif',
            'webp' => 'image/webp',
            _ => 'image/png',
          };

      _selectedImageData = 'data:$mimeType;base64,${base64Encode(imageBytes)}';
      _imagenUrlCtrl.clear();
    } catch (_) {
      if (!mounted) return;
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          raw,
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
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

    final imagenUrl = _imageValue;

    final producto = Producto(
      id: productoId,
      restaurantId:
          widget.producto?.restaurantId ?? sl<TenantContext>().restaurantId,
      categoriaId: _categoriaId,
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      precio: double.tryParse(_precioCtrl.text.trim()) ?? 0.0,
      imagenUrl: imagenUrl.isEmpty ? null : imagenUrl,
      disponible: _disponible,
      activo: _activo,
      createdAt: widget.producto?.createdAt ?? now,
      updatedAt: now,
      variantes: variantesEntidades,
    );

    Navigator.of(context).pop(producto);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Altura segura: clamp evita que MediaQuery devuelva 0 brevemente
    // cuando el OS dialog (FilePicker en Windows) interrumpe el render.
    final safeMaxHeight = (MediaQuery.sizeOf(context).height * 0.80).clamp(
      420.0,
      700.0,
    );

    return AlertDialog(
      title: Text(_isEditing ? 'Editar Producto' : 'Nuevo Producto'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 500,
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
                        if (_selectedImageData != null) {
                          _selectedImageData = null;
                        }
                        setState(() {});
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
                                ? 'Cargando...'
                                : (_imageValue.isEmpty
                                      ? 'Seleccionar foto'
                                      : 'Cambiar foto'),
                          ),
                        ),
                        if (_imageValue.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              _selectedImageData = null;
                              _imagenUrlCtrl.clear();
                              setState(() {});
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
            if (_pickingImage)
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
                        'Procesando imagen...',
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
          onPressed: _pickingImage ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _pickingImage ? null : _submit,
          child: Text(_isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

/// Datos de entrada para el procesamiento de imagen en un Isolate.
class _ImageInput {
  final Uint8List bytes;
  final String extension;
  const _ImageInput({required this.bytes, required this.extension});
}

class _OptimizedImage {
  final Uint8List bytes;
  final String mimeType;

  const _OptimizedImage({required this.bytes, required this.mimeType});
}

/// Función top-level para procesar/redimensionar una imagen en un Isolate
/// separado via [compute], evitando bloquear el hilo principal de la UI.
_OptimizedImage? _processImageIsolate(_ImageInput input) {
  const maxWidth = 1280;
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) return null;

  final resized = decoded.width > maxWidth
      ? img.copyResize(decoded, width: maxWidth)
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
    bytes: Uint8List.fromList(img.encodeJpg(resized, quality: 78)),
  );
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
