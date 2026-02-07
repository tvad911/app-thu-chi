import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../providers/privacy_provider.dart';
import '../../../providers/app_lock_provider.dart';
import '../categories/category_list_screen.dart';
import 'sync_settings_screen.dart';
import '../audit/audit_log_list_screen.dart';
import '../auth/lock_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasPinSet = false;

  @override
  void initState() {
    super.initState();
    _loadPinStatus();
  }

  Future<void> _loadPinStatus() async {
    final lockService = ref.read(appLockServiceProvider);
    final hasPin = await lockService.hasPinSet();
    if (mounted) setState(() => _hasPinSet = hasPin);
  }

  @override
  Widget build(BuildContext context) {
    final isPrivacy = ref.watch(privacyModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
          // ===== SECURITY SECTION =====
          _sectionHeader('Bảo mật & Riêng tư'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(_hasPinSet ? 'Đổi mã PIN' : 'Đặt mã PIN'),
            subtitle: Text(_hasPinSet ? 'Thay đổi mã khóa ứng dụng' : 'Bảo vệ ứng dụng bằng mã PIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _handlePinSetup(context),
          ),
          if (_hasPinSet)
            ListTile(
              leading: const Icon(Icons.lock_open),
              title: const Text('Xóa mã PIN'),
              subtitle: const Text('Tắt khóa ứng dụng'),
              onTap: () => _handleRemovePin(context),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off),
            title: const Text('Chế độ riêng tư'),
            subtitle: const Text('Ẩn tất cả số tiền hiển thị'),
            value: isPrivacy,
            onChanged: (value) {
              ref.read(privacyModeProvider.notifier).state = value;
              CurrencyUtils.privacyMode = value;
            },
          ),

          const Divider(),

          // ===== DATA SECTION =====
          _sectionHeader('Dữ liệu'),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Sao lưu dữ liệu (Backup)'),
            subtitle: const Text('Xuất dữ liệu ra file JSON'),
            onTap: () async {
              try {
                await ref.read(dataServiceProvider).exportToJson();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Khôi phục dữ liệu (Restore)'),
            subtitle: const Text('Nhập dữ liệu từ file JSON'),
            onTap: () => _confirmRestore(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Cài đặt Đồng bộ (Sync)'),
            subtitle: const Text('Google Drive / S3 Storage'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncSettingsScreen()));
            },
          ),

          const Divider(),

          // ===== MANAGEMENT SECTION =====
          _sectionHeader('Quản lý'),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Quản lý danh mục'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryListScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Lịch sử hoạt động (Audit Logs)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogListScreen())),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Future<void> _handlePinSetup(BuildContext context) async {
    if (_hasPinSet) {
      // Verify current PIN first
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LockScreen()),
      );
      if (verified != true) return;
    }

    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LockScreen(isSettingPin: true)),
    );
    if (result == true) {
      _loadPinStatus();
    }
  }

  Future<void> _handleRemovePin(BuildContext context) async {
    // Verify current PIN first
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LockScreen()),
    );
    if (verified != true) return;

    final lockService = ref.read(appLockServiceProvider);
    await lockService.removePin();
    _loadPinStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa mã PIN')),
      );
    }
  }

  void _confirmRestore(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục dữ liệu?'),
        content: const Text(
          'Hành động này sẽ XÓA TOÀN BỘ dữ liệu hiện tại và thay thế bằng dữ liệu từ file backup. Bạn có chắc chắn không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(dataServiceProvider).importFromJson();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Khôi phục dữ liệu thành công!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e')),
                  );
                }
              }
            },
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }
}
