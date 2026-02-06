import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import 'account_form_screen.dart';

class AccountListScreen extends ConsumerWidget {
  const AccountListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Ví'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openAddAccount(context),
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Chưa có ví nào'),
                  TextButton(
                    onPressed: () => _openAddAccount(context),
                    child: const Text('Thêm ví ngay'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _AccountListItem(account: accounts[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddAccount(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openAddAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountFormScreen()),
    );
  }
}

class _AccountListItem extends StatelessWidget {
  final Account account;

  const _AccountListItem({required this.account});

  @override
  Widget build(BuildContext context) {
    Color? accountColor;
    if (account.color != null) {
      accountColor = Color(int.parse(account.color!.replaceAll('#', '0xFF')));
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accountColor ?? Colors.grey,
          child: const Icon(Icons.account_balance_wallet, color: Colors.white),
        ),
        title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_getTypeName(account.type)),
        trailing: Text(
          CurrencyUtils.formatVND(account.balance),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AccountFormScreen(account: account),
            ),
          );
        },
      ),
    );
  }

  String _getTypeName(String type) {
    switch (type) {
      case 'cash':
        return 'Tiền mặt';
      case 'bank':
        return 'Ngân hàng';
      case 'credit':
        return 'Thẻ tín dụng';
      case 'saving_goal':
        return 'Quỹ tích lũy';
      default:
        return type;
    }
  }
}
