import 'package:equatable/equatable.dart';
import 'package:restaurant_app/core/domain/enums.dart';

/// Entidad de dominio: Llamado a mesero.
///
/// Representa una solicitud realizada desde el menú público.
class LlamadoMesero extends Equatable {
  final String id;
  final String restaurantId;
  final String? mesaId;
  final String? mesaNombre;
  final EstadoLlamado estado;
  final DateTime createdAt;
  final DateTime? atendidoAt;

  const LlamadoMesero({
    required this.id,
    required this.restaurantId,
    this.mesaId,
    this.mesaNombre,
    this.estado = EstadoLlamado.pendiente,
    required this.createdAt,
    this.atendidoAt,
  });

  LlamadoMesero copyWith({
    String? id,
    String? restaurantId,
    String? mesaId,
    String? mesaNombre,
    EstadoLlamado? estado,
    DateTime? createdAt,
    DateTime? atendidoAt,
  }) {
    return LlamadoMesero(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      mesaId: mesaId ?? this.mesaId,
      mesaNombre: mesaNombre ?? this.mesaNombre,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
      atendidoAt: atendidoAt ?? this.atendidoAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    mesaId,
    mesaNombre,
    estado,
    createdAt,
    atendidoAt,
  ];
}
