import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';

/// Tarjeta que muestra un producto del menú.
///
/// Incluye toggle de disponibilidad y opciones de editar/eliminar.
class ProductoCard extends ConsumerWidget {
  final Producto producto;
  final String? categoriaNombre;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ProductoCard({
    super.key,
    required this.producto,
    this.categoriaNombre,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifier = ref.read(menuProvider.notifier);

    final bool disponible = producto.disponible;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: disponible ? 1.0 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado de color por disponibilidad ──────────────
            Container(
              height: 6,
              color: disponible ? colorScheme.primary : colorScheme.outline,
            ),
            Container(
              height: 132,
              width: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              child: _buildImage(producto.imagenUrl, colorScheme),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Nombre + toggle ────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            producto.nombre,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: disponible
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 36,
                          height: 20,
                          child: Switch.adaptive(
                            value: disponible,
                            onChanged: (val) => notifier.cambiarDisponibilidad(
                              producto.id,
                              val,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // ── Descripción ────────────────────────────────
                    if (producto.descripcion != null &&
                        producto.descripcion!.isNotEmpty) ...[
                      Text(
                        producto.descripcion!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],

                    const Spacer(),

                    // ── Chips: categoría + variantes ───────────────
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (categoriaNombre != null)
                          Chip(
                            label: Text(
                              categoriaNombre!,
                              style: const TextStyle(fontSize: 10),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (producto.tieneVariantes)
                          Chip(
                            avatar: const Icon(Icons.tune, size: 12),
                            label: Text(
                              '${producto.variantes.length} vars.',
                              style: const TextStyle(fontSize: 10),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),

                    // ── Precio + acciones ──────────────────────────
                    Row(
                      children: [
                        Text(
                          '\$${producto.precioMinimo.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (producto.tieneVariantes)
                          Text(
                            ' desde',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const Spacer(),
                        // Editar
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Editar',
                          onPressed: onEdit,
                        ),
                        // Eliminar
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Eliminar',
                          color: colorScheme.error,
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? imageValue, ColorScheme colorScheme) {
    final raw = imageValue?.trim();
    if (raw == null || raw.isEmpty) return _placeholder(colorScheme);

    if (raw.startsWith('data:image')) {
      final commaIndex = raw.indexOf(',');
      if (commaIndex == -1) return _placeholder(colorScheme);

      try {
        return Image.memory(
          base64Decode(raw.substring(commaIndex + 1)),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: 720,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => _placeholder(colorScheme),
        );
      } catch (_) {
        return _placeholder(colorScheme);
      }
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Image.network(
        raw,
        fit: BoxFit.cover,
        cacheWidth: 720,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _placeholder(colorScheme),
      );
    }

    if (raw.startsWith('assets/')) {
      return Image.asset(
        raw,
        fit: BoxFit.cover,
        cacheWidth: 720,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _placeholder(colorScheme),
      );
    }

    return _placeholder(colorScheme);
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.photo_camera_back_outlined,
        color: colorScheme.onSurfaceVariant,
        size: 36,
      ),
    );
  }
}
