import 'package:equatable/equatable.dart';

/// Entidad de dominio: Cliente.
///
/// La cédula (o RUC) actúa como identificador único (PK) del cliente.
/// Formato válido: 10 dígitos (cédula EC) o 13 dígitos (RUC EC).
class Cliente extends Equatable {
  final int? idCliente;

  /// Cédula o RUC — clave primaria, única e inmutable.
  final String cedula;
  final String restaurantId;
  final String nombre;
  final String? apellido;
  final String? telefono;
  final String? email;
  final String? direccion;
  final DateTime? fechaNacimiento;
  final String? notas;
  final bool estado;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Cliente({
    this.idCliente,
    required this.cedula,
    required this.restaurantId,
    required this.nombre,
    this.apellido,
    this.telefono,
    this.email,
    this.direccion,
    this.fechaNacimiento,
    this.notas,
    this.estado = true,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Nombre completo (nombre + apellido).
  String get nombreCompleto =>
      apellido != null && apellido!.isNotEmpty ? '$nombre $apellido' : nombre;

  /// Iniciales para avatar (hasta 2 caracteres).
  String get iniciales {
    final parts = nombreCompleto.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// Valida si la cédula tiene el formato ecuatoriano correcto.
  /// Acepta 10 dígitos (cédula) o 13 dígitos (RUC).
  static bool esCedulaValida(String cedula) {
    final clean = cedula.trim();
    if (clean.length != 10 && clean.length != 13) return false;
    if (!RegExp(r'^\d+$').hasMatch(clean)) return false;
    // Validar dígito verificador para cédula de 10 dígitos
    if (clean.length == 10) return _verificarCedula(clean);
    // RUC: primeros 10 dígitos pasan la validación de cédula
    return _verificarCedula(clean.substring(0, 10));
  }

  static bool _verificarCedula(String cedula) {
    final prov = int.parse(cedula.substring(0, 2));
    if (prov < 1 || prov > 24) return false;
    const coeficientes = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    int suma = 0;
    for (int i = 0; i < 9; i++) {
      int val = int.parse(cedula[i]) * coeficientes[i];
      if (val >= 10) val -= 9;
      suma += val;
    }
    final verificador = int.parse(cedula[9]);
    final residuo = suma % 10;
    return residuo == 0 ? verificador == 0 : (10 - residuo) == verificador;
  }

  Cliente copyWith({
    int? idCliente,
    String? cedula,
    String? restaurantId,
    String? nombre,
    String? apellido,
    String? telefono,
    String? email,
    String? direccion,
    DateTime? fechaNacimiento,
    String? notas,
    bool? estado,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Cliente(
      idCliente: idCliente ?? this.idCliente,
      cedula: cedula ?? this.cedula,
      restaurantId: restaurantId ?? this.restaurantId,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      direccion: direccion ?? this.direccion,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      notas: notas ?? this.notas,
      estado: estado ?? this.estado,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    idCliente,
    cedula,
    restaurantId,
    nombre,
    apellido,
    telefono,
    email,
    direccion,
    fechaNacimiento,
    notas,
    estado,
    activo,
    createdAt,
    updatedAt,
  ];
}
