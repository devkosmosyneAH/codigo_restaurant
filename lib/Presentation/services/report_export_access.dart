import 'report_export_access_stub.dart'
    if (dart.library.io) 'report_export_access_io.dart'
    as impl;

Future<Map<String, dynamic>> exportCsvReport({
  required String fileName,
  required String csvContent,
}) => impl.exportCsvReport(fileName: fileName, csvContent: csvContent);
