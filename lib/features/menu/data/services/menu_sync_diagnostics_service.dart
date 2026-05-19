import 'package:flutter/foundation.dart';

class MenuSyncDiagnosticsSnapshot {
  final bool driveConnected;
  final String? driveAccountEmail;
  final DateTime? tokenExpiresAt;
  final DateTime? lastUploadAt;
  final bool? lastUploadOk;
  final String? lastUploadFileId;
  final String? lastUploadUrl;
  final DateTime? lastRealtimeSyncAt;
  final bool? lastRealtimeSyncOk;
  final String? lastRealtimeSyncOperation;
  final int pendingQueueCount;
  final String? lastError;
  final DateTime? lastErrorAt;
  final DateTime? lastCleanupAt;
  final int lastCleanupScanned;
  final int lastCleanupCandidates;
  final int lastCleanupDeleted;
  final bool lastCleanupDryRun;
  final String? lastCleanupMessage;
  final DateTime updatedAt;

  const MenuSyncDiagnosticsSnapshot({
    required this.driveConnected,
    required this.driveAccountEmail,
    required this.tokenExpiresAt,
    required this.lastUploadAt,
    required this.lastUploadOk,
    required this.lastUploadFileId,
    required this.lastUploadUrl,
    required this.lastRealtimeSyncAt,
    required this.lastRealtimeSyncOk,
    required this.lastRealtimeSyncOperation,
    required this.pendingQueueCount,
    required this.lastError,
    required this.lastErrorAt,
    required this.lastCleanupAt,
    required this.lastCleanupScanned,
    required this.lastCleanupCandidates,
    required this.lastCleanupDeleted,
    required this.lastCleanupDryRun,
    required this.lastCleanupMessage,
    required this.updatedAt,
  });
}

class MenuSyncDiagnosticsService extends ChangeNotifier {
  bool _driveConnected = false;
  String? _driveAccountEmail;
  DateTime? _tokenExpiresAt;
  DateTime? _lastUploadAt;
  bool? _lastUploadOk;
  String? _lastUploadFileId;
  String? _lastUploadUrl;
  DateTime? _lastRealtimeSyncAt;
  bool? _lastRealtimeSyncOk;
  String? _lastRealtimeSyncOperation;
  int _pendingQueueCount = 0;
  String? _lastError;
  DateTime? _lastErrorAt;
  DateTime? _lastCleanupAt;
  int _lastCleanupScanned = 0;
  int _lastCleanupCandidates = 0;
  int _lastCleanupDeleted = 0;
  bool _lastCleanupDryRun = false;
  String? _lastCleanupMessage;
  DateTime _updatedAt = DateTime.now();

  MenuSyncDiagnosticsSnapshot get snapshot => MenuSyncDiagnosticsSnapshot(
    driveConnected: _driveConnected,
    driveAccountEmail: _driveAccountEmail,
    tokenExpiresAt: _tokenExpiresAt,
    lastUploadAt: _lastUploadAt,
    lastUploadOk: _lastUploadOk,
    lastUploadFileId: _lastUploadFileId,
    lastUploadUrl: _lastUploadUrl,
    lastRealtimeSyncAt: _lastRealtimeSyncAt,
    lastRealtimeSyncOk: _lastRealtimeSyncOk,
    lastRealtimeSyncOperation: _lastRealtimeSyncOperation,
    pendingQueueCount: _pendingQueueCount,
    lastError: _lastError,
    lastErrorAt: _lastErrorAt,
    lastCleanupAt: _lastCleanupAt,
    lastCleanupScanned: _lastCleanupScanned,
    lastCleanupCandidates: _lastCleanupCandidates,
    lastCleanupDeleted: _lastCleanupDeleted,
    lastCleanupDryRun: _lastCleanupDryRun,
    lastCleanupMessage: _lastCleanupMessage,
    updatedAt: _updatedAt,
  );

  void updateDriveStatus({
    required bool connected,
    String? accountEmail,
    DateTime? tokenExpiresAt,
    String? error,
  }) {
    _driveConnected = connected;
    _driveAccountEmail = accountEmail;
    _tokenExpiresAt = tokenExpiresAt;
    if (error != null && error.trim().isNotEmpty) {
      _lastError = error.trim();
      _lastErrorAt = DateTime.now();
    }
    _touch();
  }

  void recordUploadSuccess({
    required String fileId,
    required String publicUrl,
  }) {
    _lastUploadAt = DateTime.now();
    _lastUploadOk = true;
    _lastUploadFileId = fileId;
    _lastUploadUrl = publicUrl;
    _touch();
  }

  void recordUploadFailure(Object error) {
    _lastUploadAt = DateTime.now();
    _lastUploadOk = false;
    _lastError = error.toString();
    _lastErrorAt = DateTime.now();
    _touch();
  }

  void recordRealtimeSync({
    required bool success,
    required String operation,
    String? details,
  }) {
    _lastRealtimeSyncAt = DateTime.now();
    _lastRealtimeSyncOk = success;
    _lastRealtimeSyncOperation = operation;
    if (!success && details != null && details.trim().isNotEmpty) {
      _lastError = details.trim();
      _lastErrorAt = DateTime.now();
    }
    _touch();
  }

  void updatePendingQueueCount(int count) {
    _pendingQueueCount = count < 0 ? 0 : count;
    _touch();
  }

  void recordCleanup({
    required int scanned,
    required int orphanCandidates,
    required int deleted,
    required bool dryRun,
    String? message,
  }) {
    _lastCleanupAt = DateTime.now();
    _lastCleanupScanned = scanned;
    _lastCleanupCandidates = orphanCandidates;
    _lastCleanupDeleted = deleted;
    _lastCleanupDryRun = dryRun;
    _lastCleanupMessage = message;
    _touch();
  }

  void recordError(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    _lastError = trimmed;
    _lastErrorAt = DateTime.now();
    _touch();
  }

  void clearError() {
    _lastError = null;
    _lastErrorAt = null;
    _touch();
  }

  void _touch() {
    _updatedAt = DateTime.now();
    notifyListeners();
  }
}
