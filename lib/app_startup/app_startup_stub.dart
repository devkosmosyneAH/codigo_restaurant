import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/services/backup_access.dart' as backup_access;

Future<void> initializeDesktopWindow() async {}

Future<void> initializePlatformSpecific() async {}

Future<void> initDatabaseSafely() async {
  await DatabaseHelper.instance.database;
  await backup_access.performAutomaticBackupIfNeeded();
}
