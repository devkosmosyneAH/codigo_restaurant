import 'package:equatable/equatable.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/pedidos/domain/entities/pedido_item.dart';

/// Entidad de dominio: Pedido.
///
/// Representa un pedido completo asociado a una mesa y un mesero.
/// Contiene una lista de [items] (productos pedidos).
///
/// Regla de negocio: Solo puede editarse si su estado es
/// 'creado' o 'aceptado' (antes de entrar a preparación).
class Pedido extends Equatable {
  final String id;
  final String restaurantId;
  final String? mesaId;
  final String? meseroId;
  final EstadoPedido estado;
  final String? observaciones;
  final double total;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Items del pedido (cargados opcionalmente).
  final List<PedidoItem> items;

  /// Nombre de la mesa (para display, cargado opcionalmente).
  final String? mesaNombre;

  /// Nombre del mesero (para display, cargado opcionalmente).
  final String? meseroNombre;

  const Pedido({
    required this.id,
    required this.restaurantId,
    this.mesaId,
    this.meseroId,
    this.estado = EstadoPedido.creado,
    this.observaciones,
    this.total = 0,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.mesaNombre,
    this.meseroNombre,
  });

  /// Total calculado desde los items.
  double get totalCalculado =>
      items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Cantidad total de items en el pedido.
  int get cantidadItems => items.fold(0, (sum, item) => sum + item.cantidad);

  /// Si el pedido puede ser editado.
  bool get esEditable => estado.esEditable;

  /// Si se pueden agregar items al pedido.
  bool get puedeAgregarItems => estado.puedeAgregarItems;

  /// Si el pedido está activo (no entregado).
  bool get esActivo => estado.esActivo;

  /// Si el pedido está listo para cobrar.
  bool get listoPaCobrar =>
      estado == EstadoPedido.finalizado || estado == EstadoPedido.entregado;

  /// Tiempo transcurrido desde la creación.
  Duration get tiempoTranscurrido => DateTime.now().difference(createdAt);

  Pedido copyWith({
    String? id,
    String? restaurantId,
    String? mesaId,
    String? meseroId,
    EstadoPedido? estado,
    String? observaciones,
    double? total,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PedidoItem>? items,
    String? mesaNombre,
    String? meseroNombre,
  }) {
    return Pedido(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      mesaId: mesaId ?? this.mesaId,
      meseroId: meseroId ?? this.meseroId,
      estado: estado ?? this.estado,
      observaciones: observaciones ?? this.observaciones,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      mesaNombre: mesaNombre ?? this.mesaNombre,
      meseroNombre: meseroNombre ?? this.meseroNombre,
    );
  }

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    mesaId,
    meseroId,
    estado,
    observaciones,
    total,
    createdAt,
    updatedAt,
  ];
}
