import 'package:restaurant_app/core/database/database_helper.dart';

Future<void> initializeDesktopWindow() async {}

Future<void> initializePlatformSpecific() async {}

Future<void> initDatabaseSafely() async {
  await DatabaseHelper.instance.database;
}
