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
import '../../../data/repositories/transaction_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final Event? initialEvent;
  final TransactionWithDetails? transaction;
  const TransactionFormScreen({super.key, this.initialEvent, this.transaction});

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
  Event? _selectedEvent;
  List<File> _existingAttachedFiles = [];
  List<File> _newAttachedFiles = [];
  List<File> _deletedAttachedFiles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);

    if (widget.transaction != null) {
      final t = widget.transaction!.transaction;
      _amountController.text = CurrencyUtils.format(t.amount).replaceAll(RegExp(r'[^0-9]'), '');
      _noteController.text = t.note ?? '';
      _selectedDate = t.date;
      _selectedType = TransactionType.values.firstWhere((e) => e.name == t.type);
      
      _loadAttachments();
      
      // Defer setting selectedAccount/Category/Event until data is loaded or in build? 
      // Actually we can just keep IDs and let the UI match them, 
      // OR we rely on the provider data which will be loaded in build.
      // But we need to set the state variables for the dropdowns to work initially.
      // However, we don't have the full objects here easily without the providers.
      // Best approach: In `build`, if `_selectedAccount` is null and `widget.transaction` is not null,
      // find the account in the list and set it.
      
      // Initialize tab index
      switch (_selectedType) {
        case TransactionType.income:
          _tabController.index = 0;
          break;
        case TransactionType.expense:
          _tabController.index = 1;
          break;
        case TransactionType.transfer:
          _tabController.index = 2;
          break;
      }
    } else {
      _tabController.index = 1; // Default to Expense
      _selectedEvent = widget.initialEvent;
    }
  }

  Future<void> _loadAttachments() async {
    final attachmentRepo = ref.read(attachmentRepositoryProvider);
    final fileStorage = ref.read(fileStorageServiceProvider);
    
    final attachments = await attachmentRepo.getAttachmentsByTransaction(widget.transaction!.transaction.id);
    
    List<File> loadedFiles = [];
    for (var att in attachments) {
      if (att.localPath != null) {
        final file = await fileStorage.getFile(att.localPath!);
        if (file != null) {
          loadedFiles.add(file);
        }
      }
    }
    
    if (mounted) {
      setState(() {
         _existingAttachedFiles = loadedFiles;
      });
    }
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

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final userId = ref.read(authProvider).user!.id;
      
      int targetTxId;
      if (widget.transaction != null) {
        targetTxId = widget.transaction!.transaction.id;
        // Update existing transaction
        await repo.updateTransaction(
          TransactionsCompanion(
            id: drift.Value(targetTxId),
            amount: drift.Value(amount),
            date: drift.Value(_selectedDate),
            type: drift.Value(_selectedType.name),
            note: drift.Value(_noteController.text.isEmpty ? null : _noteController.text),
            accountId: drift.Value(_selectedAccount!.id),
            categoryId: drift.Value(_selectedCategory?.id),
            toAccountId: drift.Value(_selectedToAccount?.id),
            eventId: drift.Value(_selectedEvent?.id),
            userId: drift.Value(userId),
          ),
        );
      } else {
        // Create new transaction
        targetTxId = await repo.insertTransaction(
          TransactionsCompanion(
            amount: drift.Value(amount),
            date: drift.Value(_selectedDate),
            type: drift.Value(_selectedType.name),
            note: drift.Value(_noteController.text.isEmpty ? null : _noteController.text),
            accountId: drift.Value(_selectedAccount!.id),
            categoryId: drift.Value(_selectedCategory?.id),
            toAccountId: drift.Value(_selectedToAccount?.id),
            eventId: drift.Value(_selectedEvent?.id),
            userId: drift.Value(userId),
          ),
        );
      }

      // Handle new attachments
      if (_newAttachedFiles.isNotEmpty) {
         final attachmentRepo = ref.read(attachmentRepositoryProvider);
         final fileStorage = ref.read(fileStorageServiceProvider);
         
         for (final file in _newAttachedFiles) {
           final metadata = await fileStorage.saveFile(file, prefix: 'tx_$targetTxId');
           await attachmentRepo.createAttachment(AttachmentsCompanion(
             transactionId: drift.Value(targetTxId),
             fileName: drift.Value(metadata['fileName']),
             fileType: drift.Value(metadata['format']),
             fileSize: drift.Value(metadata['size']),
             localPath: drift.Value(metadata['localPath']),
             syncStatus: const drift.Value('PENDING'),
           ));
         }
      }

      // Handling deletions
      if (_deletedAttachedFiles.isNotEmpty && widget.transaction != null) {
         final attachmentRepo = ref.read(attachmentRepositoryProvider);
         final attachments = await attachmentRepo.getAttachmentsByTransaction(targetTxId);
         final fileStorage = ref.read(fileStorageServiceProvider);
         
         for (final file in _deletedAttachedFiles) {
            // find the attachment by matching the path
            for (final att in attachments) {
               if (att.localPath != null && file.path.endsWith(att.localPath!)) {
                  await attachmentRepo.deleteAttachment(att.id);
                  await fileStorage.deleteFile(att.localPath!);
                  if (att.driveFileId != null && att.driveFileId!.isNotEmpty) {
                     final prefs = await SharedPreferences.getInstance();
                     final list = prefs.getStringList('deleted_cloud_files') ?? [];
                     list.add(att.driveFileId!);
                     await prefs.setStringList('deleted_cloud_files', list);
                  }
                  break;
               }
            }
         }
      }

      // Force refresh data
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(totalBalanceProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(monthlyTransactionsProvider);
      ref.invalidate(monthlyTotalsProvider);
      ref.invalidate(dailyTotalsProvider);
      ref.invalidate(monthlyCategoryStatsProvider);

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

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa giao dịch này? Hành động này sẽ hoàn trả lại số dư ví tương ứng.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isSaving = true);
      try {
        final attachmentRepo = ref.read(attachmentRepositoryProvider);
        final fileStorageService = ref.read(fileStorageServiceProvider);
        final txtId = widget.transaction!.transaction.id;
        
        // Fetch attachments to delete them from cloud and local storage
        final attachments = await attachmentRepo.getAttachmentsByTransaction(txtId);
        
        await ref.read(transactionRepositoryProvider).deleteTransaction(txtId);
        
        for (var att in attachments) {
          if (att.localPath != null && att.localPath!.isNotEmpty) {
            await fileStorageService.deleteFile(att.localPath!);
          }
          if (att.driveFileId != null && att.driveFileId!.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            final list = prefs.getStringList('deleted_cloud_files') ?? [];
            list.add(att.driveFileId!);
            await prefs.setStringList('deleted_cloud_files', list);
          }
        }
        
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(totalBalanceProvider);
        ref.invalidate(accountsProvider);
        ref.invalidate(monthlyTransactionsProvider);
        ref.invalidate(monthlyTotalsProvider);
        ref.invalidate(dailyTotalsProvider);
        ref.invalidate(monthlyCategoryStatsProvider);

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
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
        _newAttachedFiles.addAll(result.paths.map((path) => File(path!)).toList());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final activeEvents = ref.watch(activeEventsProvider);

    return FormKeyboardShortcuts(
      onSave: _saveTransaction,
      onCancel: () => Navigator.pop(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.transaction != null ? 'Cập nhật giao dịch' : 'Thêm giao dịch'),
          actions: [
            if (widget.transaction != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _isSaving ? null : _deleteTransaction,
              ),
          ],
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

          // Initialize values from transaction if editing and not yet selected
          if (widget.transaction != null) {
             final t = widget.transaction!.transaction;
             if (_selectedAccount == null) {
               try {
                 _selectedAccount = accounts.firstWhere((a) => a.id == t.accountId);
               } catch (_) {}
             }
             if (_selectedToAccount == null && t.toAccountId != null) {
               try {
                 _selectedToAccount = accounts.firstWhere((a) => a.id == t.toAccountId);
               } catch (_) {}
             }
          }

          // Set default account if not set and creating new
          if (_selectedAccount == null && accounts.isNotEmpty && widget.transaction == null) {
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
                      
                      // Pre-select category if editing
                      if (widget.transaction != null && _selectedCategory == null && widget.transaction!.transaction.categoryId != null) {
                         try {
                           _selectedCategory = categories.firstWhere((c) => c.id == widget.transaction!.transaction.categoryId);
                         } catch (_) {}
                      }

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

                // Event Selection
                activeEvents.when(
                  data: (events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    return DropdownButtonFormField<Event?>(
                      value: _selectedEvent,
                      decoration: const InputDecoration(
                        labelText: 'Sự kiện (tuỳ chọn)',
                        prefixIcon: Icon(Icons.event),
                      ),
                      items: [
                        const DropdownMenuItem<Event?>(
                          value: null,
                          child: Text('Không có sự kiện'),
                        ),
                        ...events.map((e) => DropdownMenuItem<Event?>(
                          value: e,
                          child: Text(e.name),
                        )),
                      ],
                      onChanged: (val) => setState(() => _selectedEvent = val),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
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
                if (_existingAttachedFiles.isNotEmpty || _newAttachedFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AttachmentViewer(
                    files: [..._existingAttachedFiles, ..._newAttachedFiles],
                    onRemove: (file) {
                      setState(() {
                        if (_newAttachedFiles.contains(file)) {
                           _newAttachedFiles.remove(file);
                        } else if (_existingAttachedFiles.contains(file)) {
                           _existingAttachedFiles.remove(file);
                           _deletedAttachedFiles.add(file);
                        }
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
        label: Text(_isSaving 
            ? 'Đang lưu...' 
            : (widget.transaction != null ? 'Cập nhật' : 'Lưu giao dịch')),
      ),
      ),
    );
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
