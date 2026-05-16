import 'package:restaurant_app/core/utils/typedefs.dart';

/// Clase base abstracta para todos los Use Cases.
///
/// Implementa el patrón Command con un único método [call]
/// para mantener la uniformidad en la capa de dominio.
///
/// [Type] = Tipo de dato de retorno exitoso.
/// [Params] = Parámetros que recibe el caso de uso.
abstract class UseCase<Type, Params> {
  const UseCase();

  ResultFuture<Type> call(Params params);
}

/// Use Case sin parámetros.
abstract class UseCaseWithoutParams<Type> {
  const UseCaseWithoutParams();

  ResultFuture<Type> call();
}

/// Clase auxiliar cuando un Use Case no requiere parámetros.
class NoParams {
  const NoParams();
}
