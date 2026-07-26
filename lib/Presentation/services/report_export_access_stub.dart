Future<Map<String, dynamic>> exportCsvReport({
  required String fileName,
  required String csvContent,
}) async {
  return {
    'success': false,
    'cancelled': false,
    'message':
        'La exportación CSV no está disponible en la versión web de la app.',
  };
}
