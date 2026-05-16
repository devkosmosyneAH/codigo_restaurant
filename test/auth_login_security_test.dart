import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurant_app/features/usuarios/domain/entities/usuario.dart';
import 'package:restaurant_app/features/usuarios/domain/repositories/usuario_repository.dart';
import 'package:restaurant_app/features/usuarios/domain/usecases/usuario_usecases.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthChangeNotifier login hardening', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
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

    test('blocks access temporarily after 3 failed attempts', () async {
      sl.registerLazySingleton<VerificarPin>(
        () => VerificarPin(_FakeUsuarioRepository()),
      );

      final auth = AuthChangeNotifier();

      final first = await auth.loginWithPin('0000');
      final second = await auth.loginWithPin('0000');
      final third = await auth.loginWithPin('0000');
      final blocked = await auth.loginWithPin('1111');

      expect(first, contains('PIN incorrecto'));
      expect(second, contains('PIN incorrecto'));
      expect(third, contains('Demasiados intentos'));
      expect(blocked, contains('bloqueado'));
      expect(auth.isAuthenticated, isFalse);
    });

    test('successful login clears the failed-attempt counter', () async {
      sl.registerLazySingleton<VerificarPin>(
        () => VerificarPin(
          _FakeUsuarioRepository(validUsersByPin: {'1111': _adminUser()}),
        ),
      );

      final auth = AuthChangeNotifier();

      final first = await auth.loginWithPin('0000');
      final success = await auth.loginWithPin('1111');
      await auth.logout();
      final afterSuccess = await auth.loginWithPin('0000');

      expect(first, contains('Te quedan 2 intentos'));
      expect(success, isNull);
      expect(afterSuccess, contains('Te quedan 2 intentos'));
    });
  });
}

Usuario _adminUser() => Usuario(
  id: 'usr_admin_01',
  restaurantId: 'la_pena_001',
  nombre: 'Administrador',
  email: 'admin@test.com',
  pin: '1111',
  rol: RolUsuario.administrador,
  activo: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class _FakeUsuarioRepository implements UsuarioRepository {
  _FakeUsuarioRepository({Map<String, Usuario>? validUsersByPin})
    : _validUsersByPin = validUsersByPin ?? const {};

  final Map<String, Usuario> _validUsersByPin;

  @override
  ResultFuture<Usuario?> verificarPin(String restaurantId, String pin) async {
    return Right(_validUsersByPin[pin]);
  }

  @override
  ResultFuture<Usuario> createUsuario(Usuario usuario) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<void> deleteUsuario(String id) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<Usuario?> getUsuarioById(String id) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<List<Usuario>> getUsuarios(String restaurantId) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<List<Usuario>> getUsuariosByRol(
    String restaurantId,
    String rol,
  ) {
    throw UnimplementedError();
  }

  @override
  ResultFuture<Usuario> updateUsuario(Usuario usuario) {
    throw UnimplementedError();
  }
}
