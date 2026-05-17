import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TenantContext', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SessionService.overrideSensitiveStore(InMemorySensitiveSessionStore());
    });

    tearDown(() {
      SessionService.resetSensitiveStore();
    });

    test('uses default restaurant before a session is set', () {
      final context = TenantContext();

      expect(context.restaurantId, AppConstants.defaultRestaurantId);
      expect(context.userId, isNull);
      expect(context.rol, isNull);
    });

    test('stores session tenant and clears back to default', () {
      final context = TenantContext()
        ..setFromSession(
          restaurantId: 'restaurant_002',
          userId: 'usr_002',
          rol: 'administrador',
        );

      expect(context.restaurantId, 'restaurant_002');
      expect(context.userId, 'usr_002');
      expect(context.rol, 'administrador');

      context.clear();

      expect(context.restaurantId, AppConstants.defaultRestaurantId);
      expect(context.userId, isNull);
      expect(context.rol, isNull);
    });

    test('falls back to default when session restaurant is empty', () {
      final context = TenantContext()
        ..setFromSession(restaurantId: '', userId: 'usr_003', rol: 'cajero');

      expect(context.restaurantId, AppConstants.defaultRestaurantId);
      expect(context.userId, 'usr_003');
      expect(context.rol, 'cajero');
    });

    test('can be initialized from the persisted session', () async {
      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'user_session':
            '{"id":"usr_admin_02","restaurantId":"restaurant_002","rol":"administrador"}',
      });

      final context = await TenantContext.fromCurrentSession();

      expect(context.restaurantId, 'restaurant_002');
      expect(context.userId, 'usr_admin_02');
      expect(context.rol, 'administrador');
    });
  });
}
