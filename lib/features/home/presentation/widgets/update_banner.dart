import 'package:flutter/material.dart';
import 'package:restaurant_app/core/theme/app_colors.dart';
import 'package:restaurant_app/core/utils/version_check_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Banner no intrusivo que informa al usuario sobre una actualización disponible.
///
/// - Se oculta si no hay actualización o si el usuario lo descarta.
/// - Si [info.mandatory] es `true`, no muestra el botón de cerrar.
/// - Aparece en la parte superior del Dashboard.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, required this.info});

  final VersionInfo info;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final isMandatory = widget.info.mandatory;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 420;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nueva versión disponible: ${widget.info.latestVersion}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      if (widget.info.releaseNotes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.info.releaseNotes,
                          maxLines: isCompact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      if (widget.info.downloadUrl != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              _openDownload(widget.info.downloadUrl!),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Descargar actualización'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isMandatory)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: Colors.grey[600],
                    tooltip: 'Descartar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _dismissed = true),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
