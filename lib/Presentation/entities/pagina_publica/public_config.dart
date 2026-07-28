import 'dart:convert';

/// Entrada de horario de atención.
class HorarioEntry {
  final String dia;
  final String hora;

  const HorarioEntry({required this.dia, required this.hora});

  Map<String, dynamic> toMap() => {'dia': dia, 'hora': hora};

  factory HorarioEntry.fromMap(Map<String, dynamic> map) =>
      HorarioEntry(dia: map['dia'] as String, hora: map['hora'] as String);

  HorarioEntry copyWith({String? dia, String? hora}) =>
      HorarioEntry(dia: dia ?? this.dia, hora: hora ?? this.hora);
}

/// Configuración de la página pública visible para clientes.
///
/// El administrador la edita desde el panel interno; los cambios
/// se reflejan inmediatamente en la vista pública.
class PublicConfig {
  final String restaurantId;
  final String slogan;
  final String descripcion;
  final String telefono;
  final String whatsapp;
  final String direccion;
  final List<HorarioEntry> horarios;
  final String facebook;
  final String instagram;
  final bool mostrarBotonMenu;
  final bool mostrarBotonReservas;
  final DateTime updatedAt;

  // ── Tarjetas de experiencia (sección "Por qué elegirnos") ────────
  final String exp1Titulo;
  final String exp1Desc;
  final String exp2Titulo;
  final String exp2Desc;
  final String exp3Titulo;
  final String exp3Desc;

  // ── Textos de sección Menú ───────────────────────────────────────
  final String tituloMenu;
  final String subtituloMenu;

  // ── Textos de sección Reservaciones ─────────────────────────────
  final String tituloReservas;
  final String subtituloReservas;

  // ── Mapa de ubicación ───────────────────────────────────────────
  final String mapUrl;
  final double mapLat;
  final double mapLng;

  // ── Datos corporativos / institucionales ────────────────────────
  final String logoUrl;
  final String nombreNegocio;
  final String propietario;
  final String emailContacto;
  final String emailSecundario;
  final String telefonoSecundario;

  // ── Cocina ──────────────────────────────────────────────────────
  final bool cocinaModoAutomatico;
  final int cocinaTiempoAutoMinutos;

  const PublicConfig({
    required this.restaurantId,
    required this.slogan,
    required this.descripcion,
    required this.telefono,
    required this.whatsapp,
    required this.direccion,
    required this.horarios,
    required this.facebook,
    required this.instagram,
    required this.mostrarBotonMenu,
    required this.mostrarBotonReservas,
    required this.updatedAt,
    this.exp1Titulo = 'Gastronomía Auténtica',
    this.exp1Desc =
        'Recetas tradicionales elaboradas con ingredientes frescos de temporada.',
    this.exp2Titulo = 'Ambiente Familiar',
    this.exp2Desc =
        'Un espacio cálido y acogedor ideal para toda ocasión especial.',
    this.exp3Titulo = 'Servicio Excepcional',
    this.exp3Desc =
        'Atención personalizada que supera las expectativas de cada visita.',
    this.tituloMenu = 'Nuestro Menú',
    this.subtituloMenu =
        'Platos elaborados con ingredientes frescos de temporada',
    this.tituloReservas = 'Reserva tu Mesa',
    this.subtituloReservas =
        'Asegura tu lugar para una experiencia gastronómica especial',
    this.mapUrl = 'https://maps.app.goo.gl/KL4cFAxBxDDKmgaS9',
    this.mapLat = -2.9721229,
    this.mapLng = -78.437791,
    this.logoUrl = '',
    this.nombreNegocio = '',
    this.propietario = '',
    this.emailContacto = '',
    this.emailSecundario = '',
    this.telefonoSecundario = '',
    this.cocinaModoAutomatico = false,
    this.cocinaTiempoAutoMinutos = 15,
  });

