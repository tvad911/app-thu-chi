import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/saving_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import 'saving_form_screen.dart';

class SavingsListScreen extends ConsumerWidget {
  const SavingsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savingsAsync = ref.watch(activeSavingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ Tiết Kiệm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavingFormScreen()),
              );
            },
          ),
        ],
      ),
      body: savingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
        data: (savings) {
          if (savings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.savings_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Chưa có sổ tiết kiệm nào'),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SavingFormScreen()),
                      );
                    },
                    child: const Text('Mở sổ ngay'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: savings.length,
            separatorBuilder: (ctx, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = savings[index];
              return _SavingCard(item: item);
            },
          );
        },
      ),
    );
  }
}

class _SavingCard extends ConsumerWidget {
  final SavingWithAccount item;
  const _SavingCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = item.account.balance;
    final interest = item.saving.interestRate;
    final expectedInterest = item.saving.expectedInterest;
    final maturity = item.saving.maturityDate;
    final daysLeft = maturity.difference(DateTime.now()).inDays;

    return Dismissible(
      key: ValueKey(item.saving.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _deleteSaving(context, ref),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editSaving(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.account.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$interest%/năm',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Balance row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Số dư gốc', style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          CurrencyUtils.format(balance),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Lãi dự kiến', style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          '+${CurrencyUtils.format(expectedInterest)}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Maturity row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Đáo hạn: ${DateFormat('dd/MM/yyyy').format(maturity)}'),
                    if (daysLeft > 0)
                      Text(
                        'Còn $daysLeft ngày',
                        style: TextStyle(color: Colors.orange[800]),
                      )
                    else
                      const Text(
                        'Đã đến hạn',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),

                // Settle button
                if (daysLeft <= 0) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showSettleDialog(context, ref),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Tất toán ngay'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editSaving(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SavingFormScreen(existingSaving: item)),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa sổ tiết kiệm?'),
        content: Text('Bạn có chắc muốn xóa "${item.account.name}"?\nTất cả giao dịch liên quan sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _deleteSaving(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(savingRepositoryProvider).deleteSaving(item.saving.id);
      ref.invalidate(activeSavingsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(totalBalanceProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa sổ tiết kiệm')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  void _showSettleDialog(BuildContext context, WidgetRef ref) {
    final interestController = TextEditingController(
      text: item.saving.expectedInterest.toStringAsFixed(0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Consumer(
            builder: (ctx, settleRef, _) {
              final accountsAsync = settleRef.watch(accountsProvider);

              return accountsAsync.when(
                loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('Lỗi: $e'),
                data: (accounts) {
                  final validAccounts = accounts.where((a) => a.type != 'SAVING_DEPOSIT' && !(a.isArchived)).toList();
                  Account? selectedAccount = validAccounts.isNotEmpty ? validAccounts.first : null;

                  return StatefulBuilder(
                    builder: (ctx, setLocalState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Tất toán: ${item.account.name}',
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text('Gốc: ${CurrencyUtils.format(item.account.balance)}'),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: interestController,
                          decoration: const InputDecoration(
                            labelText: 'Tiền lãi thực nhận',
                            suffixText: '₫',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Account>(
                          value: selectedAccount,
                          decoration: const InputDecoration(labelText: 'Nhận về tài khoản'),
                          items: validAccounts.map((a) => DropdownMenuItem(
                            value: a,
                            child: Text('${a.name} (${CurrencyUtils.format(a.balance)})'),
                          )).toList(),
                          onChanged: (val) => setLocalState(() => selectedAccount = val),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: selectedAccount == null ? null : () async {
                            try {
                              final actualInterest = double.tryParse(interestController.text) ?? 0;
                              final userId = settleRef.read(currentUserProvider)!.id;

                              await settleRef.read(savingRepositoryProvider).settleSaving(
                                savingId: item.saving.id,
                                targetAccountId: selectedAccount!.id,
                                actualInterest: actualInterest,
                                settleDate: DateTime.now(),
                                userId: userId,
                              );

                              settleRef.invalidate(activeSavingsProvider);
                              settleRef.invalidate(accountsProvider);
                              settleRef.invalidate(totalBalanceProvider);

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Tất toán thành công!')),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Lỗi: $e')),
                                );
                              }
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Xác nhận tất toán'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
