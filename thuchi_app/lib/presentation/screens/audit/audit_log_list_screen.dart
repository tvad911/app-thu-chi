import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart'; // Add drift import

import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';

class AuditLogListScreen extends ConsumerWidget {
  const AuditLogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Audit logs usually don't need a StreamProvider as they are huge. 
    // FutureProvider with pagination is better, but MVP: simple FutureBuilder.
    // Assuming we fetch last 50 logs.
    
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử hoạt động')),
      body: FutureBuilder<List<AuditLog>>(
        future: _fetchLogs(ref),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(child: Text('Chưa có lịch sử hoạt động'));
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: _getIconForAction(log.action),
                title: Text(log.description ?? log.action),
                subtitle: Text(app_date.DateUtils.formatFullDate(log.timestamp)),
                trailing: Text(
                  _getTime(log.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<AuditLog>> _fetchLogs(WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    return (db.select(db.auditLogs)
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
          ..limit(50))
        .get();
  }

  Icon _getIconForAction(String action) {
    if (action.contains('CREATE')) return const Icon(Icons.add_circle_outline, color: Colors.green);
    if (action.contains('UPDATE')) return const Icon(Icons.edit, color: Colors.blue);
    if (action.contains('DELETE')) return const Icon(Icons.delete_outline, color: Colors.red);
    return const Icon(Icons.info_outline);
  }

  String _getTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
