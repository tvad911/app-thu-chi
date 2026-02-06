import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';

class SavingFormScreen extends ConsumerStatefulWidget {
  const SavingFormScreen({super.key});

  @override
  ConsumerState<SavingFormScreen> createState() => _SavingFormScreenState();
}

class _SavingFormScreenState extends ConsumerState<SavingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestRateController = TextEditingController(); // % per year

  Account? _sourceAccount;
  DateTime _startDate = DateTime.now();
  int _termMonths = 6; // Default 6 months

  // Predefined terms
  final List<int> _terms = [1, 3, 6, 12, 18, 24, 36];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _interestRateController.dispose();
    super.dispose();
  }
  
  // Calculate expected interest for preview
  double get _previewInterest {
     final amount = CurrencyUtils.parse(_amountController.text) ?? 0;
     final rate = double.tryParse(_interestRateController.text) ?? 0;
     if (amount <= 0 || rate <= 0) return 0;
     
     // Simple Interest: Principal * Rate * (Months / 12)
     return amount * (rate / 100) * (_termMonths / 12);
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_sourceAccount == null) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng chọn nguồn tiền')),
         );
         return;
      }
      
      final amount = CurrencyUtils.parse(_amountController.text)!;
      if (amount > _sourceAccount!.balance) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Số dư nguồn tiền không đủ')),
         );
         return;
      }

      try {
        final repo = ref.read(savingRepositoryProvider);
        final userId = ref.read(currentUserProvider)!.id;

        await repo.createSaving(
          name: _nameController.text,
          amount: amount,
          termMonths: _termMonths,
          interestRate: double.parse(_interestRateController.text),
          startDate: _startDate,
          sourceAccountId: _sourceAccount!.id,
          userId: userId,
        );
        
        // Refresh provider
        ref.invalidate(activeSavingsProvider);
        ref.invalidate(accountsProvider);
        ref.invalidate(totalBalanceProvider);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã mở sổ tiết kiệm thành công')),
          );
        }
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mở Sổ Tiết Kiệm Mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên sổ tiết kiệm',
                  hintText: 'Ví dụ: Sổ BIDV 6 tháng',
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 16),
              
              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Số tiền gửi',
                  suffixText: '₫',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                 validator: (val) {
                   final amount = CurrencyUtils.parse(val ?? '');
                   if (amount == null || amount <= 0) return 'Số tiền không hợp lệ';
                   return null;
                 },
                 onChanged: (_) => setState(() {}), // Update preview
              ),
              const SizedBox(height: 16),
              
              // Source Account
              accountsAsync.when(
                data: (accounts) {
                   // Filter out existing Saving Accounts or inactive ones if needed
                   final validAccounts = accounts.where((a) => a.type != 'SAVING_DEPOSIT').toList();
                   
                   return DropdownButtonFormField<Account>(
                     value: _sourceAccount,
                     decoration: const InputDecoration(
                       labelText: 'Nguồn tiền',
                       prefixIcon: Icon(Icons.account_balance_wallet),
                     ),
                     items: validAccounts.map((a) => DropdownMenuItem(
                       value: a,
                       child: Text('${a.name} (${CurrencyUtils.format(a.balance)})'),
                     )).toList(),
                     onChanged: (val) => setState(() => _sourceAccount = val),
                   );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_,__) => const Text('Lỗi tải danh sách ví'),
              ),
              const SizedBox(height: 24),
              
              Text('Kỳ hạn & Lãi suất', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              
              // Terms Selection
              DropdownButtonFormField<int>(
                 value: _termMonths,
                 decoration: const InputDecoration(
                   labelText: 'Kỳ hạn',
                   prefixIcon: Icon(Icons.update),
                 ),
                 items: _terms.map((t) => DropdownMenuItem(
                   value: t,
                   child: Text('$t tháng'),
                 )).toList(),
                 onChanged: (val) {
                   if (val != null) {
                     setState(() => _termMonths = val);
                   }
                 },
              ),
              const SizedBox(height: 16),
              
              // Interest Rate
              TextFormField(
                controller: _interestRateController,
                decoration: const InputDecoration(
                  labelText: 'Lãi suất (%/năm)',
                  suffixText: '%',
                  prefixIcon: Icon(Icons.percent),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                   final rate = double.tryParse(val ?? '');
                   if (rate == null || rate < 0) return 'Lãi suất không hợp lệ';
                   return null;
                },
                onChanged: (_) => setState(() {}), // Update preview
              ),
              
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ngày đáo hạn:'),
                          Text(
                            DateFormat('dd/MM/yyyy').format(DateTime.now().add(Duration(days: _termMonths * 30))), 
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tiền lãi dự kiến:'),
                          Text(
                             CurrencyUtils.format(_previewInterest),
                             style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(),
                       Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tổng nhận về:'),
                          Text(
                             CurrencyUtils.format((CurrencyUtils.parse(_amountController.text) ?? 0) + _previewInterest),
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                   onPressed: _submit,
                   child: const Padding(
                     padding: EdgeInsets.all(16.0),
                     child: Text('Xác nhận gửi', style: TextStyle(fontSize: 16)),
                   ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
