import 'package:restaurant_app/features/usuarios/data/models/usuario_model.dart';

/// Contrato del datasource local para el módulo de Usuarios.
abstract class UsuarioLocalDataSource {
  Future<List<UsuarioModel>> getUsuarios(String restaurantId);
  Future<UsuarioModel?> getUsuarioById(String id);
  Future<UsuarioModel> createUsuario(UsuarioModel usuario);
  Future<UsuarioModel> updateUsuario(UsuarioModel usuario);

  /// Soft-delete: marca activo = 0.
  Future<void> deleteUsuario(String id);

  /// Verifica que el PIN coincida con el del usuario.
  /// Retorna el [UsuarioModel] si el PIN es correcto, null si no.
  Future<UsuarioModel?> verificarPin(String restaurantId, String pin);

  Future<List<UsuarioModel>> getUsuariosByRol(String restaurantId, String rol);
}
