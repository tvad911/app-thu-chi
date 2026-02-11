import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateService {
  // Use user's github repo as default update source
  static const String _versionUrl = 'https://raw.githubusercontent.com/tvad911/app-thu-chi/main/version.json';

  Future<UpdateInfo?> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await http.get(Uri.parse(_versionUrl));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String latestVersion = data['version'];
        final int latestBuildNumber = data['build_number'];
        final String downloadUrl = data['download_url'];
        final String releaseNotes = data['release_notes'] ?? '';

        // Simple comparison logic
        // 1. Compare build number if available (most reliable for Android)
        // 2. Or assume version strings are comparable
        bool hasUpdate = false;
        
        if (latestBuildNumber > currentBuildNumber) {
          hasUpdate = true;
        } else if (latestBuildNumber == currentBuildNumber) {
           // If build numbers equal, check version string (optional)
        }

        if (hasUpdate) {
          return UpdateInfo(
            version: latestVersion,
            buildNumber: latestBuildNumber,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            hasUpdate: true,
          );
        }
      }
    } catch (e) {
      print('Error checking update: $e');
    }
    return null;
  }

  Future<void> launchUpdateUrl(String url) async {
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
  final bool hasUpdate;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.hasUpdate,
  });
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

final checkForUpdateProvider = FutureProvider<UpdateInfo?>((ref) async {
  final service = ref.watch(updateServiceProvider);
  return service.checkUpdate();
});
