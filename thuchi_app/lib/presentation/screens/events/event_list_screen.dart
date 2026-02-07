import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/repositories/event_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import 'event_form_screen.dart';

class EventListScreen extends ConsumerWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: Text('Chưa đăng nhập'));

    return Scaffold(
      appBar: AppBar(title: const Text('Sự kiện / Chuyến đi')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<EventWithSpending>>(
        future: ref.read(eventRepositoryProvider).getEventsWithSpending(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flight_takeoff, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có sự kiện nào', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Nhấn + để tạo sự kiện mới', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) => _buildEventCard(context, ref, events[index]),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, WidgetRef ref, EventWithSpending data) {
    final event = data.event;
    final theme = Theme.of(context);
    final usagePercent = data.usagePercent;

    Color progressColor;
    if (usagePercent >= 100) {
      progressColor = Colors.red;
    } else if (usagePercent >= 80) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventFormScreen(eventId: event.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (event.isFinished)
                    Chip(
                      label: const Text('Kết thúc', style: TextStyle(fontSize: 11)),
                      backgroundColor: Colors.grey.shade200,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Date range
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${app_date.DateUtils.formatFullDate(event.startDate)}'
                    '${event.endDate != null ? ' – ${app_date.DateUtils.formatFullDate(event.endDate!)}' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Transaction count
              Row(
                children: [
                  const Icon(Icons.receipt_long, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${data.transactionCount} giao dịch', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),

              if (event.budget > 0) ...[
                const SizedBox(height: 12),

                // Budget progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Đã chi: ${CurrencyUtils.formatVND(data.totalSpending)}', style: const TextStyle(fontSize: 13)),
                    Text('Ngân sách: ${CurrencyUtils.formatVND(event.budget)}', style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (usagePercent / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    color: progressColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${usagePercent.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: progressColor, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
