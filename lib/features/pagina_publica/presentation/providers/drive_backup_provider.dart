import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/services/database_service.dart';
import 'package:restaurant_app/services/drive_backup_service.dart';

// ── Estado ────────────────────────────────────────────────────────────────────

class DriveBackupState {
  final bool isSignedIn;
  final bool needsDriveConsent;
  final String? userEmail;
  final bool isLoading;
  final String? lastMessage;
  final bool lastSuccess;
  final DateTime? lastBackupDate;

  const DriveBackupState({
    this.isSignedIn = false,
    this.needsDriveConsent = false,
    this.userEmail,
    this.isLoading = false,
    this.lastMessage,
    this.lastSuccess = false,
    this.lastBackupDate,
  });

  DriveBackupState copyWith({
    bool? isSignedIn,
    bool? needsDriveConsent,
    String? userEmail,
    bool? isLoading,
    String? lastMessage,
    bool? lastSuccess,
    DateTime? lastBackupDate,
    bool clearMessage = false,
  }) => DriveBackupState(
    isSignedIn: isSignedIn ?? this.isSignedIn,
    needsDriveConsent: needsDriveConsent ?? this.needsDriveConsent,
    userEmail: userEmail ?? this.userEmail,
    isLoading: isLoading ?? this.isLoading,
    lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
    lastSuccess: lastSuccess ?? this.lastSuccess,
    lastBackupDate: lastBackupDate ?? this.lastBackupDate,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DriveBackupNotifier extends StateNotifier<DriveBackupState> {
  DriveBackupNotifier({
    DriveBackupService? service,
    bool autoCheckSignIn = true,
  }) : _service = service ?? sl<DriveBackupService>(),
       super(const DriveBackupState()) {
    if (autoCheckSignIn) {
      _checkSignIn();
    }
  }

  final DriveBackupService _service;

  Future<void> _checkSignIn() async {
    final account = await _service.signInSilently();
    if (account != null) {
      final lastDate = await _service.lastBackupDate();
      // Verificar si la cuenta ya tiene token Drive válido (sin UI).
      final hasDrive = await _service.ensureDriveAuthenticated(
        interactive: false,
      );
      state = state.copyWith(
        isSignedIn: true,
        userEmail: account.email,
        lastBackupDate: lastDate,
        needsDriveConsent: !hasDrive,
      );
    }
  }

  Future<void> signIn() async {
    state = state.copyWith(isLoading: true, clearMessage: true);
    final account = await _service.signIn();
    if (account != null) {
      final lastDate = await _service.lastBackupDate();
      state = state.copyWith(
        isLoading: false,
        isSignedIn: true,
        userEmail: account.email,
        lastBackupDate: lastDate,
        lastMessage: 'Sesión iniciada como ${account.email}',
        lastSuccess: true,
        needsDriveConsent: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        lastMessage: 'Inicio de sesión cancelado o fallido.',
        lastSuccess: false,
      );
    }
  }

  /// Pide interactivamente consentimiento para Drive (si hace falta).
  Future<void> connectDriveInteractively() async {
    state = state.copyWith(isLoading: true, clearMessage: true);
    final granted = await _service.ensureDriveAuthenticated(interactive: true);
    if (granted) {
      final lastDate = await _service.lastBackupDate();
      state = state.copyWith(
        isLoading: false,
        isSignedIn: true,
        userEmail: _service.currentEmail,
        lastBackupDate: lastDate,
        lastMessage: 'Drive autorizado correctamente.',
        lastSuccess: true,
        needsDriveConsent: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        lastMessage: 'No se concedieron permisos para Drive.',
        lastSuccess: false,
      );
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const DriveBackupState(
      lastMessage: 'Sesión de Google cerrada.',
      lastSuccess: true,
    );
  }

  Future<void> backup() async {
    state = state.copyWith(isLoading: true, clearMessage: true);
    final result = await _service.backup();
    state = state.copyWith(
      isLoading: false,
      lastMessage: result.message,
      lastSuccess: result.success,
      lastBackupDate: result.success ? result.timestamp : state.lastBackupDate,
    );
  }

  Future<void> restore() async {
    state = state.copyWith(isLoading: true, clearMessage: true);
    // Cerrar la BD antes de reemplazar el archivo
    await DatabaseHelper.instance.close();
    await DatabaseService.closeDatabase();
    final result = await _service.restore();
    // Reabrir la BD para que la app siga funcionando
    await DatabaseHelper.instance.database;
    await DatabaseService.database;
    state = state.copyWith(
      isLoading: false,
      lastMessage: result.message,
      lastSuccess: result.success,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final driveBackupProvider =
    StateNotifierProvider<DriveBackupNotifier, DriveBackupState>(
      (ref) => DriveBackupNotifier(),
    );
