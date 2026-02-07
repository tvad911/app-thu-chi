import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diacritic/diacritic.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';

class TransactionSearchScreen extends ConsumerStatefulWidget {
  const TransactionSearchScreen({super.key});

  @override
  ConsumerState<TransactionSearchScreen> createState() => _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends ConsumerState<TransactionSearchScreen> {
  final _searchController = TextEditingController();

  // Filters
  String? _selectedType; // expense, income, transfer
  DateTime? _dateFrom;
  DateTime? _dateTo;
  double? _amountMin;
  double? _amountMax;

  List<Transaction> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final db = ref.read(databaseProvider);
    final keyword = _searchController.text.trim();
    final normalizedKeyword = removeDiacritics(keyword.toLowerCase());

    // Fetch all transactions for the user, then filter client-side
    // This approach allows diacritic-insensitive search on note field
    final query = db.select(db.transactions)
      ..where((t) => t.userId.equals(user.id))
      ..orderBy([(t) => drift.OrderingTerm(expression: t.date, mode: drift.OrderingMode.desc)]);

    var allResults = await query.get();

    // Apply filters client-side for simplicity and correctness
    if (_selectedType != null) {
      allResults = allResults.where((t) => t.type == _selectedType).toList();
    }
    if (_dateFrom != null) {
      allResults = allResults.where((t) => !t.date.isBefore(_dateFrom!)).toList();
    }
    if (_dateTo != null) {
      final endOfDay = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
      allResults = allResults.where((t) => !t.date.isAfter(endOfDay)).toList();
    }
    if (_amountMin != null) {
      allResults = allResults.where((t) => t.amount >= _amountMin!).toList();
    }
    if (_amountMax != null) {
      allResults = allResults.where((t) => t.amount <= _amountMax!).toList();
    }

    // Keyword search with diacritics support
    if (keyword.isNotEmpty) {
      allResults = allResults.where((t) {
        final note = t.note ?? '';
        final normalizedNote = removeDiacritics(note.toLowerCase());
        return normalizedNote.contains(normalizedKeyword) || note.toLowerCase().contains(keyword.toLowerCase());
      }).toList();
    }

    setState(() {
      _results = allResults;
      _isLoading = false;
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm giao dịch')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo ghi chú...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _search();
                        },
                      ),
                    IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilters),
                  ],
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),

          // Active filter chips
          if (_selectedType != null || _dateFrom != null || _dateTo != null || _amountMin != null || _amountMax != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (_selectedType != null)
                    _filterChip(_typeLabel(_selectedType!), () => setState(() => _selectedType = null)),
                  if (_dateFrom != null)
                    _filterChip('Từ: ${app_date.DateUtils.formatDayMonth(_dateFrom!)}', () => setState(() => _dateFrom = null)),
                  if (_dateTo != null)
                    _filterChip('Đến: ${app_date.DateUtils.formatDayMonth(_dateTo!)}', () => setState(() => _dateTo = null)),
                  if (_amountMin != null)
                    _filterChip('Min: ${CurrencyUtils.formatCompact(_amountMin!)}', () => setState(() => _amountMin = null)),
                  if (_amountMax != null)
                    _filterChip('Max: ${CurrencyUtils.formatCompact(_amountMax!)}', () => setState(() => _amountMax = null)),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, size: 64, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Nhập từ khóa hoặc sử dụng bộ lọc', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(child: Text('Không tìm thấy kết quả', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (ctx, i) => _buildTransactionTile(ctx, _results[i]),
                          ),
          ),

          // Result count
          if (_hasSearched && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${_results.length} kết quả',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onDeleted: () {
          onRemove();
          _search();
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, Transaction t) {
    final isExpense = t.type == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final sign = isExpense ? '-' : '+';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(
          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 20,
        ),
      ),
      title: Text(t.note ?? _typeLabel(t.type)),
      subtitle: Text(app_date.DateUtils.formatFullDate(t.date)),
      trailing: Text(
        '$sign${CurrencyUtils.formatVND(t.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'expense': return 'Chi tiêu';
      case 'income': return 'Thu nhập';
      case 'transfer': return 'Chuyển khoản';
      default: return type;
    }
  }

  void _showFilters() {
    final amountMinCtrl = TextEditingController(text: _amountMin?.toStringAsFixed(0) ?? '');
    final amountMaxCtrl = TextEditingController(text: _amountMax?.toStringAsFixed(0) ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bộ lọc nâng cao', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Type selector
            const Text('Loại giao dịch', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('Tất cả'), selected: _selectedType == null, onSelected: (_) => setState(() => _selectedType = null)),
                ChoiceChip(label: const Text('Chi tiêu'), selected: _selectedType == 'expense', onSelected: (_) => setState(() => _selectedType = 'expense')),
                ChoiceChip(label: const Text('Thu nhập'), selected: _selectedType == 'income', onSelected: (_) => setState(() => _selectedType = 'income')),
                ChoiceChip(label: const Text('Chuyển'), selected: _selectedType == 'transfer', onSelected: (_) => setState(() => _selectedType = 'transfer')),
              ],
            ),
            const SizedBox(height: 16),

            // Date range
            const Text('Khoảng thời gian', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_dateFrom != null ? app_date.DateUtils.formatFullDate(_dateFrom!) : 'Từ ngày'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _pickDate(true);
                      if (mounted) _showFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_dateTo != null ? app_date.DateUtils.formatFullDate(_dateTo!) : 'Đến ngày'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _pickDate(false);
                      if (mounted) _showFilters();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount range
            const Text('Khoảng số tiền', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amountMinCtrl,
                    decoration: const InputDecoration(labelText: 'Tối thiểu', suffixText: '₫', isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: amountMaxCtrl,
                    decoration: const InputDecoration(labelText: 'Tối đa', suffixText: '₫', isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedType = null;
                        _dateFrom = null;
                        _dateTo = null;
                        _amountMin = null;
                        _amountMax = null;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Xóa bộ lọc'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _amountMin = double.tryParse(amountMinCtrl.text);
                        _amountMax = double.tryParse(amountMaxCtrl.text);
                      });
                      Navigator.pop(ctx);
                      _search();
                    },
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
