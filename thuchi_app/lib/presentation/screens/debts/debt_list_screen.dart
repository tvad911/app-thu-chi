import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/database/app_database.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;
import 'debt_detail_screen.dart';

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
        onPressed: () {
          // Navigate to form
          Navigator.pushNamed(context, '/debts/add');
        },
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
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: debt.id))
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          debt.person,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          overflow: TextOverflow.ellipsis,
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
                      if (debt.dueDate != null) ...[
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

  void _showPaymentDialog(BuildContext context, Debt debt) {
    final principalController = TextEditingController(text: debt.remainingAmount.toString());
    final interestController = TextEditingController(text: '0');
    final noteController = TextEditingController();
    int? selectedAccountId;
    int? selectedInterestCategoryId;

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final accountsAsync = ref.watch(accountsProvider);
          final categoriesAsync = debt.type == 'borrow' ? ref.watch(expenseCategoriesProvider) : ref.watch(incomeCategoriesProvider);

          return AlertDialog(
            title: Text('Trả nợ cho ${debt.person}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: principalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tiền gốc trả',
                      suffixText: 'đ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: interestController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tiền lãi trả (nếu có)',
                      suffixText: 'đ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  accountsAsync.when(
                    data: (accounts) {
                      if (selectedAccountId == null && accounts.isNotEmpty) {
                        selectedAccountId = accounts.first.id;
                      }
                      return DropdownButtonFormField<int>(
                        value: selectedAccountId,
                        decoration: const InputDecoration(labelText: 'Từ ví'),
                        items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
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
                    loading: () => Container(),
                    error: (_, __) => Container(),
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
              FilledButton(
                onPressed: () async {
                  final principal = double.tryParse(principalController.text) ?? 0;
                  final interest = double.tryParse(interestController.text) ?? 0;
                  
                  if (principal > 0 || interest > 0) {
                    await ref.read(debtRepositoryProvider).addRepayment(
                      debtId: debt.id,
                      principal: principal,
                      interest: interest,
                      accountId: selectedAccountId!,
                      categoryId: selectedInterestCategoryId,
                      note: noteController.text,
                    );
                    if (context.mounted) Navigator.pop(context);
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

  void _markAsFinished(Debt debt) {
     // Already handled by repository when principal covers remaining
  }
}
