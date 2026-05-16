import 'package:restaurant_app/core/utils/typedefs.dart';
import 'package:restaurant_app/features/cotizaciones/domain/entities/cotizacion.dart';

/// Contrato del repositorio de cotizaciones.
abstract class CotizacionRepository {
  /// Crea una cotizacion.
  ResultFuture<void> createCotizacion(Cotizacion cotizacion);

  /// Lista cotizaciones por restaurante.
  ResultFuture<List<Cotizacion>> getCotizaciones(String restaurantId);

  /// Actualiza estado de una cotizacion.
  ResultFuture<void> updateEstado(String cotizacionId, String estado);

  /// Actualiza todos los campos de una cotizacion (reemplaza sus items).
  ResultFuture<void> updateCotizacion(Cotizacion cotizacion);

  /// Elimina una cotizacion y sus items.
  ResultFuture<void> deleteCotizacion(String cotizacionId);
}
