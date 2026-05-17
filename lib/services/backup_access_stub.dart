import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/services/web_json_file_bridge.dart'
    as web_json_file_bridge;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const String _backupIndexKey = 'web_backup_index_v1';
const String _backupConfigKey = 'web_backup_config_v1';
const String _backupPayloadPrefix = 'web_backup_payload_v1_';

const Map<String, dynamic> _defaultConfig = {
  'autoBackupEnabled': true,
  'backupIntervalHours': 24,
  'maxBackupFiles': 10,
  'lastBackupTime': null,
};

final DateFormat _dtFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

typedef WebJsonExportHook =
    Future<String?> Function(String fileName, String jsonContent);
typedef WebJsonImportHook = Future<String?> Function();

WebJsonExportHook _webJsonExportHook = _defaultWebJsonExportHook;
WebJsonImportHook _webJsonImportHook = _defaultWebJsonImportHook;

@visibleForTesting
void setWebBackupJsonHooks({
  WebJsonExportHook? exportHook,
  WebJsonImportHook? importHook,
}) {
  _webJsonExportHook = exportHook ?? _defaultWebJsonExportHook;
  _webJsonImportHook = importHook ?? _defaultWebJsonImportHook;
}

Future<String?> _defaultWebJsonExportHook(String fileName, String jsonContent) {
  return web_json_file_bridge.saveJsonFile(
    fileName: fileName,
    jsonContent: jsonContent,
  );
}

Future<String?> _defaultWebJsonImportHook() {
  return web_json_file_bridge.pickJsonFileContent();
}

Future<void> performAutomaticBackupIfNeeded() async {
  await _performAutomaticBackupIfNeededInternal();
}

Future<Map<String, dynamic>> getBackupOverview() async {
  await _performAutomaticBackupIfNeededInternal();

  final db = await DatabaseHelper.instance.database;
  final dbSizeMb = await _estimateDbSizeMb(db);
  final backups = await _readBackupEntries();
  final config = await _readBackupConfig();

  DateTime? lastBackup;
  final lastRaw = config['lastBackupTime'];
  if (lastRaw is String && lastRaw.isNotEmpty) {
    lastBackup = DateTime.tryParse(lastRaw);
  }

  return {
    'supported': true,
    'supportsImportExport': true,
    'storageType': 'browser',
    'message':
        'En web, los respaldos se guardan dentro del navegador y pueden exportarse/importarse en formato JSON.',
    'stats': {
      'totalBackups': backups.length,
      'lastBackupTime': lastBackup,
      'autoBackupEnabled': config['autoBackupEnabled'] ?? true,
      'backupIntervalHours': config['backupIntervalHours'] ?? 24,
      'maxBackupFiles': config['maxBackupFiles'] ?? 10,
    },
    'backups': backups
        .map(
          (b) => {
            'name': b.name,
            'created': b.createdAt,
            'size': b.sizeBytes / (1024 * 1024),
            'sizeFormatted': _formatSize(b.sizeBytes),
            'createdFormatted': _dtFmt.format(b.createdAt),
          },
        )
        .toList(),
    'dbInfo': {
      'path': 'SQLite Web (IndexedDB del navegador)',
      'exists': true,
      'sizeMB': dbSizeMb,
      'storageType': 'browser',
    },
  };
}

Future<bool> createManualBackup({String? customName}) async {
  return _createBackup(customName: customName);
}

Future<bool> restoreBackup(String backupName) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final snapshotJson = prefs.getString(_payloadKey(backupName));
    if (snapshotJson == null || snapshotJson.isEmpty) {
      return false;
    }

    final decoded = jsonDecode(snapshotJson);
    if (decoded is! Map) return false;

    final tablesRaw = decoded['tables'];
    if (tablesRaw is! Map) return false;
    final snapshotTables = tablesRaw.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    final db = await DatabaseHelper.instance.database;

    var restoredTables = 0;

    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');

      final existingTables = await _listUserTables(txn);

      for (final entry in snapshotTables.entries) {
        final table = entry.key;
        if (!existingTables.contains(table)) continue;

        try {
          await txn.delete(table);

          final rows = entry.value;
          if (rows is List) {
            for (final rawRow in rows) {
              if (rawRow is! Map) continue;
              final row = <String, Object?>{};
              rawRow.forEach((key, value) {
                row[key.toString()] = _decodeValue(value);
              });
              if (row.isNotEmpty) {
                await txn.insert(
                  table,
                  row,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }

          restoredTables++;
        } catch (_) {
          // Evitar que una tabla problemática impida restaurar el resto.
        }
      }

      await txn.execute('PRAGMA foreign_keys = ON');
    });

    return restoredTables > 0;
  } catch (_) {
    return false;
  }
}

