import 'package:equatable/equatable.dart';

/// Clase base para errores del dominio.
///
/// Todas las fallas deben extender de [Failure] para mantener
/// un contrato uniforme en la capa de dominio.
abstract class Failure extends Equatable {
  final String message;
  final int? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Error relacionado con la base de datos local (SQLite).
class DatabaseFailure extends Failure {
  const DatabaseFailure({required super.message, super.code});
}

/// Error de servidor / Firebase / sincronización.
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Error de caché o almacenamiento local.
class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.code});
}

/// Error de regla de negocio (validación, duplicados, etc.).
class BusinessFailure extends Failure {
  const BusinessFailure({required super.message, super.code});
}

/// Error de validación de datos.
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

/// Error genérico / inesperado.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({required super.message, super.code});
}
