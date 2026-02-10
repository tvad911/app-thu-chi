import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/database/app_database.dart';
import '../../../data/repositories/event_repository.dart';
import '../../../providers/app_providers.dart';
import '../transactions/transaction_form_screen.dart';
import 'event_form_screen.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  EventWithSpending? _eventData;
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(eventRepositoryProvider);
    final data = await repo.getEventWithSpending(widget.eventId);
    final txns = await repo.getTransactionsForEvent(widget.eventId);
    if (mounted) {
      setState(() {
        _eventData = data;
        _transactions = txns;
        _isLoading = false;
      });
    }
  }

  Future<void> _finishEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết thúc sự kiện?'),
        content: const Text('Sự kiện sẽ được đánh dấu hoàn thành và không hiện gợi ý trong giao dịch mới.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kết thúc')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(eventRepositoryProvider).finishEvent(widget.eventId);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sự kiện')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final data = _eventData!;
    final event = data.event;
    final usagePercent = data.usagePercent;

    Color progressColor;
    if (usagePercent >= 100) {
      progressColor = Colors.red;
    } else if (usagePercent >= 80) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EventFormScreen(eventId: event.id)),
              );
              if (result == true) _loadData();
            },
          ),
        ],
      ),
      floatingActionButton: event.isFinished ? null : FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TransactionFormScreen(initialEvent: event)),
          );
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm chi tiêu'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status chip
            if (event.isFinished)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Chip(
                  label: Text('Đã kết thúc', style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.grey,
                ),
              ),

            // Date range
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          '${app_date.DateUtils.formatFullDate(event.startDate)}'
                          '${event.endDate != null ? ' – ${app_date.DateUtils.formatFullDate(event.endDate!)}' : ''}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    if (event.note != null && event.note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(event.note!, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Budget Dashboard
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ngân sách', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _statItem('Đã chi', CurrencyUtils.formatVND(data.totalSpending), Colors.red),
                        ),
                        Expanded(
                          child: _statItem('Ngân sách', CurrencyUtils.formatVND(event.budget), Colors.blue),
                        ),
                        Expanded(
                          child: _statItem('Còn lại', CurrencyUtils.formatVND(data.remainingBudget),
                              data.remainingBudget >= 0 ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                    if (event.budget > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (usagePercent / 100).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          color: progressColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${usagePercent.toStringAsFixed(1)}% ngân sách',
                        style: TextStyle(fontSize: 12, color: progressColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Finish button
            if (!event.isFinished)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: _finishEvent,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Kết thúc sự kiện'),
                ),
              ),

            // Transaction list
            Text(
              'Giao dịch (${_transactions.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_transactions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Chưa có giao dịch nào gắn sự kiện này', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ),

            ..._transactions.map((t) {
              final isExpense = t.type == 'expense';
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isExpense ? Colors.red.shade50 : Colors.green.shade50,
                    child: Icon(
                      isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 16,
                      color: isExpense ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(t.note ?? (isExpense ? 'Chi tiêu' : 'Thu nhập'), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(app_date.DateUtils.formatFullDate(t.date), style: const TextStyle(fontSize: 11)),
                  trailing: Text(
                    '${isExpense ? "-" : "+"}${CurrencyUtils.format(t.amount)}',
                    style: TextStyle(
                      color: isExpense ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ),
      ],
    );
  }
}
