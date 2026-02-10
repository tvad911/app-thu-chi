import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../core/services/data_service.dart';
import '../../../core/services/snapshot_service.dart';
// import '../../widgets/common/confirm_dialog.dart';

class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotsAsync = ref.watch(snapshotListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Dữ liệu'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Reset Dữ liệu'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Khôi phục cài đặt gốc',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Xóa toàn bộ dữ liệu và đưa về mặc định'),
            onTap: () => _confirmReset(context, ref),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Bản sao lưu (Snapshots)'),
          snapshotsAsync.when(
            data: (snapshots) {
              if (snapshots.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('Chưa có bản sao lưu nào')),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshots.length,
                itemBuilder: (context, index) {
                  final file = snapshots[index];
                  final name = p.basename(file.path);
                  final modified = file.lastModifiedSync();
                  final size = file.lengthSync();

                  return Dismissible(
                    key: Key(file.path),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                       return await showDialog(
                         context: context,
                         builder: (context) => AlertDialog(
                           title: const Text('Xóa bản sao lưu?'),
                           content: Text('Bạn có chắc muốn xóa "$name"?'),
                           actions: [
                             TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                             TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
                           ],
                         ),
                       );
                    },
                    onDismissed: (direction) {
                      ref.read(snapshotServiceProvider).deleteSnapshot(file);
                      // Refresh list manually or wait for auto-refresh if provider watches something?
                      // FutureProvider.autoDispose re-runs on watch, but we need to invalidate it.
                      ref.invalidate(snapshotListProvider);
                    },
                    child: ListTile(
                      leading: const Icon(Icons.restore),
                      title: Text(name),
                      subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(modified)} - ${_formatSize(size)}'),
                      onTap: () => _confirmRestore(context, ref, file),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Lỗi: $err')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSnapshotDialog(context, ref),
        child: const Icon(Icons.add),
        tooltip: 'Tạo bản sao lưu mới',
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Cảnh báo: Reset Dữ liệu'),
        content: const Text(
          'Hành động này sẽ XÓA TOÀN BỘ dữ liệu hiện tại (giao dịch, tài khoản, v.v.) và đưa ứng dụng về trạng thái ban đầu.\n\nBạn KHÔNG THỂ hoàn tác hành động này (trừ khi đã tạo snapshot).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Ngay'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(dataServiceProvider).resetToDefault();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã reset dữ liệu thành công!')),
          );
          Navigator.pop(context); // Go back or go to home
          // Resetting usually invalidates current user session? No, keeping user logged in.
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi reset: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmRestore(BuildContext context, WidgetRef ref, File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục Snapshot'),
        content: Text(
          'Bạn có chắc muốn khôi phục dữ liệu từ bản sao lưu này?\n\nDữ liệu hiện tại sẽ bị thay thế hoàn toàn.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(snapshotServiceProvider).restoreSnapshot(file);
        // Refresh UI is automatic via provider invalidation in DataService
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã khôi phục dữ liệu thành công!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khôi phục: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showCreateSnapshotDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo bản sao lưu mới'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tên gợi nhớ (Tùy chọn)',
            hintText: 'VD: Truoc_khi_reset',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final name = controller.text.isEmpty ? 'snapshot' : controller.text;
              await ref.read(snapshotServiceProvider).createSnapshot(name);
              // Invalidate list to refresh
              ref.invalidate(snapshotListProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }
}
