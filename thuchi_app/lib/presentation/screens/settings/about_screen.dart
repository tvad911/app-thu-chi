import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _currentVersion = '';
  String _buildNumber = '';
  String? _latestVersion;
  String? _releaseNotes;
  String? _downloadUrl;
  bool _isLoading = true;
  String? _error;

  // Cấu hình repository GitHub (thay thế bằng repo thực tế của bạn)
  static const String _githubOwner = 'tvad911';
  static const String _githubRepo = 'app-thu-chi';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      // 1. Lấy thông tin phiên bản hiện tại
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });

      // 2. Kiểm tra cập nhật từ GitHub
      await _checkUpdate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể kiểm tra cập nhật: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkUpdate() async {
    try {
      final url = Uri.parse(
          'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String; // e.g., "v1.0.1"
        final body = data['body'] as String?;
        final htmlUrl = data['html_url'] as String;

        // Xử lý version string (bỏ 'v' nếu có)
        final cleanTagName = tagName.replaceAll('v', '');
        final hasUpdate = _compareVersions(cleanTagName, _currentVersion);

        if (mounted) {
          setState(() {
            _latestVersion = cleanTagName;
            _releaseNotes = body;
            _downloadUrl = htmlUrl;
            _isLoading = false;
          });

          if (hasUpdate) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Có bản cập nhật mới!')),
            );
          }
        }
      } else {
        if (mounted) {
          setState(() {
            // 404 có thể do chưa có release nào
            if (response.statusCode == 404) {
              _error = 'Chưa có bản phát hành nào trên GitHub.';
            } else {
              _error = 'Li server: ${response.statusCode}';
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi kết nối: $e';
          _isLoading = false;
        });
      }
    }
  }

  // So sánh version đơn giản (x.y.z)
  bool _compareVersions(String remote, String local) {
    try {
      List<int> rParts = remote.split('.').map(int.parse).toList();
      List<int> lParts = local.split('.').map(int.parse).toList();

      for (int i = 0; i < rParts.length && i < lParts.length; i++) {
        if (rParts[i] > lParts[i]) return true;
        if (rParts[i] < lParts[i]) return false;
      }
      // Nếu remote dài hơn (ví dụ 1.0.1 so với 1.0), coi là mới hơn
      if (rParts.length > lParts.length) return true;
    } catch (e) {
      // Fallback nếu format không chuẩn
      return remote != local;
    }
    return false;
  }

  Future<void> _launchUpdateUrl() async {
    if (_downloadUrl != null) {
      final uri = Uri.parse(_downloadUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở liên kết cập nhật')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate = _latestVersion != null &&
        _compareVersions(_latestVersion!, _currentVersion);

    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin ứng dụng')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Logo & App Name
            const Icon(Icons.account_balance_wallet,
                size: 80, color: Colors.blue), // Thay logo app nếu có
            const SizedBox(height: 16),
            const Text(
              'Quản Lý Thu Chi',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Phiên bản: $_currentVersion (Build $_buildNumber)',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),

            const SizedBox(height: 40),

            // Trạng thái cập nhật
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red))),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _checkUpdate();
                        },
                      )
                    ],
                  ),
                ),
              )
            else if (hasUpdate)
              _buildUpdateCard()
            else
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text('Bạn đang sử dụng phiên bản mới nhất.',
                              style: TextStyle(color: Colors.green))),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 40),
            // Footer info
            const Text('© 2024 TVAD911', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Có bản cập nhật mới: v$_latestVersion',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Thông tin thay đổi:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_releaseNotes ?? 'Không có ghi chú phát hành.'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _launchUpdateUrl,
                icon: const Icon(Icons.download),
                label: const Text('Cập nhật ngay'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
