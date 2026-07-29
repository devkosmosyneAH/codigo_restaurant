import 'dart:io';
import 'dart:ui' show Size;
import 'package:restaurant_app/Presentation/core/database/database_helper.dart';
import 'package:restaurant_app/Presentation/services/database_service.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeDesktopWindow() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(null, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await windowManager.setSize(const Size(800, 600));
  await windowManager.setMinimumSize(const Size(400, 300));
  await windowManager.setResizable(true);
  await windowManager.setMinimizable(true);
  await windowManager.setMaximizable(true);
  await windowManager.setClosable(true);
  await windowManager.setTitle('La Peña • Sistema de Gestión');

  if (Platform.isWindows) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await windowManager.restore();
    await windowManager.focus();
  }
}

Future<void> initializePlatformSpecific() async {
  // No database initialization required when using Firebase and Drive only.
  // Mantener deshabilitado cualquier acceso a SQLite local en el arranque.
}

Future<void> initDatabaseSafely() async {
  // Deshabilitado: no se inicializa SQLite local.
  DatabaseHelper.disableLocalDatabase();
  DatabaseService.disableLocalDatabase();
}
