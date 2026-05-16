import 'dart:convert';

import 'package:restaurant_app/features/pagina_publica/domain/entities/public_config.dart';

/// Modelo de datos para SQLite.
class PublicConfigModel extends PublicConfig {
  const PublicConfigModel({
    required super.restaurantId,
    required super.slogan,
    required super.descripcion,
    required super.telefono,
    required super.whatsapp,
    required super.direccion,
    required super.horarios,
    required super.facebook,
    required super.instagram,
    required super.mostrarBotonMenu,
    required super.mostrarBotonReservas,
    required super.updatedAt,
    super.exp1Titulo,
    super.exp1Desc,
    super.exp2Titulo,
    super.exp2Desc,
    super.exp3Titulo,
    super.exp3Desc,
    super.tituloMenu,
    super.subtituloMenu,
    super.tituloReservas,
    super.subtituloReservas,
    super.mapUrl,
    super.mapLat,
    super.mapLng,
    super.logoUrl,
    super.nombreNegocio,
    super.propietario,
    super.emailContacto,
    super.emailSecundario,
    super.telefonoSecundario,
    super.cocinaModoAutomatico,
    super.cocinaTiempoAutoMinutos,
  });

  factory PublicConfigModel.fromEntity(PublicConfig e) => PublicConfigModel(
    restaurantId: e.restaurantId,
    slogan: e.slogan,
    descripcion: e.descripcion,
    telefono: e.telefono,
    whatsapp: e.whatsapp,
    direccion: e.direccion,
    horarios: e.horarios,
    facebook: e.facebook,
    instagram: e.instagram,
    mostrarBotonMenu: e.mostrarBotonMenu,
    mostrarBotonReservas: e.mostrarBotonReservas,
    updatedAt: e.updatedAt,
    exp1Titulo: e.exp1Titulo,
    exp1Desc: e.exp1Desc,
    exp2Titulo: e.exp2Titulo,
    exp2Desc: e.exp2Desc,
    exp3Titulo: e.exp3Titulo,
    exp3Desc: e.exp3Desc,
    tituloMenu: e.tituloMenu,
    subtituloMenu: e.subtituloMenu,
    tituloReservas: e.tituloReservas,
    subtituloReservas: e.subtituloReservas,
    mapUrl: e.mapUrl,
    mapLat: e.mapLat,
    mapLng: e.mapLng,
    logoUrl: e.logoUrl,
    nombreNegocio: e.nombreNegocio,
    propietario: e.propietario,
    emailContacto: e.emailContacto,
    emailSecundario: e.emailSecundario,
    telefonoSecundario: e.telefonoSecundario,
    cocinaModoAutomatico: e.cocinaModoAutomatico,
    cocinaTiempoAutoMinutos: e.cocinaTiempoAutoMinutos,
  );

  factory PublicConfigModel.fromMap(Map<String, dynamic> map) {
    List<HorarioEntry> horarios = [];
    try {
      final raw = map['horarios'] as String?;
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        horarios = decoded
            .map((e) => HorarioEntry.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return PublicConfigModel(
      restaurantId: map['restaurant_id'] as String,
      slogan: map['slogan'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      telefono: map['telefono'] as String? ?? '',
      whatsapp: map['whatsapp'] as String? ?? '',
      direccion: map['direccion'] as String? ?? '',
      horarios: horarios,
      facebook: map['facebook'] as String? ?? '',
      instagram: map['instagram'] as String? ?? '',
      mostrarBotonMenu: (map['mostrar_boton_menu'] as int? ?? 1) == 1,
      mostrarBotonReservas: (map['mostrar_boton_reservas'] as int? ?? 1) == 1,
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
      exp1Titulo: map['exp1_titulo'] as String? ?? 'Gastronomía Auténtica',
      exp1Desc:
          map['exp1_desc'] as String? ??
          'Recetas tradicionales elaboradas con ingredientes frescos de temporada.',
      exp2Titulo: map['exp2_titulo'] as String? ?? 'Ambiente Familiar',
      exp2Desc:
          map['exp2_desc'] as String? ??
          'Un espacio cálido y acogedor ideal para toda ocasión especial.',
      exp3Titulo: map['exp3_titulo'] as String? ?? 'Servicio Excepcional',
      exp3Desc:
          map['exp3_desc'] as String? ??
          'Atención personalizada que supera las expectativas de cada visita.',
      tituloMenu: map['titulo_menu'] as String? ?? 'Nuestro Menú',
      subtituloMenu:
          map['subtitulo_menu'] as String? ??
          'Platos elaborados con ingredientes frescos de temporada',
      tituloReservas: map['titulo_reservas'] as String? ?? 'Reserva tu Mesa',
      subtituloReservas:
          map['subtitulo_reservas'] as String? ??
          'Asegura tu lugar para una experiencia gastronómica especial',
      mapUrl:
          map['map_url'] as String? ??
          'https://maps.app.goo.gl/KL4cFAxBxDDKmgaS9',
      mapLat: (map['map_lat'] as num?)?.toDouble() ?? -2.9721229,
      mapLng: (map['map_lng'] as num?)?.toDouble() ?? -78.437791,
      logoUrl: map['logo_url'] as String? ?? '',
      nombreNegocio: map['nombre_negocio'] as String? ?? '',
      propietario: map['propietario'] as String? ?? '',
      emailContacto: map['email_contacto'] as String? ?? '',
      emailSecundario: map['email_secundario'] as String? ?? '',
      telefonoSecundario: map['telefono_secundario'] as String? ?? '',
      cocinaModoAutomatico: (map['cocina_modo_automatico'] as int? ?? 0) == 1,
      cocinaTiempoAutoMinutos:
          (map['cocina_tiempo_auto_minutos'] as int?) ?? 15,
    );
  }

  Map<String, dynamic> toMap() => {
    'restaurant_id': restaurantId,
    'slogan': slogan,
    'descripcion': descripcion,
    'telefono': telefono,
    'whatsapp': whatsapp,
    'direccion': direccion,
    'horarios': horariosJson,
    'facebook': facebook,
    'instagram': instagram,
    'mostrar_boton_menu': mostrarBotonMenu ? 1 : 0,
    'mostrar_boton_reservas': mostrarBotonReservas ? 1 : 0,
    'updated_at': updatedAt.toIso8601String(),
    'exp1_titulo': exp1Titulo,
    'exp1_desc': exp1Desc,
    'exp2_titulo': exp2Titulo,
    'exp2_desc': exp2Desc,
    'exp3_titulo': exp3Titulo,
    'exp3_desc': exp3Desc,
    'titulo_menu': tituloMenu,
    'subtitulo_menu': subtituloMenu,
    'titulo_reservas': tituloReservas,
    'subtitulo_reservas': subtituloReservas,
    'map_url': mapUrl,
    'map_lat': mapLat,
    'map_lng': mapLng,
    'logo_url': logoUrl,
    'nombre_negocio': nombreNegocio,
    'propietario': propietario,
    'email_contacto': emailContacto,
    'email_secundario': emailSecundario,
    'telefono_secundario': telefonoSecundario,
    'cocina_modo_automatico': cocinaModoAutomatico ? 1 : 0,
    'cocina_tiempo_auto_minutos': cocinaTiempoAutoMinutos,
  };
}
