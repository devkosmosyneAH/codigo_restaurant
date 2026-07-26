// Enumeraciones del dominio del sistema.
//
// Centralizan los estados y tipos posibles para mantener
// type-safety en toda la aplicación.

// ── Estados de Mesa ──────────────────────────────────────────────────

/// Estados posibles de una mesa.
enum EstadoMesa {
  libre('libre', 'Libre'),
  ocupada('ocupada', 'Ocupada'),
  reservada('reservada', 'Reservada');

  final String value;
  final String label;

  const EstadoMesa(this.value, this.label);

  /// Convierte un string de la BD a enum.
  static EstadoMesa fromString(String value) {
    return EstadoMesa.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EstadoMesa.libre,
    );
  }
}

// ── Estados de Pedido ────────────────────────────────────────────────

/// Estados posibles de un pedido.
///
/// Flujo: pendiente_aprobacion → creado → aceptado → en_preparacion → finalizado → entregado
enum EstadoPedido {
  pendienteAprobacion('pendiente_aprobacion', 'Pendiente aprobación'),
  creado('creado', 'Creado'),
  aceptado('aceptado', 'Aceptado'),
  enPreparacion('en_preparacion', 'En Preparación'),
  finalizado('finalizado', 'Finalizado'),
  entregado('entregado', 'Entregado');

  final String value;
  final String label;

  const EstadoPedido(this.value, this.label);

  static EstadoPedido fromString(String value) {
    return EstadoPedido.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EstadoPedido.creado,
    );
  }

  /// Verifica si el pedido puede ser editado.
  bool get esEditable =>
      this == EstadoPedido.pendienteAprobacion ||
      this == EstadoPedido.creado ||
      this == EstadoPedido.aceptado;

  /// Verifica si se pueden agregar items al pedido
  /// (aplica mientras no haya sido cobrado/entregado).
  bool get puedeAgregarItems => this != EstadoPedido.entregado;

  /// Verifica si el pedido está activo (no entregado).
  bool get esActivo => this != EstadoPedido.entregado;
}

// ── Métodos de Pago ──────────────────────────────────────────────────

/// Métodos de pago soportados.
enum MetodoPago {
  efectivo('efectivo', 'Efectivo'),
  tarjeta('tarjeta', 'Tarjeta'),
  transferencia('transferencia', 'Transferencia');

  final String value;
  final String label;

  const MetodoPago(this.value, this.label);

  static MetodoPago fromString(String value) {
    return MetodoPago.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MetodoPago.efectivo,
    );
  }
}

/// Tipo de comprobante generado al cobrar.
enum TipoComprobante {
  ticket('ticket', 'Ticket'),
  factura('factura', 'Factura'),
  notaCredito('nota_credito', 'Nota de crédito');

  final String value;
  final String label;

  const TipoComprobante(this.value, this.label);

  static TipoComprobante fromString(String value) {
    return TipoComprobante.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TipoComprobante.ticket,
    );
  }
}

/// Estado interno del flujo SRI para una venta/factura.
enum EstadoComprobanteSri {
  noAplica('no_aplica', 'No aplica'),
  preparado('preparado', 'Listo para SRI'),
  noConfigurado('no_configurado', 'Sin configurar'),
  pendienteEnvio('pendiente_envio', 'Pendiente de envío'),
  enviado('enviado', 'Enviado'),
  recibido('recibido', 'Recibido'),
  devuelto('devuelto', 'Devuelto'),
  autorizado('autorizado', 'Autorizado'),
  noAutorizado('no_autorizado', 'No autorizado'),
  rechazado('rechazado', 'Rechazado'),
  pendienteReintento('pendiente_reintento', 'Pendiente de reintento'),
  anulado('anulado', 'Anulado'),
  error('error', 'Con incidencia');

  final String value;
  final String label;

  const EstadoComprobanteSri(this.value, this.label);

  static EstadoComprobanteSri fromString(String value) {
    return EstadoComprobanteSri.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EstadoComprobanteSri.noAplica,
    );
  }
}

// ── Roles de Usuario ─────────────────────────────────────────────────

/// Roles del sistema con permisos diferenciados.
enum RolUsuario {
  administrador('administrador', 'Administrador'),
  cajero('cajero', 'Cajero'),
  mesero('mesero', 'Mesero'),
  cocina('cocina', 'Cocina');

