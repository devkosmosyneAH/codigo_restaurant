import 'backup_access_stub.dart'
    if (dart.library.io) 'backup_access_io.dart'
    as impl;

Future<Map<String, dynamic>> getBackupOverview() => impl.getBackupOverview();

Future<bool> createManualBackup({String? customName}) =>
    impl.createManualBackup(customName: customName);

Future<bool> restoreBackup(String backupName) => impl.restoreBackup(backupName);

Future<bool> deleteBackup(String backupName) => impl.deleteBackup(backupName);

Future<Map<String, dynamic>> exportBackup(String backupName) =>
    impl.exportBackup(backupName);

Future<Map<String, dynamic>> importBackupFile() => impl.importBackupFile();
