Future<Map<String, dynamic>> getBackupOverview() async {
  return {
    'supported': false,
    'message':
        'Los respaldos automáticos están disponibles en Android, Windows, Linux y macOS. En la versión web no se pueden gestionar archivos locales.',
    'stats': const <String, dynamic>{},
    'backups': const <Map<String, dynamic>>[],
    'dbInfo': const <String, dynamic>{},
  };
}

Future<bool> createManualBackup({String? customName}) async => false;

Future<bool> restoreBackup(String backupName) async => false;

Future<bool> deleteBackup(String backupName) async => false;

Future<Map<String, dynamic>> exportBackup(String backupName) async {
  return {
    'success': false,
    'cancelled': false,
    'message':
        'Exportar respaldos no está disponible en la versión web de la app.',
  };
}

Future<Map<String, dynamic>> importBackupFile() async {
  return {
    'success': false,
    'cancelled': false,
    'message':
        'Importar respaldos no está disponible en la versión web de la app.',
  };
}
