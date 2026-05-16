import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_app/core/database/database_helper.dart';
import 'package:restaurant_app/services/database_service.dart';
import 'package:restaurant_app/services/drive_backup_service.dart';

// ── Estado ────────────────────────────────────────────────────────────────────

class DriveBackupState {
  final bool isSignedIn;
  final String? userEmail;
  final bool isLoading;
  final String? lastMessage;
  final bool lastSuccess;
  final DateTime? lastBackupDate;

  const DriveBackupState({
    this.isSignedIn = false,
    this.userEmail,
    this.isLoading = false,
    this.lastMessage,
    this.lastSuccess = false,
    this.lastBackupDate,
  });

  DriveBackupState copyWith({
    bool? isSignedIn,
    String? userEmail,
    bool? isLoading,
    String? lastMessage,
    bool? lastSuccess,
    DateTime? lastBackupDate,
    bool clearMessage = false,
  }) => DriveBackupState(
    isSignedIn: isSignedIn ?? this.isSignedIn,
    userEmail: userEmail ?? this.userEmail,
    isLoading: isLoading ?? this.isLoading,
    lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
    lastSuccess: lastSuccess ?? this.lastSuccess,
    lastBackupDate: lastBackupDate ?? this.lastBackupDate,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DriveBackupNotifier extends StateNotifier<DriveBackupState> {
  DriveBackupNotifier() : super(const DriveBackupState()) {
    _checkSignIn();
  }

  final _service = DriveBackupService.instance;

  Future<void> _checkSignIn() async {
    final account = await _service.signInSilently();
    if (account != null) {
      final lastDate = await _service.lastBackupDate();
      state = state.copyWith(
        isSignedIn: true,
        userEmail: account.email,
        lastBackupDate: lastDate,
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
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        lastMessage: 'Inicio de sesión cancelado o fallido.',
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
