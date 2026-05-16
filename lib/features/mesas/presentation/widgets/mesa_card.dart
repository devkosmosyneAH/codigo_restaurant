import 'package:flutter/material.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/mesas/domain/entities/mesa.dart';

/// Card visual de una mesa en el grid.
///
/// Muestra el número, capacidad y estado con color diferenciado.
/// Soporta tap y long press para interacción.
class MesaCard extends StatelessWidget {
  final Mesa mesa;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MesaCard({super.key, required this.mesa, this.onTap, this.onLongPress});

  Color _getColorByEstado(EstadoMesa estado) {
    switch (estado) {
      case EstadoMesa.libre:
        return AppColors.mesaLibre;
      case EstadoMesa.ocupada:
        return AppColors.mesaOcupada;
      case EstadoMesa.reservada:
        return AppColors.mesaReservada;
    }
  }

  IconData _getIconByEstado(EstadoMesa estado) {
    switch (estado) {
      case EstadoMesa.libre:
        return Icons.check_circle_outline_rounded;
      case EstadoMesa.ocupada:
        return Icons.people_rounded;
      case EstadoMesa.reservada:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorByEstado(mesa.estado);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxWidth < 170 || constraints.maxHeight < 210;
        final isTight =
            constraints.maxWidth < 150 || constraints.maxHeight < 180;
        final padding = EdgeInsets.all(isTight ? 10 : (isCompact ? 12 : 16));
        final iconSize = isTight ? 24.0 : (isCompact ? 28.0 : 36.0);
        final titleSize = isTight ? 14.0 : (isCompact ? 16.0 : 18.0);
        final metaSize = isTight ? 11.0 : 13.0;
        final badgeSize = isTight ? 10.0 : 12.0;
        final gapSmall = isTight ? 3.0 : 4.0;
        final gapMedium = isTight ? 6.0 : 8.0;

        return Card(
          elevation: mesa.estado == EstadoMesa.ocupada ? 5 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color.withValues(alpha: 0.7), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.10),
                    color.withValues(alpha: 0.04),
                  ],
                ),
              ),
              padding: padding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono con fondo circular
                  Container(
                    width: iconSize + 16,
                    height: iconSize + 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      _getIconByEstado(mesa.estado),
                      color: color,
                      size: iconSize,
                    ),
                  ),
                  SizedBox(height: gapMedium),
                  // Nombre de la mesa
                  Flexible(
                    child: Text(
                      mesa.displayName,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: isCompact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: gapSmall),
                  // Capacidad
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: isTight ? 12 : 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${mesa.capacidad} personas',
                        style: TextStyle(
                          fontSize: metaSize,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: gapMedium),
                  // Badge de estado
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTight ? 10 : 14,
                        vertical: isTight ? 3 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: color.withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        mesa.estado.label,
                        style: TextStyle(
                          color: color,
                          fontSize: badgeSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (mesa.estado == EstadoMesa.reservada &&
                      mesa.nombreReserva != null &&
                      mesa.nombreReserva!.isNotEmpty) ...[
                    SizedBox(height: gapSmall + 2),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTight ? 6 : 8,
                        vertical: isTight ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mesaReservada.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.mesaReservada.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: isTight ? 10 : 11,
                            color: AppColors.mesaReservada,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              mesa.nombreReserva!,
                              style: TextStyle(
                                fontSize: isTight ? 10 : 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mesaReservada,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (mesa.estaUnida) ...[
                    SizedBox(height: gapSmall),
                    Icon(
                      Icons.link_rounded,
                      size: isTight ? 14 : 16,
                      color: Colors.grey,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
