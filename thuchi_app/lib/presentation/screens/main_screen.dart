
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/accounts/account_list_screen.dart';
import '../../presentation/screens/reports/reports_screen.dart';
import '../../presentation/screens/budgets/budget_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/savings/savings_list_screen.dart';
import '../../presentation/screens/transactions/transaction_form_screen.dart'; // Correct import
import '../../providers/auth_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    AccountListScreen(),
    BudgetScreen(),
    ReportsScreen(),
    SavingsListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const NewTransactionIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewTransactionIntent: CallbackAction<NewTransactionIntent>(
            onInvoke: (NewTransactionIntent intent) {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
              );
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800; // Breakpoint
              
              if (isDesktop) {
                 return Scaffold(
                  body: Row(
                    children: [
                       NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (int index) {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        labelType: NavigationRailLabelType.all,
                        leading: Column(
                           children: [
                             const SizedBox(height: 16),
                             FloatingActionButton(
                                elevation: 0,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
                                  );
                                },
                                tooltip: 'Thêm (Ctrl+N)',
                                child: const Icon(Icons.add),
                              ),
                              const SizedBox(height: 16),
                           ]
                        ),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home),
                            label: Text('Trang chủ'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.account_balance_wallet_outlined),
                            selectedIcon: Icon(Icons.account_balance_wallet),
                            label: Text('Ví'),
                          ),
                           NavigationRailDestination(
                            icon: Icon(Icons.pie_chart_outline), 
                            selectedIcon: Icon(Icons.pie_chart), 
                            label: Text('Ngân sách'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.bar_chart_outlined),
                            selectedIcon: Icon(Icons.bar_chart),
                            label: Text('Thống kê'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.savings_outlined),
                            selectedIcon: Icon(Icons.savings),
                            label: Text('Tiết kiệm'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings),
                            label: Text('Cài đặt'),
                          ),
                        ],
                      ),
                      const VerticalDivider(thickness: 1, width: 1),
                      Expanded(
                        child: Scaffold(
                           appBar: AppBar(
                             title: const Text('ThuChi Desktop'),
                             actions: [
                               IconButton(
                                  icon: const Icon(Icons.logout),
                                  onPressed: () => _handleLogout(context),
                                )
                             ],
                           ),
                           body: _screens[_selectedIndex],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Mobile Layout
              return Scaffold(
                appBar: AppBar(
                  title: const Text('ThuChi'),
                  actions: [
                     IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => _handleLogout(context),
                    ),
                  ],
                ),
                body: IndexedStack(
                  index: _selectedIndex,
                  children: _screens,
                ),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Trang chủ',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: 'Ví',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.pie_chart_outline), 
                      selectedIcon: Icon(Icons.pie_chart), 
                      label: 'Ngân sách',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: 'Thống kê',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.savings_outlined),
                      selectedIcon: Icon(Icons.savings),
                      label: 'Tiết kiệm',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: 'Cài đặt',
                    ),
                  ],
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
                    );
                  },
                  tooltip: 'Thêm giao dịch (Ctrl+N)',
                  child: const Icon(Icons.add),
                ),
              );
            }
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
               child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );

      if (shouldLogout == true) {
        ref.read(authProvider.notifier).logout();
      }
  }
}

class NewTransactionIntent extends Intent {
  const NewTransactionIntent();
}
