import 'package:restaurant_app/features/inventario/domain/entities/producto_ingrediente.dart';

/// Modelo de datos: ProductoIngrediente.
///
/// Serialización SQLite para la entidad [ProductoIngrediente].
class ProductoIngredienteModel extends ProductoIngrediente {
  const ProductoIngredienteModel({
    required super.id,
    required super.productoId,
    required super.ingredienteId,
    required super.cantidadRequerida,
    super.ingredienteNombre,
    super.unidadMedida,
  });

  factory ProductoIngredienteModel.fromMap(Map<String, dynamic> map) {
    return ProductoIngredienteModel(
      id: map['id'] as String,
      productoId: map['producto_id'] as String,
      ingredienteId: map['ingrediente_id'] as String,
      cantidadRequerida: (map['cantidad_requerida'] as num).toDouble(),
      ingredienteNombre: map['ingrediente_nombre'] as String?,
      unidadMedida: map['unidad_medida'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': productoId,
      'ingrediente_id': ingredienteId,
      'cantidad_requerida': cantidadRequerida,
    };
  }

  factory ProductoIngredienteModel.fromEntity(ProductoIngrediente entity) {
    return ProductoIngredienteModel(
      id: entity.id,
      productoId: entity.productoId,
      ingredienteId: entity.ingredienteId,
      cantidadRequerida: entity.cantidadRequerida,
      ingredienteNombre: entity.ingredienteNombre,
      unidadMedida: entity.unidadMedida,
    );
  }
}
