import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
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
    // We need a provider that streams bills. 
    // Assuming simple future/stream for now or we build a specific provider here.
    // Let's create a temporary stream provider for bills in this file or use repository directly.
    
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BillFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBillList({required bool isPaid}) {
    // In a real app, this should be a proper StreamProvider
    return FutureBuilder<List<Bill>>(
      future: ref.read(billRepositoryProvider).getBills(isPaid: isPaid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
           return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        
        final bills = snapshot.data ?? [];
        if (bills.isEmpty) {
           return const Center(child: Text('Không có hóa đơn nào'));
        }

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
                    color: _getStatusColor(bill).withOpacity(0.1),
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
                       )
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtils.formatVND(bill.amount),
                      style: TextStyle(
                        color: _getStatusColor(bill),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (!isPaid)
                      const Text('Chưa trả', style: TextStyle(fontSize: 10, color: Colors.red)),
                  ],
                ),
                onTap: () => _showPayDialog(bill),
              ),
            );
          },
        );
      },
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

  void _showPayDialog(Bill bill) {
    if (bill.isPaid) return;
    
    // In real implementation:
    // navigate to detail or show bottom sheet to confirm payment + account selection + attachment review
    // For now, simpler confirmation
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Thanh toán: ${bill.title}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Số tiền: ${CurrencyUtils.formatVND(bill.amount)}'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                 // Needs Account Selection logic here. 
                 // For MVP, defaulting to first account or prompting user.
                 Navigator.pop(context); // Close bottom sheet
                 _processPayment(bill);
              },
              child: const Text('Xác nhận Thanh toán'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _processPayment(Bill bill) async {
     // TODO: Get selected account from User
     // final accountId = ...
     // await ref.read(billRepositoryProvider).payBill(bill.id, accountId);
     // reload
     setState(() {});
  }
}
