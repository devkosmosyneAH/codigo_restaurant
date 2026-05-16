import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/pagina_publica/data/datasources/public_config_datasource.dart';
import 'package:restaurant_app/features/pagina_publica/data/models/public_config_model.dart';

class PublicConfigDatasourceImpl implements PublicConfigDatasource {
  final DatabaseHelper _db;
  final SyncManager _syncManager;
  // ignore: unused_field
  final TenantContext _tenantContext;

  PublicConfigDatasourceImpl({
    required DatabaseHelper dbHelper,
    required SyncManager syncManager,
    required TenantContext tenantContext,
  }) : _db = dbHelper,
       _syncManager = syncManager,
       _tenantContext = tenantContext;
  static const _table = 'public_config';

  @override
  Future<PublicConfigModel?> getConfig(String restaurantId) async {
    try {
      final rows = await _db.query(
        _table,
        where: 'restaurant_id = ?',
        whereArgs: [restaurantId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return PublicConfigModel.fromMap(rows.first);
    } catch (e) {
      throw DatabaseException(
        message: 'Error al obtener configuración pública: $e',
      );
    }
  }

  @override
  Future<PublicConfigModel> saveConfig(PublicConfigModel config) async {
    try {
      final map = config.toMap();
      // Upsert: insertar o reemplazar si ya existe para el restaurant_id
      await _db.rawQuery(
        '''INSERT OR REPLACE INTO $_table
           (restaurant_id, slogan, descripcion, telefono, whatsapp, direccion,
            horarios, facebook, instagram, mostrar_boton_menu,
            mostrar_boton_reservas, updated_at, exp1_titulo, exp1_desc,
            exp2_titulo, exp2_desc, exp3_titulo, exp3_desc, titulo_menu,
            subtitulo_menu, titulo_reservas, subtitulo_reservas, map_url,
            map_lat, map_lng, nombre_negocio, propietario, email_contacto,
            email_secundario, telefono_secundario, logo_url,
            cocina_modo_automatico, cocina_tiempo_auto_minutos)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          map['restaurant_id'],
          map['slogan'],
          map['descripcion'],
          map['telefono'],
          map['whatsapp'],
          map['direccion'],
          map['horarios'],
          map['facebook'],
          map['instagram'],
          map['mostrar_boton_menu'],
          map['mostrar_boton_reservas'],
          map['updated_at'],
          map['exp1_titulo'],
          map['exp1_desc'],
          map['exp2_titulo'],
          map['exp2_desc'],
          map['exp3_titulo'],
          map['exp3_desc'],
          map['titulo_menu'],
          map['subtitulo_menu'],
          map['titulo_reservas'],
          map['subtitulo_reservas'],
          map['map_url'],
          map['map_lat'],
          map['map_lng'],
          map['nombre_negocio'],
          map['propietario'],
          map['email_contacto'],
          map['email_secundario'],
          map['telefono_secundario'],
          map['logo_url'],
          map['cocina_modo_automatico'],
          map['cocina_tiempo_auto_minutos'],
        ],
      );
      await _syncManager.registrarOperacion(
        tabla: _table,
        registroId: config.restaurantId,
        operacion: SyncOperation.update,
        restaurantId: config.restaurantId,
      );
      return config;
    } catch (e) {
      throw DatabaseException(
        message: 'Error al guardar configuración pública: $e',
      );
    }
  }
}
