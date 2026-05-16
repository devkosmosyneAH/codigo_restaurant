import 'package:restaurant_app/features/clientes/domain/entities/cliente.dart';

/// Modelo de datos: Cliente.
///
/// Serialización SQLite para la entidad [Cliente].
class ClienteModel extends Cliente {
  const ClienteModel({
    super.idCliente,
    required super.cedula,
    required super.restaurantId,
    required super.nombre,
    super.apellido,
    super.telefono,
    super.email,
    super.direccion,
    super.fechaNacimiento,
    super.notas,
    super.estado,
    super.activo,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ClienteModel.fromMap(Map<String, dynamic> map) {
    final nombre =
        map['nombre'] as String? ?? (map['nombres'] as String? ?? '').trim();
    return ClienteModel(
      idCliente: (map['id_cliente'] as num?)?.toInt(),
      cedula: (map['cedula'] as String?) ?? '',
      restaurantId: map['restaurant_id'] as String,
      nombre: nombre,
      apellido: map['apellido'] as String?,
      telefono: map['telefono'] as String?,
      email: map['email'] as String?,
      direccion: map['direccion'] as String?,
      fechaNacimiento: map['fecha_nacimiento'] != null
          ? DateTime.tryParse(map['fecha_nacimiento'] as String)
          : null,
      notas: map['notas'] as String?,
      estado: (map['estado'] as int? ?? 1) == 1,
      activo: (map['activo'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    final nombres = apellido != null && apellido!.isNotEmpty
        ? '$nombre $apellido'
        : nombre;
    return {
      'id_cliente': idCliente,
      'cedula': cedula,
      'restaurant_id': restaurantId,
      'nombres': nombres,
      'nombre': nombre,
      'apellido': apellido,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
      'notas': notas,
      'estado': estado ? 1 : 0,
      'activo': activo ? 1 : 0,
      'fecha_registro': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ClienteModel.fromEntity(Cliente cliente) {
    return ClienteModel(
      idCliente: cliente.idCliente,
      cedula: cliente.cedula,
      restaurantId: cliente.restaurantId,
      nombre: cliente.nombre,
      apellido: cliente.apellido,
      telefono: cliente.telefono,
      email: cliente.email,
      direccion: cliente.direccion,
      fechaNacimiento: cliente.fechaNacimiento,
      notas: cliente.notas,
      estado: cliente.estado,
      activo: cliente.activo,
      createdAt: cliente.createdAt,
      updatedAt: cliente.updatedAt,
    );
  }
}
