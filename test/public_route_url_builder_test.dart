import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/utils/public_route_url_builder.dart';

void main() {
  group('PublicRouteUrlBuilder', () {
    test('builds menu URL from the current GitHub Pages base URL', () {
      final url = PublicRouteUrlBuilder.route(
        AppRouter.menuPublico,
        fallbackUrl: 'https://menu.restaurante.com/menu-public',
        currentUri: Uri.parse(
          'https://devkosmosyneah.github.io/Restaurant/#/empresa-config',
        ),
      );

      expect(url, 'https://devkosmosyneah.github.io/Restaurant/#/menu-public');
    });

    test('keeps table order query parameters inside the hash route', () {
      final url = PublicRouteUrlBuilder.route(
        AppRouter.pedidoMesa,
        fallbackUrl: 'https://menu.restaurante.com/pedido-mesa',
        currentUri: Uri.parse(
          'https://devkosmosyneah.github.io/Restaurant/#/mesas',
        ),
        queryParameters: const {'mesa': 'mesa_1', 'nombre': 'Mesa 1'},
      );

      expect(
        url,
        'https://devkosmosyneah.github.io/Restaurant/#/pedido-mesa?mesa=mesa_1&nombre=Mesa+1',
      );
    });

    test('uses fallback URL outside an HTTP deployment', () {
      final url = PublicRouteUrlBuilder.route(
        AppRouter.menuPublico,
        fallbackUrl: 'https://menu.restaurante.com/menu-public',
        currentUri: Uri.parse('file:///C:/app/index.html'),
      );

      expect(url, 'https://menu.restaurante.com/menu-public');
    });
  });
}
