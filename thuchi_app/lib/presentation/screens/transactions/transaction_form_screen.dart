import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/attachment_viewer.dart';
import '../../widgets/form_keyboard_shortcuts.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key});

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  TransactionType _selectedType = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  Account? _selectedAccount;
  Account? _selectedToAccount; // For transfer
  Category? _selectedCategory;
  List<File> _attachedFiles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = 1; // Default to Expense
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedType = TransactionType.income;
            break;
          case 1:
            _selectedType = TransactionType.expense;
            break;
          case 2:
            _selectedType = TransactionType.transfer;
            break;
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final amount = CurrencyUtils.parse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví')),
      );
      return;
    }

    if (_selectedType != TransactionType.transfer && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục')),
      );
      return;
    }

    if (_selectedType == TransactionType.transfer) {
      if (_selectedToAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ví đến')),
        );
        return;
      }
      if (_selectedAccount!.id == _selectedToAccount!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ví nguồn và ví đích trùng nhau')),
        );
        return;
      }
    }

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final userId = ref.read(authProvider).user!.id;
      
      final txId = await repo.insertTransaction(
        TransactionsCompanion(
          amount: drift.Value(amount),
          date: drift.Value(_selectedDate),
          type: drift.Value(_selectedType.name),
          note: drift.Value(_noteController.text.isEmpty ? null : _noteController.text),
          accountId: drift.Value(_selectedAccount!.id),
          categoryId: drift.Value(_selectedCategory?.id),
          toAccountId: drift.Value(_selectedToAccount?.id),
          userId: drift.Value(userId),
        ),
          userId: drift.Value(userId),
        ),
      );

      // Save attachments
      if (_attachedFiles.isNotEmpty) {
        final attachmentRepo = ref.read(attachmentRepositoryProvider);
        final fileStorage = ref.read(fileStorageServiceProvider);
        
        for (final file in _attachedFiles) {
          final metadata = await fileStorage.saveFile(file);
          await attachmentRepo.createAttachment(AttachmentsCompanion(
            transactionId: drift.Value(txId),
            fileName: drift.Value(metadata['fileName']),
            fileType: drift.Value(metadata['format']), // Simplified MIME
            fileSize: drift.Value(metadata['size']),
            localPath: drift.Value(metadata['localPath']),
            syncStatus: const drift.Value('PENDING'),
          ));
        }
        
        // Trigger generic background sync if enabled (Not blocking)
        // _triggerBackgroundSync();
      }

      // Force refresh data
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(accountsProvider);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _attachedFiles.addAll(result.paths.map((path) => File(path!)).toList());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return FormKeyboardShortcuts(
      onSave: _saveTransaction,
      onCancel: () => Navigator.pop(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thêm giao dịch'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Thu nhập'),
              Tab(text: 'Chi tiêu'),
              Tab(text: 'Chuyển khoản'),
            ],
          ),
        ),
        body: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Lỗi tải ví: $err')),
          data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Text('Bạn cần tạo ví trước khi thêm giao dịch'),
                   TextButton(
                     onPressed: () {
                       Navigator.pop(context);
                       // User should navigate to create account from home
                     },
                     child: const Text('Quay lại'),
                   )
                ],
              ),
            );
          }

          // Set default account if not set
          if (_selectedAccount == null && accounts.isNotEmpty) {
             _selectedAccount = accounts.first;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount Input
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền',
                    suffixText: '₫',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _getColorForType(context, _selectedType),
                    fontWeight: FontWeight.bold,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 24),

                // Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      app_date.DateUtils.formatFullDate(_selectedDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Account Selection
                DropdownButtonFormField<Account>(
                  value: _selectedAccount,
                  decoration: const InputDecoration(
                    labelText: 'Ví nguồn',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                  items: accounts
                      .where((a) => 
                        _selectedType == TransactionType.transfer || 
                        !['saving_goal', 'SAVING_DEPOSIT'].contains(a.type)
                      )
                      .map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text(a.name),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedAccount = val),
                ),

                // To Account (for Transfer)
                if (_selectedType == TransactionType.transfer) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Account>(
                    value: _selectedToAccount,
                    decoration: const InputDecoration(
                      labelText: 'Đến ví',
                      prefixIcon: Icon(Icons.login),
                    ),
                    items: accounts.map((a) {
                      return DropdownMenuItem(
                        value: a,
                        child: Text(a.name),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedToAccount = val),
                  ),
                ],

                // Category Selection (for Income/Expense)
                if (_selectedType != TransactionType.transfer) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Danh mục', style: Theme.of(context).textTheme.titleMedium),
                      // TODO: Add category button
                    ],
                  ),
                  const SizedBox(height: 8),
                  categoriesAsync.when(
                    data: (categories) {
                      final filtered = categories.where((c) =>
                        (_selectedType == TransactionType.expense && c.type == 'expense') ||
                        (_selectedType == TransactionType.income && c.type == 'income')
                      ).toList();

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final cat = filtered[index];
                          final isSelected = _selectedCategory?.id == cat.id;

                          return InkWell(
                            onTap: () => setState(() => _selectedCategory = cat),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                border: isSelected
                                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    IconData(cat.iconCodepoint, fontFamily: 'MaterialIcons'),
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimaryContainer
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimaryContainer
                                        : null,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stack) => const Text('Lỗi tải danh mục'),
                  ),
                ],

                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                // Attachments
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Đính kèm ảnh/file'),
                    ),
                  ],
                ),
                if (_attachedFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AttachmentViewer(
                    files: _attachedFiles,
                    onRemove: (file) {
                      setState(() {
                        _attachedFiles.remove(file);
                      });
                    },
                  ),
                ],
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveTransaction,
        icon: _isSaving 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.check),
        label: Text(_isSaving ? 'Đang lưu...' : 'Lưu giao dịch'),
      ),
    );
  }

      ), // Scaffold
    ); // FormKeyboardShortcuts
  }

  Color _getColorForType(BuildContext context, TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return Colors.green;
      case TransactionType.expense:
        return Colors.red;
      case TransactionType.transfer:
        return Colors.blue;
    }
  }
}
