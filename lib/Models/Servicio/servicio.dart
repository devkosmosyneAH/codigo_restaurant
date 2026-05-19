import 'dart:convert';

class Servicio {
  final String key;
  final String id;
  final String nombre;
  final String? descripcion;
  final List<int> precioEscalonado;
  final bool activo;

  Servicio({
    required this.key,
    required this.id,
    required this.nombre,
    this.descripcion,
    List<int>? precioEscalonado,
    this.activo = true,
  }) : precioEscalonado = precioEscalonado ?? const [];

  factory Servicio.fromMap(Map<String, dynamic> map) => Servicio(
    key: map['_key'],
    id: map['id'],
    nombre: map['nombre'],
    descripcion: map['descripcion'],
    precioEscalonado: (() {
      final raw = map['precioescalonado'];
      if (raw == null) return <int>[];
      if (raw is bool) return <int>[];
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            return List<int>.from(
              decoded.map(
                (e) => e is int ? e : int.tryParse(e.toString()) ?? 0,
              ),
            );
          }
        } catch (_) {}
        return <int>[];
      }
      return <int>[];
    })(),
    activo: map['activo'] == 1,
  );

  Map<String, dynamic> toMap() => {
    '_key': key,
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'precioescalonado': jsonEncode(precioEscalonado),
    'activo': activo ? 1 : 0,
  };
}
