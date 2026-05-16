import 'package:equatable/equatable.dart';
import 'package:restaurant_app/core/domain/enums.dart';

/// Entidad de dominio: Item de un pedido.
///
/// Representa un producto individual dentro de un pedido,
/// con su cantidad, precio y observaciones.
class PedidoItem extends Equatable {
  final String id;
  final String pedidoId;
  final String productoId;
  final String? varianteId;
  final int cantidad;
  final double precioUnitario;
  final String? observaciones;
  final EstadoPedido estado;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Nombre del producto (cargado opcionalmente para display).
  final String? productoNombre;

  /// Nombre de la variante (cargado opcionalmente para display).
  final String? varianteNombre;

  const PedidoItem({
    required this.id,
    required this.pedidoId,
    required this.productoId,
    this.varianteId,
    this.cantidad = 1,
    required this.precioUnitario,
    this.observaciones,
    this.estado = EstadoPedido.creado,
    required this.createdAt,
    required this.updatedAt,
    this.productoNombre,
    this.varianteNombre,
  });

  /// Subtotal del item (precio × cantidad).
  double get subtotal => precioUnitario * cantidad;

  /// Si el item puede ser editado (solo en estados creado/aceptado).
  bool get esEditable => estado.esEditable;

  PedidoItem copyWith({
    String? id,
    String? pedidoId,
    String? productoId,
    String? varianteId,
    int? cantidad,
    double? precioUnitario,
    String? observaciones,
    EstadoPedido? estado,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? productoNombre,
    String? varianteNombre,
  }) {
    return PedidoItem(
      id: id ?? this.id,
      pedidoId: pedidoId ?? this.pedidoId,
      productoId: productoId ?? this.productoId,
      varianteId: varianteId ?? this.varianteId,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      observaciones: observaciones ?? this.observaciones,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      productoNombre: productoNombre ?? this.productoNombre,
      varianteNombre: varianteNombre ?? this.varianteNombre,
    );
  }

  @override
  List<Object?> get props => [
    id,
    pedidoId,
    productoId,
    varianteId,
    cantidad,
    precioUnitario,
    observaciones,
    estado,
    createdAt,
    updatedAt,
  ];
}
