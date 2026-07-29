import 'package:restaurant_app/Presentation/core/database/database_helper.dart';
import 'package:restaurant_app/Presentation/services/backup_access.dart' as backup_access;
import 'package:restaurant_app/Presentation/services/database_service.dart';

Future<void> initializeDesktopWindow() async {}

Future<void> initializePlatformSpecific() async {}

Future<void> initDatabaseSafely() async {
  // Deshabilitado: no se inicializa SQLite local.
  DatabaseHelper.disableLocalDatabase();
  DatabaseService.disableLocalDatabase();
  await backup_access.performAutomaticBackupIfNeeded();
}
