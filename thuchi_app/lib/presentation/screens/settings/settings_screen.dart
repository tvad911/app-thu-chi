import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_service.dart';
import '../categories/category_list_screen.dart';
import 'sync_settings_screen.dart';
import '../bills/bill_list_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
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
            onTap: () => _confirmRestore(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Cài đặt Đồng bộ (Sync)'),
            subtitle: const Text('Google Drive / S3 Storage'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
              );
            },
          ),
          const Divider(),
           ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Quản lý Hóa đơn định kỳ (Bills)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(builder: (_) => const BillListScreen()),
               );
            },
          ),
           ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Quản lý danh mục'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(builder: (_) => const CategoryListScreen()),
               );
            },
          ),
        ],
      ),
    );
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
