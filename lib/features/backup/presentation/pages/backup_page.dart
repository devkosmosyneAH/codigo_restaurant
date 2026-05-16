import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/features/pagina_publica/presentation/providers/drive_backup_provider.dart';
import 'package:restaurant_app/services/backup_access.dart' as backup_access;

/// Página unificada de respaldos.
/// Combina respaldo local (archivo .db) con respaldo en Google Drive.
/// Solo accesible para administradores.
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm', 'es');
  static final _dtFmtDrive = DateFormat("d MMM y  HH:mm", 'es');

  late Future<Map<String, dynamic>> _localFuture;
  bool _localBusy = false;

  @override
  void initState() {
    super.initState();
    _localFuture = backup_access.getBackupOverview();
  }

  void _reloadLocal() {
    setState(() => _localFuture = backup_access.getBackupOverview());
  }

  void _showMsg(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _crearRespaldo() async {
    setState(() => _localBusy = true);
    final ok = await backup_access.createManualBackup();
    setState(() => _localBusy = false);
    _showMsg(
      ok
          ? 'Respaldo local creado correctamente.'
          : 'No se pudo crear el respaldo.',
      success: ok,
    );
    _reloadLocal();
  }

  Future<void> _importarArchivo() async {
    final result = await backup_access.importBackupFile();
    if (result['cancelled'] == true) return;
    _showMsg(
      result['message']?.toString() ?? 'No se pudo importar el archivo.',
      success: result['success'] == true,
    );
    _reloadLocal();
  }

  Future<void> _exportarRespaldo(String backupName) async {
    final result = await backup_access.exportBackup(backupName);
    if (result['cancelled'] == true) return;
    _showMsg(
      result['message']?.toString() ?? 'Error al exportar.',
      success: result['success'] == true,
    );
  }

  Future<void> _restaurar(Map<String, dynamic> backup) async {
    final confirmado = await _showConfirm(
      title: 'Restaurar respaldo local',
      content:
          'Se reemplazará la base actual por "${backup['name']}".\n\n'
          'Antes se creará una copia de seguridad automática.\n\n'
          '¿Continuar?',
      actionLabel: 'Restaurar',
      actionColor: AppColors.secondary,
    );
    if (confirmado != true) return;

    setState(() => _localBusy = true);
    final ok = await backup_access.restoreBackup(backup['name'].toString());
    setState(() => _localBusy = false);
    _showMsg(
      ok
          ? 'Respaldo restaurado. Reinicia la app para aplicar los cambios.'
          : 'No se pudo restaurar el respaldo.',
      success: ok,
    );
    _reloadLocal();
  }

  Future<void> _eliminar(Map<String, dynamic> backup) async {
    final confirmado = await _showConfirm(
      title: 'Eliminar respaldo',
      content: 'Se eliminará "${backup['name']}" de forma permanente.',
      actionLabel: 'Eliminar',
      actionColor: AppColors.error,
    );
    if (confirmado != true) return;

    final ok = await backup_access.deleteBackup(backup['name'].toString());
    _showMsg(
      ok ? 'Respaldo eliminado.' : 'No se pudo eliminar el respaldo.',
      success: ok,
    );
    _reloadLocal();
  }

  Future<bool?> _showConfirm({
    required String title,
    required String content,
    required String actionLabel,
    Color actionColor = AppColors.primary,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: actionColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              actionLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driveState = ref.watch(driveBackupProvider);
    final driveNotifier = ref.read(driveBackupProvider.notifier);

    // Escuchar resultado de operaciones Drive
    ref.listen(driveBackupProvider.select((s) => s.lastMessage), (_, msg) {
      if (msg != null && mounted) {
        _showMsg(msg, success: driveState.lastSuccess);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F1),
      appBar: AppBar(
        title: const Text('Respaldos del sistema'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Encabezado ────────────────────────────────────────────
          _HeaderCard(),
          const SizedBox(height: 16),

          // ── Sección Local ─────────────────────────────────────────
          _SectionLabel(
            icon: Icons.storage_rounded,
            label: 'Respaldo local',
            color: Colors.indigo,
          ),
          const SizedBox(height: 8),
          _LocalSection(
            future: _localFuture,
            busy: _localBusy,
            dtFmt: _dtFmt,
            onCrear: _crearRespaldo,
            onImportar: _importarArchivo,
            onRefresh: _reloadLocal,
            onExportar: _exportarRespaldo,
            onRestaurar: _restaurar,
            onEliminar: _eliminar,
          ),
          const SizedBox(height: 20),

          // ── Sección Drive (solo en plataformas nativas) ───────────
          if (!kIsWeb) ...[
            _SectionLabel(
              icon: Icons.cloud_sync_rounded,
              label: 'Google Drive',
              color: const Color(0xFF1A73E8),
            ),
            const SizedBox(height: 8),
            _DriveSection(
              state: driveState,
              notifier: driveNotifier,
              dtFmt: _dtFmtDrive,
              onConfirmBackup: () => _confirmDriveBackup(driveNotifier),
              onConfirmRestore: () => _confirmDriveRestore(driveNotifier),
            ),
            const SizedBox(height: 16),
          ] else ...[
            _InfoBanner(
              icon: Icons.info_outline_rounded,
              message:
                  'El respaldo en Google Drive no está disponible en la versión web. '
                  'Usa la app de escritorio o Android.',
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDriveBackup(DriveBackupNotifier notifier) async {
    final ok = await _showConfirm(
      title: 'Subir backup a Drive',
      content:
          'Se subirá la base de datos actual a Google Drive.\n'
          'Si ya existe un respaldo en la nube, se sobrescribirá.\n\n'
          '¿Deseas continuar?',
      actionLabel: 'Subir',
      actionColor: AppColors.primary,
    );
    if (ok == true) await notifier.backup();
  }

  Future<void> _confirmDriveRestore(DriveBackupNotifier notifier) async {
    final ok = await _showConfirm(
      title: 'Restaurar desde Drive',
      content:
          'Esta acción reemplazará los datos actuales con el respaldo de '
          'Google Drive.\n\n'
          'Luego deberás reiniciar la app para aplicar los cambios.\n\n'
          '¿Deseas continuar?',
      actionLabel: 'Restaurar',
      actionColor: AppColors.error,
    );
    if (ok == true) await notifier.restore();
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C57), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.backup_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestión de respaldos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Crea copias de seguridad locales y en Google Drive. '
                  'Restaura datos ante cualquier pérdida.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.blue.shade800, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Local Section ─────────────────────────────────────────────────────────────

class _LocalSection extends StatelessWidget {
  const _LocalSection({
    required this.future,
    required this.busy,
    required this.dtFmt,
    required this.onCrear,
    required this.onImportar,
    required this.onRefresh,
    required this.onExportar,
    required this.onRestaurar,
    required this.onEliminar,
  });

  final Future<Map<String, dynamic>> future;
  final bool busy;
  final DateFormat dtFmt;
  final VoidCallback onCrear;
  final VoidCallback onImportar;
  final VoidCallback onRefresh;
  final ValueChanged<String> onExportar;
  final ValueChanged<Map<String, dynamic>> onRestaurar;
  final ValueChanged<Map<String, dynamic>> onEliminar;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _Card(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final data = snap.data ?? {};
        final supported = data['supported'] == true;

        if (!supported) {
          return _Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                data['message']?.toString() ??
                    'Respaldos locales no disponibles en esta plataforma.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        final stats = Map<String, dynamic>.from(data['stats'] as Map? ?? {});
        final backups = (data['backups'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final dbInfo = Map<String, dynamic>.from(data['dbInfo'] as Map? ?? {});
        final lastBackup = stats['lastBackupTime'] as DateTime?;
        final dbSize = (dbInfo['sizeMB'] as num?)?.toDouble() ?? 0;

        return Column(
          children: [
            // Acciones
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Copia archivos .db en este equipo. Expórtalos para moverlos a otra máquina.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : onCrear,
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Crear respaldo'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onImportar,
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: const Text('Importar .db'),
                      ),
                      IconButton.outlined(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Actualizar lista',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Stats
            _StatRow(
              children: [
                _StatChip(
                  label: 'Respaldos',
                  value: '${stats['totalBackups'] ?? backups.length}',
                  icon: Icons.inventory_2_outlined,
                  color: Colors.indigo,
                ),
                _StatChip(
                  label: 'BD activa',
                  value: '${dbSize.toStringAsFixed(2)} MB',
                  icon: Icons.storage_rounded,
                  color: Colors.teal,
                ),
                _StatChip(
                  label: 'Último',
                  value: lastBackup == null
                      ? 'Nunca'
                      : DateFormat('dd/MM HH:mm').format(lastBackup),
                  icon: Icons.history_toggle_off_rounded,
                  color: Colors.deepOrange,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Ruta BD
            _Card(
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_open_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ubicación de la base de datos',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        Text(
                          dbInfo['path']?.toString() ?? 'No disponible',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Lista de respaldos
            if (backups.isEmpty)
              const _Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Aún no hay respaldos guardados.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            else
              ...backups.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _BackupTile(
                    backup: b,
                    dtFmt: dtFmt,
                    onExportar: () => onExportar(b['name'].toString()),
                    onRestaurar: () => onRestaurar(b),
                    onEliminar: () => onEliminar(b),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Drive Section ─────────────────────────────────────────────────────────────

class _DriveSection extends StatelessWidget {
  const _DriveSection({
    required this.state,
    required this.notifier,
    required this.dtFmt,
    required this.onConfirmBackup,
    required this.onConfirmRestore,
  });

  final DriveBackupState state;
  final DriveBackupNotifier notifier;
  final DateFormat dtFmt;
  final VoidCallback onConfirmBackup;
  final VoidCallback onConfirmRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cuenta
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(
                icon: Icons.account_circle_rounded,
                title: 'Cuenta de Google',
              ),
              const SizedBox(height: 14),
              if (state.isSignedIn) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.userEmail ?? 'Usuario de Google',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Conectado',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: state.isLoading ? null : notifier.signOut,
                      child: const Text(
                        'Cerrar sesión',
                        style: TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (state.lastBackupDate != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Último backup en Drive',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              dtFmt.format(state.lastBackupDate!.toLocal()),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (state.lastBackupDate == null) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Aún no hay respaldos en Drive. Usa "Subir backup ahora" para crear el primero.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ] else ...[
                const Text(
                  'Conéctate con tu cuenta de Google para guardar y restaurar '
                  'copias de seguridad en la nube.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: _GoogleSignInButton(
                    isLoading: state.isLoading,
                    onTap: notifier.signIn,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Acciones (solo si está conectado)
        if (state.isSignedIn) ...[
          const SizedBox(height: 8),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardTitle(
                  icon: Icons.settings_backup_restore_rounded,
                  title: 'Backup y restauración',
                ),
                const SizedBox(height: 16),
                _DriveTile(
                  icon: Icons.cloud_upload_rounded,
                  iconBg: const Color(0xFFE3F4F7),
                  iconColor: AppColors.primary,
                  title: 'Subir backup ahora',
                  subtitle: 'Guarda la base de datos actual en Google Drive.',
                  buttonLabel: 'Subir',
                  buttonColor: AppColors.primary,
                  isLoading: state.isLoading,
                  onTap: onConfirmBackup,
                ),
                const Divider(height: 24),
                _DriveTile(
                  icon: Icons.cloud_download_rounded,
                  iconBg: const Color(0xFFFDF0E8),
                  iconColor: AppColors.secondary,
                  title: 'Restaurar desde Drive',
                  subtitle:
                      'Reemplaza la base local con el último backup de Drive. '
                      'Se requiere reiniciar la app.',
                  buttonLabel: 'Restaurar',
                  buttonColor: AppColors.secondary,
                  isLoading: state.isLoading,
                  onTap: onConfirmRestore,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 8)])
          .take(children.length * 2 - 1)
          .toList(),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.backup,
    required this.dtFmt,
    required this.onExportar,
    required this.onRestaurar,
    required this.onEliminar,
  });

  final Map<String, dynamic> backup;
  final DateFormat dtFmt;
  final VoidCallback onExportar;
  final VoidCallback onRestaurar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Icon(
            Icons.save_as_rounded,
            color: colors.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          backup['name'].toString(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${backup['createdFormatted']}  •  ${backup['sizeFormatted']}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Acciones',
          onSelected: (value) {
            if (value == 'exportar') onExportar();
            if (value == 'restaurar') onRestaurar();
            if (value == 'eliminar') onEliminar();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'exportar',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.file_download_outlined),
                title: Text('Exportar'),
              ),
            ),
            const PopupMenuItem(
              value: 'restaurar',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.settings_backup_restore_rounded),
                title: Text('Restaurar'),
              ),
            ),
            const PopupMenuItem(
              value: 'eliminar',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: Text(
                  'Eliminar',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveTile extends StatelessWidget {
  const _DriveTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonColor,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color buttonColor;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        onPressed: onTap,
                        child: Text(
                          buttonLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDDAD5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/google_logo.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.g_mobiledata_rounded, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Continuar con Google',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
