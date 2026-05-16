import 'package:equatable/equatable.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';
import 'package:restaurant_app/features/usuarios/domain/repositories/usuario_repository.dart';

// ── Use Cases ──────────────────────────────────────────────────────────────────

class GetUsuarios {
  const GetUsuarios(this._repository);
  final UsuarioRepository _repository;

  ResultFuture<List<Usuario>> call(String restaurantId) =>
      _repository.getUsuarios(restaurantId);
}

class GetUsuarioById {
  const GetUsuarioById(this._repository);
  final UsuarioRepository _repository;

  ResultFuture<Usuario?> call(String id) => _repository.getUsuarioById(id);
}

class GetUsuariosByRol {
  const GetUsuariosByRol(this._repository);
  final UsuarioRepository _repository;

  ResultFuture<List<Usuario>> call(String restaurantId, String rol) =>
      _repository.getUsuariosByRol(restaurantId, rol);
}

// ── Params ─────────────────────────────────────────────────────────────────────

class CreateUsuarioParams extends Equatable {
  final String restaurantId;
  final String nombre;
  final String? email;
  final String? pin;
  final String rol;

  const CreateUsuarioParams({
    required this.restaurantId,
    required this.nombre,
    this.email,
    this.pin,
    required this.rol,
  });

  @override
  List<Object?> get props => [restaurantId, nombre, email, pin, rol];
}

class UpdateUsuarioParams extends Equatable {
  final String id;
  final String nombre;
  final String? email;
  final String? pin;
  final String rol;

  const UpdateUsuarioParams({
    required this.id,
    required this.nombre,
    this.email,
    this.pin,
    required this.rol,
  });

  @override
  List<Object?> get props => [id, nombre, email, pin, rol];
}

class CreateUsuario {
  const CreateUsuario(this._repository);
  final UsuarioRepository _repository;

  ResultFuture<Usuario> call(Usuario usuario) =>
      _repository.createUsuario(usuario);
}

class UpdateUsuario {
  const UpdateUsuario(this._repository);
  final UsuarioRepository _repository;

  ResultFuture<Usuario> call(Usuario usuario) =>
      _repository.updateUsuario(usuario);
}

class DeleteUsuario {
  const DeleteUsuario(this._repository);
  final UsuarioRepository _repository;

  ResultFuture<void> call(String id) => _repository.deleteUsuario(id);
}

class VerificarPin {
  const VerificarPin(this._repository);
  final UsuarioRepository _repository;

  ResultFuture<Usuario?> call(String restaurantId, String pin) =>
      _repository.verificarPin(restaurantId, pin);
}
