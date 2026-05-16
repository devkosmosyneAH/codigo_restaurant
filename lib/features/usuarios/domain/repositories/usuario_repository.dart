import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';

/// Contrato del repositorio de Usuarios (capa de dominio).
abstract class UsuarioRepository {
  ResultFuture<List<Usuario>> getUsuarios(String restaurantId);
  ResultFuture<Usuario?> getUsuarioById(String id);
  ResultFuture<Usuario> createUsuario(Usuario usuario);
  ResultFuture<Usuario> updateUsuario(Usuario usuario);
  ResultFuture<void> deleteUsuario(String id);
  ResultFuture<Usuario?> verificarPin(String restaurantId, String pin);
  ResultFuture<List<Usuario>> getUsuariosByRol(String restaurantId, String rol);
}
