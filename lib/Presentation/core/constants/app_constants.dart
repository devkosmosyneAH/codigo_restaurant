/// Constantes globales de la aplicación.
///
/// Centraliza valores fijos usados en toda la app para evitar
/// magic numbers y facilitar mantenimiento.
class AppConstants {
  AppConstants._();

  // ── Información de la App ──────────────────────────────────────────
  static const String appName = 'La Peña';
  static const String appFullName = 'La Peña Bar & Restaurant';
  static const String appVersion = '1.0.0';

  // ── Activación local (demo / licencia fija) ─────────────────────────────
  static const String demoActivationCode = 'DEMO-LAPENA-7D';
  static const String fullActivationCode = 'LAPENA-FULL-2026';
  static const Duration demoActivationDuration = Duration(days: 7);

  // ── Moneda ───────────────────────────────────────────────────────────────
  static const String currencySymbol = '\$';
  static const String currencyCode = 'USD';

  // ── Contacto ─────────────────────────────────────────────────────────────
  static const String facebookUrl =
      'https://www.facebook.com/profile.php?id=100089948505536';
  static const String contactPhone = '099 464 5989';
  static const String contactWhatsapp = '0994645989';
  static const String contactEmail = 'barhouse69@gmail.com';
  static const String contactInstagram =
      'https://www.instagram.com/bar_house69/';

  // ── Base de datos ────────────────────────────────────────────────────────
  /// Nombre único de la base SQLite compartido por móvil y desktop.
  static const String databaseName = 'data.db';
  static const int databaseVersion = 36;

  // ── Facturación electrónica / SRI ───────────────────────────────────────
  /// Endpoint base del backend puente para facturación electrónica.
  /// La conexión real queda preparada, pero desactivada/comentada por ahora.
  static const String sriBridgeBaseUrl = 'https://api.tu-dominio.com/sri';
  static const String sriBridgeInvoicePath = '/facturacion/facturas';
  static const String sriBridgeCertificatePath = '/certificados';
  static const String sriBridgeAuthorizePath = '/facturacion/autorizar';
  static const String sriBridgeStatusPath = '/facturacion/estado';
  static const String sriBridgeEmailPath = '/facturacion/email';
  static const String sriEnvironment = 'pruebas';

  // ── Menú público (QR) ─────────────────────────────────────────────
  /// URL base del menú público para generar QR.
  static const String publicMenuBaseUrl =
      'https://menu.restaurante.com/menu-public';

  /// URL base para el QR de pedido por mesa (clientes piden desde su mesa).
  static const String publicOrderBaseUrl =
      'https://menu.restaurante.com/pedido-mesa';

  // ── Multi-restaurante ────────────────────────────────────────────────────
  /// ID del restaurante La Peña.
  static const String defaultRestaurantId = 'la_pena_001';

  // ── Reservaciones ─────────────────────────────────────────────────
  static const int reservaDuracionMinutos = 90;
  static const int restaurantOpeningHour = 10;
  static const int restaurantClosingHour = 23;

  // ── Estados de Mesa ────────────────────────────────────────────────
  static const String mesaLibre = 'libre';
  static const String mesaOcupada = 'ocupada';
  static const String mesaReservada = 'reservada';

  // ── Estados de Pedido ──────────────────────────────────────────────
  static const String pedidoCreado = 'creado';
  static const String pedidoAceptado = 'aceptado';
  static const String pedidoEnPreparacion = 'en_preparacion';
  static const String pedidoFinalizado = 'finalizado';
  static const String pedidoEntregado = 'entregado';

  // ── Métodos de Pago ────────────────────────────────────────────────
  static const String pagoEfectivo = 'efectivo';
  static const String pagoTarjeta = 'tarjeta';
  static const String pagoTransferencia = 'transferencia';

  // ── Roles ──────────────────────────────────────────────────────────
  static const String rolAdministrador = 'administrador';
  static const String rolCajero = 'cajero';
  static const String rolMesero = 'mesero';
  static const String rolCocina = 'cocina';

  // ── Actualizaciones automáticas ───────────────────────────────────
  /// URL del JSON público con la última versión disponible.
  /// Puede ser un GitHub Gist (raw) o cualquier host estático.
  /// Dejar vacío ('') para desactivar el chequeo.
  /// Ejemplo de URL de Gist:
  ///   https://gist.githubusercontent.com/tu-usuario/ID_GIST/raw/version.json
  static const String versionCheckUrl =
      'https://gist.githubusercontent.com/tu-usuario/REEMPLAZAR/raw/version.json';

  // ── Sync ───────────────────────────────────────────────────────────
  static const Duration syncInterval = Duration(minutes: 5);
  static const int maxSyncRetries = 3;
}
