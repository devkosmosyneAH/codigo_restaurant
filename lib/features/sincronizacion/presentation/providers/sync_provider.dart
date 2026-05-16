import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/sync/sync_cloud_service.dart';
import 'package:restaurant_app/core/sync/sync_manager.dart';
import 'package:restaurant_app/core/sync/sync_record.dart';

// ── Estado ─────────────────────────────────────────────────────────────────────

class SyncState {
  /// Todos los registros del log (pendientes + sincronizados).
  final List<SyncRecord> registros;
  final bool isLoading;
  final bool isSyncing;
  final bool isCheckingCloud;
  final bool? cloudAvailable;
  final String? cloudStatusMessage;
  final DateTime? ultimaSync;
  final String? error;
  final String? successMessage;

  const SyncState({
    this.registros = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.isCheckingCloud = false,
    this.cloudAvailable,
    this.cloudStatusMessage,
    this.ultimaSync,
    this.error,
    this.successMessage,
  });

  List<SyncRecord> get pendientes =>
      registros.where((r) => !r.sincronizado).toList();

  List<SyncRecord> get sincronizados =>
      registros.where((r) => r.sincronizado).toList();

  int get totalPendientes => pendientes.length;
  bool get tienePendientes => pendientes.isNotEmpty;

  SyncState copyWith({
    List<SyncRecord>? registros,
    bool? isLoading,
    bool? isSyncing,
    bool? isCheckingCloud,
    bool? cloudAvailable,
    String? cloudStatusMessage,
    bool clearCloudStatus = false,
    DateTime? ultimaSync,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return SyncState(
      registros: registros ?? this.registros,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isCheckingCloud: isCheckingCloud ?? this.isCheckingCloud,
      cloudAvailable: cloudAvailable ?? this.cloudAvailable,
      cloudStatusMessage: clearCloudStatus
          ? null
          : cloudStatusMessage ?? this.cloudStatusMessage,
      ultimaSync: ultimaSync ?? this.ultimaSync,
      error: clearError ? null : error ?? this.error,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier({
    required SyncManager syncManager,
    required SyncCloudService cloudService,
  }) : _cloudService = cloudService,
       _syncManager = syncManager,
       super(const SyncState()) {
    loadRegistros();
    checkCloudAvailability();
    // Refresca cada 30 segundos para reflejar operaciones recientes de la app
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => loadRegistros(),
    );
  }

  final SyncManager _syncManager;
  final SyncCloudService _cloudService;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Carga todos los registros del sync_log.
  Future<void> loadRegistros() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final pendientes = await _syncManager.obtenerPendientes();
      final sincronizados = await _syncManager.obtenerSincronizados();
      state = state.copyWith(
        isLoading: false,
        registros: [...pendientes, ...sincronizados],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Verifica si la sincronización en nube está disponible.
  Future<void> checkCloudAvailability() async {
    state = state.copyWith(
      isCheckingCloud: true,
      clearCloudStatus: true,
      clearError: true,
    );

    try {
      await _cloudService.ensureAvailable();
      state = state.copyWith(
        isCheckingCloud: false,
        cloudAvailable: true,
        cloudStatusMessage: 'Nube disponible para sincronizar',
      );
    } catch (_) {
      state = state.copyWith(
        isCheckingCloud: false,
        cloudAvailable: false,
        cloudStatusMessage:
            'Nube no disponible. Revisa la configuración de Firebase.',
      );
    }
  }

  /// Sincroniza cada registro pendiente enviándolo a Firestore.
  ///
  /// Solo marca como sincronizado cuando el push remoto finaliza correctamente.
  Future<void> sincronizarAhora() async {
    if (!state.tienePendientes) {
      state = state.copyWith(
        successMessage: 'No hay operaciones pendientes de sincronizar',
      );
      return;
    }

    state = state.copyWith(isSyncing: true, clearError: true);

    // Fallar rápido si Firebase/Firestore no está listo, para evitar
    // incrementar intentos de cada registro por un problema global.
    try {
      await _cloudService.ensureAvailable();
      state = state.copyWith(
        cloudAvailable: true,
        cloudStatusMessage: 'Nube disponible para sincronizar',
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        cloudAvailable: false,
        cloudStatusMessage:
            'Nube no disponible. Revisa la configuración de Firebase.',
        error: e.toString(),
      );
      return;
    }

    int procesados = 0;
    int errores = 0;

    for (final record in state.pendientes) {
      try {
        await _cloudService.pushRecord(record);
        await _syncManager.marcarSincronizado(record.id);
        procesados++;
      } catch (e) {
        await _syncManager.incrementarIntentos(record.id);
        errores++;
      }
    }

    final msg = errores == 0
        ? '$procesados operación(es) sincronizada(s) correctamente'
        : '$procesados sincronizadas, $errores con error';

    state = state.copyWith(
      isSyncing: false,
      ultimaSync: DateTime.now(),
      successMessage: msg,
    );

    await loadRegistros();
  }

  /// Elimina del log todos los registros ya sincronizados con más de [dias] días.
  Future<void> limpiarHistorial({int dias = 7}) async {
    state = state.copyWith(isLoading: true);
    try {
      await _syncManager.limpiarSincronizados(dias: dias);
      await loadRegistros();
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Historial limpiado (registros > $dias días)',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(syncManager: sl(), cloudService: sl());
});
