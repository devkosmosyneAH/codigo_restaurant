import 'package:restaurant_app/Presentation/core/utils/typedefs.dart';
import 'package:restaurant_app/Presentation/entities/reservaciones/reserva.dart';

/// Contrato del repositorio de reservaciones.
abstract class ReservaRepository {
  ResultFuture<void> createReserva(Reserva reserva);
  ResultFuture<void> updateReserva(Reserva reserva);
  ResultFuture<List<Reserva>> getReservasByMonth(
    String restaurantId,
    String startDate,
    String endDate,
  );
  ResultFuture<List<Reserva>> getReservasByDate(
    String restaurantId,
    String date,
  );
}
