import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/errors/exceptions.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/utils/pin_hasher.dart';
import 'package:restaurant_app/features/usuarios/data/datasources/usuario_local_datasource.dart';
import 'package:restaurant_app/features/usuarios/data/models/usuario_model.dart';

/// Implementación SQLite del datasource de Usuarios.
class UsuarioLocalDataSourceImpl implements UsuarioLocalDataSource {
  final DatabaseHelper _dbHelper;
  final SyncManager _syncManager;
  // ignore: unused_field
  final TenantContext _tenantContext;

  UsuarioLocalDataSourceImpl({
    required DatabaseHelper dbHelper,
    required SyncManager syncManager,
    required TenantContext tenantContext,
  }) : _dbHelper = dbHelper,
       _syncManager = syncManager,
       _tenantContext = tenantContext;

  void _validarPin(String? pin) {
    final value = pin?.trim() ?? '';
    if (!RegExp(r'^\d{4}$').hasMatch(value)) {
      throw const BusinessException(
        message: 'Cada usuario debe tener un PIN válido de 4 dígitos.',
      );
    }
  }

  Future<void> _validarAdministradorUnico({
    required String restaurantId,
    required RolUsuario rol,
    String? excludeUserId,
  }) async {
    if (rol != RolUsuario.administrador) return;

    final rows = await _dbHelper.query(
      'usuarios',
      where: excludeUserId == null
          ? 'restaurant_id = ? AND rol = ? AND activo = 1'
          : 'restaurant_id = ? AND rol = ? AND activo = 1 AND id != ?',
      whereArgs: excludeUserId == null
          ? [restaurantId, RolUsuario.administrador.value]
          : [restaurantId, RolUsuario.administrador.value, excludeUserId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      throw const BusinessException(
        message: 'Solo se permite un usuario administrador activo.',
      );
    }
  }

  @override
  Future<List<UsuarioModel>> getUsuarios(String restaurantId) async {
    final rows = await _dbHelper.query(
      'usuarios',
      where: 'restaurant_id = ? AND activo = 1',
      whereArgs: [restaurantId],
      orderBy: 'nombre ASC',
    );
    return rows.map(UsuarioModel.fromMap).toList();
  }

  @override
  Future<UsuarioModel?> getUsuarioById(String id) async {
    final rows = await _dbHelper.query(
      'usuarios',
      where: 'id = ? AND activo = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UsuarioModel.fromMap(rows.first);
  }

  @override
  Future<UsuarioModel> createUsuario(UsuarioModel usuario) async {
    _validarPin(usuario.pin);
    await _validarAdministradorUnico(
      restaurantId: usuario.restaurantId,
      rol: usuario.rol,
    );

    // Hashear el PIN antes de persistir
    final hashedPin = PinHasher.hash(usuario.pin!);
    final usuarioConHash = UsuarioModel.fromMap({
      ...usuario.toMap(),
      'pin': hashedPin,
    });
    await _dbHelper.insert('usuarios', usuarioConHash.toMap());
    await _syncManager.registrarOperacion(
      tabla: 'usuarios',
      registroId: usuario.id,
      operacion: SyncOperation.insert,
      restaurantId: usuario.restaurantId,
    );
    return usuario; // devuelve con PIN original para la sesión en memoria
  }

  @override
  Future<UsuarioModel> updateUsuario(UsuarioModel usuario) async {
    _validarPin(usuario.pin);
    await _validarAdministradorUnico(
      restaurantId: usuario.restaurantId,
      rol: usuario.rol,
      excludeUserId: usuario.id,
    );

    // Hashear el PIN antes de persistir
    final hashedPin = PinHasher.hash(usuario.pin!);
    final updated = UsuarioModel.fromMap({
      ...usuario.toMap(),
      'pin': hashedPin,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await _dbHelper.update(
      'usuarios',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
    await _syncManager.registrarOperacion(
      tabla: 'usuarios',
      registroId: usuario.id,
      operacion: SyncOperation.update,
      restaurantId: usuario.restaurantId,
    );
    return usuario; // devuelve con PIN original para la sesión en memoria
  }

  @override
  Future<void> deleteUsuario(String id) async {
    final rows = await _dbHelper.query(
      'usuarios',
      where: 'id = ? AND activo = 1',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final usuario = UsuarioModel.fromMap(rows.first);
      if (usuario.rol == RolUsuario.administrador) {
        final admins = await _dbHelper.query(
          'usuarios',
          where: 'restaurant_id = ? AND rol = ? AND activo = 1',
          whereArgs: [usuario.restaurantId, RolUsuario.administrador.value],
          limit: 2,
        );

        if (admins.length <= 1) {
          throw const BusinessException(
            message: 'No se puede eliminar el único administrador activo.',
          );
        }
      }
    }

    await _dbHelper.update(
      'usuarios',
      {'activo': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _syncManager.registrarOperacion(
      tabla: 'usuarios',
      registroId: id,
      operacion: SyncOperation.delete,
      restaurantId: _tenantContext.restaurantId,
    );
  }

  @override
  Future<UsuarioModel?> verificarPin(String restaurantId, String pin) async {
    // Hashear el PIN ingresado y comparar con el almacenado
    final hashedPin = PinHasher.hash(pin);
    final rows = await _dbHelper.query(
      'usuarios',
      where: 'restaurant_id = ? AND pin = ? AND activo = 1',
      whereArgs: [restaurantId, hashedPin],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    // Devolver con PIN en texto plano para la sesión en memoria (nunca se re-persiste)
    final model = UsuarioModel.fromMap(rows.first);
    return UsuarioModel.fromMap({...model.toMap(), 'pin': pin});
  }

  @override
  Future<List<UsuarioModel>> getUsuariosByRol(
    String restaurantId,
    String rol,
  ) async {
    final rows = await _dbHelper.query(
      'usuarios',
      where: 'restaurant_id = ? AND rol = ? AND activo = 1',
      whereArgs: [restaurantId, rol],
      orderBy: 'nombre ASC',
    );
    return rows.map(UsuarioModel.fromMap).toList();
  }
}
