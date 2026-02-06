import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/repositories/transaction_repository.dart';
import '../../../providers/app_providers.dart';

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

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final transaction = transactions[index];
              return TransactionItem(item: transaction);
            },
            childCount: transactions.length,
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
        '${app_date.DateUtils.formatDayMonth(t.date)} • ${item.account.name}',
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
        // TODO: Navigate to Common Details
      },
    );
  }
}
