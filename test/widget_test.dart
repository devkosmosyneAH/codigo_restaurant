// Smoke test básico de la aplicación RestaurantApp.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:restaurant_app/app_startup/app_startup.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await sl.reset();
    await initializePlatformSpecific();
    await initDatabaseSafely();
    await initDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('App opens with activation gate on first launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RestaurantApp()));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu código de activación'), findsOneWidget);
  });
}
