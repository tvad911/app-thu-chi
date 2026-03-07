import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../providers/app_providers.dart';
import '../transactions/transaction_form_screen.dart' as import_transaction_screen;

class AccountTransactionsScreen extends ConsumerWidget {
  final Account account;
  const AccountTransactionsScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(accountTransactionsProvider(account.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.name, style: const TextStyle(fontSize: 16)),
            Text(
              CurrencyUtils.formatVND(account.balance),
              style: TextStyle(
                fontSize: 13,
                color: account.balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có giao dịch nào'),
                ],
              ),
            );
          }

          // Group by date
          final grouped = <DateTime, List<TransactionWithDetails>>{};
          for (final t in transactions) {
            final dateKey = DateTime(t.transaction.date.year, t.transaction.date.month, t.transaction.date.day);
            grouped.putIfAbsent(dateKey, () => []).add(t);
          }
          final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final dateKey = sortedKeys[index];
              final dayTransactions = grouped[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      app_date.DateUtils.formatDate(dateKey),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  // Transaction items
                  ...dayTransactions.map((item) => _TransactionTile(
                    item: item,
                    currentAccountId: account.id,
                  )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionWithDetails item;
  final int currentAccountId;

  const _TransactionTile({required this.item, required this.currentAccountId});

  @override
  Widget build(BuildContext context) {
    final tx = item.transaction;
    final type = tx.type;
    final isIncome = type == 'income';
    final isTransfer = type == 'transfer';

    // Determine if this is incoming (credit) or outgoing (debit) for this account
    final isCredit = isIncome ||
        (isTransfer && tx.toAccountId == currentAccountId);

    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isCredit ? colorScheme.incomeColor : colorScheme.expenseColor;

    // Icon color from category
    Color iconColor = borderColor;
    IconData iconData = isTransfer ? Icons.swap_horiz : (isCredit ? Icons.arrow_downward : Icons.arrow_upward);
    if (item.category != null) {
      if (item.category!.color != null) {
        try {
          iconColor = Color(int.parse(item.category!.color!.replaceAll('#', '0xFF')));
        } catch (_) {}
      }
      iconData = IconData(
        item.category!.iconCodepoint,
        fontFamily: 'MaterialIcons',
      );
    }

    final amountPrefix = isCredit ? '+' : '-';

    return Card(
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: borderColor.withOpacity(0.1),
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(
          item.category?.name ?? (isTransfer ? 'Chuyển khoản' : type),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: tx.note != null && tx.note!.isNotEmpty
            ? Text(tx.note!, maxLines: 1, overflow: TextOverflow.ellipsis)
            : Text(item.account.name, style: TextStyle(color: Colors.grey[600])),
        trailing: Text(
          '$amountPrefix${CurrencyUtils.format(tx.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCredit ? colorScheme.incomeColor : colorScheme.expenseColor,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => import_transaction_screen.TransactionFormScreen(
                transaction: item,
              ),
            ),
          );
        },
      ),
    );
  }
}
