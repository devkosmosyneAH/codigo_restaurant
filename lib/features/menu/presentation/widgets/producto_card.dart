import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/presentation/providers/menu_provider.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/menu_image_loader.dart';

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
              child: MenuImageLoader(
                localCachePath: producto.imagenLocalCachePath,
                primaryImageValue: producto.imagenUrl,
                fallbackImageValue: producto.drivePublicUrl,
                fit: BoxFit.cover,
                cacheWidth: 720,
                filterQuality: FilterQuality.low,
                placeholder: _placeholder(colorScheme),
              ),
            ),
            // Reemplaza todo el Expanded(child: Padding(...)) actual con esto:
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  10,
                  8,
                  10,
                  8,
                ), // padding más ajustado
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre + Switch (siempre arriba)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            producto.nombre,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5, // reducido para móvil
                            ),
                            maxLines: 1, // ← importante en móviles
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 32,
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

                    // Descripción (flexible)
                    Expanded(
                      child: Text(
                        producto.descripcion?.trim() ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Chips + Precio + Botones (todo en una fila compacta)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Chips (compactos)
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              if (categoriaNombre != null)
                                Chip(
                                  label: Text(
                                    categoriaNombre!,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 0,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              if (producto.tieneVariantes)
                                Chip(
                                  avatar: const Icon(Icons.tune, size: 10),
                                  label: Text(
                                    '${producto.variantes.length} vars.',
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 0,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ),

                        // Precio
                        Text(
                          '\$${producto.precioMinimo.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (producto.tieneVariantes)
                          Text(
                            ' desde',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10.5,
                            ),
                          ),

                        const SizedBox(width: 4),

                        // Botones edición/eliminar (más pequeños)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: onEdit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
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
