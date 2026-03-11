import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  static const String _versionUrl = 'https://raw.githubusercontent.com/tvad911/app-thu-chi/main/version.json';
  static const String _releasesUrl = 'https://github.com/tvad911/app-thu-chi/releases';
  static const String _dismissedVersionKey = 'dismissed_update_version';

  Future<UpdateInfo?> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await http.get(Uri.parse(_versionUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String latestVersion = data['version'];
        final int latestBuildNumber = data['build_number'];
        final String downloadUrl = data['download_url'];
        final String releaseNotes = data['release_notes'] ?? '';

        // Compare build numbers — most reliable for Android
        final bool hasUpdate = latestBuildNumber > currentBuildNumber;

        if (hasUpdate) {
          // Check if user already dismissed this specific version
          final isDismissed = await isVersionDismissed(latestVersion);

          return UpdateInfo(
            version: latestVersion,
            buildNumber: latestBuildNumber,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            releasePageUrl: '$_releasesUrl/tag/v$latestVersion',
            hasUpdate: true,
            isDismissed: isDismissed,
          );
        }
      }
    } catch (e) {
      // Silently ignore update check errors
    }
    return null;
  }

  /// Check if user has dismissed this version's notification
  Future<bool> isVersionDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dismissedVersionKey) == version;
  }

  /// Remember that user dismissed notification for this version
  Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }

  /// Clear dismissed version (e.g., when a newer version comes out)
  Future<void> clearDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedVersionKey);
  }

  Future<void> launchReleasePage(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final String releasePageUrl;
  final bool hasUpdate;
  final bool isDismissed;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releasePageUrl,
    required this.hasUpdate,
    this.isDismissed = false,
  });
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

final checkForUpdateProvider = FutureProvider<UpdateInfo?>((ref) async {
  final service = ref.watch(updateServiceProvider);
  return service.checkUpdate();
});
