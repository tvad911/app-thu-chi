import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/auth_provider.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  final Account? account;

  const AccountFormScreen({super.key, this.account});

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late AccountType _selectedType;
  Color _selectedColor = Colors.green;

  final List<Color> _colorOptions = [
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name);
    _balanceController = TextEditingController(
      text: widget.account != null
          ? CurrencyUtils.formatNumber(widget.account!.balance)
          : '',
    );
    
    _selectedType = widget.account != null
        ? AccountType.values.firstWhere(
            (e) => e.name == widget.account!.type,
            orElse: () => AccountType.cash,
          )
        : AccountType.cash;

    if (widget.account?.color != null) {
      _selectedColor = Color(int.parse(widget.account!.color!.replaceAll('#', '0xFF')));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _saveAccount() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final balance = CurrencyUtils.parse(_balanceController.text) ?? 0.0;
      final colorHex = '#${_selectedColor.toARGB32().toRadixString(16).substring(2)}';

      final repo = ref.read(accountRepositoryProvider);

      try {
        if (widget.account == null) {
          // Create new
          final userId = ref.read(authProvider).user!.id;
          await repo.insertAccount(
            AccountsCompanion(
              name: drift.Value(name),
              balance: drift.Value(balance),
              type: drift.Value(_selectedType.name),
              color: drift.Value(colorHex),
              userId: drift.Value(userId),
            ),
          );
        } else {
          // Update existing
          await repo.updateAccount(
            widget.account!.copyWith(
              name: name,
              balance: balance,
              type: _selectedType.name,
              color: drift.Value(colorHex),
            ),
          );
        }
        
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'Thêm ví mới' : 'Sửa thông tin ví'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveAccount,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên ví',
                hintText: 'Ví dụ: Tiền mặt, Vietcombank',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tên ví';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _balanceController,
              decoration: const InputDecoration(
                labelText: 'Số dư ban đầu',
                suffixText: '₫',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                if (CurrencyUtils.parse(value) == null) {
                  return 'Số tiền không hợp lệ';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Loại ví',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<AccountType>(
              segments: AccountType.values.map((type) {
                return ButtonSegment<AccountType>(
                  value: type,
                  label: Text(type.displayName),
                );
              }).toList(),
              selected: {_selectedType},
              onSelectionChanged: (Set<AccountType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Màu sắc',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: _colorOptions.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor == color
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            )
                          : null,
                    ),
                    child: _selectedColor == color
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
