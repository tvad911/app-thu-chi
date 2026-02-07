import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final int? eventId;
  const EventFormScreen({super.key, this.eventId});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;
  Event? _existingEvent;

  bool get isEditing => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadEvent();
  }

  Future<void> _loadEvent() async {
    final db = ref.read(databaseProvider);
    final event = await (db.select(db.events)..where((e) => e.id.equals(widget.eventId!))).getSingle();
    setState(() {
      _existingEvent = event;
      _nameController.text = event.name;
      _budgetController.text = event.budget > 0 ? event.budget.toStringAsFixed(0) : '';
      _noteController.text = event.note ?? '';
      _startDate = event.startDate;
      _endDate = event.endDate;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    final repo = ref.read(eventRepositoryProvider);
    final budget = double.tryParse(_budgetController.text) ?? 0;
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    try {
      if (isEditing) {
        await repo.updateEvent(
          widget.eventId!,
          EventsCompanion(
            name: drift.Value(_nameController.text.trim()),
            startDate: drift.Value(_startDate),
            endDate: drift.Value(_endDate),
            budget: drift.Value(budget),
            note: drift.Value(note),
          ),
        );
      } else {
        await repo.createEvent(
          EventsCompanion(
            name: drift.Value(_nameController.text.trim()),
            startDate: drift.Value(_startDate),
            endDate: drift.Value(_endDate),
            budget: drift.Value(budget),
            note: drift.Value(note),
            userId: drift.Value(user.id),
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa sự kiện?'),
        content: const Text('Hành động này không thể hoàn tác. Các giao dịch liên quan sẽ không bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(eventRepositoryProvider).deleteEvent(widget.eventId!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa sự kiện' : 'Tạo sự kiện mới'),
        actions: [
          if (isEditing)
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteEvent),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên sự kiện *',
                hintText: 'VD: Du lịch Thái Lan',
                prefixIcon: Icon(Icons.event),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
            ),
            const SizedBox(height: 16),

            // Start date
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Ngày bắt đầu'),
              subtitle: Text(app_date.DateUtils.formatFullDate(_startDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectDate(context, true),
            ),

            // End date
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Ngày kết thúc'),
              subtitle: Text(_endDate != null ? app_date.DateUtils.formatFullDate(_endDate!) : 'Chưa xác định'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_endDate != null)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _endDate = null)),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _selectDate(context, false),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _budgetController,
              decoration: const InputDecoration(
                labelText: 'Ngân sách dự kiến',
                hintText: 'VD: 5000000',
                prefixIcon: Icon(Icons.account_balance_wallet),
                suffixText: '₫',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _saveEvent,
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(isEditing ? 'Cập nhật' : 'Tạo sự kiện'),
              ),
            ),

            if (isEditing && _existingEvent != null && !_existingEvent!.isFinished) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(eventRepositoryProvider).finishEvent(widget.eventId!);
                  if (mounted) Navigator.pop(context, true);
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Đánh dấu hoàn thành'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
