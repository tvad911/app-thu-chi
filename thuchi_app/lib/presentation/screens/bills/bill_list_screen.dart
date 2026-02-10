import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import 'bill_form_screen.dart';

class BillListScreen extends ConsumerStatefulWidget {
  const BillListScreen({super.key});

  @override
  ConsumerState<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends ConsumerState<BillListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hóa đơn định kỳ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sắp tới'),
            Tab(text: 'Đã thanh toán'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBillList(isPaid: false),
          _buildBillList(isPaid: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillFormScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBillList({required bool isPaid}) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: Text('Vui lòng đăng nhập'));

    return StreamBuilder<List<Bill>>(
      stream: isPaid
          ? ref.read(billRepositoryProvider).watchPaidBills(user.id)
          : ref.read(billRepositoryProvider).watchUpcomingBills(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));

        final bills = snapshot.data ?? [];
        if (bills.isEmpty) return const Center(child: Text('Không có hóa đơn nào'));

        return ListView.builder(
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final bill = bills[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(bill).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.receipt, color: _getStatusColor(bill)),
                ),
                title: Text(bill.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hạn: ${app_date.DateUtils.formatDate(bill.dueDate)}'),
                    if (bill.repeatCycle != 'NONE')
                      Row(
                        children: [
                          const Icon(Icons.repeat, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(_getCycleText(bill.repeatCycle), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtils.formatVND(bill.amount),
                      style: TextStyle(color: _getStatusColor(bill), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      bill.isPaid ? 'Đã trả' : 'Chưa trả',
                      style: TextStyle(fontSize: 10, color: bill.isPaid ? Colors.green : Colors.red),
                    ),
                  ],
                ),
                onTap: () => _showActionSheet(bill),
              ),
            );
          },
        );
      },
    );
  }

  void _showActionSheet(Bill bill) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(bill.title, style: Theme.of(ctx).textTheme.titleLarge),
            ),
            const Divider(height: 0),

            // 1. Edit
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Chỉnh sửa'),
              onTap: () {
                Navigator.pop(ctx);
                _editBill(bill);
              },
            ),

            // 2. Toggle paid status
            ListTile(
              leading: Icon(
                bill.isPaid ? Icons.cancel_outlined : Icons.check_circle_outline,
                color: bill.isPaid ? Colors.orange : Colors.green,
              ),
              title: Text(bill.isPaid ? 'Đánh dấu chưa thanh toán' : 'Đánh dấu đã thanh toán'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePaid(bill);
              },
            ),

            // 3. Pay (only for unpaid)
            if (!bill.isPaid)
              ListTile(
                leading: const Icon(Icons.payment, color: Colors.green),
                title: const Text('Thanh toán (tạo giao dịch)'),
                subtitle: const Text('Trừ tiền từ ví & tạo giao dịch chi'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPayDialog(bill);
                },
              ),

            // 4. Delete
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Xóa'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmDelete(bill);
                if (confirmed) _deleteBill(bill);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(Bill bill) {
    if (bill.isPaid) return Colors.green;
    final daysLeft = bill.dueDate.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return Colors.red;
    if (daysLeft <= 3) return Colors.orange;
    return Colors.blue;
  }

  String _getCycleText(String cycle) {
    switch (cycle) {
      case 'WEEKLY': return 'Hàng tuần';
      case 'MONTHLY': return 'Hàng tháng';
      case 'YEARLY': return 'Hàng năm';
      default: return '';
    }
  }

  void _editBill(Bill bill) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BillFormScreen(bill: bill)));
  }

  Future<void> _togglePaid(Bill bill) async {
    try {
      await ref.read(billRepositoryProvider).toggleBillPaid(bill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bill.isPaid ? 'Đã đánh dấu chưa thanh toán' : 'Đã đánh dấu thanh toán')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<bool> _confirmDelete(Bill bill) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hóa đơn?'),
        content: Text('Bạn có chắc muốn xóa "${bill.title}"?'),
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

  Future<void> _deleteBill(Bill bill) async {
    try {
      await ref.read(billRepositoryProvider).deleteBill(bill.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa hóa đơn')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _showPayDialog(Bill bill) {
    int? selectedAccountId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Consumer(
            builder: (ctx, payRef, _) {
              final accountsAsync = payRef.watch(accountsProvider);
              return accountsAsync.when(
                loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('Lỗi: $e'),
                data: (accounts) {
                  final validAccounts = accounts.where((a) => a.type != 'SAVING_DEPOSIT').toList();
                  if (selectedAccountId == null && validAccounts.isNotEmpty) {
                    selectedAccountId = validAccounts.first.id;
                  }
                  return StatefulBuilder(
                    builder: (ctx, setLocalState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Thanh toán: ${bill.title}', style: Theme.of(ctx).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        Text('Số tiền: ${CurrencyUtils.formatVND(bill.amount)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: selectedAccountId,
                          decoration: const InputDecoration(labelText: 'Thanh toán từ ví'),
                          items: validAccounts.map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} (${CurrencyUtils.formatVND(a.balance)})'),
                          )).toList(),
                          onChanged: (val) => setLocalState(() => selectedAccountId = val),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: selectedAccountId == null ? null : () async {
                            try {
                              await payRef.read(billRepositoryProvider).payBill(
                                billId: bill.id,
                                accountId: selectedAccountId!,
                              );
                              payRef.invalidate(accountsProvider);
                              payRef.invalidate(totalBalanceProvider);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Thanh toán thành công!')));
                              }
                            } catch (e) {
                              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Xác nhận thanh toán'),
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
