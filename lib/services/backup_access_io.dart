import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/services/backup_service.dart';
import 'package:restaurant_app/services/database_location_service.dart';
import 'package:restaurant_app/services/database_service.dart';

Future<Map<String, dynamic>> getBackupOverview() async {
  final stats = await BackupService.getBackupStats();
  final backups = await BackupService.listBackups();
  final dbInfo = await DatabaseService.getDatabaseInfo();

  return {
    'supported': true,
    'message': null,
    'stats': stats,
    'backups': backups,
    'dbInfo': dbInfo,
  };
}

Future<bool> createManualBackup({String? customName}) {
  return DatabaseService.createManualBackup(customName: customName);
}

Future<bool> restoreBackup(String backupName) async {
  await DatabaseHelper.instance.close();
  await DatabaseService.closeDatabase();

  try {
    return await BackupService.restoreFromBackup(backupName);
  } finally {
    await DatabaseHelper.instance.database;
    await DatabaseService.database;
  }
}

Future<bool> deleteBackup(String backupName) {
  return BackupService.deleteBackup(backupName);
}

Future<Map<String, dynamic>> exportBackup(String backupName) async {
  try {
    final backupDir = await _getBackupDirectory();
    final sourcePath = p.join(backupDir, '$backupName.db');
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      return {
        'success': false,
        'cancelled': false,
        'message': 'No se encontró el respaldo seleccionado.',
      };
    }

    String? targetPath;
    try {
      targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar respaldo en otra ubicación',
        fileName: '$backupName.db',
        type: FileType.custom,
        allowedExtensions: const ['db'],
      );
    } catch (_) {
      targetPath = null;
    }

    if (targetPath == null) {
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecciona la carpeta de destino',
      );
      if (directory == null) {
        return {
          'success': false,
          'cancelled': true,
          'message': 'Exportación cancelada.',
        };
      }
      targetPath = p.join(directory, '$backupName.db');
    }

    if (p.extension(targetPath).toLowerCase() != '.db') {
      targetPath = '$targetPath.db';
    }

    await sourceFile.copy(targetPath);

    return {
      'success': true,
      'cancelled': false,
      'path': targetPath,
      'message': 'Respaldo exportado en: $targetPath',
    };
  } catch (_) {
    return {
      'success': false,
      'cancelled': false,
      'message': 'No se pudo exportar el respaldo.',
    };
  }
}

Future<Map<String, dynamic>> importBackupFile() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecciona un respaldo .db',
      type: FileType.custom,
      allowedExtensions: const ['db'],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return {
        'success': false,
        'cancelled': true,
        'message': 'Importación cancelada.',
      };
    }

    final sourcePath = result.files.single.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      return {
        'success': false,
        'cancelled': false,
        'message': 'No se pudo leer el archivo seleccionado.',
      };
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return {
        'success': false,
        'cancelled': false,
        'message': 'El archivo seleccionado ya no existe.',
      };
    }

    final backupDir = await _getBackupDirectory();
    await Directory(backupDir).create(recursive: true);

    final cleanName = _sanitizeBackupName(
      p.basenameWithoutExtension(sourcePath),
    );
    final importedName =
        'import_${cleanName}_${DateTime.now().millisecondsSinceEpoch}';
    final destinationPath = p.join(backupDir, '$importedName.db');

    await sourceFile.copy(destinationPath);

    return {
      'success': true,
      'cancelled': false,
      'backupName': importedName,
      'path': destinationPath,
      'message':
          'Respaldo importado correctamente. Ya puedes restaurarlo desde la lista.',
    };
  } catch (_) {
    return {
      'success': false,
      'cancelled': false,
      'message': 'No se pudo importar el archivo de respaldo.',
    };
  }
}

Future<String> _getBackupDirectory() async {
  final dbPath = await DatabaseLocationService.getDatabasePath();
  return p.join(p.dirname(dbPath), 'backups');
}

String _sanitizeBackupName(String value) {
  final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
  return sanitized.isEmpty ? 'respaldo' : sanitized;
}
