import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';
import 'package:restaurant_app/features/usuarios/domain/repositories/usuario_repository.dart';
import 'package:restaurant_app/features/usuarios/domain/usecases/usuario_usecases.dart';
import 'package:restaurant_app/features/usuarios/presentation/providers/usuario_provider.dart';

void main() {
  group('UsuarioNotifier security rules', () {
    setUp(() async {
      await sl.reset();
      sl.registerSingleton<TenantContext>(
        TenantContext()..setFromSession(
          restaurantId: 'la_pena_001',
          userId: 'usr_admin_1',
          rol: 'administrador',
        ),
      );
    });

    tearDown(() async {
      await sl.reset();
    });
    test('rejects creating a second administrator', () async {
      final repo = _FakeUsuarioRepository(initialUsers: [_adminUser()]);
      final notifier = _buildNotifier(repo);
      await notifier.loadUsuarios();

      final ok = await notifier.crearUsuario(
        nombre: 'Nuevo admin',
        email: 'admin2@test.com',
        pin: '1234',
        rol: RolUsuario.administrador,
      );

      expect(ok, isFalse);
      expect(notifier.state.error, contains('administrador'));
      expect(repo.createCalls, 0);
    });

    test('rejects creating a user without a 4-digit PIN', () async {
      final repo = _FakeUsuarioRepository(initialUsers: [_adminUser()]);
      final notifier = _buildNotifier(repo);
      await notifier.loadUsuarios();

      final ok = await notifier.crearUsuario(
        nombre: 'Mesero sin pin',
        email: 'mesero@test.com',
        pin: '',
        rol: RolUsuario.mesero,
      );

      expect(ok, isFalse);
      expect(notifier.state.error, contains('PIN'));
      expect(repo.createCalls, 0);
    });

    test(
      'rejects promoting another user to administrator when one exists',
      () async {
        final repo = _FakeUsuarioRepository(
          initialUsers: [
            _adminUser(),
            _staffUser(id: 'usr_mesero_1', nombre: 'Carlos'),
          ],
        );
        final notifier = _buildNotifier(repo);
        await notifier.loadUsuarios();

        final usuario = notifier.state.usuarios.firstWhere(
          (u) => u.id == 'usr_mesero_1',
        );

        final ok = await notifier.actualizarUsuario(
          usuario: usuario,
          nombre: usuario.nombre,
          email: usuario.email,
          pin: '',
          rol: RolUsuario.administrador,
        );

        expect(ok, isFalse);
        expect(notifier.state.error, contains('administrador'));
        expect(repo.updateCalls, 0);
      },
    );

    test('rejects deleting the only active administrator', () async {
      final repo = _FakeUsuarioRepository(initialUsers: [_adminUser()]);
      final notifier = _buildNotifier(repo);
      await notifier.loadUsuarios();

      final ok = await notifier.eliminarUsuario(notifier.state.usuarios.first);

      expect(ok, isFalse);
      expect(notifier.state.error, contains('administrador'));
      expect(repo.deleteCalls, 0);
    });
  });
}

UsuarioNotifier _buildNotifier(_FakeUsuarioRepository repo) {
  return UsuarioNotifier(
    getUsuarios: GetUsuarios(repo),
    createUsuario: CreateUsuario(repo),
    updateUsuario: UpdateUsuario(repo),
    deleteUsuario: DeleteUsuario(repo),
    verificarPin: VerificarPin(repo),
  );
}

Usuario _adminUser() => Usuario(
  id: 'usr_admin_1',
  restaurantId: 'la_pena_001',
  nombre: 'Administrador',
  email: 'admin@test.com',
  pin: '1111',
  rol: RolUsuario.administrador,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Usuario _staffUser({required String id, required String nombre}) => Usuario(
  id: id,
  restaurantId: 'la_pena_001',
  nombre: nombre,
  email: '$id@test.com',
  pin: '2222',
  rol: RolUsuario.mesero,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class _FakeUsuarioRepository implements UsuarioRepository {
  _FakeUsuarioRepository({List<Usuario>? initialUsers})
    : _users = [...?initialUsers];

  final List<Usuario> _users;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  ResultFuture<Usuario> createUsuario(Usuario usuario) async {
    createCalls++;
    _users.add(usuario);
    return Right(usuario);
  }

  @override
  ResultFuture<void> deleteUsuario(String id) async {
    deleteCalls++;
    _users.removeWhere((u) => u.id == id);
    return const Right(null);
  }

  @override
  ResultFuture<Usuario?> getUsuarioById(String id) async {
    return Right(_users.where((u) => u.id == id).cast<Usuario?>().firstOrNull);
  }

  @override
  ResultFuture<List<Usuario>> getUsuarios(String restaurantId) async {
    return Right(
      _users.where((u) => u.restaurantId == restaurantId && u.activo).toList(),
    );
  }

  @override
  ResultFuture<List<Usuario>> getUsuariosByRol(
    String restaurantId,
    String rol,
  ) async {
    return Right(
      _users
          .where(
            (u) =>
                u.restaurantId == restaurantId &&
                u.activo &&
                u.rol.value == rol,
          )
          .toList(),
    );
  }

  @override
  ResultFuture<Usuario> updateUsuario(Usuario usuario) async {
    updateCalls++;
    final index = _users.indexWhere((u) => u.id == usuario.id);
    if (index >= 0) {
      _users[index] = usuario;
    }
    return Right(usuario);
  }

  @override
  ResultFuture<Usuario?> verificarPin(String restaurantId, String pin) async {
    for (final user in _users) {
      if (user.restaurantId == restaurantId && user.pin == pin && user.activo) {
        return Right(user);
      }
    }
    return const Right(null);
  }
}
