import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import 'debt_form_screen.dart';

class DebtDetailScreen extends ConsumerStatefulWidget {
  final int debtId;
  const DebtDetailScreen({super.key, required this.debtId});

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  Debt? _debt;
  List<Transaction> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final repo = ref.read(debtRepositoryProvider);
    final debt = await repo.getDebtById(widget.debtId);
    final txns = await repo.getDebtTransactions(widget.debtId);
    if (mounted) {
      setState(() {
        _debt = debt;
        _transactions = txns;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết khoản nợ')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final debt = _debt;
    if (debt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết khoản nợ')),
        body: const Center(child: Text('Không tìm thấy khoản nợ')),
      );
    }

    final isLend = debt.type == 'lend';
    final remaining = debt.remainingAmount;
    final progress = debt.totalAmount > 0 ? (debt.totalAmount - remaining) / debt.totalAmount : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết khoản nợ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Chỉnh sửa',
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => DebtFormScreen(existingDebt: debt)),
              );
              if (result == true) _loadData();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(debt, isLend, remaining, progress),
            const SizedBox(height: 24),
            _buildInfoSection(debt),
            const SizedBox(height: 24),
            const Text(
              'Lịch sử giao dịch',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_transactions.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Chưa có giao dịch nào'),
              ))
            else
              ..._transactions.map((t) => _buildTransactionItem(t)),
          ],
        ),
      ),
      floatingActionButton: debt.isFinished ? null : FloatingActionButton.extended(
        onPressed: () => _showRepaymentDialog(context, debt),
        label: Text(isLend ? 'Nhận trả nợ' : 'Trả nợ'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(Debt debt, bool isLend, double remaining, double progress) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isLend
              ? [Colors.green.shade600, Colors.green.shade400]
              : [Colors.red.shade600, Colors.red.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLend ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLend ? 'CHO VAY' : 'ĐI VAY',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              debt.person,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isLend ? 'Họ đang nợ bạn' : 'Bạn đang nợ họ',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              CurrencyUtils.formatVND(remaining),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            if (debt.isFinished)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('ĐÃ TẤT TOÁN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tiến độ: ${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Tổng gốc: ${CurrencyUtils.formatVND(debt.totalAmount)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              backgroundColor: Colors.white.withOpacity(0.3),
              color: Colors.white,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(Debt debt) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.calendar_today, 'Ngày bắt đầu', app_date_utils.DateUtils.formatFullDate(debt.startDate)),
            const Divider(),
            _buildInfoRow(Icons.event_note, 'Hạn cuối', debt.dueDate != null ? app_date_utils.DateUtils.formatFullDate(debt.dueDate!) : 'Không có'),
            const Divider(),
            _buildInfoRow(Icons.percent, 'Lãi suất', '${debt.interestRate}${debt.interestType == "fixed" ? "đ" : "%"} (${debt.interestType})'),
            if (debt.note != null && debt.note!.isNotEmpty) ...[
              const Divider(),
              _buildInfoRow(Icons.description, 'Ghi chú', debt.note!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction t) {
    final isTransfer = t.type == 'transfer';
    final isIncome = t.type == 'income';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTransfer ? Colors.blue.shade50 : (isIncome ? Colors.green.shade50 : Colors.red.shade50),
          child: Icon(
            isTransfer ? Icons.compare_arrows : (isIncome ? Icons.add : Icons.remove),
            color: isTransfer ? Colors.blue : (isIncome ? Colors.green : Colors.red),
          ),
        ),
        title: Text(t.note ?? 'Giao dịch trả nợ'),
        subtitle: Text(app_date_utils.DateUtils.formatFullDate(t.date)),
        trailing: Text(
          '${isIncome ? "+" : "-"}${CurrencyUtils.formatVND(t.amount)}',
          style: TextStyle(
            color: isIncome ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showRepaymentDialog(BuildContext context, Debt debt) {
    final principalController = TextEditingController(text: debt.remainingAmount.toStringAsFixed(0));
    final interestController = TextEditingController(text: '0');
    final noteController = TextEditingController();
    int? selectedAccountId;
    int? selectedInterestCategoryId;

    final isLend = debt.type == 'lend';

    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer(
        builder: (dialogCtx, dialogRef, _) {
          final accountsAsync = dialogRef.watch(accountsProvider);
          final categoriesAsync = debt.type == 'borrow'
              ? dialogRef.watch(expenseCategoriesProvider)
              : dialogRef.watch(incomeCategoriesProvider);

          return AlertDialog(
            title: Text(isLend ? 'Nhận trả nợ từ ${debt.person}' : 'Trả nợ cho ${debt.person}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: principalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isLend ? 'Tiền gốc nhận lại' : 'Tiền gốc trả',
                      suffixText: 'đ',
                      helperText: 'Còn lại: ${CurrencyUtils.formatVND(debt.remainingAmount)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: interestController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isLend ? 'Tiền lãi nhận' : 'Tiền lãi trả',
                      suffixText: 'đ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  accountsAsync.when(
                    data: (accounts) {
                      final validAccounts = accounts.where((a) => a.type != 'SAVING_DEPOSIT').toList();
                      if (selectedAccountId == null && validAccounts.isNotEmpty) {
                        selectedAccountId = validAccounts.first.id;
                      }
                      return DropdownButtonFormField<int>(
                        value: selectedAccountId,
                        decoration: InputDecoration(labelText: isLend ? 'Nhận vào ví' : 'Trả từ ví'),
                        items: validAccounts.map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name} (${CurrencyUtils.formatVND(a.balance)})'),
                        )).toList(),
                        onChanged: (val) => selectedAccountId = val,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Lỗi ví'),
                  ),
                  const SizedBox(height: 16),
                  categoriesAsync.when(
                    data: (categories) {
                      return DropdownButtonFormField<int>(
                        value: selectedInterestCategoryId,
                        decoration: const InputDecoration(labelText: 'Hạng mục tiền lãi'),
                        items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (val) => selectedInterestCategoryId = val,
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Ghi chú'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Hủy')),
              FilledButton(
                onPressed: () async {
                  final principal = double.tryParse(principalController.text) ?? 0;
                  final interest = double.tryParse(interestController.text) ?? 0;

                  if ((principal > 0 || interest > 0) && selectedAccountId != null) {
                    await dialogRef.read(debtRepositoryProvider).addRepayment(
                      debtId: debt.id,
                      principal: principal,
                      interest: interest,
                      accountId: selectedAccountId!,
                      categoryId: selectedInterestCategoryId,
                      note: noteController.text.isNotEmpty ? noteController.text : null,
                    );
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    _loadData(); // Refresh detail screen
                  }
                },
                child: const Text('Xác nhận'),
              ),
            ],
          );
        },
      ),
    );
  }
}
