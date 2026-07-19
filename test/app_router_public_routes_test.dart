import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/config/routes/app_router.dart';

void main() {
  group('AppRouter public location checks', () {
    test('recognizes public menu and restaurant routes', () {
      expect(AppRouter.isPublicLocation('/menu-public'), isTrue);
      expect(AppRouter.isPublicLocation('/menu-public?mesa=1'), isTrue);
      expect(AppRouter.isPublicLocation('/restaurante'), isTrue);
      expect(AppRouter.isPublicLocation('/c/abc123'), isTrue);
      expect(AppRouter.isPublicLocation('/pedido-mesa?mesa=1'), isTrue);
    });

    test('keeps protected app routes blocked for anonymous users', () {
      expect(AppRouter.isPublicLocation('/pedidos'), isFalse);
      expect(AppRouter.isPublicLocation('/ventas'), isFalse);
      expect(AppRouter.isPublicLocation('/usuarios'), isFalse);
      expect(AppRouter.isPublicLocation('/caja'), isFalse);
    });
  });
}
