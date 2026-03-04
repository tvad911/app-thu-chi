import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/utils/currency_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../providers/app_providers.dart';
import '../transactions/transaction_form_screen.dart' as txn_screen;

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  DateTime _selectedDate = DateTime.now();

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
  }

  /// Bảng màu phong phú cho fallback khi category chưa set color
  static const _budgetPalette = [
    Color(0xFF2196F3), // Blue
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF9800), // Orange
    Color(0xFF009688), // Teal
    Color(0xFF795548), // Brown
    Color(0xFF3F51B5), // Indigo
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF00BCD4), // Cyan
    Color(0xFF8BC34A), // Light Green
  ];

  /// Lấy màu hiển thị của budget item
  /// Ưu tiên: category color → palette theo index
  Color _resolveColor(Category category, int index) {
    final hex = category.color;
    if (hex != null && hex.isNotEmpty) {
      try {
        return Color(int.parse(hex.replaceAll('#', '0xFF')));
      } catch (_) {}
    }
    return _budgetPalette[index % _budgetPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(
        budgetsForMonthProvider((_selectedDate.month, _selectedDate.year)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngân sách Chi tiêu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddBudgetDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Selector
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  'Tháng ${_selectedDate.month}/${_selectedDate.year}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          const Divider(),

          Expanded(
            child: budgetsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('Lỗi: $err')),
              data: (budgets) {
                if (budgets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Chưa có ngân sách nào cho tháng này'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showAddBudgetDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Thiết lập ngay'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: budgets.length,
                  itemBuilder: (context, index) {
                    final item = budgets[index];
                    final percentage = item.usagePercentage;
                    final color = _resolveColor(item.category, index);

                    return _BudgetCard(
                      item: item,
                      color: color,
                      percentage: percentage,
                      selectedDate: _selectedDate,
                      onEdit: () => _showAddBudgetDialog(context,
                          existingBudget: item.budget),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBudgetDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context, {Budget? existingBudget}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _BudgetForm(
        selectedDate: _selectedDate,
        existingBudget: existingBudget,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Card with tap → transaction history
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final BudgetWithCategory item;
  final Color color;
  final double percentage;
  final DateTime selectedDate;
  final VoidCallback onEdit;

  const _BudgetCard({
    required this.item,
    required this.color,
    required this.percentage,
    required this.selectedDate,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showTransactionHistory(context),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(
                      IconData(item.category.iconCodepoint,
                          fontFamily: 'MaterialIcons'),
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.category.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Hạn mức: ${CurrencyUtils.formatVND(item.budget.amountLimit)}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Tap hint
                  Icon(Icons.history, size: 18, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: onEdit,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: percentage > 1.0 ? 1.0 : percentage,
                backgroundColor: Colors.grey[200],
                color: color,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    CurrencyUtils.formatVND(item.spentAmount),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (percentage >= 0.8) ...[
                const SizedBox(height: 4),
                Text(
                  percentage >= 1.0
                      ? 'Đã vượt quá hạn mức!'
                      : 'Sắp hết ngân sách!',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ],
              // Tap hint label
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap để xem lịch sử giao dịch',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BudgetTransactionSheet(
        categoryId: item.category.id,
        categoryName: item.category.name,
        categoryIconCode: item.category.iconCodepoint,
        month: selectedDate.month,
        year: selectedDate.year,
        color: color,
        amountLimit: item.budget.amountLimit,
        spentAmount: item.spentAmount,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheet: Lịch sử giao dịch theo category + tháng
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetTransactionSheet extends ConsumerWidget {
  final int categoryId;
  final String categoryName;
  final int categoryIconCode;
  final int month;
  final int year;
  final Color color;
  final double amountLimit;
  final double spentAmount;

  const _BudgetTransactionSheet({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIconCode,
    required this.month,
    required this.year,
    required this.color,
    required this.amountLimit,
    required this.spentAmount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(budgetTransactionsProvider(
      (categoryId: categoryId, month: month, year: year),
    ));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    IconData(categoryIconCode, fontFamily: 'MaterialIcons'),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tháng $month/$year',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Summary row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _SummaryChip(
                  label: 'Đã chi',
                  value: CurrencyUtils.formatVND(spentAmount),
                  color: color,
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'Hạn mức',
                  value: CurrencyUtils.formatVND(amountLimit),
                  color: Colors.grey[600]!,
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'Còn lại',
                  value: CurrencyUtils.formatVND(
                      (amountLimit - spentAmount).clamp(0, double.infinity)),
                  color: (amountLimit - spentAmount) >= 0
                      ? Colors.green
                      : Colors.red,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Transaction List
          Expanded(
            child: txnsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Lỗi: $e')),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'Chưa có giao dịch nào trong tháng này',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = transactions[index];
                    final t = item.transaction;
                    return _TransactionTile(
                      item: item,
                      color: color,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                txn_screen.TransactionFormScreen(
                                    transaction: item),
                          ),
                        );
                        ref.invalidate(budgetTransactionsProvider);
                        ref.invalidate(budgetsForMonthProvider);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionWithDetails item;
  final Color color;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.item,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = item.transaction;
    final date = t.date;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          item.category != null
              ? IconData(item.category!.iconCodepoint,
                  fontFamily: 'MaterialIcons')
              : Icons.arrow_upward,
          size: 16,
          color: color,
        ),
      ),
      title: Text(
        t.note ?? item.category?.name ?? 'Chi tiêu',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Text(
        '${date.day}/${date.month}/${date.year}  •  ${item.account.name}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Text(
        '-${CurrencyUtils.formatVND(t.amount)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Form (Add / Edit)
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetForm extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final Budget? existingBudget;

  const _BudgetForm({
    required this.selectedDate,
    this.existingBudget,
  });

  @override
  ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<_BudgetForm> {
  final _amountController = TextEditingController();
  Category? _selectedCategory;
  bool _isRecurring = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingBudget != null) {
      _amountController.text =
          widget.existingBudget!.amountLimit.toStringAsFixed(0);
      _isRecurring = widget.existingBudget!.isRecurring;
    }
  }

  Future<void> _save() async {
    if (_selectedCategory == null && widget.existingBudget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn danh mục')));
      return;
    }

    final amount =
        double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')));
      return;
    }

    final repo = ref.read(budgetRepositoryProvider);
    final categoryId =
        widget.existingBudget?.categoryId ?? _selectedCategory!.id;

    await repo.setBudget(
      BudgetsCompanion(
        categoryId: drift.Value(categoryId),
        amountLimit: drift.Value(amount),
        month: drift.Value(widget.selectedDate.month),
        year: drift.Value(widget.selectedDate.year),
        isRecurring: drift.Value(_isRecurring),
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.existingBudget != null) {
      final repo = ref.read(budgetRepositoryProvider);
      await repo.deleteBudget(widget.existingBudget!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategoriesAsync = ref.watch(expenseCategoriesProvider);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existingBudget != null
                  ? 'Chỉnh sửa ngân sách'
                  : 'Thêm ngân sách mới',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Dropdown only if creating new
            if (widget.existingBudget == null)
              expenseCategoriesAsync.when(
                data: (categories) {
                  return DropdownButtonFormField<Category>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                        labelText: 'Danh mục chi tiêu'),
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Icon(
                                      IconData(c.iconCodepoint,
                                          fontFamily: 'MaterialIcons'),
                                      size: 18,
                                      color: c.color != null
                                          ? Color(int.parse(c.color!
                                              .replaceAll('#', '0xFF')))
                                          : null),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const Text('Lỗi tải danh mục'),
              ),

            if (widget.existingBudget != null) const SizedBox.shrink(),

            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Hạn mức (VNĐ)',
                suffixText: '₫',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _isRecurring,
                  onChanged: (v) =>
                      setState(() => _isRecurring = v ?? false),
                ),
                const Text('Tự động lặp lại tháng sau'),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.existingBudget != null)
                  TextButton(
                    onPressed: _delete,
                    child: Text('Xóa',
                        style: TextStyle(color: Colors.red[700])),
                  ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Lưu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