Future<bool> deleteBackup(String backupName) async {
  final prefs = await SharedPreferences.getInstance();
  final entries = await _readBackupEntries();
  entries.removeWhere((e) => e.name == backupName);

  final removedPayload = await prefs.remove(_payloadKey(backupName));
  final indexSaved = await _writeBackupEntries(entries, prefs: prefs);

  return removedPayload || indexSaved;
}

Future<Map<String, dynamic>> exportBackup(String backupName) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_payloadKey(backupName));
    if (payload == null || payload.isEmpty) {
      return {
        'success': false,
        'cancelled': false,
        'message': 'No se encontró el respaldo seleccionado.',
      };
    }

    final entries = await _readBackupEntries();
    final entry = entries.where((e) => e.name == backupName).firstOrNull;

    final snapshot = jsonDecode(payload);
    if (!_isValidSnapshot(snapshot)) {
      return {
        'success': false,
        'cancelled': false,
        'message': 'El respaldo seleccionado tiene un formato inválido.',
      };
    }

    final exportDoc = {
      'format': 'lapena-web-backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'backup': {
        'name': backupName,
        if (entry != null) 'createdAt': entry.createdAt.toIso8601String(),
        if (entry != null) 'sizeBytes': entry.sizeBytes,
      },
      'snapshot': snapshot,
    };

    final jsonContent = const JsonEncoder.withIndent('  ').convert(exportDoc);
    final suggestedFileName = '$backupName.json';
    final savedName = await _webJsonExportHook(suggestedFileName, jsonContent);

    if (savedName == null) {
      return {
        'success': false,
        'cancelled': true,
        'message': 'Exportación cancelada.',
      };
    }

    return {
      'success': true,
      'cancelled': false,
      'fileName': savedName,
      'message': 'Respaldo exportado correctamente en formato JSON.',
    };
  } catch (_) {
    return {
      'success': false,
      'cancelled': false,
      'message': 'No se pudo exportar el respaldo en JSON.',
    };
  }
}

