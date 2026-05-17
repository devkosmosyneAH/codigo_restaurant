import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionService secure session', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SessionService.overrideSensitiveStore(InMemorySensitiveSessionStore());
    });

    tearDown(() {
      SessionService.resetSensitiveStore();
    });

    test(
      'saves and restores session without persisting sensitive JSON in prefs',
      () async {
        final ok = await SessionService.saveUserSession({
          'id': 'usr_admin_01',
          'restaurantId': 'la_pena_001',
          'nombre': 'Administrador',
          'rol': 'administrador',
          'activo': true,
        });

        final prefs = await SharedPreferences.getInstance();
        final restored = await SessionService.getCurrentUserSession();

        expect(ok, isTrue);
        expect(prefs.getBool('is_logged_in'), isTrue);
        expect(prefs.getString('user_session'), isNull);
        expect(restored, isNotNull);
        expect(restored!['id'], 'usr_admin_01');
      },
    );

    test('migrates legacy shared_preferences session on first read', () async {
      final legacyJson = jsonEncode({
        'id': 'usr_legacy_01',
        'restaurantId': 'la_pena_001',
        'nombre': 'Legacy User',
        'rol': 'mesero',
      });

      SharedPreferences.setMockInitialValues({
        'is_logged_in': true,
        'user_session': legacyJson,
      });
      SessionService.overrideSensitiveStore(InMemorySensitiveSessionStore());

      final migrated = await SessionService.getCurrentUserSession();
      final prefs = await SharedPreferences.getInstance();
      final restoredAgain = await SessionService.getCurrentUserSession();

      expect(migrated, isNotNull);
      expect(migrated!['id'], 'usr_legacy_01');
      expect(prefs.getString('user_session'), isNull);
      expect(restoredAgain, isNotNull);
      expect(restoredAgain!['id'], 'usr_legacy_01');
    });

    test('logout clears stored session state', () async {
      await SessionService.saveUserSession({
        'id': 'usr_mesero_01',
        'restaurantId': 'la_pena_001',
        'nombre': 'Mesero',
        'rol': 'mesero',
      });

      final out = await SessionService.logout();

      expect(out, isTrue);
      expect(await SessionService.isUserLoggedIn(), isFalse);
      expect(await SessionService.getCurrentUserSession(), isNull);
    });
  });
}
