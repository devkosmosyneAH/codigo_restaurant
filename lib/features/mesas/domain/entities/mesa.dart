import 'package:equatable/equatable.dart';
import 'package:restaurant_app/core/domain/enums.dart';

/// Entidad de dominio: Mesa.
///
/// Representa una mesa del restaurante.
/// Las mesas son dinámicas (se pueden agregar/eliminar).
/// Soporta unión de mesas a través de [mesaUnionId].
class Mesa extends Equatable {
  final String id;
  final String restaurantId;
  final int numero;
  final String? nombre;
  final int capacidad;
  final EstadoMesa estado;

  /// Si esta mesa está unida a otra, comparten este ID.
  final String? mesaUnionId;

  /// Nombre de quien tiene la reserva (solo cuando estado = reservada).
  final String? nombreReserva;

  /// Posición en el layout visual (para futuro mapa de mesas).
  final double posicionX;
  final double posicionY;

  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Mesa({
    required this.id,
    required this.restaurantId,
    required this.numero,
    this.nombre,
    this.capacidad = 4,
    this.estado = EstadoMesa.libre,
    this.mesaUnionId,
    this.nombreReserva,
    this.posicionX = 0,
    this.posicionY = 0,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Nombre para mostrar en la tarjeta de reserva.
  String get displayReserva => nombreReserva ?? '';

  /// Nombre para mostrar: usa [nombre] si existe, sino "Mesa [numero]".
  String get displayName => nombre ?? 'Mesa $numero';

  /// Indica si la mesa está disponible para un nuevo pedido.
  bool get estaDisponible => estado == EstadoMesa.libre;

  /// Indica si la mesa forma parte de una unión.
  bool get estaUnida => mesaUnionId != null;

  Mesa copyWith({
    String? id,
    String? restaurantId,
    int? numero,
    String? nombre,
    int? capacidad,
    EstadoMesa? estado,
    String? mesaUnionId,
    String? nombreReserva,
    bool clearNombreReserva = false,
    double? posicionX,
    double? posicionY,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Mesa(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      numero: numero ?? this.numero,
      nombre: nombre ?? this.nombre,
      capacidad: capacidad ?? this.capacidad,
      estado: estado ?? this.estado,
      mesaUnionId: mesaUnionId ?? this.mesaUnionId,
      nombreReserva: clearNombreReserva
          ? null
          : (nombreReserva ?? this.nombreReserva),
      posicionX: posicionX ?? this.posicionX,
      posicionY: posicionY ?? this.posicionY,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    numero,
    nombre,
    capacidad,
    estado,
    mesaUnionId,
    nombreReserva,
    activo,
    createdAt,
    updatedAt,
  ];
}
