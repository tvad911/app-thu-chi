import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/repositories/saving_repository.dart';
import '../../../providers/app_providers.dart';
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
              final balance = item.account.balance;
              final interest = item.saving.interestRate;
              final expectedInterest = item.saving.expectedInterest;
              final maturity = item.saving.maturityDate;
              final daysLeft = maturity.difference(DateTime.now()).inDays;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      if (daysLeft <= 0) ...[
                        const SizedBox(height: 8),
                         OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Show Settle Dialog
                            // For MVP simplicity, we can just show a toast or implement dialog later
                             ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tính năng tất toán đang được phát triển')),
                             );
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Tất toán ngay'),
                          style: OutlinedButton.styleFrom(
                             foregroundColor: Colors.red,
                             side: const BorderSide(color: Colors.red),
                          ),
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
    );
  }
}
