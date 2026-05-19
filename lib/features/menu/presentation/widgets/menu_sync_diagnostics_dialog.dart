import 'package:flutter/material.dart';

import 'package:restaurant_app/core/di/injection_container.dart';
import 'package:restaurant_app/features/menu/data/services/drive_image_sync_queue_service.dart';
import 'package:restaurant_app/features/menu/data/services/drive_menu_connection_service.dart';
import 'package:restaurant_app/features/menu/data/services/menu_sync_diagnostics_service.dart';

class MenuSyncDiagnosticsDialog extends StatefulWidget {
  const MenuSyncDiagnosticsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const MenuSyncDiagnosticsDialog(),
    );
  }

  @override
  State<MenuSyncDiagnosticsDialog> createState() =>
      _MenuSyncDiagnosticsDialogState();
}

class _MenuSyncDiagnosticsDialogState extends State<MenuSyncDiagnosticsDialog> {
  late final MenuSyncDiagnosticsService _diagnostics;
  late final DriveImageSyncQueueService _queueService;
  late final DriveMenuConnectionService _driveService;

  bool _isRefreshing = false;
  bool _isCleaning = false;
  bool _dryRun = true;

  @override
  void initState() {
    super.initState();
    _diagnostics = sl<MenuSyncDiagnosticsService>();
    _queueService = sl<DriveImageSyncQueueService>();
    _driveService = sl<DriveMenuConnectionService>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final connected = await _driveService.restoreSessionSilently();
      await _queueService.countPendingOperations();
      _diagnostics.updateDriveStatus(
        connected: connected,
        accountEmail: _driveService.currentEmail,
      );
    } catch (e) {
      _diagnostics.recordError('Error al refrescar diagnóstico: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _runCleanup() async {
    if (_isCleaning) return;
    setState(() => _isCleaning = true);

    try {
      final result = await _queueService.cleanupOrphanedDriveImages(
        dryRun: _dryRun,
        allowInteractiveSignIn: true,
      );

      if (!mounted) return;
      final modeLabel = _dryRun ? 'simulación' : 'limpieza';
      final suffix = result.message == null || result.message!.trim().isEmpty
          ? ''
          : '\n${result.message}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$modeLabel completada: '
            '${result.orphanCandidates} huérfanas detectadas, '
            '${result.deleted} eliminadas.$suffix',
          ),
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en limpieza de huérfanas: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCleaning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: const Text('Diagnóstico interno de Menú/Drive'),
      content: SizedBox(
        width: 560,
        child: AnimatedBuilder(
          animation: _diagnostics,
          builder: (context, _) {
            final snapshot = _diagnostics.snapshot;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kvRow(
                    title: 'Drive conectado',
                    value: snapshot.driveConnected ? 'OK' : 'NO',
                    valueColor: snapshot.driveConnected
                        ? Colors.green.shade700
                        : cs.error,
                  ),
                  _kvRow(
                    title: 'Cuenta',
                    value: snapshot.driveAccountEmail ?? 'N/D',
                  ),
                  _kvRow(
                    title: 'Último upload',
                    value: _statusWithTime(
                      ok: snapshot.lastUploadOk,
                      at: snapshot.lastUploadAt,
                    ),
                  ),
                  _kvRow(
                    title: 'Último sync RTDB',
                    value: _statusWithTime(
                      ok: snapshot.lastRealtimeSyncOk,
                      at: snapshot.lastRealtimeSyncAt,
                      suffix: snapshot.lastRealtimeSyncOperation,
                    ),
                  ),
                  _kvRow(
                    title: 'Pendientes en cola',
                    value: snapshot.pendingQueueCount.toString(),
                  ),
                  _kvRow(
                    title: 'Último error',
                    value: snapshot.lastError == null
                        ? 'Ninguno'
                        : '${snapshot.lastError} '
                              '(${_formatDateTime(snapshot.lastErrorAt)})',
                    valueColor: snapshot.lastError == null ? null : cs.error,
                  ),
                  _kvRow(
                    title: 'Token expiración',
                    value: _formatTokenExpiry(snapshot.tokenExpiresAt),
                  ),
                  _kvRow(
                    title: 'Limpieza huérfanas',
                    value:
                        '${snapshot.lastCleanupCandidates} candidatas, '
                        '${snapshot.lastCleanupDeleted} eliminadas '
                        '(${snapshot.lastCleanupDryRun ? 'dry-run' : 'real'}) '
                        '· ${_formatDateTime(snapshot.lastCleanupAt)}',
                  ),
                  if (snapshot.lastCleanupMessage != null &&
                      snapshot.lastCleanupMessage!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        snapshot.lastCleanupMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _dryRun,
                        onChanged: (_isCleaning || _isRefreshing)
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _dryRun = value);
                              },
                      ),
                      const Expanded(
                        child: Text(
                          'Dry run (solo detectar huérfanas, sin borrar)',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: (_isRefreshing || _isCleaning) ? null : _refresh,
          child: _isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Refrescar'),
        ),
        OutlinedButton.icon(
          onPressed: (_isRefreshing || _isCleaning) ? null : _runCleanup,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: Text(_dryRun ? 'Simular limpieza' : 'Limpiar ahora'),
        ),
        FilledButton(
          onPressed: _isRefreshing || _isCleaning
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _kvRow({
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: valueColor)),
          ),
        ],
      ),
    );
  }

  String _statusWithTime({
    required bool? ok,
    required DateTime? at,
    String? suffix,
  }) {
    final base = switch (ok) {
      true => 'OK',
      false => 'ERROR',
      null => 'N/D',
    };

    final withTime = at == null ? base : '$base (${_formatDateTime(at)})';
    if (suffix == null || suffix.trim().isEmpty) return withTime;
    return '$withTime · $suffix';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'N/D';
    final local = value.toLocal();

    String two(int n) {
      return n.toString().padLeft(2, '0');
    }

    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _formatTokenExpiry(DateTime? expiresAt) {
    if (expiresAt == null) return 'N/D';
    final now = DateTime.now();
    final diff = expiresAt.difference(now);
    if (diff.inSeconds <= 0) {
      return 'Expirado';
    }
    return '${diff.inMinutes} min (${_formatDateTime(expiresAt)})';
  }
}
