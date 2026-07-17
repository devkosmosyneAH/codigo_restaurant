import 'package:flutter/material.dart';
import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/menu/domain/entities/producto.dart';
import 'package:restaurant_app/features/menu/presentation/widgets/menu_image_loader.dart';

/// Tarjeta de producto para el menu publico.
class PublicProductoCard extends StatefulWidget {
  final Producto producto;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onOpenOptions;
  final int cantidad;

  const PublicProductoCard({
    super.key,
    required this.producto,
    this.onAdd,
    this.onIncrement,
    this.onDecrement,
    this.onOpenOptions,
    this.cantidad = 0,
  });

  @override
  State<PublicProductoCard> createState() => _PublicProductoCardState();
}

class _PublicProductoCardState extends State<PublicProductoCard> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tieneVariantes = widget.producto.tieneVariantes;
    final showQtyControls = widget.cantidad > 0;
    final precio = widget.producto.precioReferencial;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final scale = animationsDisabled
        ? 1.0
        : _pressed
        ? 0.985
        : _hovered
        ? 1.01
        : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: GestureDetector(
          onTap: tieneVariantes ? widget.onOpenOptions : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE9E0D5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _hovered ? 0.11 : 0.06,
                    ),
                    blurRadius: _hovered ? 14 : 9,
                    offset: Offset(0, _hovered ? 7 : 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: MenuImageLoader(
                        localCachePath: widget.producto.imagenLocalCachePath,
                        primaryImageValue: widget.producto.imagenUrl,
                        fallbackImageValue: widget.producto.drivePublicUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 720,
                        filterQuality: FilterQuality.low,
                        placeholder: _placeholder(cs),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.producto.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              height: 1.18,
                            ),
                          ),
                          if (widget.producto.descripcion != null &&
                              widget.producto.descripcion!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.producto.descripcion!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.25,
                              ),
                            ),
                          ],
                          if (tieneVariantes) ...[
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: widget.onOpenOptions,
                              child: Text(
                                '${_buildVariantesSummary(widget.producto)} · Ver opciones',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '${tieneVariantes ? 'Desde ' : ''}${AppConstants.currencySymbol}${precio.toStringAsFixed(2)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (showQtyControls)
                                _QuantityControl(
                                  cantidad: widget.cantidad,
                                  onIncrement: tieneVariantes
                                      ? widget.onOpenOptions
                                      : widget.onIncrement,
                                  onDecrement: widget.onDecrement,
                                )
                              else
                                Tooltip(
                                  message: tieneVariantes
                                      ? 'Elegir opcion'
                                      : 'Agregar',
                                  child: Material(
                                    color: AppColors.primary,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: tieneVariantes
                                          ? widget.onOpenOptions
                                          : widget.onAdd,
                                      child: const SizedBox.square(
                                        dimension: 34,
                                        child: Icon(
                                          Icons.add_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHighest,
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Icon(
        Icons.restaurant_menu_rounded,
        color: cs.onSurfaceVariant,
        size: 42,
      ),
    );
  }

  String _buildVariantesSummary(Producto producto) {
    final activas = producto.variantes.where((v) => v.activo).toList();
    if (activas.isEmpty) {
      return 'Opciones disponibles';
    }

    final preview = activas.take(2).map((v) => v.nombre.trim()).join(' · ');
    final restantes = activas.length - 2;
    final suffix = restantes > 0 ? ' +$restantes' : '';
    return '${activas.length} opciones: $preview$suffix';
  }
}

class _QuantityControl extends StatelessWidget {
  final int cantidad;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _QuantityControl({
    required this.cantidad,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9D0C1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(
            icon: Icons.remove_rounded,
            onTap: onDecrement,
            color: const Color(0xFF7E6A55),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$cantidad',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _QtyBtn(
            icon: Icons.add_rounded,
            onTap: onIncrement,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _QtyBtn({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: onTap != null ? color : Colors.grey),
      ),
    );
  }
}
