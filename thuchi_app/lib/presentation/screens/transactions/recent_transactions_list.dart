import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/repositories/transaction_repository.dart';
import '../../../providers/app_providers.dart';
import 'transaction_form_screen.dart' as import_transaction_screen;

class RecentTransactionsList extends ConsumerWidget {
  const RecentTransactionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);

    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Chưa có giao dịch nào'),
              ),
            ),
          );
        }

        // Group transactions by date
        final grouped = <DateTime, List<TransactionWithDetails>>{};
        for (final t in transactions) {
          final dateKey = DateTime(t.transaction.date.year, t.transaction.date.month, t.transaction.date.day);
          grouped.putIfAbsent(dateKey, () => []).add(t);
        }
        final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        // Build flat list with date headers
        final items = <_ListItem>[];
        for (final dateKey in sortedKeys) {
          items.add(_ListItem.header(dateKey));
          for (final txn in grouped[dateKey]!) {
            items.add(_ListItem.transaction(txn));
          }
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              if (item.isHeader) {
                return _DateHeader(date: item.date!);
              }
              return TransactionItem(item: item.transaction!);
            },
            childCount: items.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        )),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Center(child: Text('Lỗi: $err')),
      ),
    );
  }
}

/// Internal model for mixed header/transaction list
class _ListItem {
  final DateTime? date;
  final TransactionWithDetails? transaction;
  final bool isHeader;

  _ListItem.header(this.date) : transaction = null, isHeader = true;
  _ListItem.transaction(this.transaction) : date = null, isHeader = false;
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        app_date.DateUtils.formatRelative(date),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class TransactionItem extends StatelessWidget {
  final TransactionWithDetails item;

  const TransactionItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final t = item.transaction;
    final colorScheme = Theme.of(context).colorScheme;

    Color amountColor;
    String prefix;
    IconData icon;

    if (t.type == 'income') {
      amountColor = colorScheme.incomeColor;
      prefix = '+';
      icon = Icons.arrow_downward;
    } else if (t.type == 'expense') {
      amountColor = colorScheme.expenseColor;
      prefix = '-';
      icon = Icons.arrow_upward;
    } else {
      amountColor = colorScheme.transferColor;
      prefix = '';
      icon = Icons.swap_horiz;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Icon(
          item.category != null
              ? IconData(item.category!.iconCodepoint,
                  fontFamily: 'MaterialIcons')
              : icon,
          color: amountColor,
        ),
      ),
      title: Text(
        item.category?.name ?? t.type,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        item.account.name,
      ),
      trailing: Text(
        '$prefix${CurrencyUtils.formatVND(t.amount)}',
        style: TextStyle(
          color: amountColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => import_transaction_screen.TransactionFormScreen(transaction: item),
          ),
        );
      },
    );
  }
}
