// Excepciones personalizadas del sistema.
//
// Las excepciones se lanzan en la capa de datos y se convierten
// en [Failure] en la capa de repositorio.

/// Excepción al interactuar con la base de datos local.
class DatabaseException implements Exception {
  final String message;
  final int? code;

  const DatabaseException({required this.message, this.code});

  @override
  String toString() => 'DatabaseException: $message (code: $code)';
}

/// Excepción de comunicación con servidor (Firebase, API).
class ServerException implements Exception {
  final String message;
  final int? code;

  const ServerException({required this.message, this.code});

  @override
  String toString() => 'ServerException: $message (code: $code)';
}

/// Excepción de caché.
class CacheException implements Exception {
  final String message;

  const CacheException({required this.message});

  @override
  String toString() => 'CacheException: $message';
}

/// Excepción de validación de negocio.
class BusinessException implements Exception {
  final String message;

  const BusinessException({required this.message});

  @override
  String toString() => 'BusinessException: $message';
}
