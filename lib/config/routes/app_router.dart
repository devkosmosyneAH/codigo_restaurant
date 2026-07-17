import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/domain/enums.dart';
import 'package:restaurant_app/features/auth/presentation/pages/login_page.dart';
import 'package:restaurant_app/features/auth/presentation/providers/activation_provider.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurant_app/features/home/presentation/pages/home_page.dart';
import 'package:restaurant_app/features/mesas/presentation/pages/mesas_page.dart';
import 'package:restaurant_app/features/pedidos/presentation/pages/pedidos_page.dart';
import 'package:restaurant_app/features/pedidos/presentation/pages/nuevo_pedido_page.dart';
import 'package:restaurant_app/features/cocina/presentation/pages/cocina_page.dart';
import 'package:restaurant_app/features/menu/presentation/pages/menu_page.dart';
import 'package:restaurant_app/features/caja/presentation/pages/caja_page.dart';
import 'package:restaurant_app/features/reportes/presentation/pages/reportes_page.dart';
import 'package:restaurant_app/features/usuarios/presentation/pages/usuarios_page.dart';
import 'package:restaurant_app/features/sincronizacion/presentation/pages/sincronizacion_page.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/pages/cotizaciones_page.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/pages/cotizacion_manual_form_page.dart';
import 'package:restaurant_app/features/home/presentation/widgets/main_scaffold.dart';
import 'package:restaurant_app/features/menu/presentation/pages/menu_public_page.dart';
import 'package:restaurant_app/features/reservaciones/presentation/pages/reservas_page.dart';
import 'package:restaurant_app/features/reservaciones/presentation/pages/reservas_public_page.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/pages/restaurante_public_page.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/pages/restaurante_config_page.dart';
import 'package:restaurant_app/features/cotizaciones/presentation/pages/cotizacion_publica_page.dart';
import 'package:restaurant_app/features/backup/presentation/pages/backup_page.dart';
import 'package:restaurant_app/features/clientes/presentation/pages/clientes_page.dart';
import 'package:restaurant_app/features/pedidos/presentation/pages/pedido_mesa_publica_page.dart';
import 'package:restaurant_app/features/home/presentation/pages/empresa_config_page.dart';

