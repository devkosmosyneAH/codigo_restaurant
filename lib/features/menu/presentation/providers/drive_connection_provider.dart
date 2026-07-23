import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurant_app/features/menu/data/services/drive_menu_connection_service.dart';
import 'package:restaurant_app/services/drive_auth_coordinator.dart';

/// Estado de la conexión Drive para el panel admin.
enum DriveConnectionStatus { unknown, checking, connected, disconnected }

/// Estado inmutable que refleja la conexión Drive actual.
class DriveConnectionState {
  final DriveConnectionStatus status;
  final String? email;
  final String? error;

  /// `true` si el popup OAuth fue bloqueado por el navegador (solo web).
  final bool isPopupBlocked;

  const DriveConnectionState({
    this.status = DriveConnectionStatus.unknown,
    this.email,
    this.error,
    this.isPopupBlocked = false,
  });

  bool get isConnected => status == DriveConnectionStatus.connected;
  bool get isChecking => status == DriveConnectionStatus.checking;
  bool get isDisconnected => status == DriveConnectionStatus.disconnected;
  bool get isUnknown => status == DriveConnectionStatus.unknown;

  DriveConnectionState copyWith({
    DriveConnectionStatus? status,
    String? email,
    String? error,
    bool clearError = false,
    bool? isPopupBlocked,
  }) {
    return DriveConnectionState(
      status: status ?? this.status,
      email: email ?? this.email,
      error: clearError ? null : (error ?? this.error),
      isPopupBlocked: isPopupBlocked ?? this.isPopupBlocked,
    );
  }
}

/// Gestiona el estado de autenticación Drive en el panel admin.
///
/// Uso:
/// - Llamar [checkSilently] en initState del admin panel para restaurar
///   sesión sin mostrar popup.
/// - Llamar [connectInteractively] cuando el usuario toca "Conectar Drive"
///   (gesto directo del usuario, garantiza que el popup no sea bloqueado).
class DriveConnectionNotifier extends StateNotifier<DriveConnectionState> {
  final DriveMenuConnectionService _service;

  DriveConnectionNotifier(this._service)
    : super(const DriveConnectionState(status: DriveConnectionStatus.unknown));

  /// Verifica Drive silenciosamente.
  ///
  /// No muestra popup ni solicita login al usuario. Ideal para llamar
  /// automáticamente en [initState] del panel de menú.
  Future<void> checkSilently() async {
    if (state.isChecking) return;
    final auth = sl<AuthChangeNotifier>();
    if (!auth.isAuthenticated) {
      state = const DriveConnectionState(
        status: DriveConnectionStatus.disconnected,
        error: 'Inicia sesión para administrar Google Drive.',
      );
      return;
    }
    state = state.copyWith(
      status: DriveConnectionStatus.checking,
      clearError: true,
    );
    final result = await _service.ensureDriveAuthenticated(interactive: false);
    state = _fromResult(result);
  }

  /// Inicia OAuth interactivo para conectar Drive.
  ///
  /// **Debe ser llamado desde un gesto directo del usuario** (onPressed de
  /// un botón) para que el popup no sea bloqueado en navegadores web.
  ///
  /// Devuelve `true` si Drive quedó conectado correctamente.
  Future<bool> connectInteractively() async {
    if (state.isChecking) return false;
    final auth = sl<AuthChangeNotifier>();
    if (!auth.isAuthenticated) {
      state = const DriveConnectionState(
        status: DriveConnectionStatus.disconnected,
        error: 'Inicia sesión para administrar Google Drive.',
      );
      return false;
    }
    state = state.copyWith(
      status: DriveConnectionStatus.checking,
      clearError: true,
    );
    final result = await _service.ensureDriveAuthenticated(interactive: true);
    state = _fromResult(result);
    return result.isConnected;
  }

  /// Fuerza un re-check silencioso (p.ej. después de que el diálogo de
  /// producto fue cerrado y el estado puede haber cambiado).
  Future<void> refresh() => checkSilently();

  DriveConnectionState _fromResult(DriveAuthResult result) {
    return switch (result.status) {
      DriveAuthStatus.connected => DriveConnectionState(
        status: DriveConnectionStatus.connected,
        email: result.email,
      ),
      DriveAuthStatus.notConnected => const DriveConnectionState(
        status: DriveConnectionStatus.disconnected,
      ),
      DriveAuthStatus.error => DriveConnectionState(
        status: DriveConnectionStatus.disconnected,
        error: result.message,
        isPopupBlocked: result.isPopupBlocked,
      ),
    };
  }
}

/// Provider global del estado de conexión Drive.
///
/// Consumir con `ref.watch(driveConnectionProvider)` para estado reactivo.
/// Llamar `ref.read(driveConnectionProvider.notifier).checkSilently()` o
/// `.connectInteractively()` para acciones.
final driveConnectionProvider =
    StateNotifierProvider<DriveConnectionNotifier, DriveConnectionState>((ref) {
      return DriveConnectionNotifier(sl<DriveMenuConnectionService>());
    });
