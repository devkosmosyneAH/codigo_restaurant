import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/app_startup/app_startup.dart';
import 'package:restaurant_app/config/routes/app_router.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/firebase/firebase_initializer.dart';
import 'package:restaurant_app/core/theme/app_theme.dart';
import 'package:restaurant_app/features/auth/presentation/providers/activation_provider.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurant_app/core/sync/hybrid_sync_orchestrator.dart';
import 'package:restaurant_app/services/drive_auth_coordinator.dart';

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

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    debugPrint(details.exceptionAsString());
    debugPrintStack(stackTrace: details.stack);
  };

  try {
    debugPrint('STEP 1 - initializeDateFormatting');
    await initializeDateFormatting('es', null);

    debugPrint('STEP 2 - initializeDesktopWindow');
    await initializeDesktopWindow();

    debugPrint('STEP 3 - initializePlatformSpecific');
    await initializePlatformSpecific();

    debugPrint('STEP 4 - FirebaseAppInitializer.initialize');
    await FirebaseAppInitializer.initialize();

    debugPrint('STEP 5 - initDependencies');
    await initDependencies();

    debugPrint('STEP 6 - ActivationChangeNotifier.loadStatus');
    await sl<ActivationChangeNotifier>().loadStatus();

    // Mover la restauración de sesión de Google a post-frame para evitar
    // condiciones de carrera con la inicialización de plugins nativos.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        debugPrint('STEP 7 - DriveAuthCoordinator.restoreSessionSilently (post frame)');
        await sl<DriveAuthCoordinator>().restoreSessionSilently();

        debugPrint('STEP 8 - AuthChangeNotifier.restoreSession (post frame)');
        await sl<AuthChangeNotifier>().restoreSession();
      } catch (e, st) {
        debugPrint('ERROR EN RESTORE SESSIONS (post frame)');
        debugPrint(e.toString());
        debugPrintStack(stackTrace: st);
        // No rethrow: evitar bloquear el arranque por problemas de sesión.
      }
    });

    debugPrint('STEP 9 - HybridSyncOrchestrator.start');
    await sl<HybridSyncOrchestrator>().start();

    debugPrint('STEP 10 - runApp');
    runApp(const ProviderScope(child: RestaurantApp()));
  } catch (e, s) {
    debugPrint('==============================');
    debugPrint('ERROR EN MAIN');
    debugPrint(e.toString());
    debugPrintStack(stackTrace: s);
    debugPrint('==============================');
    rethrow;
  }
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