  final String value;
  final String label;

  const RolUsuario(this.value, this.label);

  static RolUsuario fromString(String value) {
    return RolUsuario.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RolUsuario.mesero,
    );
  }

  /// El administrador tiene acceso total.
  bool get esAdmin => this == RolUsuario.administrador;

  /// Puede acceder al dashboard principal.
  bool get puedeVerInicio => this != RolUsuario.cocina;

  /// Puede gestionar mesas (admin y mesero).
  bool get puedeGestionarMesas =>
      this == RolUsuario.administrador || this == RolUsuario.mesero;

  /// Puede ver y operar cocina (admin y cocina).
  bool get puedeGestionarCocina =>
      this == RolUsuario.administrador || this == RolUsuario.cocina;

  /// Puede gestionar el menú del sistema.
  bool get puedeGestionarMenu => esAdmin;

  /// Puede gestionar reservas.
  bool get puedeGestionarReservas => esAdmin;

  /// Puede gestionar cotizaciones.
  bool get puedeGestionarCotizaciones => esAdmin;

  /// Puede ver reportes (admin y cajero).
  bool get puedeVerReportes =>
      this == RolUsuario.administrador || this == RolUsuario.cajero;

  /// Puede ver información financiera y de ventas.
  bool get puedeVerResumenFinanciero => puedeVerReportes;

  /// Puede gestionar pedidos (admin, mesero y cajero).
  bool get puedeGestionarPedidos => this != RolUsuario.cocina;

  /// Puede gestionar caja (admin y cajero).
  bool get puedeGestionarCaja =>
      this == RolUsuario.administrador || this == RolUsuario.cajero;

  /// Puede administrar usuarios.
  bool get puedeGestionarUsuarios => esAdmin;

  /// Puede gestionar el directorio de clientes.
  bool get puedeGestionarClientes =>
      this == RolUsuario.administrador || this == RolUsuario.cajero;

  /// Puede operar sincronización y tareas sensibles.
  bool get puedeSincronizar => esAdmin;
}

// ── Operaciones de Sincronización ────────────────────────────────────

/// Tipo de operación para el log de sincronización.
enum OperacionSync {
  insert('insert'),
  update('update'),
  delete('delete');

  final String value;

  const OperacionSync(this.value);

  static OperacionSync fromString(String value) {
    return OperacionSync.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OperacionSync.insert,
    );
  }
}

// ── Llamados a Mesero ───────────────────────────────────────────────

/// Estado de un llamado a mesero.
enum EstadoLlamado {
  pendiente('pendiente', 'Pendiente'),
  atendido('atendido', 'Atendido');

  final String value;
  final String label;

  const EstadoLlamado(this.value, this.label);

  static EstadoLlamado fromString(String value) {
    return EstadoLlamado.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EstadoLlamado.pendiente,
    );
  }
}

// ── Reservaciones ───────────────────────────────────────────────────

/// Tipo de reservacion.
enum TipoReserva {
  mesa('mesa', 'Mesa'),
  local('local', 'Evento privado');

  final String value;
  final String label;

  const TipoReserva(this.value, this.label);

  static TipoReserva fromString(String value) {
    return TipoReserva.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TipoReserva.mesa,
    );
  }
}

/// Estado de una reservación.
enum EstadoReserva {
  pendiente('pendiente', 'Pendiente'),
  confirmada('confirmada', 'Confirmada'),
  cancelada('cancelada', 'Cancelada'),
  completada('completada', 'Completada'),
  noAsistio('no_asistio', 'No asistió');

  final String value;
  final String label;

  const EstadoReserva(this.value, this.label);

  static EstadoReserva fromString(String value) {
    return EstadoReserva.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EstadoReserva.pendiente,
    );
  }
}

/// Tipos simples de evento para reserva del local completo.
enum TipoEvento {
  cumpleanos('cumpleanos', 'Cumpleaños'),
  reunion('reunion', 'Reunión'),
  corporativo('corporativo', 'Corporativo'),
  privado('privado', 'Privado'),
  otro('otro', 'Otro');

  final String value;
  final String label;

  const TipoEvento(this.value, this.label);

  static TipoEvento fromString(String value) {
    return TipoEvento.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TipoEvento.otro,
    );
  }
}
