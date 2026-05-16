import 'package:restaurant_app/features/cotizaciones/data/models/cotizacion_model.dart';

/// Contrato del datasource local para cotizaciones.
abstract class CotizacionLocalDataSource {
  /// Crea una cotizacion con sus items.
  Future<void> createCotizacion(CotizacionModel cotizacion);

  /// Lista cotizaciones por restaurante.
  Future<List<CotizacionModel>> getCotizaciones(String restaurantId);

  /// Actualiza el estado de una cotizacion.
  Future<void> updateEstado(String cotizacionId, String estado);

  /// Actualiza todos los campos de una cotizacion (reemplaza sus items).
  Future<void> updateCotizacion(CotizacionModel cotizacion);

  /// Elimina una cotizacion y sus items.
  Future<void> deleteCotizacion(String cotizacionId);
}
