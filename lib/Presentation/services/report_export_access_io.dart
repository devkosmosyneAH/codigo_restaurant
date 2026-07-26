import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

Future<Map<String, dynamic>> exportCsvReport({
  required String fileName,
  required String csvContent,
}) async {
  try {
    String? targetPath;

    try {
      targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte CSV',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
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
      targetPath = p.join(directory, fileName);
    }

    if (p.extension(targetPath).toLowerCase() != '.csv') {
      targetPath = '$targetPath.csv';
    }

    final normalizedContent = csvContent.replaceAll(RegExp(r'\r?\n'), '\r\n');
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(normalizedContent)];

    final file = File(targetPath);
    await file.writeAsBytes(bytes, flush: true);

    return {
      'success': true,
      'cancelled': false,
      'path': targetPath,
      'message': 'Reporte CSV guardado en: $targetPath',
    };
  } catch (_) {
    return {
      'success': false,
      'cancelled': false,
      'message': 'No se pudo exportar el reporte CSV.',
    };
  }
}
