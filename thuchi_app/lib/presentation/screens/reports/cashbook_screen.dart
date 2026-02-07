import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';

/// Cashbook view — daily running balance
class CashbookScreen extends ConsumerStatefulWidget {
  const CashbookScreen({super.key});

  @override
  ConsumerState<CashbookScreen> createState() => _CashbookScreenState();
}

class _CashbookScreenState extends ConsumerState<CashbookScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: Text('Chưa đăng nhập'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ quỹ (Cashbook)'),
      ),
      body: Column(
        children: [
          // Month selector
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                    });
                  },
                ),
                Text(
                  'Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                    });
                  },
                ),
              ],
            ),
          ),

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Row(
              children: [
                SizedBox(width: 80, child: Text('Ngày', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                Expanded(child: Text('Nội dung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                SizedBox(width: 90, child: Text('Thu', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green))),
                SizedBox(width: 90, child: Text('Chi', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red))),
                SizedBox(width: 90, child: Text('Tồn', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              ],
            ),
          ),

          // Cashbook entries
          Expanded(
            child: FutureBuilder<List<CashbookEntry>>(
              future: _loadCashbook(user.id),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snap.data ?? [];
                if (entries.isEmpty) {
                  return const Center(child: Text('Không có giao dịch', style: TextStyle(color: Colors.grey)));
                }

                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 80, child: Text(app_date.DateUtils.formatDayMonth(e.date), style: const TextStyle(fontSize: 12))),
                          Expanded(child: Text(e.note, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                          SizedBox(
                            width: 90,
                            child: Text(
                              e.income > 0 ? CurrencyUtils.formatCompact(e.income) : '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              e.expense > 0 ? CurrencyUtils.formatCompact(e.expense) : '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              CurrencyUtils.formatCompact(e.balance),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: e.balance >= 0 ? Colors.black87 : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Future<List<CashbookEntry>> _loadCashbook(int userId) async {
    final db = ref.read(databaseProvider);

    // Fetch all transactions for user, sort by date
    final allTransactions = await (db.select(db.transactions)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => drift.OrderingTerm(expression: t.date, mode: drift.OrderingMode.asc)]))
        .get();

    // Filter by selected month client-side
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

    final transactions = allTransactions
        .where((t) => !t.date.isBefore(firstDay) && !t.date.isAfter(lastDay))
        .toList();

    // Calculate running balance
    double runningBalance = 0;
    final entries = <CashbookEntry>[];

    for (final t in transactions) {
      double income = 0;
      double expense = 0;

      if (t.type == 'income') {
        income = t.amount;
        runningBalance += t.amount;
      } else if (t.type == 'expense') {
        expense = t.amount;
        runningBalance -= t.amount;
      }

      if (t.type != 'transfer') {
        entries.add(CashbookEntry(
          date: t.date,
          note: t.note ?? (t.type == 'income' ? 'Thu nhập' : 'Chi tiêu'),
          income: income,
          expense: expense,
          balance: runningBalance,
        ));
      }
    }

    return entries;
  }
}

class CashbookEntry {
  final DateTime date;
  final String note;
  final double income;
  final double expense;
  final double balance;

  CashbookEntry({
    required this.date,
    required this.note,
    required this.income,
    required this.expense,
    required this.balance,
  });
}
