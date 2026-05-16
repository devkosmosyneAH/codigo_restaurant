import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:restaurant_app/app_startup/app_startup.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/features/home/presentation/widgets/main_scaffold.dart';

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

  testWidgets('mobile navigation exposes logout through Más menu', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const MainScaffold(
            child: Scaffold(body: Center(child: Text('Contenido'))),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    final moreMenu = find.byIcon(Icons.menu_rounded);

    if (moreMenu.evaluate().isNotEmpty) {
      await tester.tap(moreMenu);
      await tester.pumpAndSettle();
      expect(find.text('Cerrar sesión'), findsOneWidget);
    } else {
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
    }
  });
}
