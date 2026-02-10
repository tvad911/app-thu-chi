import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/cloud_models.dart';
import '../../../core/services/drive_storage_provider.dart';
import '../../../core/services/s3_storage_provider.dart';

// Providers for state management
final storageProviderTypeProvider = StateProvider<String>((ref) => 'none'); // 'none', 'drive', 's3'

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  final _secureStorage = const FlutterSecureStorage();
  
  // S3 Form Controllers
  final _endpointCtrl = TextEditingController();
  final _bucketCtrl = TextEditingController();
  final _accessKeyCtrl = TextEditingController();
  final _secretKeyCtrl = TextEditingController();
  final _regionCtrl = TextEditingController(text: 'us-east-1');
  
  bool _isLoading = false;
  String? _connectionStatus;
  Duration? _lastCheck;
  
  // Google Drive info
  Map<String, String>? _driveUserInfo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString('sync_provider') ?? 'none';
    
    // Load S3 settings from secure storage
    if (type == 's3') {
      _endpointCtrl.text = await _secureStorage.read(key: 's3_endpoint') ?? '';
      _bucketCtrl.text = await _secureStorage.read(key: 's3_bucket') ?? '';
      _accessKeyCtrl.text = await _secureStorage.read(key: 's3_access_key') ?? '';
      _secretKeyCtrl.text = await _secureStorage.read(key: 's3_secret_key') ?? '';
      _regionCtrl.text = await _secureStorage.read(key: 's3_region') ?? 'us-east-1';
    } else if (type == 'drive') {
       // Check drive auth status
       _checkDriveStatus();
    }

    ref.read(storageProviderTypeProvider.notifier).state = type;
  }
  
  Future<void> _checkDriveStatus() async {
    final provider = GoogleDriveProvider();
    if (await provider.isConnected()) {
      final info = await provider.getUserInfo();
      setState(() => _driveUserInfo = info);
    }
  }

  Future<void> _saveSettings(String type) async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_provider', type);
    
    if (type == 's3') {
      await _secureStorage.write(key: 's3_endpoint', value: _endpointCtrl.text.trim());
      await _secureStorage.write(key: 's3_bucket', value: _bucketCtrl.text.trim());
      await _secureStorage.write(key: 's3_access_key', value: _accessKeyCtrl.text.trim());
      await _secureStorage.write(key: 's3_secret_key', value: _secretKeyCtrl.text.trim());
      await _secureStorage.write(key: 's3_region', value: _regionCtrl.text.trim());
      
      // Test connection
      await _testS3Connection();
    }
    
    ref.read(storageProviderTypeProvider.notifier).state = type;
    setState(() => _isLoading = false);
  }

  Future<void> _testS3Connection() async {
    try {
      final config = S3Config(
        endpoint: _endpointCtrl.text.trim(),
        accessKey: _accessKeyCtrl.text.trim(),
        secretKey: _secretKeyCtrl.text.trim(),
        bucketName: _bucketCtrl.text.trim(),
        region: _regionCtrl.text.trim(),
      );
      
      final provider = S3StorageProvider(config);
      final success = await provider.authenticate();
      
      if (mounted) {
        setState(() {
          _connectionStatus = success ? 'Kết nối thành công!' : 'Kết nối thất bại. Kiểm tra cấu hình.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = 'Lỗi: $e';
        });
      }
    }
  }
  
  Future<void> _connectGoogleDrive() async {
    setState(() => _isLoading = true);
    try {
      final provider = GoogleDriveProvider();
      final success = await provider.authenticate();
      
      if (success) {
        await _saveSettings('drive');
        await _checkDriveStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã kết nối với Google Drive thành công')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng nhập thất bại. Đảm bảo bạn đã cấu hình google-services.json')),
          );
        }
      }
    } on UnsupportedError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Platform không hỗ trợ')),
        );
        // Switch to none
        ref.read(storageProviderTypeProvider.notifier).state = 'none';
      }
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi kết nối: $e')),
          );
       }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentType = ref.watch(storageProviderTypeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt Đồng bộ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProviderSelector(currentType),
          const SizedBox(height: 24),
          if (currentType == 's3') _buildS3Form(),
          if (currentType == 'drive') _buildDriveInfo(),
          if (currentType == 'none') _buildNoneInfo(),
          
          const Divider(height: 48),
          
          if (currentType != 'none') ...[
            FilledButton.icon(
              onPressed: _isLoading ? null : () {}, // To be implemented: Manual Sync
              icon: const Icon(Icons.sync),
              label: const Text('Đồng bộ ngay'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ứng dụng sẽ tự động đồng bộ ảnh khi có kết nối mạng.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildProviderSelector(String currentType) {
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    return SegmentedButton<String>(
      segments: [
        const ButtonSegment(
          value: 'none', 
          label: Text('Tắt'), 
          icon: Icon(Icons.cloud_off)
        ),
        if (!isDesktop)
          const ButtonSegment(
            value: 'drive', 
            label: Text('Google Drive'), 
            icon: Icon(Icons.add_to_drive)
          ),
        const ButtonSegment(
          value: 's3', 
          label: Text('S3 Storage'), 
          icon: Icon(Icons.storage)
        ),
      ],
      selected: {currentType},
      onSelectionChanged: (Set<String> newSelection) {
        final newType = newSelection.first;
        if (newType == 'drive') {
          // Drive requires auth flow
        } else if (newType == 's3') {
           // Provide fields
        } else {
           _saveSettings('none');
        }
        
        // Update local state first for UI response
        ref.read(storageProviderTypeProvider.notifier).state = newType;
        
        // If switching to none, save immediately
        if (newType == 'none') {
          _saveSettings('none');
        }
      },
    );
  }

  Widget _buildS3Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cấu hình S3 (MinIO / AWS / Wasabi)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _endpointCtrl,
          decoration: const InputDecoration(
            labelText: 'Endpoint',
            hintText: 's3.amazonaws.com or play.min.io',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bucketCtrl,
          decoration: const InputDecoration(
            labelText: 'Bucket Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regionCtrl,
          decoration: const InputDecoration(
            labelText: 'Region',
            hintText: 'us-east-1',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _accessKeyCtrl,
          decoration: const InputDecoration(
            labelText: 'Access Key',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _secretKeyCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Secret Key',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        
        if (_connectionStatus != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: _connectionStatus!.contains('thành công') ? Colors.green.shade50 : Colors.red.shade50,
            child: Row(
              children: [
                Icon(
                   _connectionStatus!.contains('thành công') ? Icons.check_circle : Icons.error,
                   color: _connectionStatus!.contains('thành công') ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_connectionStatus!)),
              ],
            ),
          ),
          
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              onPressed: _testS3Connection,
              child: const Text('Kiểm tra kết nối'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _isLoading ? null : () => _saveSettings('s3'),
                child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Text('Lưu cấu hình'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildDriveInfo() {
    return Column(
      children: [
        const SizedBox(height: 20),
        if (_driveUserInfo == null)
           Column(
             children: [
               const Icon(Icons.drive_folder_upload, size: 64, color: Colors.grey),
               const SizedBox(height: 16),
               const Text('Chưa kết nối tài khoản Google'),
               const SizedBox(height: 16),
               FilledButton.icon(
                 onPressed: _connectGoogleDrive,
                 icon: const Icon(Icons.login),
                 label: const Text('Đăng nhập bằng Google'),
               ),
             ],
           )
        else
           Card(
             child: ListTile(
               leading: CircleAvatar(
                 backgroundImage: _driveUserInfo!['photoUrl']?.isNotEmpty == true 
                     ? NetworkImage(_driveUserInfo!['photoUrl']!) 
                     : null,
                 child: _driveUserInfo!['photoUrl']?.isEmpty == true ? const Icon(Icons.person) : null,
               ),
               title: Text(_driveUserInfo!['name'] ?? 'User'),
               subtitle: Text(_driveUserInfo!['email'] ?? ''),
               trailing: IconButton(
                 icon: const Icon(Icons.logout),
                 onPressed: () async {
                   await GoogleDriveProvider().signOut();
                   setState(() => _driveUserInfo = null);
                   _saveSettings('none');
                 },
               ),
             ),
           ),
      ],
    );
  }
  
  Widget _buildNoneInfo() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Text(
          'Ảnh đính kèm sẽ chỉ được lưu trong bộ nhớ máy.\nKhuyên dùng bật đồng bộ để tránh mất dữ liệu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
