/// Definición de todas las tablas de la base de datos.
///
/// Centraliza los scripts SQL de creación para facilitar
/// mantenimiento y migraciones futuras.
///
/// IMPORTANTE: Todas las tablas incluyen [restaurant_id]
/// para soportar multi-restaurante desde el inicio.
class DatabaseTables {
  DatabaseTables._();

  /// Script de creación de todas las tablas.
  static List<String> get createTableStatements => [
    _createRestaurantsTable,
    _createUsersTable,
    _createMesasTable,
    _createCategoriasTable,
    _createProductosTable,
    _createProductosPublicLookupIndex,
    _createDriveConnectionsTable,
    _createDriveConnectionsRestaurantUniqueIndex,
    _createVariantesTable,
    _createVariantesProductoLookupIndex,
    _createPedidosTable,
    _createPedidoItemsTable,
    _createVentasTable,
    _createVentaDetallesTable,
    _createLlamadosTable,
    _createCotizacionesTable,
    _createCotizacionItemsTable,
    _createReservasTable,
    _createIngredientesTable,
    _createProductoIngredientesTable,
    _createSyncLogTable,
    _createSyncAuditLogTable,
    _createSecurityAuditLogTable,
    _createSriSecuencialesTable,
    _createSriFiscalConfigsTable,
    _createSriCertificateRefsTable,
    _createSriComprobantesTable,
    _createSriAttemptsTable,
    _createSriEmailDeliveriesTable,
    _createSriComprobantesClaveIndex,
    _createSriComprobantesVentaIndex,
    _createSriComprobantesEstadoIndex,
    _createSriAttemptsRetryIndex,
    _createSriEmailDeliveriesEstadoIndex,
    _createPublicConfigTable,
    _createClientesTable,
    _createClientesTenantCedulaIndex,
    _createClientesSearchIndex,
    _createVentasClienteIdentificacionIndex,
    _createVentasIdentificacionClienteIndex,
    _createSyncLogPerformanceIndex,
    _createSyncAuditLogCreatedAtIndex,
    _createSyncAuditLogLookupIndex,
    _createSecurityAuditLogCreatedAtIndex,
    _createSecurityAuditLogEventIndex,
  ];

