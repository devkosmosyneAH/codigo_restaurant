import 'package:restaurant_app/features/reservaciones/data/models/reserva_model.dart';

/// Contrato del datasource local para reservaciones.
abstract class ReservaLocalDataSource {
  Future<void> createReserva(ReservaModel reserva);
  Future<void> updateReserva(ReservaModel reserva);
  Future<List<ReservaModel>> getReservasByMonth(
    String restaurantId,
    String startDate,
    String endDate,
  );
  Future<List<ReservaModel>> getReservasByDate(
    String restaurantId,
    String date,
  );
}
