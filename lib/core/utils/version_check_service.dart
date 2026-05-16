import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:restaurant_app/core/constants/app_constants.dart';

/// Información de la versión disponible obtenida del servidor.
class VersionInfo {
  const VersionInfo({
    required this.latestVersion,
    required this.mandatory,
    required this.releaseNotes,
    this.downloadUrl,
  });

  final String latestVersion;
  final bool mandatory;
  final String releaseNotes;
  final String? downloadUrl;

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      latestVersion: (json['version'] as String?) ?? '',
      mandatory: (json['mandatory'] as bool?) ?? false,
      releaseNotes: (json['notes'] as String?) ?? '',
      downloadUrl: json['download_url'] as String?,
    );
  }
}

/// Resultado del chequeo de actualización.
sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable(this.info);
  final VersionInfo info;
}

class UpToDate extends UpdateCheckResult {
  const UpToDate();
}

class UpdateCheckFailed extends UpdateCheckResult {
  const UpdateCheckFailed(this.reason);
  final String reason;
}

/// Servicio que compara la versión actual con la última publicada en el JSON
/// remoto (GitHub Gist o cualquier host estático).
///
/// Formato esperado del JSON remoto:
/// ```json
/// {
///   "version": "1.0.1",
///   "mandatory": false,
///   "notes": "Corrección de errores y mejoras de rendimiento",
///   "download_url": "https://github.com/tu-usuario/restaurant_app/releases/latest"
/// }
/// ```
class VersionCheckService {
  VersionCheckService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Verifica si hay una nueva versión disponible.
  Future<UpdateCheckResult> checkForUpdate() async {
    final url = AppConstants.versionCheckUrl;
    if (url.isEmpty) return const UpToDate();

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return UpdateCheckFailed('HTTP ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final info = VersionInfo.fromJson(json);

      return _isNewer(info.latestVersion, AppConstants.appVersion)
          ? UpdateAvailable(info)
          : const UpToDate();
    } on Exception catch (e) {
      return UpdateCheckFailed(e.toString());
    }
  }

  /// `true` si [remote] es una versión semver mayor que [current].
  static bool _isNewer(String remote, String current) {
    final r = _parseSemver(remote);
    final c = _parseSemver(current);
    if (r == null || c == null) return false;
    if (r[0] != c[0]) return r[0] > c[0];
    if (r[1] != c[1]) return r[1] > c[1];
    return r[2] > c[2];
  }

  static List<int>? _parseSemver(String version) {
    final clean = version.startsWith('v') ? version.substring(1) : version;
    final parts = clean.split('.');
    if (parts.length < 3) return null;
    final nums = parts.take(3).map(int.tryParse).toList();
    if (nums.any((n) => n == null)) return null;
    return nums.cast<int>();
  }
}
