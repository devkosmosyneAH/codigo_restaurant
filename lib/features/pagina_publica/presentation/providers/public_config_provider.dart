import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/core/tenant/tenant_context.dart';
import 'package:restaurant_app/features/pagina_publica/domain/entities/public_config.dart';
import 'package:restaurant_app/features/pagina_publica/domain/usecases/public_config_usecases.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class PublicConfigState {
  final PublicConfig? config;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? successMessage;

  const PublicConfigState({
    this.config,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.successMessage,
  });

  bool get hasConfig => config != null;

  PublicConfigState copyWith({
    PublicConfig? config,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) => PublicConfigState(
    config: config ?? this.config,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : (error ?? this.error),
    successMessage: clearSuccess
        ? null
        : (successMessage ?? this.successMessage),
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PublicConfigNotifier extends StateNotifier<PublicConfigState> {
  PublicConfigNotifier({
    required GetPublicConfig getConfig,
    required SavePublicConfig saveConfig,
  }) : _getConfig = getConfig,
       _saveConfig = saveConfig,
       super(const PublicConfigState()) {
    load();
  }

  final GetPublicConfig _getConfig;
  final SavePublicConfig _saveConfig;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getConfig(sl<TenantContext>().restaurantId);
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (config) => state = state.copyWith(isLoading: false, config: config),
    );
  }

  Future<bool> save(PublicConfig config) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final result = await _saveConfig(config);
    return result.fold(
      (failure) {
        state = state.copyWith(isSaving: false, error: failure.message);
        return false;
      },
      (saved) {
        state = state.copyWith(
          isSaving: false,
          config: saved,
          successMessage: 'Configuración guardada correctamente.',
        );
        return true;
      },
    );
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final publicConfigProvider =
    StateNotifierProvider<PublicConfigNotifier, PublicConfigState>((ref) {
      return PublicConfigNotifier(getConfig: sl(), saveConfig: sl());
    });
