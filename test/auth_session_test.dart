import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurant_app/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthChangeNotifier session persistence', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      SessionService.overrideSensitiveStore(InMemorySensitiveSessionStore());
      await sl.reset();
      sl.registerSingleton<TenantContext>(TenantContext());
    });

    tearDown(() async {
      SessionService.resetSensitiveStore();
      await sl.reset();
    });

    test('restores a saved user session on startup', () async {
      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'user_session':
            '{"id":"usr_admin_01","restaurantId":"la_pena_001","nombre":"Administrador","email":null,"pin":"1111","rol":"administrador","activo":true,"createdAt":"2026-01-01T00:00:00.000","updatedAt":"2026-01-01T00:00:00.000"}',
      });

      final auth = AuthChangeNotifier();
      await auth.restoreSession();

      final prefs = await SharedPreferences.getInstance();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.usuario?.id, 'usr_admin_01');
      expect(auth.usuario?.rol, RolUsuario.administrador);
      expect(auth.usuario?.nombre, 'Administrador');
      expect(prefs.getString('user_session'), isNull);
    });

    test('logout clears memory and persisted session', () async {
      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'user_session':
            '{"id":"usr_mesero_01","restaurantId":"la_pena_001","nombre":"Mesero","email":null,"pin":"3333","rol":"mesero","activo":true,"createdAt":"2026-01-01T00:00:00.000","updatedAt":"2026-01-01T00:00:00.000"}',
      });

      final auth = AuthChangeNotifier();
      await auth.restoreSession();
      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(await SessionService.isUserLoggedIn(), isFalse);
      expect(await SessionService.getCurrentUserSession(), isNull);
    });
  });
}