  /// Config por defecto con los datos de La Peña.
  factory PublicConfig.defaults(String restaurantId) => PublicConfig(
    restaurantId: restaurantId,
    slogan: 'El sabor auténtico que te hace volver',
    descripcion:
        'Bienvenido a La Peña Bar & Restaurant, un espacio donde la buena '
        'comida, la música y el ambiente familiar se unen para brindarte una '
        'experiencia única. Disfruta de nuestra gastronomía elaborada con '
        'productos frescos y el cariño de nuestra cocina.',
    telefono: '099 464 5989',
    whatsapp: '0994645989',
    direccion: 'Limón Indanza, Morona Santiago, Ecuador',
    horarios: [
      HorarioEntry(dia: 'Lunes – Viernes', hora: '12:00 – 22:00'),
      HorarioEntry(dia: 'Sábado', hora: '12:00 – 24:00'),
      HorarioEntry(dia: 'Domingo', hora: '12:00 – 21:00'),
    ],
    facebook: 'https://www.facebook.com/profile.php?id=100089948505536',
    instagram: 'https://www.instagram.com/bar_house69/',
    mostrarBotonMenu: true,
    mostrarBotonReservas: true,
    updatedAt: DateTime(2026),
  );

  String get horariosJson =>
      jsonEncode(horarios.map((h) => h.toMap()).toList());

  PublicConfig copyWith({
    String? slogan,
    String? descripcion,
    String? telefono,
    String? whatsapp,
    String? direccion,
    List<HorarioEntry>? horarios,
    String? facebook,
    String? instagram,
    bool? mostrarBotonMenu,
    bool? mostrarBotonReservas,
    DateTime? updatedAt,
    String? exp1Titulo,
    String? exp1Desc,
    String? exp2Titulo,
    String? exp2Desc,
    String? exp3Titulo,
    String? exp3Desc,
    String? tituloMenu,
    String? subtituloMenu,
    String? tituloReservas,
    String? subtituloReservas,
    String? mapUrl,
    double? mapLat,
    double? mapLng,
    String? logoUrl,
    String? nombreNegocio,
    String? propietario,
    String? emailContacto,
    String? emailSecundario,
    String? telefonoSecundario,
    bool? cocinaModoAutomatico,
    int? cocinaTiempoAutoMinutos,
  }) => PublicConfig(
    restaurantId: restaurantId,
    slogan: slogan ?? this.slogan,
    descripcion: descripcion ?? this.descripcion,
    telefono: telefono ?? this.telefono,
    whatsapp: whatsapp ?? this.whatsapp,
    direccion: direccion ?? this.direccion,
    horarios: horarios ?? this.horarios,
    facebook: facebook ?? this.facebook,
    instagram: instagram ?? this.instagram,
    mostrarBotonMenu: mostrarBotonMenu ?? this.mostrarBotonMenu,
    mostrarBotonReservas: mostrarBotonReservas ?? this.mostrarBotonReservas,
    updatedAt: updatedAt ?? this.updatedAt,
    exp1Titulo: exp1Titulo ?? this.exp1Titulo,
    exp1Desc: exp1Desc ?? this.exp1Desc,
    exp2Titulo: exp2Titulo ?? this.exp2Titulo,
    exp2Desc: exp2Desc ?? this.exp2Desc,
    exp3Titulo: exp3Titulo ?? this.exp3Titulo,
    exp3Desc: exp3Desc ?? this.exp3Desc,
    tituloMenu: tituloMenu ?? this.tituloMenu,
    subtituloMenu: subtituloMenu ?? this.subtituloMenu,
    tituloReservas: tituloReservas ?? this.tituloReservas,
    subtituloReservas: subtituloReservas ?? this.subtituloReservas,
    mapUrl: mapUrl ?? this.mapUrl,
    mapLat: mapLat ?? this.mapLat,
    mapLng: mapLng ?? this.mapLng,
    logoUrl: logoUrl ?? this.logoUrl,
    nombreNegocio: nombreNegocio ?? this.nombreNegocio,
    propietario: propietario ?? this.propietario,
    emailContacto: emailContacto ?? this.emailContacto,
    emailSecundario: emailSecundario ?? this.emailSecundario,
    telefonoSecundario: telefonoSecundario ?? this.telefonoSecundario,
    cocinaModoAutomatico: cocinaModoAutomatico ?? this.cocinaModoAutomatico,
    cocinaTiempoAutoMinutos:
        cocinaTiempoAutoMinutos ?? this.cocinaTiempoAutoMinutos,
  );
}
