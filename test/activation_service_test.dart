import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/services/activation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActivationService', () {
    late ActivationService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = ActivationService();
    });

    test('activates a 7-day demo code locally', () async {
      final base = DateTime(2026, 4, 9, 12);

      final error = await service.activateWithCode(
        AppConstants.demoActivationCode,
        now: base,
      );
      final status = await service.getStatus(
        now: base.add(const Duration(days: 6)),
      );

      expect(error, isNull);
      expect(status.canAccessApp, isTrue);
      expect(status.isDemo, isTrue);
      expect(status.isExpired, isFalse);
    });

    test('marks the demo as expired after a week', () async {
      final base = DateTime(2026, 4, 9, 12);
      await service.activateWithCode(
        AppConstants.demoActivationCode,
        now: base,
      );

      final status = await service.getStatus(
        now: base.add(const Duration(days: 8)),
      );

      expect(status.canAccessApp, isFalse);
      expect(status.isExpired, isTrue);
    });

    test('accepts a fixed activation code without expiry', () async {
      final base = DateTime(2026, 4, 9, 12);
      await service.activateWithCode(
        AppConstants.fullActivationCode,
        now: base,
      );

      final status = await service.getStatus(
        now: base.add(const Duration(days: 30)),
      );

      expect(status.canAccessApp, isTrue);
      expect(status.isFull, isTrue);
      expect(status.isExpired, isFalse);
    });
  });
}
