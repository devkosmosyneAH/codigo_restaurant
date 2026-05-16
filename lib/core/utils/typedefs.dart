import 'package:dartz/dartz.dart';
import 'package:restaurant_app/core/errors/failures.dart';

/// Alias de tipos comunes usados en toda la aplicación.
///
/// [ResultFuture] facilita el patrón Either para manejar errores
/// funcionales sin lanzar excepciones en la capa de dominio.

/// Resultado asíncrono: [Left] = Failure, [Right] = T (éxito).
typedef ResultFuture<T> = Future<Either<Failure, T>>;

/// Resultado síncrono: [Left] = Failure, [Right] = T (éxito).
typedef ResultSync<T> = Either<Failure, T>;

/// Resultado sin valor de retorno (solo éxito/fallo).
typedef ResultVoid = ResultFuture<void>;

/// Mapa genérico de datos (para JSON, SQLite rows, etc.).
typedef DataMap = Map<String, dynamic>;
