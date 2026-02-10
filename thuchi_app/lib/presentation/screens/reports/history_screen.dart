import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Hoạt động'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Giao dịch'),
            Tab(text: 'Khác'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _confirmClearLogs(context),
            tooltip: 'Xóa lịch sử',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AuditLogList(type: 'Transaction'),
          _AuditLogList(excludeType: 'Transaction'),
        ],
      ),
    );
  }

  Future<void> _confirmClearLogs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch sử?'),
        content: const Text('Bạn có chắc muốn xóa toàn bộ nhật ký hoạt động?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
             onPressed: () => Navigator.pop(context, true), 
             child: const Text('Xóa', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(auditLogRepositoryProvider).clearLogs();
      // No explicit refresh needed if stream is used, but if future based need to refresh.
      // We will implement Stream based list.
    }
  }
}

class _AuditLogList extends ConsumerWidget {
  final String? type;
  final String? excludeType;

  const _AuditLogList({this.type, this.excludeType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need a provider that returns Stream<List<AuditLog>>
    // But auditLogRepositoryProvider is a simple class.
    // Let's create a stream provider here or use FutureBuilder if standard.
    // Since we added watch methods, we can use StreamBuilder.
    
    final repo = ref.watch(auditLogRepositoryProvider);
    
    return StreamBuilder<List<AuditLog>>(
      stream: type != null 
          ? repo.watchLogsByEntityType(type!) 
          : repo.watchRecentLogs(), // Simple approach
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var logs = snapshot.data!;
        
        // Manual filter for excludeType if needed (since repository methods are simple)
        if (excludeType != null) {
          logs = logs.where((l) => l.entityType != excludeType).toList();
        }

        if (logs.isEmpty) {
          return const Center(child: Text('Không có dữ liệu'));
        }

        return ListView.separated(
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final log = logs[index];
            return ListTile(
              leading: _buildLeadingIcon(log.action),
              title: Text(_buildTitle(log)),
              subtitle: Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(log.timestamp)),
              trailing: _buildTrailing(log),
              onTap: () => _showLogDetails(context, log),
            );
          },
        );
      },
    );
  }

  Widget _buildLeadingIcon(String action) {
    switch (action) {
      case 'CREATE': return const Icon(Icons.add_circle, color: Colors.green);
      case 'UPDATE': return const Icon(Icons.edit, color: Colors.blue);
      case 'DELETE': return const Icon(Icons.delete, color: Colors.red);
      default: return const Icon(Icons.info, color: Colors.grey);
    }
  }

  String _buildTitle(AuditLog log) {
    if (log.description != null && log.description!.isNotEmpty) {
      return log.description!;
    }
    return '${log.action} ${log.entityType} #${log.entityId}';
  }
  
  Widget? _buildTrailing(AuditLog log) {
     if (log.newValue != null) {
       try {
         final map = jsonDecode(log.newValue!) as Map<String, dynamic>;
         if (map.containsKey('amount')) {
           final amount = map['amount'];
           return Text(
             '${amount is num ? NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount) : amount}',
             style: const TextStyle(fontWeight: FontWeight.bold),
           );
         }
       } catch (_) {}
     }
     return null;
  }

  void _showLogDetails(BuildContext context, AuditLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${log.action} ${log.entityType}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ID: ${log.entityId}'),
              Text('Time: ${log.timestamp}'),
              if (log.description != null) ...[
                const SizedBox(height: 8),
                const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(log.description!),
              ],
              if (log.oldValue != null) ...[
                const SizedBox(height: 8),
                const Text('Old Value:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_prettyJson(log.oldValue!)),
              ],
              if (log.newValue != null) ...[
                const SizedBox(height: 8),
                const Text('New Value:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_prettyJson(log.newValue!)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }

  String _prettyJson(String jsonString) {
    try {
      final object = jsonDecode(jsonString);
      return const JsonEncoder.withIndent('  ').convert(object);
    } catch (e) {
      return jsonString;
    }
  }
}
