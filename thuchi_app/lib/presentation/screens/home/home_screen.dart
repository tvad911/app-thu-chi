import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../data/repositories/event_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import '../accounts/account_list_horizontal.dart';
import '../bills/bill_list_screen.dart';
import '../debts/debt_list_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/event_list_screen.dart';
import '../transactions/recent_transactions_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalance = ref.watch(totalBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh providers
          ref.invalidate(totalBalanceProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: totalBalance.when(
                  data: (balance) => _TotalBalanceCard(balance: balance),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('Lỗi: $err'),
                ),
              ),
            ),

            // Active Events Widget
            SliverToBoxAdapter(
              child: _ActiveEventsBanner(ref: ref),
            ),
            // Quick access shortcuts
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _QuickAction(
                      icon: Icons.monetization_on,
                      label: 'Vay/Cho vay',
                      color: Colors.orange,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtListScreen())),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.receipt_long,
                      label: 'Hóa đơn',
                      color: Colors.purple,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillListScreen())),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.flight_takeoff,
                      label: 'Sự kiện',
                      color: Colors.teal,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventListScreen())),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Ví của bạn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AccountListHorizontal(),
                ],
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.all(16.0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Giao dịch gần đây',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const RecentTransactionsList(),
          ],
        ),
      ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  final double balance;

  const _TotalBalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Tổng số dư',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              CurrencyUtils.formatVND(balance),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveEventsBanner extends StatelessWidget {
  final WidgetRef ref;
  const _ActiveEventsBanner({required this.ref});

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<List<EventWithSpending>>(
      future: ref.read(eventRepositoryProvider).getEventsWithSpending(user.id),
      builder: (context, snapshot) {
        final events = (snapshot.data ?? []).where((e) => !e.event.isFinished).toList();
        if (events.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: events.take(2).map((data) {
              final event = data.event;
              final usagePercent = data.usagePercent;
              Color progressColor;
              if (usagePercent >= 100) {
                progressColor = Colors.red;
              } else if (usagePercent >= 80) {
                progressColor = Colors.orange;
              } else {
                progressColor = Colors.teal;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.flight_takeoff, color: Colors.teal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                '${CurrencyUtils.format(data.totalSpending)} / ${CurrencyUtils.format(event.budget)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (usagePercent / 100).clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  color: progressColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
