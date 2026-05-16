import 'package:restaurant_app/core/constants/app_constants.dart';
import 'package:restaurant_app/services/session_service.dart';

/// Fuente única de verdad para el contexto del tenant activo en tiempo de ejecución.
///
/// Se inicializa desde [AuthChangeNotifier] tras login o restauración de sesión.
/// Todos los datasources y providers leen [restaurantId] desde aquí en lugar de
/// usar [AppConstants.defaultRestaurantId] directamente.
class TenantContext {
  String _restaurantId = AppConstants.defaultRestaurantId;
  String? _userId;
  String? _rol;

  String get restaurantId => _restaurantId;
  String? get userId => _userId;
  String? get rol => _rol;

  /// Inicializa el contexto con los datos de sesión del usuario autenticado.
  void setFromSession({
    required String restaurantId,
    required String? userId,
    required String? rol,
  }) {
    _restaurantId = restaurantId.isNotEmpty
        ? restaurantId
        : AppConstants.defaultRestaurantId;
    _userId = userId;
    _rol = rol;
  }

  /// Limpia el contexto al cerrar sesión.
  void clear() {
    _restaurantId = AppConstants.defaultRestaurantId;
    _userId = null;
    _rol = null;
  }

  /// Crea e inicializa un [TenantContext] desde la sesión persistida en SharedPreferences.
  static Future<TenantContext> fromCurrentSession() async {
    final session = await SessionService.getCurrentUserSession();
    final ctx = TenantContext();
    if (session != null) {
      ctx.setFromSession(
        restaurantId:
            session['restaurantId'] as String? ??
            AppConstants.defaultRestaurantId,
        userId: session['id'] as String?,
        rol: session['rol'] as String?,
      );
    }
    return ctx;
  }
}
