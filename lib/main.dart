import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:restaurant_app/Presentation/app_startup/app_startup.dart';
import 'package:restaurant_app/Presentation/config/routes/app_router.dart';
import 'package:restaurant_app/Presentation/core/di/injection_container.dart';
import 'package:restaurant_app/Presentation/core/firebase/firebase_initializer.dart';
import 'package:restaurant_app/Presentation/core/theme/app_theme.dart';
import 'package:restaurant_app/Presentation/providers/auth/activation_provider.dart';
import 'package:restaurant_app/Presentation/providers/auth/auth_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  return runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);

        debugPrint('==================== FLUTTER ERROR ====================');
        debugPrint(details.exceptionAsString());
        debugPrintStack(stackTrace: details.stack);
        debugPrint('=======================================================');
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        debugPrint('================ PLATFORM ERROR =================');
        debugPrint(error.toString());
        debugPrintStack(stackTrace: stack);
        debugPrint('=================================================');
        return true;
      };

      try {
        debugPrint('STEP 1 - initializeDateFormatting');
        await initializeDateFormatting('es', null);

        debugPrint('STEP 2 - initializeDesktopWindow');
        await initializeDesktopWindow();

        debugPrint('STEP 3 - initializePlatformSpecific');
        await initializePlatformSpecific();

        debugPrint('STEP 4 - initDatabaseSafely');
        await initDatabaseSafely();

        debugPrint('STEP 5 - FirebaseAppInitializer.initialize');
        await FirebaseAppInitializer.initialize();

        debugPrint('STEP 6 - initDependencies');
        await initDependencies();

        debugPrint('STEP 7 - ActivationChangeNotifier.loadStatus');
        await sl<ActivationChangeNotifier>().loadStatus();

        debugPrint('STEP 8 - AuthChangeNotifier.restoreSession');
        await sl<AuthChangeNotifier>().restoreSession();

        debugPrint('STEP 9 - runApp');

        runApp(const ProviderScope(child: RestaurantApp()));
      } catch (e, s) {
        debugPrint('================ ERROR EN MAIN =================');
        debugPrint(e.toString());
        debugPrintStack(stackTrace: s);
        debugPrint('================================================');

        rethrow;
      }
    },
    (error, stack) {
      debugPrint('================ ZONE ERROR =================');
      debugPrint(error.toString());
      debugPrintStack(stackTrace: stack);
      debugPrint('==============================================');
    },
  );
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'La Peña • Sistema de Gestión',

      debugShowCheckedModeBanner: false,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],

      locale: const Locale('es', 'ES'),

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      routerConfig: AppRouter.router,
    );
  }
}
