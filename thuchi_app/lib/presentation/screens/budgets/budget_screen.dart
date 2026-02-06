import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/utils/currency_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../providers/app_providers.dart';

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

  Color _getStatusColor(double percentage) {
    if (percentage >= 1.0) return Colors.red;
    if (percentage >= 0.8) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    // Watch budgets for the selected month/year
    final budgetsAsync = ref.watch(budgetsForMonthProvider((_selectedDate.month, _selectedDate.year)));

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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  'Tháng ${_selectedDate.month}/${_selectedDate.year}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi: $err')),
              data: (budgets) {
                if (budgets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
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
                    final color = _getStatusColor(percentage);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Icon(
                                    IconData(item.category.iconCodepoint, fontFamily: 'MaterialIcons'),
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.category.name, 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                      ),
                                      Text(
                                        'Hạn mức: ${CurrencyUtils.formatVND(item.budget.amountLimit)}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _showAddBudgetDialog(context, existingBudget: item.budget),
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
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (percentage >= 0.8) ...[
                              const SizedBox(height: 4),
                              Text(
                                percentage >= 1.0 
                                  ? 'Đã vượt quá hạn mức!' 
                                  : 'Sắp hết ngân sách!',
                                style: TextStyle(color: color, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ]
                          ],
                        ),
                      ),
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
      _amountController.text = widget.existingBudget!.amountLimit.toStringAsFixed(0);
      _isRecurring = widget.existingBudget!.isRecurring;
      // Note: Setting selectedCategory for existing budget requires fetching category by ID sync or passed in.
      // For simplicity, we just won't show the category dropdown if editing, or will load it.
      // Ideally, the parent passes the whole BudgetWithCategory item.
      // BUT, since we have only ID, we should pre-select it after the list loads.
    }
  }

  Future<void> _save() async {
    if (_selectedCategory == null && widget.existingBudget == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn danh mục')));
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')));
      return;
    }

    final repo = ref.read(budgetRepositoryProvider);
    
    // Create new or update
    final categoryId = widget.existingBudget?.categoryId ?? _selectedCategory!.id;
    
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
    // Only show categories that are Expense type
    final expenseCategoriesAsync = ref.watch(expenseCategoriesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existingBudget != null ? 'Chỉnh sửa ngân sách' : 'Thêm ngân sách mới',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Dropdown only if creating new
            if (widget.existingBudget == null)
              expenseCategoriesAsync.when(
                data: (categories) {
                   return DropdownButtonFormField<Category>(
                     value: _selectedCategory,
                     decoration: const InputDecoration(labelText: 'Danh mục chi tiêu'),
                     items: categories.map((c) => DropdownMenuItem(
                       value: c,
                       child: Row(
                         children: [
                            Icon(IconData(c.iconCodepoint, fontFamily: 'MaterialIcons'), size: 18),
                            const SizedBox(width: 8),
                            Text(c.name),
                         ],
                       ),
                     )).toList(),
                     onChanged: (val) => setState(() => _selectedCategory = val),
                   );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const Text('Lỗi tải danh mục'),
              ),
            
            if (widget.existingBudget != null)
               // Only show name if we could fetch it, or simplified UI
               // Since we passed only Budget object, we don't have name easily here without reading provider.
               // It's okay, user knows what they clicked.
               const SizedBox.shrink(),

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
                  onChanged: (v) => setState(() => _isRecurring = v ?? false)
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
                    child: Text('Xóa', style: TextStyle(color: Colors.red[700]))
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
