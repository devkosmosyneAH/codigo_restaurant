import 'package:restaurant_app/features/inventario/domain/entities/ingrediente.dart';

/// Modelo de datos: Ingrediente.
///
/// Serialización SQLite para la entidad [Ingrediente].
class IngredienteModel extends Ingrediente {
  const IngredienteModel({
    required super.id,
    required super.restaurantId,
    required super.nombre,
    required super.unidadMedida,
    super.stockActual,
    super.stockMinimo,
    super.costoUnitario,
    super.activo,
    required super.createdAt,
    required super.updatedAt,
  });

  factory IngredienteModel.fromMap(Map<String, dynamic> map) {
    return IngredienteModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      nombre: map['nombre'] as String,
      unidadMedida: map['unidad_medida'] as String,
      stockActual: (map['stock_actual'] as num?)?.toDouble() ?? 0,
      stockMinimo: (map['stock_minimo'] as num?)?.toDouble() ?? 0,
      costoUnitario: (map['costo_unitario'] as num?)?.toDouble() ?? 0,
      activo: (map['activo'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'nombre': nombre,
      'unidad_medida': unidadMedida,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'costo_unitario': costoUnitario,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory IngredienteModel.fromEntity(Ingrediente entity) {
    return IngredienteModel(
      id: entity.id,
      restaurantId: entity.restaurantId,
      nombre: entity.nombre,
      unidadMedida: entity.unidadMedida,
      stockActual: entity.stockActual,
      stockMinimo: entity.stockMinimo,
      costoUnitario: entity.costoUnitario,
      activo: entity.activo,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