  // ── Restaurantes ───────────────────────────────────────────────────
  static const String _createRestaurantsTable = '''
    CREATE TABLE IF NOT EXISTS restaurantes (
      id TEXT PRIMARY KEY,
      nombre TEXT NOT NULL,
      direccion TEXT,
      telefono TEXT,
      logo_url TEXT,
      configuracion TEXT,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  // ── Usuarios ───────────────────────────────────────────────────────
  static const String _createUsersTable = '''
    CREATE TABLE IF NOT EXISTS usuarios (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      nombre TEXT NOT NULL,
      email TEXT,
      pin TEXT,
      rol TEXT NOT NULL,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id)
    )
  ''';

  // ── Mesas ──────────────────────────────────────────────────────────
  static const String _createMesasTable = '''
    CREATE TABLE IF NOT EXISTS mesas (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      numero INTEGER NOT NULL,
      nombre TEXT,
      capacidad INTEGER NOT NULL DEFAULT 4,
      estado TEXT NOT NULL DEFAULT 'libre',
      mesa_union_id TEXT,
      nombre_reserva TEXT,
      posicion_x REAL DEFAULT 0,
      posicion_y REAL DEFAULT 0,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id)
    )
  ''';

  // ── Categorías del Menú ────────────────────────────────────────────
  static const String _createCategoriasTable = '''
    CREATE TABLE IF NOT EXISTS categorias (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      nombre TEXT NOT NULL,
      descripcion TEXT,
      orden INTEGER NOT NULL DEFAULT 0,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id)
    )
  ''';

  // ── Productos ──────────────────────────────────────────────────────
  static const String _createProductosTable = '''
    CREATE TABLE IF NOT EXISTS productos (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      categoria_id TEXT NOT NULL,
      nombre TEXT NOT NULL,
      descripcion TEXT,
      precio REAL NOT NULL,
      imagen_url TEXT,
      drive_file_id TEXT,
      drive_public_url TEXT,
      imagen_local_cache_path TEXT,
      disponible INTEGER NOT NULL DEFAULT 1,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
      FOREIGN KEY (categoria_id) REFERENCES categorias(id)
    )
  ''';

  static const String _createProductosPublicLookupIndex = '''
    CREATE INDEX IF NOT EXISTS idx_productos_restaurant_public_lookup
    ON productos (restaurant_id, activo, disponible, categoria_id, nombre COLLATE NOCASE)
  ''';

  // ── Conexión Drive por Tenant ───────────────────────────────────
  static const String _createDriveConnectionsTable = '''
    CREATE TABLE IF NOT EXISTS drive_connections (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      folder_id TEXT NOT NULL,
      folder_name TEXT NOT NULL,
      owner_email TEXT,
      public_share_enabled INTEGER NOT NULL DEFAULT 0,
      created_by TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id)
    )
  ''';

  static const String _createDriveConnectionsRestaurantUniqueIndex = '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_drive_connections_restaurant
    ON drive_connections (restaurant_id)
  ''';

  // ── Variantes de Producto ──────────────────────────────────────────
  static const String _createVariantesTable = '''
    CREATE TABLE IF NOT EXISTS variantes (
      id TEXT PRIMARY KEY,
      producto_id TEXT NOT NULL,
      nombre TEXT NOT NULL,
      precio REAL NOT NULL,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (producto_id) REFERENCES productos(id)
    )
  ''';

  static const String _createVariantesProductoLookupIndex = '''
    CREATE INDEX IF NOT EXISTS idx_variantes_producto_activo_precio
    ON variantes (producto_id, activo, precio)
  ''';

  // ── Pedidos ────────────────────────────────────────────────────────
  static const String _createPedidosTable = '''
    CREATE TABLE IF NOT EXISTS pedidos (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      mesa_id TEXT,
      mesero_id TEXT,
      estado TEXT NOT NULL DEFAULT 'creado',
      observaciones TEXT,
      total REAL NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
      FOREIGN KEY (mesa_id) REFERENCES mesas(id),
      FOREIGN KEY (mesero_id) REFERENCES usuarios(id)
    )
  ''';

  // ── Items de Pedido ────────────────────────────────────────────────
  static const String _createPedidoItemsTable = '''
    CREATE TABLE IF NOT EXISTS pedido_items (
      id TEXT PRIMARY KEY,
      pedido_id TEXT NOT NULL,
      producto_id TEXT,
      variante_id TEXT,
      cantidad INTEGER NOT NULL DEFAULT 1,
      precio_unitario REAL NOT NULL,
      observaciones TEXT,
      estado TEXT NOT NULL DEFAULT 'creado',
      nombre_display TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (pedido_id) REFERENCES pedidos(id)
    )
  ''';

  // ── Ventas (Caja) ─────────────────────────────────────────────────
  static const String _createVentasTable = '''
    CREATE TABLE IF NOT EXISTS ventas (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      pedido_id TEXT,
      cajero_id TEXT,
      id_cliente INTEGER,
      tipo_cliente TEXT NOT NULL DEFAULT 'consumidor_final',
      identificacion_cliente TEXT,
      nombre_cliente TEXT,
      telefono_cliente TEXT,
      direccion_cliente TEXT,
      cliente_nombre TEXT,
      cliente_email TEXT,
      cliente_identificacion TEXT,
      metodo_pago TEXT NOT NULL,
      tipo_comprobante TEXT NOT NULL DEFAULT 'ticket',
      sri_estado TEXT NOT NULL DEFAULT 'no_aplica',
      subtotal REAL NOT NULL,
      impuestos REAL NOT NULL DEFAULT 0,
      total REAL NOT NULL,
      descripcion_pago TEXT,
      sri_clave_acceso TEXT,
      sri_mensaje TEXT,
      sri_comprobante_id TEXT,
      sri_numero_autorizacion TEXT,
      sri_fecha_autorizacion TEXT,
      sri_xml_hash TEXT,
      sri_ride_path TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      source_cotizacion_id TEXT,
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
      FOREIGN KEY (cajero_id) REFERENCES usuarios(id),
      FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
    )
  ''';

  // ── Detalle de Ventas ──────────────────────────────────────────────
  static const String _createVentaDetallesTable = '''
    CREATE TABLE IF NOT EXISTS venta_detalles (
      id TEXT PRIMARY KEY,
      venta_id TEXT NOT NULL,
      producto_id TEXT,
      variante_id TEXT,
      cantidad INTEGER NOT NULL,
      precio_unitario REAL NOT NULL,
      subtotal REAL NOT NULL,
      FOREIGN KEY (venta_id) REFERENCES ventas(id)
    )
  ''';

  // ── Llamados a Mesero ─────────────────────────────────────────────
  static const String _createLlamadosTable = '''
    CREATE TABLE IF NOT EXISTS llamados_mesero (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      mesa_id TEXT,
      estado TEXT NOT NULL DEFAULT 'pendiente',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      atendido_at TEXT,
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
      FOREIGN KEY (mesa_id) REFERENCES mesas(id)
    )
  ''';

  // ── Cotizaciones ─────────────────────────────────────────────────
  static const String _createCotizacionesTable = '''
    CREATE TABLE IF NOT EXISTS cotizaciones (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      mesa_id TEXT,
      id_cliente INTEGER,
      cliente_nombre TEXT NOT NULL,
      cliente_telefono TEXT NOT NULL,
      cliente_email TEXT NOT NULL,
      estado TEXT NOT NULL DEFAULT 'pendiente',
      reserva_local INTEGER NOT NULL DEFAULT 0,
      personas INTEGER,
      fecha_evento TEXT,
      comida_preferida TEXT,
      notas TEXT,
      cliente_empresa TEXT,
      cliente_direccion TEXT,
      hora_evento TEXT,
      lugar_evento TEXT,
      descuento REAL NOT NULL DEFAULT 0,
      tasa_impuesto REAL NOT NULL DEFAULT 0,
      origen TEXT NOT NULL DEFAULT 'publica',
      subtotal REAL NOT NULL,
      total REAL NOT NULL,
      hora_emision TEXT,
      firma_nombre TEXT,
      firma_cargo TEXT,
      firma_numero_documento TEXT,
      firma_es_imagen INTEGER NOT NULL DEFAULT 0,
      firma_imagen_bytes BLOB,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
      FOREIGN KEY (mesa_id) REFERENCES mesas(id),
      FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
    )
  ''';

  static const String _createCotizacionItemsTable = '''
    CREATE TABLE IF NOT EXISTS cotizacion_items (
      id TEXT PRIMARY KEY,
      cotizacion_id TEXT NOT NULL,
      producto_id TEXT,
      producto_nombre TEXT NOT NULL,
      descripcion TEXT,
      cantidad INTEGER NOT NULL,
      precio_unitario REAL NOT NULL,
      descuento_item REAL NOT NULL DEFAULT 0,
      subtotal REAL NOT NULL,
      FOREIGN KEY (cotizacion_id) REFERENCES cotizaciones(id)
    )
  ''';

  // ── Reservaciones ────────────────────────────────────────────────
  static const String _createReservasTable = '''
    CREATE TABLE IF NOT EXISTS reservaciones (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      tipo TEXT NOT NULL,
      mesa_id TEXT,
      id_cliente INTEGER,
      cotizacion_id TEXT UNIQUE,
      fecha TEXT NOT NULL,
      hora_inicio TEXT NOT NULL DEFAULT '19:00',
      hora_fin TEXT NOT NULL DEFAULT '20:30',
      numero_personas INTEGER NOT NULL DEFAULT 2,
      estado TEXT NOT NULL DEFAULT 'pendiente',
      tipo_evento TEXT,
      cliente_nombre TEXT NOT NULL,
      cliente_telefono TEXT NOT NULL,
      cliente_email TEXT NOT NULL,
      notas TEXT,
      requerimientos TEXT,
      nombre_local_evento TEXT,
      manteles TEXT,
      color_manteleria TEXT,
      precio_estimado REAL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
      FOREIGN KEY (mesa_id) REFERENCES mesas(id),
      FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
      FOREIGN KEY (cotizacion_id) REFERENCES cotizaciones(id)
    )
  ''';

  // ── Ingredientes (Inventario Opcional) ─────────────────────────────
  static const String _createIngredientesTable = '''
    CREATE TABLE IF NOT EXISTS ingredientes (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      nombre TEXT NOT NULL,
      unidad_medida TEXT NOT NULL,
      stock_actual REAL NOT NULL DEFAULT 0,
      stock_minimo REAL NOT NULL DEFAULT 0,
      costo_unitario REAL DEFAULT 0,
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id)
    )
  ''';

  // ── Relación Producto-Ingrediente ──────────────────────────────────
  static const String _createProductoIngredientesTable = '''
    CREATE TABLE IF NOT EXISTS producto_ingredientes (
      id TEXT PRIMARY KEY,
      producto_id TEXT NOT NULL,
      ingrediente_id TEXT NOT NULL,
      cantidad_requerida REAL NOT NULL,
      FOREIGN KEY (producto_id) REFERENCES productos(id),
      FOREIGN KEY (ingrediente_id) REFERENCES ingredientes(id)
    )
  ''';

  // ── Secuenciales SRI ──────────────────────────────────────────────
  static const String _createSriSecuencialesTable = '''
    CREATE TABLE IF NOT EXISTS sri_secuenciales (
      id TEXT NOT NULL,
      restaurant_id TEXT NOT NULL,
      ultimo_secuencial INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (id, restaurant_id)
    )
  ''';

  // ── Configuración y comprobantes SRI ─────────────────────────────
  static const String _createSriFiscalConfigsTable = '''
    CREATE TABLE IF NOT EXISTS sri_fiscal_configs (
      restaurant_id TEXT PRIMARY KEY,
      ruc TEXT NOT NULL DEFAULT '',
      razon_social TEXT NOT NULL DEFAULT '',
      nombre_comercial TEXT NOT NULL DEFAULT '',
      direccion_matriz TEXT NOT NULL DEFAULT '',
      obligado_contabilidad INTEGER NOT NULL DEFAULT 0,
      regimen TEXT NOT NULL DEFAULT '',
      contribuyente_especial TEXT NOT NULL DEFAULT '',
      establecimiento TEXT NOT NULL DEFAULT '001',
      punto_emision TEXT NOT NULL DEFAULT '001',
      autorizacion_sri TEXT NOT NULL DEFAULT '',
      ambiente TEXT NOT NULL DEFAULT 'pruebas',
      endpoint_backend TEXT NOT NULL DEFAULT '',
      activo INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id)
    )
  ''';

  static const String _createSriCertificateRefsTable = '''
    CREATE TABLE IF NOT EXISTS sri_certificate_refs (
      restaurant_id TEXT PRIMARY KEY,
      certificate_id_backend TEXT NOT NULL DEFAULT '',
      subject TEXT NOT NULL DEFAULT '',
      issuer TEXT NOT NULL DEFAULT '',
      serial TEXT NOT NULL DEFAULT '',
      valid_from TEXT,
      valid_to TEXT,
      fingerprint_sha256 TEXT NOT NULL DEFAULT '',
      encrypted_at TEXT,
      status TEXT NOT NULL DEFAULT 'no_cargado',
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id)
    )
  ''';

  static const String _createSriComprobantesTable = '''
    CREATE TABLE IF NOT EXISTS sri_comprobantes (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      venta_id TEXT,
      tipo TEXT NOT NULL,
      ambiente TEXT NOT NULL DEFAULT 'pruebas',
      clave_acceso TEXT NOT NULL DEFAULT '',
      secuencial TEXT NOT NULL DEFAULT '',
      xml_local_hash TEXT,
      xml_firmado_hash TEXT,
      estado TEXT NOT NULL DEFAULT 'pendiente_envio',
      numero_autorizacion TEXT,
      fecha_autorizacion TEXT,
      mensaje TEXT,
      ride_path TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
      FOREIGN KEY (venta_id) REFERENCES ventas(id)
    )
  ''';

  static const String _createSriAttemptsTable = '''
    CREATE TABLE IF NOT EXISTS sri_attempts (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      comprobante_id TEXT NOT NULL,
      tipo_operacion TEXT NOT NULL,
      request_id TEXT,
      estado TEXT NOT NULL,
      http_status INTEGER,
      sri_estado TEXT,
      mensaje TEXT,
      retry_count INTEGER NOT NULL DEFAULT 0,
      next_retry_at TEXT,
      payload_hash TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
      FOREIGN KEY (comprobante_id) REFERENCES sri_comprobantes(id)
    )
  ''';

  static const String _createSriEmailDeliveriesTable = '''
    CREATE TABLE IF NOT EXISTS sri_email_deliveries (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      comprobante_id TEXT NOT NULL,
      email TEXT NOT NULL,
      estado TEXT NOT NULL DEFAULT 'pendiente',
      mensaje TEXT,
      sent_at TEXT,
      retry_count INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
      FOREIGN KEY (comprobante_id) REFERENCES sri_comprobantes(id)
    )
  ''';

  static const String _createSriComprobantesClaveIndex = '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_sri_comprobantes_clave
    ON sri_comprobantes (restaurant_id, clave_acceso)
    WHERE clave_acceso != ''
  ''';

  static const String _createSriComprobantesVentaIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sri_comprobantes_venta
    ON sri_comprobantes (restaurant_id, venta_id)
  ''';

  static const String _createSriComprobantesEstadoIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sri_comprobantes_estado
    ON sri_comprobantes (restaurant_id, estado)
  ''';

  static const String _createSriAttemptsRetryIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sri_attempts_retry
    ON sri_attempts (restaurant_id, next_retry_at, retry_count)
  ''';

  static const String _createSriEmailDeliveriesEstadoIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sri_email_deliveries_estado
    ON sri_email_deliveries (restaurant_id, estado)
  ''';

  // ── Configuración de Página Pública ─────────────────────────────────
  static const String _createPublicConfigTable = '''
    CREATE TABLE IF NOT EXISTS public_config (
      restaurant_id TEXT PRIMARY KEY,
      slogan TEXT NOT NULL DEFAULT '',
      descripcion TEXT NOT NULL DEFAULT '',
      telefono TEXT NOT NULL DEFAULT '',
      whatsapp TEXT NOT NULL DEFAULT '',
      direccion TEXT NOT NULL DEFAULT '',
      horarios TEXT NOT NULL DEFAULT '[]',
      facebook TEXT NOT NULL DEFAULT '',
      instagram TEXT NOT NULL DEFAULT '',
      mostrar_boton_menu INTEGER NOT NULL DEFAULT 1,
      mostrar_boton_reservas INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      exp1_titulo TEXT NOT NULL DEFAULT 'Gastronomía Auténtica',
      exp1_desc TEXT NOT NULL DEFAULT 'Recetas tradicionales elaboradas con ingredientes frescos de temporada.',
      exp2_titulo TEXT NOT NULL DEFAULT 'Ambiente Familiar',
      exp2_desc TEXT NOT NULL DEFAULT 'Un espacio cálido y acogedor ideal para toda ocasión especial.',
      exp3_titulo TEXT NOT NULL DEFAULT 'Servicio Excepcional',
      exp3_desc TEXT NOT NULL DEFAULT 'Atención personalizada que supera las expectativas de cada visita.',
      titulo_menu TEXT NOT NULL DEFAULT 'Nuestro Menú',
      subtitulo_menu TEXT NOT NULL DEFAULT 'Platos elaborados con ingredientes frescos de temporada',
      titulo_reservas TEXT NOT NULL DEFAULT 'Reserva tu Mesa',
      subtitulo_reservas TEXT NOT NULL DEFAULT 'Asegura tu lugar para una experiencia gastronómica especial',
      map_url TEXT NOT NULL DEFAULT 'https://maps.app.goo.gl/KL4cFAxBxDDKmgaS9',
      map_lat REAL NOT NULL DEFAULT -2.9721229,
      map_lng REAL NOT NULL DEFAULT -78.437791,
      nombre_negocio TEXT NOT NULL DEFAULT '',
      propietario TEXT NOT NULL DEFAULT '',
      email_contacto TEXT NOT NULL DEFAULT '',
      email_secundario TEXT NOT NULL DEFAULT '',
      telefono_secundario TEXT NOT NULL DEFAULT '',
      logo_url TEXT NOT NULL DEFAULT '',
      cocina_modo_automatico INTEGER NOT NULL DEFAULT 0,
      cocina_tiempo_auto_minutos INTEGER NOT NULL DEFAULT 15
    )
  ''';

  // ── Clientes ──────────────────────────────────────────────────────
  static const String _createClientesTable = '''
    CREATE TABLE IF NOT EXISTS clientes (
      id_cliente INTEGER PRIMARY KEY AUTOINCREMENT,
      cedula TEXT NOT NULL,
      restaurant_id TEXT NOT NULL,
      nombres TEXT NOT NULL,
      nombre TEXT NOT NULL,
      apellido TEXT,
      telefono TEXT,
      direccion TEXT,
      email TEXT,
      fecha_nacimiento TEXT,
      notas TEXT,
      estado INTEGER NOT NULL DEFAULT 1,
      activo INTEGER NOT NULL DEFAULT 1,
      fecha_registro TEXT NOT NULL DEFAULT (datetime('now')),
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id)
    )
  ''';

  static const String _createClientesTenantCedulaIndex = '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_clientes_restaurant_cedula
    ON clientes (restaurant_id, cedula)
  ''';

  static const String _createClientesSearchIndex = '''
    CREATE INDEX IF NOT EXISTS idx_clientes_restaurant_estado_nombres
    ON clientes (restaurant_id, activo, estado, nombres COLLATE NOCASE)
  ''';

  static const String _createVentasClienteIdentificacionIndex = '''
    CREATE INDEX IF NOT EXISTS idx_ventas_restaurant_cliente_identificacion
    ON ventas (restaurant_id, cliente_identificacion)
  ''';

  static const String _createVentasIdentificacionClienteIndex = '''
    CREATE INDEX IF NOT EXISTS idx_ventas_restaurant_identificacion_cliente
    ON ventas (restaurant_id, identificacion_cliente)
  ''';

  // ── Log de Sincronización ──────────────────────────────────────────
  static const String _createSyncLogTable = '''
    CREATE TABLE IF NOT EXISTS sync_log (
      id TEXT PRIMARY KEY,
      tabla TEXT NOT NULL,
      registro_id TEXT NOT NULL,
      operacion TEXT NOT NULL,
      datos TEXT,
      sincronizado INTEGER NOT NULL DEFAULT 0,
      intentos INTEGER NOT NULL DEFAULT 0,
      restaurant_id TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const String _createSyncLogPerformanceIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sync_log_pending_lookup
    ON sync_log (sincronizado, tabla, intentos, created_at)
  ''';

  static const String _createSyncAuditLogTable = '''
    CREATE TABLE IF NOT EXISTS sync_audit_log (
      id TEXT PRIMARY KEY,
      sync_record_id TEXT,
      direction TEXT NOT NULL,
      status TEXT NOT NULL,
      tabla TEXT NOT NULL,
      registro_id TEXT NOT NULL,
      restaurant_id TEXT NOT NULL,
      detail TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const String _createSyncAuditLogCreatedAtIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sync_audit_log_created_at
    ON sync_audit_log (created_at)
  ''';

  static const String _createSyncAuditLogLookupIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sync_audit_log_lookup
    ON sync_audit_log (direction, status, tabla, restaurant_id, created_at)
  ''';

  static const String _createSecurityAuditLogTable = '''
    CREATE TABLE IF NOT EXISTS security_audit_log (
      id TEXT PRIMARY KEY,
      event_type TEXT NOT NULL,
      user_id TEXT,
      restaurant_id TEXT,
      detail TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const String _createSecurityAuditLogCreatedAtIndex = '''
    CREATE INDEX IF NOT EXISTS idx_security_audit_log_created_at
    ON security_audit_log (created_at)
  ''';

  static const String _createSecurityAuditLogEventIndex = '''
    CREATE INDEX IF NOT EXISTS idx_security_audit_log_event
    ON security_audit_log (event_type, created_at)
  ''';
}