Future<Map<String, dynamic>> importBackupFile() async {
  try {
    final content = await _webJsonImportHook();
    if (content == null) {
      return {
        'success': false,
        'cancelled': true,
        'message': 'Importación cancelada.',
      };
    }

    final decoded = jsonDecode(content);

    dynamic snapshot;
    String? importedBaseName;

    if (decoded is Map && decoded['snapshot'] != null) {
      snapshot = decoded['snapshot'];
      final backupMeta = decoded['backup'];
      if (backupMeta is Map && backupMeta['name'] != null) {
        importedBaseName = backupMeta['name'].toString();
      }
    } else {
      snapshot = decoded;
    }

    if (!_isValidSnapshot(snapshot)) {
      return {
        'success': false,
        'cancelled': false,
        'message': 'Archivo inválido. Se esperaba un respaldo JSON compatible.',
      };
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final baseName = _sanitizeBackupName(
      importedBaseName ?? _generateBackupName(prefix: 'import_'),
    );
    final backupName = await _resolveUniqueName('import_$baseName', prefs);

    final snapshotJson = jsonEncode(snapshot);
    final sizeBytes = utf8.encode(snapshotJson).length;

    final payloadSaved = await prefs.setString(
      _payloadKey(backupName),
      snapshotJson,
    );
    if (!payloadSaved) {
      return {
        'success': false,
        'cancelled': false,
        'message': 'No se pudo guardar el respaldo importado.',
      };
    }

    final entries = await _readBackupEntries();
    entries.insert(
      0,
      _WebBackupEntry(name: backupName, createdAt: now, sizeBytes: sizeBytes),
    );

    await _enforceMaxBackups(entries, prefs);
    await _writeBackupEntries(entries, prefs: prefs);
    await _updateLastBackupTime(now, prefs: prefs);

    return {
      'success': true,
      'cancelled': false,
      'backupName': backupName,
      'message':
          'Respaldo JSON importado correctamente. Ya puedes restaurarlo desde la lista.',
    };
  } catch (_) {
    return {
      'success': false,
      'cancelled': false,
      'message': 'No se pudo importar el archivo JSON.',
    };
  }
}

Future<bool> _createBackup({String? customName}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final baseName = _sanitizeBackupName(
      customName ?? _generateBackupName(prefix: 'manual_'),
    );
    final backupName = await _resolveUniqueName(baseName, prefs);

    final snapshot = await _captureSnapshot(createdAt: now);
    final snapshotJson = jsonEncode(snapshot);
    final sizeBytes = utf8.encode(snapshotJson).length;

    final payloadSaved = await prefs.setString(
      _payloadKey(backupName),
      snapshotJson,
    );
    if (!payloadSaved) return false;

    final entries = await _readBackupEntries();
    entries.removeWhere((e) => e.name == backupName);
    entries.insert(
      0,
      _WebBackupEntry(name: backupName, createdAt: now, sizeBytes: sizeBytes),
    );

    final config = await _readBackupConfig();
    final maxFiles = (config['maxBackupFiles'] as num?)?.toInt() ?? 10;

    await _enforceMaxBackups(entries, prefs, maxFilesOverride: maxFiles);

    await _writeBackupEntries(entries, prefs: prefs);
    await _updateLastBackupTime(now, prefs: prefs);

    return true;
  } catch (_) {
    return false;
  }
}

Future<Map<String, dynamic>> _captureSnapshot({
  required DateTime createdAt,
}) async {
  final db = await DatabaseHelper.instance.database;
  final tables = await _listUserTables(db);

  final tableData = <String, dynamic>{};

  for (final table in tables) {
    final rows = await db.query(table);
    tableData[table] = rows.map(_encodeRow).toList();
  }

  return {
    'version': 1,
    'createdAt': createdAt.toIso8601String(),
    'tables': tableData,
  };
}

Future<void> _performAutomaticBackupIfNeededInternal() async {
  final config = await _readBackupConfig();
  final enabled = config['autoBackupEnabled'] != false;
  if (!enabled) return;

  final intervalHours = (config['backupIntervalHours'] as num?)?.toInt() ?? 24;
  DateTime? lastBackup;
  final lastRaw = config['lastBackupTime'];
  if (lastRaw is String && lastRaw.isNotEmpty) {
    lastBackup = DateTime.tryParse(lastRaw);
  }

  if (lastBackup == null) {
    await _createBackup(customName: _generateBackupName(prefix: 'auto_'));
    return;
  }

  final hoursSinceLast = DateTime.now().difference(lastBackup).inHours;
  if (hoursSinceLast >= intervalHours) {
    await _createBackup(customName: _generateBackupName(prefix: 'auto_'));
  }
}

Future<List<String>> _listUserTables(DatabaseExecutor db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' "
    "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
  );

  final result = rows
      .map((row) => row['name']?.toString())
      .whereType<String>()
      .toList();
  result.sort();
  return result;
}

Future<double> _estimateDbSizeMb(Database db) async {
  try {
    final pageCountRows = await db.rawQuery('PRAGMA page_count');
    final pageSizeRows = await db.rawQuery('PRAGMA page_size');

    if (pageCountRows.isEmpty || pageSizeRows.isEmpty) {
      return 0.0;
    }

    final pageCount = (pageCountRows.first.values.first as num?)?.toInt() ?? 0;
    final pageSize = (pageSizeRows.first.values.first as num?)?.toInt() ?? 0;

    if (pageCount <= 0 || pageSize <= 0) return 0.0;
    return (pageCount * pageSize) / (1024 * 1024);
  } catch (_) {
    return 0.0;
  }
}

