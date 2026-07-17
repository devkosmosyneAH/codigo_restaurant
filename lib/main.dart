import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/app_startup/app_startup.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/theme/app_theme.dart';
import 'package:restaurant_app/features/auth/presentation/providers/activation_provider.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurant_app/core/sync/hybrid_sync_orchestrator.dart';

/// Punto de entrada de la aplicación RestaurantApp.
///
/// Inicializa:
/// 1. Inyección de dependencias (GetIt)
/// 2. Base de datos SQLite
/// 3. Riverpod (gestión de estado)
/// 4. Material App con GoRouter
///

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🌍 INICIALIZAR LOCALIZACIÓN PARA FECHAS
  await initializeDateFormatting('es', null);

  // 🖥️ CONFIGURAR TAMAÑO DE VENTANA PARA DESKTOP
  await initializeDesktopWindow();

  // 🔧 INICIALIZACIÓN ESPECÍFICA POR PLATAFORMA
  await initializePlatformSpecific();

  // �🗄️ INICIALIZAR BASE DE DATOS DE FORMA SEGURA
  await initDependencies();

  // Cargar activación local (demo/licencia) antes de restaurar la sesión.
  await sl<ActivationChangeNotifier>().loadStatus();

  // Restaurar sesión local si existe para entrar directo al rol anterior.
  // Se retrasa hasta el primer frame para que GoRouter ya esté montado y
  // evitar redirecciones prematuras durante la inicialización.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    sl<AuthChangeNotifier>().restoreSession();
  });

  // Iniciar sincronizacion hibrida automatica (push + pull realtime).
  await sl<HybridSyncOrchestrator>().start();

  runApp(const ProviderScope(child: RestaurantApp()));
}

/// Widget raíz de la aplicación.
class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // ── Configuración general ─────────────────────────────────
      title: 'La Peña • Sistema de Gestión',
      debugShowCheckedModeBanner: false,

      // ── Localización ──────────────────────────────────────────
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      locale: const Locale('es', 'ES'),

      // ── Tema Material 3 ───────────────────────────────────────
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      // ── Router ────────────────────────────────────────────────
      routerConfig: AppRouter.router,
    );
  }
}