/// Configuración de rutas de la aplicación.
///
/// Usa [GoRouter] con [ShellRoute] para mantener la barra
/// de navegación lateral persistente en todas las secciones.
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  /// Rutas nombradas para navegación tipada.
  static const String login = '/login';
  static const String home = '/';
  static const String mesas = '/mesas';
  static const String pedidos = '/pedidos';
  static const String nuevoPedido = '/pedidos/nuevo';
  static const String cocina = '/cocina';
  static const String menu = '/menu';
  static const String menuPublico = '/menu-public';
  static const String reservas = '/reservas';
  static const String reservasPublico = '/reservas-public';
  static const String cotizaciones = '/cotizaciones';
  static const String cotizacionNueva = '/cotizaciones/nueva';
  static const String caja = '/caja';
  static const String reportes = '/reportes';
  static const String usuarios = '/usuarios';
  static const String sincronizacion = '/sincronizacion';
  static const String restaurantePublico = '/restaurante';
  static const String restauranteConfig = '/restaurante-config';
  static const String driveBackup = '/drive-backup';

  /// Ruta pública de cotización (sin auth): /c/:id
  static const String cotizacionPublica = '/c';

  static String cotizacionPublicaUrl(String id) => '/c/$id';
  static const String clientes = '/clientes';
  static const String empresaConfig = '/empresa-config';

  /// Ruta pública para que el cliente haga su pedido desde la mesa (via QR).
  static const String pedidoMesa = '/pedido-mesa';

  /// Retorna la ruta inicial según el rol del usuario.
  static String homeRouteForRole(RolUsuario rol) {
    return switch (rol) {
      RolUsuario.cocina => cocina,
      _ => home,
    };
  }

  /// Valida si un rol puede acceder a una ruta concreta.
  ///
  /// Esta función centraliza la política de acceso para evitar duplicidad
  /// entre router, navegación lateral y otras pantallas.
  static bool isRouteAllowedForRole(RolUsuario rol, String location) {
    if (rol.esAdmin) return true;

    if (location == menuPublico || location.startsWith('$menuPublico/')) {
      return true;
    }
    if (location == reservasPublico ||
        location.startsWith('$reservasPublico/')) {
      return true;
    }
    if (location == restaurantePublico ||
        location.startsWith('$restaurantePublico/')) {
      return true;
    }

    final accessByRoute = <String, bool Function(RolUsuario)>{
      home: (r) => r.puedeVerInicio,
      mesas: (r) => r.puedeGestionarMesas,
      pedidos: (r) => r.puedeGestionarPedidos,
      cocina: (r) => r.puedeGestionarCocina,
      menu: (r) => r.puedeGestionarMenu,
      reservas: (r) => r.puedeGestionarReservas,
      cotizaciones: (r) => r.puedeGestionarCotizaciones,
      caja: (r) => r.puedeGestionarCaja,
      reportes: (r) => r.puedeVerReportes,
      usuarios: (r) => r.puedeGestionarUsuarios,
      clientes: (r) => r.puedeGestionarClientes,
      sincronizacion: (r) => r.puedeSincronizar,
      restauranteConfig: (r) => r.esAdmin,
      empresaConfig: (r) => r.esAdmin,
      driveBackup: (r) => r.esAdmin,
    };

    return accessByRoute.entries.any(
      (entry) =>
          (location == entry.key || location.startsWith('${entry.key}/')) &&
          entry.value(rol),
    );
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: home,
    refreshListenable: Listenable.merge([
      sl<AuthChangeNotifier>(),
      sl<ActivationChangeNotifier>(),
    ]),
    redirect: (context, state) {
      final auth = sl<AuthChangeNotifier>();
      final activation = sl<ActivationChangeNotifier>();
      final isLoggedIn = auth.isAuthenticated;
      final isLoginRoute = state.matchedLocation == login;
      final loc = state.matchedLocation;

      // Las rutas públicas son accesibles siempre, sin importar activación
      // ni autenticación (clientes externos que escanean QR, por ejemplo).
      final isPublicRoute =
          loc == menuPublico ||
          loc.startsWith('$menuPublico/') ||
          loc == reservasPublico ||
          loc.startsWith('$reservasPublico/') ||
          loc == restaurantePublico ||
          loc.startsWith('$restaurantePublico/') ||
          loc == pedidoMesa ||
          loc.startsWith('$pedidoMesa/') ||
          loc.startsWith('$cotizacionPublica/');

      if (isPublicRoute) return null;

      // A partir de aquí la ruta requiere la app activada.
      if (!activation.canAccessApp && !isLoginRoute) return login;
      if (!activation.canAccessApp && isLoginRoute) return null;

      if (!isLoggedIn && !isLoginRoute) return login;
      if (isLoggedIn && isLoginRoute) {
        final target = homeRouteForRole(auth.usuario!.rol);
        return state.matchedLocation == target ? null : target;
      }
      if (isLoggedIn &&
          !isRouteAllowedForRole(auth.usuario!.rol, state.matchedLocation)) {
        final target = homeRouteForRole(auth.usuario!.rol);
        return state.matchedLocation == target ? null : target;
      }
      return null;
    },
    routes: [
      // ── Login (fuera del shell) ──────────────────────────────────
      GoRoute(
        path: login,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginPage()),
      ),

      // ── Menu publico (sin autenticacion) ─────────────────────────
      GoRoute(
        path: menuPublico,
        pageBuilder: (context, state) {
          final mesaId = state.uri.queryParameters['mesa'];
          return NoTransitionPage(child: MenuPublicPage(mesaId: mesaId));
        },
      ),

      // ── Reservas publicas (sin autenticacion) ─────────────────────
      GoRoute(
        path: reservasPublico,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: ReservasPublicPage()),
      ),
      // ── Página pública del restaurante (sin autenticación) ────────
      GoRoute(
        path: restaurantePublico,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: RestaurantePublicPage()),
      ), // ── Vista pública de cotización (sin autenticación) ──────────
      GoRoute(
        path: '$cotizacionPublica/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return NoTransitionPage(
            child: CotizacionPublicaPage(cotizacionId: id),
          );
        },
      ), // ── Pedido por mesa via QR (sin autenticación) ───────────────
      GoRoute(
        path: pedidoMesa,
        pageBuilder: (context, state) {
          final mesaId = state.uri.queryParameters['mesa'] ?? '';
          final mesaNombre = state.uri.queryParameters['nombre'] ?? '';
          return NoTransitionPage(
            child: PedidoMesaPublicaPage(
              mesaId: mesaId,
              mesaNombre: mesaNombre,
            ),
          );
        },
      ),
      // Shell route: Mantiene el scaffold principal con NavigationRail
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: home,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: mesas,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MesasPage()),
          ),
          GoRoute(
            path: pedidos,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PedidosPage()),
          ),
          GoRoute(
            path: nuevoPedido,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NuevoPedidoPage()),
          ),
          GoRoute(
            path: cocina,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CocinaPage()),
          ),
          GoRoute(
            path: menu,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MenuPage()),
          ),
          GoRoute(
            path: reservas,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReservasPage()),
          ),
          GoRoute(
            path: cotizaciones,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CotizacionesPage()),
          ),
          GoRoute(
            path: cotizacionNueva,
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: CotizacionManualFormPage());
            },
          ),
          GoRoute(
            path: caja,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CajaPage()),
          ),
          GoRoute(
            path: reportes,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportesPage()),
          ),
          GoRoute(
            path: usuarios,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UsuariosPage()),
          ),
          GoRoute(
            path: clientes,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ClientesPage()),
          ),
          GoRoute(
            path: sincronizacion,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SincronizacionPage()),
          ),
          GoRoute(
            path: restauranteConfig,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: RestauranteConfigPage()),
          ),
          GoRoute(
            path: empresaConfig,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmpresaConfigPage()),
          ),
          GoRoute(
            path: driveBackup,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BackupPage()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Página no encontrada: ${state.uri}')),
    ),
  );
}
