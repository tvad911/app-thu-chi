import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/database/app_database.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;
import 'debt_detail_screen.dart';
import 'debt_form_screen.dart';

class DebtListScreen extends ConsumerStatefulWidget {
  const DebtListScreen({super.key});

  @override
  ConsumerState<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends ConsumerState<DebtListScreen> with SingleTickerProviderStateMixin {
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
    final debtsAsync = ref.watch(activeDebtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Nợ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Cho vay'),
            Tab(text: 'Đi vay'),
          ],
        ),
      ),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
        data: (debts) {
          final lendDebts = debts.where((d) => d.type == 'lend').toList();
          final borrowDebts = debts.where((d) => d.type == 'borrow').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildDebtList(lendDebts, true),
              _buildDebtList(borrowDebts, false),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/debts/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDebtList(List<Debt> debts, bool isLend) {
    if (debts.isEmpty) {
      return const Center(child: Text('Chưa có khoản nợ nào'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: debts.length,
      itemBuilder: (context, index) {
        final debt = debts[index];
        final remaining = debt.remainingAmount;
        final progress = debt.totalAmount > 0 ? (debt.totalAmount - remaining) / debt.totalAmount : 0.0;

        final isOverdue = debt.dueDate != null && debt.dueDate!.isBefore(DateTime.now()) && !debt.isFinished;
        final isNearDue = debt.dueDate != null &&
            debt.dueDate!.difference(DateTime.now()).inDays <= debt.notifyDays &&
            !debt.isFinished;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showActionSheet(debt, isLend),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLend ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isLend ? Colors.green : Colors.red, width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLend ? Icons.arrow_upward : Icons.arrow_downward,
                                    size: 12,
                                    color: isLend ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isLend ? 'Cho vay' : 'Đi vay',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isLend ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                debt.person,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyUtils.formatVND(remaining),
                        style: TextStyle(
                          color: isLend ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    backgroundColor: Colors.grey[200],
                    color: isLend ? Colors.green : Colors.red,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.percent, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${debt.interestRate}${debt.interestType == "fixed" ? "đ" : "%"} (${debt.interestType})',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const Spacer(),
                      if (debt.isFinished)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Đã tất toán', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                      if (!debt.isFinished && debt.dueDate != null) ...[
                        Icon(
                          Icons.event_note,
                          size: 14,
                          color: isOverdue ? Colors.red : (isNearDue ? Colors.orange : Colors.grey[600]),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          app_date_utils.DateUtils.formatFullDate(debt.dueDate!),
                          style: TextStyle(
                            color: isOverdue ? Colors.red : (isNearDue ? Colors.orange : Colors.grey[600]),
                            fontSize: 13,
                            fontWeight: (isOverdue || isNearDue) ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ──── Action Sheet ────
  void _showActionSheet(Debt debt, bool isLend) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLend ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isLend ? 'Cho vay' : 'Đi vay',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isLend ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(debt.person, style: Theme.of(ctx).textTheme.titleLarge),
                  ),
                  Text(CurrencyUtils.formatVND(debt.remainingAmount),
                      style: TextStyle(color: isLend ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 0),

            // 1. View detail
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('Xem chi tiết'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: debt.id)));
              },
            ),

            // 2. Edit
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text('Chỉnh sửa'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => DebtFormScreen(existingDebt: debt)),
                );
                if (result == true) ref.invalidate(activeDebtsProvider);
              },
            ),

            // 3. Repay / Receive repayment (only if not finished)
            if (!debt.isFinished)
              ListTile(
                leading: Icon(
                  isLend ? Icons.call_received : Icons.call_made,
                  color: isLend ? Colors.green : Colors.deepOrange,
                ),
                title: Text(isLend ? 'Nhận trả nợ' : 'Trả nợ'),
                subtitle: Text(isLend
                    ? 'Ghi nhận ${debt.person} trả tiền cho bạn'
                    : 'Ghi nhận bạn trả tiền cho ${debt.person}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRepaymentDialog(debt, isLend);
                },
              ),

            // 4. Delete
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Xóa khoản nợ'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmDelete(debt);
                if (confirmed) {
                  await ref.read(debtRepositoryProvider).deleteDebt(debt.id);
                  ref.invalidate(activeDebtsProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa khoản nợ')));
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(Debt debt) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khoản nợ?'),
        content: Text('Bạn có chắc muốn xóa khoản nợ với "${debt.person}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    ) ?? false;
  }

  // ──── Repayment Dialog ────
  void _showRepaymentDialog(Debt debt, bool isLend) {
    final principalController = TextEditingController(text: debt.remainingAmount.toStringAsFixed(0));
    final interestController = TextEditingController(text: '0');
    final noteController = TextEditingController();
    int? selectedAccountId;
    int? selectedInterestCategoryId;

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
                    ref.invalidate(activeDebtsProvider);
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
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
