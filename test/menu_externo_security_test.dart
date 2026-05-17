import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/domain/enums.dart';

void main() {
  group('Menu externo seguridad de rutas', () {
    test('ruta publica de menu es accesible para cualquier rol interno', () {
      for (final rol in RolUsuario.values) {
        expect(
          AppRouter.isRouteAllowedForRole(rol, AppRouter.menuPublico),
          isTrue,
          reason: 'El rol ${rol.value} debe poder navegar a menu publico',
        );
        expect(
          AppRouter.isRouteAllowedForRole(
            rol,
            '${AppRouter.menuPublico}/mesa-5',
          ),
          isTrue,
          reason: 'El rol ${rol.value} debe poder navegar a subrutas publicas',
        );
      }
    });

    test('rutas administrativas de menu no se exponen a roles no admin', () {
      final rolesNoAdmin = RolUsuario.values.where((r) => !r.esAdmin);

      for (final rol in rolesNoAdmin) {
        expect(
          AppRouter.isRouteAllowedForRole(rol, AppRouter.menu),
          isFalse,
          reason: 'El rol ${rol.value} no debe acceder al menu administrativo',
        );
        expect(
          AppRouter.isRouteAllowedForRole(rol, AppRouter.restauranteConfig),
          isFalse,
          reason:
              'El rol ${rol.value} no debe acceder a configuracion publica interna',
        );
      }
    });
  });
}
