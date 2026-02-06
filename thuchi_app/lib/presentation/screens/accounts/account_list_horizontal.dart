import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import 'account_form_screen.dart';

class AccountListHorizontal extends ConsumerWidget {
  const AccountListHorizontal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length + 1, // +1 for "Add" button
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == accounts.length) {
                return _AddAccountCard();
              }
              return AccountCard(account: accounts[index]);
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Text('Lỗi: $err'),
    );
  }
}

class AccountCard extends StatelessWidget {
  final Account account;

  const AccountCard({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    // Parse color string to Color object
    Color? accountColor;
    if (account.color != null) {
      accountColor = Color(int.parse(account.color!.replaceAll('#', '0xFF')));
    }
    
    // Default color based on type if not set
    if (accountColor == null) {
       switch (account.type) {
        case 'cash':
          accountColor = Colors.green;
          break;
        case 'bank':
          accountColor = Colors.blue;
          break;
        case 'credit':
          accountColor = Colors.orange;
          break;
        default:
          accountColor = Colors.grey;
      }
    }

    return Container(
      width: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accountColor, accountColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accountColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getIconForType(account.type),
                color: Colors.white,
                size: 20,
              ),
              const Spacer(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyUtils.formatCompact(account.balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'cash':
        return Icons.money;
      case 'bank':
        return Icons.account_balance;
      case 'credit':
        return Icons.credit_card;
      default:
        return Icons.wallet;
    }
  }
}

class _AddAccountCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountFormScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
