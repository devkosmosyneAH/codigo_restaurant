import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/database/database_tables.dart';
import 'package:restaurant_app/core/utils/pin_hasher.dart';
import 'package:restaurant_app/services/database_location_service.dart';

/// Helper singleton para gestionar la base de datos SQLite.
///
/// Implementa patrón Singleton para garantizar una única instancia
/// de la conexión a la base de datos en toda la aplicación.
///
/// Usa [sqflite_common_ffi_web] para soporte web.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  /// Obtiene la instancia de la base de datos.
  /// Si no existe, la crea e inicializa las tablas.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa la base de datos SQLite.
  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      final webFactory = databaseFactoryFfiWeb;
      return await webFactory.openDatabase(
        AppConstants.databaseName,
        options: OpenDatabaseOptions(
          version: AppConstants.databaseVersion,
          onCreate: _onCreate,
          onUpgrade: applyMigrations,
          onOpen: _onOpen,
        ),
      );
    }

    final dbPath = await DatabaseLocationService.getDatabasePath();

    return await openDatabase(
      dbPath,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: applyMigrations,
      onOpen: _onOpen,
    );
  }

  /// Crea todas las tablas en la primera ejecución.
  Future<void> _onCreate(Database db, int version) async {
    for (final statement in DatabaseTables.createTableStatements) {
      await db.execute(statement);
    }

    final now = DateTime.now().toIso8601String();

    // ── Restaurante La Peña ──────────────────────────────────────
    await db.insert('restaurantes', {
      'id': AppConstants.defaultRestaurantId,
      'nombre': AppConstants.appFullName,
      'activo': 1,
      'created_at': now,
      'updated_at': now,
    });

    // ── 10 Mesas ─────────────────────────────────────────────────
    for (int i = 1; i <= 10; i++) {
      await db.insert('mesas', {
        'id': 'mesa_la_pena_${i.toString().padLeft(2, '0')}',
        'restaurant_id': AppConstants.defaultRestaurantId,
        'numero': i,
        'nombre': 'Mesa $i',
        'capacidad': 4,
        'estado': 'libre',
        'posicion_x': 0.0,
        'posicion_y': 0.0,
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      });
    }

    // ── 6 Categorías del Menú ────────────────────────────────────
    final categorias = [
      ('cat_lp_01', 'Entradas', 'Aperitivos y entradas de la casa', 1),
      ('cat_lp_02', 'Platos Principales', 'Especialidades del chef', 2),
      ('cat_lp_03', 'Acompañamientos', 'Guarniciones y acompañamientos', 3),
      ('cat_lp_04', 'Comidas Ligeras', 'Snacks y bocadillos', 4),
      ('cat_lp_05', 'Bebidas', 'Colas, cervezas y bebidas frías', 5),
      (
        'cat_lp_06',
        'Jugos y Refrescos',
        'Jugos naturales y bebidas especiales',
        6,
      ),
    ];

    for (final (id, nombre, descripcion, orden) in categorias) {
      await db.insert('categorias', {
        'id': id,
        'restaurant_id': AppConstants.defaultRestaurantId,
        'nombre': nombre,
        'descripcion': descripcion,
        'orden': orden,
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      });
    }

    // ── Usuarios de prueba ───────────────────────────────────────
    await _insertSeedUsers(db, now);
  }

  /// Inserta usuarios de prueba con PINs hasheados.
  static Future<void> _insertSeedUsers(Database db, String now) async {
    final users = [
      ('usr_admin_01', 'Administrador', 'administrador', '1111'),
      ('usr_cajero_01', 'Cajero', 'cajero', '2222'),
      ('usr_mesero_01', 'Mesero', 'mesero', '3333'),
      ('usr_cocina_01', 'Cocina', 'cocina', '4444'),
    ];
    for (final (id, nombre, rol, pin) in users) {
      await db.insert('usuarios', {
        'id': id,
        'restaurant_id': AppConstants.defaultRestaurantId,
        'nombre': nombre,
        'pin': PinHasher.hash(pin), // nunca guardar en texto plano
        'rol': rol,
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Maneja migraciones entre versiones de la base de datos.
  /// Método público estático para que otros servicios puedan reutilizarlo.
  static Future<void> applyMigrations(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // v2: agregar columna nombre_reserva a mesas
      await db.execute('ALTER TABLE mesas ADD COLUMN nombre_reserva TEXT');
    }
    if (oldVersion < 3) {
      // v3: insertar usuarios de prueba si no existen
      final now = DateTime.now().toIso8601String();
      await _insertSeedUsers(db, now);
    }
    if (oldVersion < 4) {
      // v4: agregar datos de cliente a ventas
      await db.execute('ALTER TABLE ventas ADD COLUMN cliente_nombre TEXT');
      await db.execute('ALTER TABLE ventas ADD COLUMN cliente_email TEXT');
    }
    if (oldVersion < 5) {
      // v5: tabla de llamados a mesero
      await db.execute('''
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
      ''');
    }
    if (oldVersion < 6) {
      // v6: tablas de cotizaciones
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cotizaciones (
          id TEXT PRIMARY KEY,
          restaurant_id TEXT NOT NULL,
          mesa_id TEXT,
          cliente_nombre TEXT NOT NULL,
          cliente_telefono TEXT NOT NULL,
          cliente_email TEXT NOT NULL,
          subtotal REAL NOT NULL,
          total REAL NOT NULL,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
          FOREIGN KEY (mesa_id) REFERENCES mesas(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cotizacion_items (
          id TEXT PRIMARY KEY,
          cotizacion_id TEXT NOT NULL,
          producto_id TEXT NOT NULL,
          producto_nombre TEXT NOT NULL,
          cantidad INTEGER NOT NULL,
          precio_unitario REAL NOT NULL,
          subtotal REAL NOT NULL,
          FOREIGN KEY (cotizacion_id) REFERENCES cotizaciones(id),
          FOREIGN KEY (producto_id) REFERENCES productos(id)
        )
      ''');
    }
    if (oldVersion < 7) {
      // v7: tabla de reservaciones
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reservaciones (
          id TEXT PRIMARY KEY,
          restaurant_id TEXT NOT NULL,
          tipo TEXT NOT NULL,
          mesa_id TEXT,
          fecha TEXT NOT NULL,
          cliente_nombre TEXT NOT NULL,
          cliente_telefono TEXT NOT NULL,
          cliente_email TEXT NOT NULL,
          notas TEXT,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
          FOREIGN KEY (mesa_id) REFERENCES mesas(id)
        )
      ''');
    }
    if (oldVersion < 8) {
      // v8: campos adicionales en cotizaciones
      await db.execute(
        'ALTER TABLE cotizaciones ADD COLUMN reserva_local INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE cotizaciones ADD COLUMN personas INTEGER');
      await db.execute('ALTER TABLE cotizaciones ADD COLUMN fecha_evento TEXT');
      await db.execute(
        'ALTER TABLE cotizaciones ADD COLUMN comida_preferida TEXT',
      );
      await db.execute('ALTER TABLE cotizaciones ADD COLUMN notas TEXT');
    }
    if (oldVersion < 9) {
      // v9: estado de cotizacion
      await db.execute(
        "ALTER TABLE cotizaciones ADD COLUMN estado TEXT NOT NULL DEFAULT 'pendiente'",
      );
    }
    if (oldVersion < 10) {
      // v10: metadatos de facturación/SRI en ventas
      await db.execute(
        'ALTER TABLE ventas ADD COLUMN cliente_identificacion TEXT',
      );
      await db.execute(
        "ALTER TABLE ventas ADD COLUMN tipo_comprobante TEXT NOT NULL DEFAULT 'ticket'",
      );
      await db.execute(
        "ALTER TABLE ventas ADD COLUMN sri_estado TEXT NOT NULL DEFAULT 'no_aplica'",
      );
      await db.execute('ALTER TABLE ventas ADD COLUMN sri_clave_acceso TEXT');
      await db.execute('ALTER TABLE ventas ADD COLUMN sri_mensaje TEXT');
    }
    if (oldVersion < 12) {
      // v12: tabla de secuenciales SRI
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sri_secuenciales (
          id TEXT NOT NULL,
          restaurant_id TEXT NOT NULL,
          ultimo_secuencial INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (id, restaurant_id)
        )
      ''');
    }
    if (oldVersion < 11) {
      // v11: datos básicos de horario/estado para reservaciones
      await db.execute(
        "ALTER TABLE reservaciones ADD COLUMN hora_inicio TEXT NOT NULL DEFAULT '19:00'",
      );
      await db.execute(
        "ALTER TABLE reservaciones ADD COLUMN hora_fin TEXT NOT NULL DEFAULT '20:30'",
      );
      await db.execute(
        'ALTER TABLE reservaciones ADD COLUMN numero_personas INTEGER NOT NULL DEFAULT 2',
      );
      await db.execute(
        "ALTER TABLE reservaciones ADD COLUMN estado TEXT NOT NULL DEFAULT 'pendiente'",
      );
      await db.execute('ALTER TABLE reservaciones ADD COLUMN tipo_evento TEXT');
      await db.execute(
        'ALTER TABLE reservaciones ADD COLUMN requerimientos TEXT',
      );
    }
    if (oldVersion < 13) {
      // v13: campos de texto editables en public_config
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN exp1_titulo TEXT NOT NULL DEFAULT 'Gastronomía Auténtica'",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN exp1_desc TEXT NOT NULL DEFAULT 'Recetas tradicionales elaboradas con ingredientes frescos de temporada.'",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN exp2_titulo TEXT NOT NULL DEFAULT 'Ambiente Familiar'",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN exp2_desc TEXT NOT NULL DEFAULT 'Un espacio cálido y acogedor ideal para toda ocasión especial.'",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN exp3_titulo TEXT NOT NULL DEFAULT 'Servicio Excepcional'",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN exp3_desc TEXT NOT NULL DEFAULT 'Atención personalizada que supera las expectativas de cada visita.'",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN titulo_menu TEXT NOT NULL DEFAULT 'Nuestro Menú'",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN subtitulo_menu TEXT NOT NULL DEFAULT 'Platos elaborados con ingredientes frescos de temporada'",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN titulo_reservas TEXT NOT NULL DEFAULT 'Reserva tu Mesa'",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN subtitulo_reservas TEXT NOT NULL DEFAULT 'Asegura tu lugar para una experiencia gastronómica especial'",
      );
    }

    if (oldVersion < 16) {
      // v16: hashear PINs de usuarios que están en texto plano
      final users = await db.query('usuarios', columns: ['id', 'pin']);
      for (final user in users) {
        final pin = user['pin'] as String?;
        if (pin != null && !PinHasher.isHashed(pin)) {
          await db.update(
            'usuarios',
            {'pin': PinHasher.hash(pin)},
            where: 'id = ?',
            whereArgs: [user['id']],
          );
        }
      }
    }
    if (oldVersion < 15) {
      // v15: tabla de clientes con cédula como PK
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clientes (
          cedula TEXT PRIMARY KEY,
          restaurant_id TEXT NOT NULL,
          nombre TEXT NOT NULL,
          apellido TEXT,
          telefono TEXT,
          email TEXT,
          direccion TEXT,
          fecha_nacimiento TEXT,
          notas TEXT,
          activo INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id)
        )
      ''');
    }
    if (oldVersion < 14) {
      // v14: mapa de ubicación en public_config
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN map_url TEXT NOT NULL DEFAULT 'https://maps.app.goo.gl/KL4cFAxBxDDKmgaS9'",
      );
      await db.execute(
        'ALTER TABLE public_config ADD COLUMN map_lat REAL NOT NULL DEFAULT -2.9721229',
      );
      await db.execute(
        'ALTER TABLE public_config ADD COLUMN map_lng REAL NOT NULL DEFAULT -78.437791',
      );
    }

    if (oldVersion < 17) {
      // v17a: campos de mantelería y precio en reservaciones
      await db.execute(
        'ALTER TABLE reservaciones ADD COLUMN nombre_local_evento TEXT',
      );
      await db.execute('ALTER TABLE reservaciones ADD COLUMN manteles TEXT');
      await db.execute(
        'ALTER TABLE reservaciones ADD COLUMN color_manteleria TEXT',
      );
      await db.execute(
        'ALTER TABLE reservaciones ADD COLUMN precio_estimado REAL',
      );

      // v17b: datos corporativos en public_config
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN nombre_negocio TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN propietario TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN email_contacto TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN email_secundario TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN telefono_secundario TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE public_config ADD COLUMN logo_url TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 18) {
      // v18: nuevos campos en cotizaciones y cotizacion_items para gestión manual
      // Nuevas columnas en cotizaciones
      await db.execute(
        'ALTER TABLE cotizaciones ADD COLUMN cliente_empresa TEXT',
      );
      await db.execute(
        'ALTER TABLE cotizaciones ADD COLUMN cliente_direccion TEXT',
      );
      await db.execute('ALTER TABLE cotizaciones ADD COLUMN hora_evento TEXT');
      await db.execute('ALTER TABLE cotizaciones ADD COLUMN lugar_evento TEXT');
      await db.execute(
        'ALTER TABLE cotizaciones ADD COLUMN descuento REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE cotizaciones ADD COLUMN tasa_impuesto REAL NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE cotizaciones ADD COLUMN origen TEXT NOT NULL DEFAULT 'publica'",
      );
      // Recrear cotizacion_items: quitar FK a productos, hacer producto_id nullable,
      // agregar columnas descripcion y descuento_item
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cotizacion_items_v18 (
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
      ''');
      await db.execute('''
        INSERT INTO cotizacion_items_v18
          (id, cotizacion_id, producto_id, producto_nombre, descripcion,
           cantidad, precio_unitario, descuento_item, subtotal)
        SELECT id, cotizacion_id, producto_id, producto_nombre, NULL,
               cantidad, precio_unitario, 0, subtotal
        FROM cotizacion_items
      ''');
      await db.execute('DROP TABLE cotizacion_items');
      await db.execute(
        'ALTER TABLE cotizacion_items_v18 RENAME TO cotizacion_items',
      );
    }
    if (oldVersion < 19) {
      // v19: firma y hora de emisión en cotizaciones
      await db.execute('ALTER TABLE cotizaciones ADD COLUMN hora_emision TEXT');
      await db.execute('ALTER TABLE cotizaciones ADD COLUMN firma_nombre TEXT');
      await db.execute('ALTER TABLE cotizaciones ADD COLUMN firma_cargo TEXT');
      await db.execute(
        'ALTER TABLE cotizaciones ADD COLUMN firma_numero_documento TEXT',
      );
      await db.execute(
        'ALTER TABLE cotizaciones ADD COLUMN firma_es_imagen INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE cotizaciones ADD COLUMN firma_imagen_bytes BLOB',
      );
    }
    if (oldVersion < 20) {
      // v20: unificación de clientes con id_cliente + snapshots históricos
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clientes_v20 (
          id_cliente INTEGER PRIMARY KEY AUTOINCREMENT,
          cedula TEXT UNIQUE,
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
      ''');
      await db.execute('''
        INSERT INTO clientes_v20 (
          cedula,
          restaurant_id,
          nombres,
          nombre,
          apellido,
          telefono,
          direccion,
          email,
          fecha_nacimiento,
          notas,
          estado,
          activo,
          fecha_registro,
          created_at,
          updated_at
        )
        SELECT
          cedula,
          restaurant_id,
          CASE
            WHEN apellido IS NOT NULL AND TRIM(apellido) != ''
              THEN TRIM(nombre) || ' ' || TRIM(apellido)
            ELSE TRIM(nombre)
          END,
          nombre,
          apellido,
          telefono,
          direccion,
          email,
          fecha_nacimiento,
          notas,
          CASE WHEN activo = 1 THEN 1 ELSE 0 END,
          activo,
          created_at,
          created_at,
          updated_at
        FROM clientes
      ''');
      await db.execute('DROP TABLE clientes');
      await db.execute('ALTER TABLE clientes_v20 RENAME TO clientes');

      await db.execute('ALTER TABLE ventas ADD COLUMN id_cliente INTEGER');
      await db.execute(
        "ALTER TABLE ventas ADD COLUMN tipo_cliente TEXT NOT NULL DEFAULT 'consumidor_final'",
      );
      await db.execute(
        'ALTER TABLE ventas ADD COLUMN identificacion_cliente TEXT',
      );
      await db.execute('ALTER TABLE ventas ADD COLUMN nombre_cliente TEXT');
      await db.execute('ALTER TABLE ventas ADD COLUMN telefono_cliente TEXT');
      await db.execute('ALTER TABLE ventas ADD COLUMN direccion_cliente TEXT');

      await db.execute(
        'ALTER TABLE cotizaciones ADD COLUMN id_cliente INTEGER',
      );
      await db.execute(
        'ALTER TABLE reservaciones ADD COLUMN id_cliente INTEGER',
      );

      await db.execute('''
        UPDATE ventas
        SET
          identificacion_cliente = COALESCE(identificacion_cliente, cliente_identificacion),
          nombre_cliente = COALESCE(nombre_cliente, cliente_nombre)
      ''');
      await db.execute('''
        UPDATE ventas
        SET
          tipo_cliente = CASE
            WHEN TRIM(COALESCE(identificacion_cliente, '')) = ''
              THEN 'consumidor_final'
            ELSE 'registrado'
          END
      ''');

      await db.execute('''
        UPDATE ventas
        SET id_cliente = (
          SELECT c.id_cliente
          FROM clientes c
          WHERE c.cedula = ventas.identificacion_cliente
          LIMIT 1
        )
        WHERE TRIM(COALESCE(identificacion_cliente, '')) != ''
      ''');

      await db.execute('''
        UPDATE cotizaciones
        SET id_cliente = (
          SELECT c.id_cliente
          FROM clientes c
          WHERE c.cedula = cotizaciones.cliente_telefono
          LIMIT 1
        )
        WHERE TRIM(COALESCE(cliente_telefono, '')) != ''
      ''');
      await db.execute('''
        UPDATE reservaciones
        SET id_cliente = (
          SELECT c.id_cliente
          FROM clientes c
          WHERE c.cedula = reservaciones.cliente_telefono
          LIMIT 1
        )
        WHERE TRIM(COALESCE(cliente_telefono, '')) != ''
      ''');
    }
    if (oldVersion < 21) {
      // v21: pedido_items — eliminar FK en producto_id (ahora nullable)
      //      y agregar columna nombre_display para cargos manuales.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pedido_items_v21 (
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
      ''');
      await db.execute('''
        INSERT INTO pedido_items_v21
          (id, pedido_id, producto_id, variante_id, cantidad,
           precio_unitario, observaciones, estado, created_at, updated_at)
        SELECT id, pedido_id, producto_id, variante_id, cantidad,
               precio_unitario, observaciones, estado, created_at, updated_at
        FROM pedido_items
      ''');
      await db.execute('DROP TABLE pedido_items');
      await db.execute('ALTER TABLE pedido_items_v21 RENAME TO pedido_items');
    }
    if (oldVersion < 22) {
      // v22: ventas — agregar referencia opcional a la cotización origen.
      await db.execute(
        'ALTER TABLE ventas ADD COLUMN source_cotizacion_id TEXT',
      );
    }
    if (oldVersion < 23) {
      // v23: garantizar que source_cotizacion_id existe aunque la DB se haya
      //      creado con onCreate en v22 (sin la columna en createTableStatements).
      final cols = await db.rawQuery('PRAGMA table_info(ventas)');
      final hasCol = cols.any((c) => c['name'] == 'source_cotizacion_id');
      if (!hasCol) {
        await db.execute(
          'ALTER TABLE ventas ADD COLUMN source_cotizacion_id TEXT',
        );
      }
    }
    if (oldVersion < 24) {
      // v24: ventas — hacer pedido_id nullable y eliminar FK a pedidos
      //      para soportar ventas de cotizaciones (su id no existe en pedidos).
      //      venta_detalles — hacer producto_id nullable y eliminar FK a productos
      //      para soportar ítems sin producto en el catálogo.

      // ── Recrear ventas ────────────────────────────────────────
      await db.execute('''
        CREATE TABLE ventas_v24 (
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
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          source_cotizacion_id TEXT,
          FOREIGN KEY (restaurant_id) REFERENCES restaurantes(id),
          FOREIGN KEY (cajero_id) REFERENCES usuarios(id),
          FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
        )
      ''');
      await db.execute('''
        INSERT INTO ventas_v24 (
          id, restaurant_id, pedido_id, cajero_id, id_cliente, tipo_cliente,
          identificacion_cliente, nombre_cliente, telefono_cliente, direccion_cliente,
          cliente_nombre, cliente_email, cliente_identificacion, metodo_pago,
          tipo_comprobante, sri_estado, subtotal, impuestos, total, descripcion_pago,
          sri_clave_acceso, sri_mensaje, created_at, source_cotizacion_id
        )
        SELECT
          id, restaurant_id, pedido_id, cajero_id, id_cliente, tipo_cliente,
          identificacion_cliente, nombre_cliente, telefono_cliente, direccion_cliente,
          cliente_nombre, cliente_email, cliente_identificacion, metodo_pago,
          tipo_comprobante, sri_estado, subtotal, COALESCE(impuestos, 0), total,
          descripcion_pago, sri_clave_acceso, sri_mensaje, created_at, source_cotizacion_id
        FROM ventas
      ''');

      // ── Recrear venta_detalles (antes de DROP ventas, usa temp table) ─
      await db.execute('''
        CREATE TABLE venta_detalles_v24 (
          id TEXT PRIMARY KEY,
          venta_id TEXT NOT NULL,
          producto_id TEXT,
          variante_id TEXT,
          cantidad INTEGER NOT NULL,
          precio_unitario REAL NOT NULL,
          subtotal REAL NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO venta_detalles_v24 (
          id, venta_id, producto_id, variante_id, cantidad, precio_unitario, subtotal
        )
        SELECT id, venta_id, producto_id, variante_id, cantidad, precio_unitario, subtotal
        FROM venta_detalles
      ''');
      await db.execute('DROP TABLE venta_detalles');
      await db.execute('DROP TABLE ventas');
      await db.execute('ALTER TABLE ventas_v24 RENAME TO ventas');
      await db.execute(
        'ALTER TABLE venta_detalles_v24 RENAME TO venta_detalles',
      );
    }
    if (oldVersion < 25) {
      // v25: reparación defensiva.
      // La migración v24 puede haber fallado parcialmente en sesiones anteriores
      // (ventas_v24 creada pero el INSERT falló porque la tabla vieja no tenía
      // source_cotizacion_id, quedando el user_version en 24 con la tabla en
      // mal estado). Esta migración detecta y corrige todos los casos posibles.

      // 1. Limpiar tablas temporales huérfanas de v24.
      final orphanVentas = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='ventas_v24'",
      );
      if (orphanVentas.isNotEmpty) {
        final hasVentas = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='ventas'",
        );
        if (hasVentas.isNotEmpty) {
          // Ambas existen → la _v24 es un sobrante vacío, descartarla.
          await db.execute('DROP TABLE ventas_v24');
        } else {
          // ventas fue eliminada pero la temporal no fue renombrada.
          await db.execute('ALTER TABLE ventas_v24 RENAME TO ventas');
        }
      }
      final orphanDet = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='venta_detalles_v24'",
      );
      if (orphanDet.isNotEmpty) {
        final hasDet = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='venta_detalles'",
        );
        if (hasDet.isNotEmpty) {
          await db.execute('DROP TABLE venta_detalles_v24');
        } else {
          await db.execute(
            'ALTER TABLE venta_detalles_v24 RENAME TO venta_detalles',
          );
        }
      }

      // 2. Garantizar que source_cotizacion_id existe en ventas.
      final cols = await db.rawQuery('PRAGMA table_info(ventas)');
      final hasCol = cols.any((c) => c['name'] == 'source_cotizacion_id');
      if (!hasCol) {
        await db.execute(
          'ALTER TABLE ventas ADD COLUMN source_cotizacion_id TEXT',
        );
      }
    }
    if (oldVersion < 26) {
      // v26: vincular reservaciones con cotizaciones.
      // Agregar cotizacion_id (nullable, único) a reservaciones si no existe.
      final reservaCols = await db.rawQuery('PRAGMA table_info(reservaciones)');
      final hasCotizacionId = reservaCols.any(
        (c) => c['name'] == 'cotizacion_id',
      );
      if (!hasCotizacionId) {
        await db.execute(
          'ALTER TABLE reservaciones ADD COLUMN cotizacion_id TEXT',
        );
        // Índice único para garantizar 1 reserva por cotización.
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_reservaciones_cotizacion_id '
          'ON reservaciones (cotizacion_id) WHERE cotizacion_id IS NOT NULL',
        );
      }
    }

    if (oldVersion < 27) {
      // v27: añadir restaurant_id a sync_log para soporte multi-tenant.
      final syncCols = await db.rawQuery('PRAGMA table_info(sync_log)');
      final hasRestaurantId = syncCols.any((c) => c['name'] == 'restaurant_id');
      if (!hasRestaurantId) {
        await db.execute(
          "ALTER TABLE sync_log ADD COLUMN restaurant_id TEXT NOT NULL DEFAULT ''",
        );
      }
    }
    if (oldVersion < 28) {
      // v28: clientes debe ser único por tenant, no globalmente por cédula.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clientes_v28 (
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
      ''');
      await db.execute('''
        INSERT INTO clientes_v28 (
          id_cliente, cedula, restaurant_id, nombres, nombre, apellido,
          telefono, direccion, email, fecha_nacimiento, notas, estado, activo,
          fecha_registro, created_at, updated_at
        )
        SELECT
          id_cliente,
          CASE
            WHEN TRIM(COALESCE(cedula, '')) = ''
              THEN 'legacy_' || restaurant_id || '_' || id_cliente
            ELSE TRIM(cedula)
          END,
          restaurant_id,
          TRIM(COALESCE(NULLIF(nombres, ''), nombre)),
          TRIM(nombre),
          NULLIF(TRIM(COALESCE(apellido, '')), ''),
          NULLIF(TRIM(COALESCE(telefono, '')), ''),
          NULLIF(TRIM(COALESCE(direccion, '')), ''),
          LOWER(NULLIF(TRIM(COALESCE(email, '')), '')),
          fecha_nacimiento,
          NULLIF(TRIM(COALESCE(notas, '')), ''),
          estado,
          activo,
          fecha_registro,
          created_at,
          updated_at
        FROM clientes
      ''');
      await db.execute('DROP TABLE clientes');
      await db.execute('ALTER TABLE clientes_v28 RENAME TO clientes');
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_clientes_restaurant_cedula
        ON clientes (restaurant_id, cedula)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_clientes_restaurant_estado_nombres
        ON clientes (restaurant_id, activo, estado, nombres COLLATE NOCASE)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_ventas_restaurant_cliente_identificacion
        ON ventas (restaurant_id, cliente_identificacion)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_ventas_restaurant_identificacion_cliente
        ON ventas (restaurant_id, identificacion_cliente)
      ''');
    }
    if (oldVersion < 29) {
      await _addColumnIfMissing(db, 'ventas', 'sri_comprobante_id', 'TEXT');
      await _addColumnIfMissing(
        db,
        'ventas',
        'sri_numero_autorizacion',
        'TEXT',
      );
      await _addColumnIfMissing(db, 'ventas', 'sri_fecha_autorizacion', 'TEXT');
      await _addColumnIfMissing(db, 'ventas', 'sri_xml_hash', 'TEXT');
      await _addColumnIfMissing(db, 'ventas', 'sri_ride_path', 'TEXT');

      await db.execute('''
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
      ''');
      await db.execute('''
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
      ''');
      await db.execute('''
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
      ''');
      await db.execute('''
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
      ''');
      await db.execute('''
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
      ''');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_sri_comprobantes_clave
        ON sri_comprobantes (restaurant_id, clave_acceso)
        WHERE clave_acceso != ''
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sri_comprobantes_venta
        ON sri_comprobantes (restaurant_id, venta_id)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sri_comprobantes_estado
        ON sri_comprobantes (restaurant_id, estado)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sri_attempts_retry
        ON sri_attempts (restaurant_id, next_retry_at, retry_count)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sri_email_deliveries_estado
        ON sri_email_deliveries (restaurant_id, estado)
      ''');
    }
    if (oldVersion < 30) {
      await _addColumnIfMissing(
        db,
        'public_config',
        'cocina_modo_automatico',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'public_config',
        'cocina_tiempo_auto_minutos',
        'INTEGER NOT NULL DEFAULT 15',
      );
    }
    if (oldVersion < 31) {
      await db.execute('''
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
      ''');
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_drive_connections_restaurant
        ON drive_connections (restaurant_id)
      ''');

      await _addColumnIfMissing(db, 'productos', 'drive_file_id', 'TEXT');
      await _addColumnIfMissing(db, 'productos', 'drive_public_url', 'TEXT');
      await _addColumnIfMissing(
        db,
        'productos',
        'imagen_local_cache_path',
        'TEXT',
      );
    }
    if (oldVersion < 32) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_productos_restaurant_public_lookup
        ON productos (restaurant_id, activo, disponible, categoria_id, nombre COLLATE NOCASE)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_variantes_producto_activo_precio
        ON variantes (producto_id, activo, precio)
      ''');
    }
    if (oldVersion < 33) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sync_log_pending_lookup
        ON sync_log (sincronizado, tabla, intentos, created_at)
      ''');
    }
    if (oldVersion < 34) {
      await _addColumnIfMissing(
        db,
        'ventas',
        'updated_at',
        "TEXT NOT NULL DEFAULT (datetime('now'))",
      );
      await _addColumnIfMissing(
        db,
        'reservaciones',
        'updated_at',
        "TEXT NOT NULL DEFAULT (datetime('now'))",
      );

      await db.execute(
        "UPDATE ventas SET updated_at = COALESCE(updated_at, created_at)",
      );
      await db.execute(
        'UPDATE reservaciones '
        'SET updated_at = COALESCE(updated_at, created_at)',
      );
    }
    if (oldVersion < 35) {
      await db.execute('''
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
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sync_audit_log_created_at
        ON sync_audit_log (created_at)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sync_audit_log_lookup
        ON sync_audit_log (direction, status, tabla, restaurant_id, created_at)
      ''');
    }
    if (oldVersion < 36) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS security_audit_log (
          id TEXT PRIMARY KEY,
          event_type TEXT NOT NULL,
          user_id TEXT,
          restaurant_id TEXT,
          detail TEXT,
          created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_security_audit_log_created_at
        ON security_audit_log (created_at)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_security_audit_log_event
        ON security_audit_log (event_type, created_at)
      ''');
    }
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final exists = cols.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  /// Se ejecuta cada vez que se abre la base de datos.
  Future<void> _onOpen(Database db) async {
    // Habilitar foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // ── Métodos CRUD Genéricos ─────────────────────────────────────────

  /// Inserta un registro en la tabla indicada.
  Future<int> insert(
    String table,
    Map<String, dynamic> data, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace,
  }) async {
    final db = await database;
    return db.insert(table, data, conflictAlgorithm: conflictAlgorithm);
  }

  /// Obtiene todos los registros de una tabla (con filtro opcional).
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  /// Actualiza registros en una tabla.
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return db.update(table, data, where: where, whereArgs: whereArgs);
  }

  /// Elimina registros de una tabla.
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Ejecuta una consulta SQL directa.
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, arguments);
  }

  /// Ejecuta una operación dentro de una transacción.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  /// Cierra la conexión a la base de datos.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