Future<Map<String, dynamic>> _readBackupConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_backupConfigKey);
  if (raw == null || raw.isEmpty) {
    return Map<String, dynamic>.from(_defaultConfig);
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return Map<String, dynamic>.from(_defaultConfig);
    }
    final merged = Map<String, dynamic>.from(_defaultConfig);
    merged.addAll(decoded.map((key, value) => MapEntry(key.toString(), value)));
    return merged;
  } catch (_) {
    return Map<String, dynamic>.from(_defaultConfig);
  }
}

Future<void> _updateLastBackupTime(
  DateTime timestamp, {
  SharedPreferences? prefs,
}) async {
  final sp = prefs ?? await SharedPreferences.getInstance();
  final config = await _readBackupConfig();
  config['lastBackupTime'] = timestamp.toIso8601String();
  await sp.setString(_backupConfigKey, jsonEncode(config));
}

Future<List<_WebBackupEntry>> _readBackupEntries() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_backupIndexKey);
  if (raw == null || raw.isEmpty) return [];

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    final entries = decoded
        .map(_WebBackupEntry.tryParse)
        .whereType<_WebBackupEntry>()
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  } catch (_) {
    return [];
  }
}

Future<bool> _writeBackupEntries(
  List<_WebBackupEntry> entries, {
  SharedPreferences? prefs,
}) async {
  final sp = prefs ?? await SharedPreferences.getInstance();
  entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
  return sp.setString(_backupIndexKey, raw);
}

Future<String> _resolveUniqueName(
  String baseName,
  SharedPreferences prefs,
) async {
  String candidate = baseName;
  var suffix = 1;
  while (prefs.containsKey(_payloadKey(candidate))) {
    candidate = '${baseName}_$suffix';
    suffix++;
  }
  return candidate;
}

Future<void> _enforceMaxBackups(
  List<_WebBackupEntry> entries,
  SharedPreferences prefs, {
  int? maxFilesOverride,
}) async {
  final config = await _readBackupConfig();
  final maxFiles =
      maxFilesOverride ?? (config['maxBackupFiles'] as num?)?.toInt() ?? 10;

  while (entries.length > maxFiles) {
    final removed = entries.removeLast();
    await prefs.remove(_payloadKey(removed.name));
  }
}

bool _isValidSnapshot(dynamic snapshot) {
  if (snapshot is! Map) return false;
  final tables = snapshot['tables'];
  return tables is Map;
}

String _payloadKey(String backupName) => '$_backupPayloadPrefix$backupName';

String _sanitizeBackupName(String value) {
  final trimmed = value.trim();
  final cleaned = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
  return cleaned.isEmpty ? _generateBackupName(prefix: 'manual_') : cleaned;
}

String _generateBackupName({String prefix = ''}) {
  final now = DateTime.now();
  final stamp =
      '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  return '${prefix}backup_$stamp';
}

String _formatSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }
  final kb = bytes / 1024;
  return '${kb.toStringAsFixed(1)} KB';
}

Map<String, dynamic> _encodeRow(Map<String, Object?> row) {
  return row.map((key, value) => MapEntry(key, _encodeValue(value)));
}

dynamic _encodeValue(Object? value) {
  if (value is Uint8List) {
    return {'__type': 'bytes', 'base64': base64Encode(value)};
  }
  return value;
}

Object? _decodeValue(dynamic value) {
  if (value is Map && value['__type'] == 'bytes') {
    final b64 = value['base64']?.toString();
    if (b64 != null) {
      return base64Decode(b64);
    }
  }
  return value;
}

class _WebBackupEntry {
  const _WebBackupEntry({
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String name;
  final DateTime createdAt;
  final int sizeBytes;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'sizeBytes': sizeBytes,
    };
  }

  static _WebBackupEntry? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final name = raw['name']?.toString();
    final createdRaw = raw['createdAt']?.toString();
    final sizeRaw = raw['sizeBytes'];

    if (name == null || name.isEmpty || createdRaw == null) return null;
    final createdAt = DateTime.tryParse(createdRaw);
    if (createdAt == null) return null;

    final sizeBytes = (sizeRaw as num?)?.toInt() ?? 0;

    return _WebBackupEntry(
      name: name,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
    );
  }
}
