import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/attachment_viewer.dart';

class DebtFormScreen extends ConsumerStatefulWidget {
  final Debt? existingDebt; // null = create mode

  const DebtFormScreen({super.key, this.existingDebt});

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestRateController = TextEditingController(text: '0');
  final _notifyDaysController = TextEditingController(text: '3');
  final _noteController = TextEditingController();

  String _type = 'lend';
  InterestType _interestType = InterestType.percentYear;
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  int? _selectedAccountId;

  List<File> _attachedFiles = [];
  bool _isSaving = false;
  bool _createTransaction = true; // V6: toggle for wallet transaction
  bool get _isEdit => widget.existingDebt != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final d = widget.existingDebt!;
      _personController.text = d.person;
      _amountController.text = d.totalAmount.toStringAsFixed(0);
      _interestRateController.text = d.interestRate.toString();
      _notifyDaysController.text = d.notifyDays.toString();
      _noteController.text = d.note ?? '';
      _type = d.type;
      _interestType = InterestType.values.firstWhere(
        (e) => e.name == d.interestType,
        orElse: () => InterestType.percentYear,
      );
      _startDate = d.startDate;
      _dueDate = d.dueDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Chỉnh sửa khoản nợ' : 'Thêm khoản nợ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type selector (disabled in edit mode)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lend', label: Text('Cho vay')),
                ButtonSegment(value: 'borrow', label: Text('Đi vay')),
              ],
              selected: {_type},
              onSelectionChanged: _isEdit ? null : (val) => setState(() => _type = val.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _personController,
              decoration: const InputDecoration(
                labelText: 'Người vay/Cho vay',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Nhập tên đối tác' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Số tiền gốc',
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'đ',
              ),
              keyboardType: TextInputType.number,
              // enabled: true, // V6: Allow editing amount
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nhập số tiền';
                if (CurrencyUtils.parse(v) == null) return 'Số tiền không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 16),
            // V6: Switch for creating transaction
            if (!_isEdit) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ghi nhận giao dịch vào Ví?'),
                subtitle: Text(
                  _createTransaction
                      ? 'Sẽ trừ/cộng tiền trong ví liên kết'
                      : 'Chỉ ghi sổ nợ, không ảnh hưởng số dư ví',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: _createTransaction,
                onChanged: (val) => setState(() => _createTransaction = val),
              ),
              const SizedBox(height: 8),
            ],
            // Account selection (only in create mode AND createTransaction is ON)
            if (!_isEdit && _createTransaction)
              accountsAsync.when(
                data: (accounts) {
                  if (_selectedAccountId == null && accounts.isNotEmpty) {
                    _selectedAccountId = accounts.first.id;
                  }
                  return DropdownButtonFormField<int>(
                    value: _selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Tài khoản/Ví liên kết',
                      prefixIcon: Icon(Icons.wallet),
                    ),
                    items: accounts.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedAccountId = val),
                    validator: (val) => val == null ? 'Vui lòng chọn ví' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Lỗi tải danh sách ví'),
              ),
            if (!_isEdit && _createTransaction) const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _interestRateController,
                    decoration: const InputDecoration(
                      labelText: 'Lãi suất',
                      prefixIcon: Icon(Icons.percent),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<InterestType>(
                    value: _interestType,
                    decoration: const InputDecoration(labelText: 'Loại lãi'),
                    items: InterestType.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.displayName),
                    )).toList(),
                    onChanged: (val) => setState(() => _interestType = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Ngày bắt đầu'),
                    subtitle: Text(_startDate.toString().split(' ')[0]),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _isEdit ? null : () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) setState(() => _startDate = date);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Ngày đáo hạn'),
                    subtitle: Text(_dueDate == null ? 'Không có' : _dueDate.toString().split(' ')[0]),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: _startDate,
                        lastDate: DateTime(2100),
                      );
                      setState(() => _dueDate = date);
                    },
                  ),
                ),
              ],
            ),
            if (_dueDate != null) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _notifyDaysController,
                decoration: const InputDecoration(
                  labelText: 'Nhắc trước (ngày)',
                  prefixIcon: Icon(Icons.notifications_active),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Attachment (only in create mode)
            if (!_isEdit) ...[
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Đính kèm chứng từ'),
                  ),
                ],
              ),
              if (_attachedFiles.isNotEmpty)
                AttachmentViewer(
                  files: _attachedFiles,
                  onRemove: (f) => setState(() => _attachedFiles.remove(f)),
                ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveDebt,
              icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
              label: Text(_isEdit ? 'Lưu thay đổi' : 'Lưu khoản nợ'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (_isEdit) {
        await _updateDebt();
      } else {
        await _createDebt();
      }
      if (mounted) Navigator.pop(context, true); // Return true on success
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _createDebt() async {
    final amount = CurrencyUtils.parse(_amountController.text)!;
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final debt = DebtsCompanion(
      person: drift.Value(_personController.text),
      totalAmount: drift.Value(amount),
      remainingAmount: drift.Value(amount),
      interestRate: drift.Value(double.tryParse(_interestRateController.text) ?? 0),
      interestType: drift.Value(_interestType.name),
      startDate: drift.Value(_startDate),
      dueDate: drift.Value(_dueDate),
      notifyDays: drift.Value(int.tryParse(_notifyDaysController.text) ?? 3),
      type: drift.Value(_type),
      note: drift.Value(_noteController.text),
      userId: drift.Value(user.id),
    );

    final debtId = await ref.read(debtRepositoryProvider).createDebt(
      debt,
      accountId: _createTransaction ? _selectedAccountId : null,
      createTransaction: _createTransaction,
    );

    // Save Attachments
    if (_attachedFiles.isNotEmpty) {
      final attachmentRepo = ref.read(attachmentRepositoryProvider);
      final fileStorage = ref.read(fileStorageServiceProvider);

      for (final file in _attachedFiles) {
        final metadata = await fileStorage.saveFile(file);
        await attachmentRepo.createAttachment(AttachmentsCompanion(
          debtId: drift.Value(debtId),
          fileName: drift.Value(metadata['fileName']),
          fileType: drift.Value(metadata['format']),
          fileSize: drift.Value(metadata['size']),
          localPath: drift.Value(metadata['localPath']),
          syncStatus: const drift.Value('PENDING'),
        ));
      }
    }
  }

  Future<void> _updateDebt() async {
    final existing = widget.existingDebt!;
    final updated = existing.copyWith(
      person: _personController.text,
      totalAmount: CurrencyUtils.parse(_amountController.text)!,
      interestRate: double.tryParse(_interestRateController.text) ?? 0,
      interestType: _interestType.name,
      dueDate: drift.Value(_dueDate),
      notifyDays: int.tryParse(_notifyDaysController.text) ?? 3,
      note: drift.Value(_noteController.text),
      updatedAt: drift.Value(DateTime.now()),
    );
    await ref.read(debtRepositoryProvider).updateDebt(updated);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'pdf', 'doc', 'png'],
    );
    if (result != null) {
      setState(() {
        _attachedFiles.addAll(result.paths.map((p) => File(p!)).toList());
      });
    }
  }
}
