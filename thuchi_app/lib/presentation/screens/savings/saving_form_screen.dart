import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../core/utils/currency_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/saving_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';

class SavingFormScreen extends ConsumerStatefulWidget {
  final SavingWithAccount? existingSaving; // null = create mode

  const SavingFormScreen({super.key, this.existingSaving});

  @override
  ConsumerState<SavingFormScreen> createState() => _SavingFormScreenState();
}

class _SavingFormScreenState extends ConsumerState<SavingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestRateController = TextEditingController();

  Account? _sourceAccount;
  DateTime _startDate = DateTime.now();
  int _termMonths = 6;
  bool _isInitialBalance = false; // V6: record-only mode for pre-existing savings
  bool get _isEdit => widget.existingSaving != null;

  final List<int> _terms = [1, 3, 6, 12, 18, 24, 36];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.existingSaving!;
      _nameController.text = s.account.name;
      _amountController.text = s.account.balance.toStringAsFixed(0);
      _interestRateController.text = s.saving.interestRate.toString();
      _termMonths = s.saving.termMonths;
      _startDate = s.saving.startDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _interestRateController.dispose();
    super.dispose();
  }

  double get _previewInterest {
    final amount = CurrencyUtils.parse(_amountController.text) ?? 0;
    final rate = double.tryParse(_interestRateController.text) ?? 0;
    if (amount <= 0 || rate <= 0) return 0;
    return amount * (rate / 100) * (_termMonths / 12);
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEdit) {
      await _update();
    } else {
      await _create();
    }
  }

  Future<void> _create() async {
    if (!_isInitialBalance && _sourceAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn nguồn tiền')),
      );
      return;
    }

    final amount = CurrencyUtils.parse(_amountController.text)!;
    if (!_isInitialBalance && amount > _sourceAccount!.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số dư nguồn tiền không đủ')),
      );
      return;
    }

    try {
      final repo = ref.read(savingRepositoryProvider);
      final userId = ref.read(currentUserProvider)!.id;

      await repo.createSaving(
        name: _nameController.text,
        amount: amount,
        termMonths: _termMonths,
        interestRate: double.parse(_interestRateController.text),
        startDate: _startDate,
        sourceAccountId: _isInitialBalance ? null : _sourceAccount!.id,
        userId: userId,
      );

      ref.invalidate(activeSavingsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(totalBalanceProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            _isInitialBalance
                ? 'Đã khai báo sổ tiết kiệm có sẵn'
                : 'Đã mở sổ tiết kiệm thành công',
          )),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Future<void> _update() async {
    try {
      final repo = ref.read(savingRepositoryProvider);
      final saving = widget.existingSaving!;

      // Only pass startDate if it actually changed
      final startDateChanged = _startDate != saving.saving.startDate;

      await repo.updateSaving(
        savingId: saving.saving.id,
        name: _nameController.text,
        amount: CurrencyUtils.parse(_amountController.text),
        interestRate: double.tryParse(_interestRateController.text),
        termMonths: _termMonths,
        startDate: startDateChanged ? _startDate : null,
      );

      ref.invalidate(activeSavingsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật sổ tiết kiệm')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Chỉnh sửa Tiết Kiệm' : 'Mở Sổ Tiết Kiệm Mới'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên sổ tiết kiệm',
                  hintText: 'Ví dụ: Sổ BIDV 6 tháng',
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 16),

              // Amount (disabled in edit mode)
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Số tiền gửi',
                  suffixText: '₫',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                // enabled: true, // V6: Allow editing amount
                validator: (val) {
                  final amount = CurrencyUtils.parse(val ?? '');
                  if (amount == null || amount <= 0) return 'Số tiền không hợp lệ';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // V6: Switch for initial balance mode
              if (!_isEdit) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Khai báo số dư có sẵn?'),
                  subtitle: Text(
                    _isInitialBalance
                        ? 'Ghi nhận tiết kiệm đã có, không trừ ví nào'
                        : 'Chuyển tiền từ ví sang sổ tiết kiệm',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: _isInitialBalance,
                  onChanged: (val) => setState(() => _isInitialBalance = val),
                ),
                const SizedBox(height: 8),
              ],

              // Source Account (only in create mode AND not initial balance)
              if (!_isEdit && !_isInitialBalance)
                accountsAsync.when(
                  data: (accounts) {
                    final validAccounts = accounts.where((a) => a.type != 'SAVING_DEPOSIT').toList();
                    return DropdownButtonFormField<Account>(
                      value: _sourceAccount,
                      decoration: const InputDecoration(
                        labelText: 'Nguồn tiền',
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      items: validAccounts.map((a) => DropdownMenuItem(
                        value: a,
                        child: Text('${a.name} (${CurrencyUtils.format(a.balance)})'),
                      )).toList(),
                      onChanged: (val) => setState(() => _sourceAccount = val),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Lỗi tải danh sách ví'),
                ),

              if (!_isEdit && !_isInitialBalance) const SizedBox(height: 24),

              // Start Date picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Ngày gửi'),
                subtitle: Text(app_date.DateUtils.formatDate(_startDate)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              const SizedBox(height: 8),

              Text('Kỳ hạn & Lãi suất', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),

              // Term
              DropdownButtonFormField<int>(
                value: _terms.contains(_termMonths) ? _termMonths : _terms.first,
                decoration: const InputDecoration(
                  labelText: 'Kỳ hạn',
                  prefixIcon: Icon(Icons.update),
                ),
                items: _terms.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text('$t tháng'),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _termMonths = val);
                },
              ),
              const SizedBox(height: 16),

              // Interest Rate
              TextFormField(
                controller: _interestRateController,
                decoration: const InputDecoration(
                  labelText: 'Lãi suất (%/năm)',
                  suffixText: '%',
                  prefixIcon: Icon(Icons.percent),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  final rate = double.tryParse(val ?? '');
                  if (rate == null || rate < 0) return 'Lãi suất không hợp lệ';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 24),

              // Preview card
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ngày đáo hạn:'),
                          Text(
                            DateFormat('dd/MM/yyyy').format(
                              DateTime(_startDate.year, _startDate.month + _termMonths, _startDate.day),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tiền lãi dự kiến:'),
                          Text(
                            CurrencyUtils.format(_previewInterest),
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tổng nhận về:'),
                          Text(
                            CurrencyUtils.format((CurrencyUtils.parse(_amountController.text) ?? 0) + _previewInterest),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _isEdit ? 'Lưu thay đổi' : 'Xác nhận gửi',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
