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

class BillFormScreen extends ConsumerStatefulWidget {
  final Bill? bill;
  const BillFormScreen({super.key, this.bill});

  @override
  ConsumerState<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends ConsumerState<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notifyDaysController = TextEditingController(text: '3');
  final _noteController = TextEditingController();
  
  DateTime _dueDate = DateTime.now();
  RepeatCycle _repeatCycle = RepeatCycle.NONE;
  Category? _selectedCategory;
  
  List<File> _attachedFiles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.bill != null) {
      _titleController.text = widget.bill!.title;
      _amountController.text = CurrencyUtils.formatVND(widget.bill!.amount).replaceAll('₫', '').trim();
      _dueDate = widget.bill!.dueDate;
      _repeatCycle = RepeatCycle.values.firstWhere((e) => e.name == widget.bill!.repeatCycle, orElse: () => RepeatCycle.NONE);
      _notifyDaysController.text = widget.bill!.notifyBefore.toString();
      _noteController.text = widget.bill!.note ?? '';
      
      // TODO: Load existing category
      // TODO: Load existing attachments
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.bill == null ? 'Thêm Hóa đơn' : 'Sửa Hóa đơn')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tên hóa đơn',
                hintText: 'Ví dụ: Tiền điện, Internet...',
                prefixIcon: Icon(Icons.receipt),
              ),
              validator: (v) => v?.isEmpty == true ? 'Nhập tên hóa đơn' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Số tiền',
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'đ',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v?.isEmpty == true ? 'Nhập số tiền' : null,
            ),
            const SizedBox(height: 16),
            // Date & Cycle
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDueDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hạn thanh toán',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(app_date.DateUtils.formatDate(_dueDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<RepeatCycle>(
                    value: _repeatCycle,
                    decoration: const InputDecoration(
                      labelText: 'Lặp lại',
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    items: const [
                      DropdownMenuItem(value: RepeatCycle.NONE, child: Text('Không lặp')),
                      DropdownMenuItem(value: RepeatCycle.WEEKLY, child: Text('Hàng tuần')),
                      DropdownMenuItem(value: RepeatCycle.MONTHLY, child: Text('Hàng tháng')),
                      DropdownMenuItem(value: RepeatCycle.YEARLY, child: Text('Hàng năm')),
                    ],
                    onChanged: (val) => setState(() => _repeatCycle = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Notify days
            TextFormField(
              controller: _notifyDaysController,
              decoration: const InputDecoration(
                labelText: 'Nhắc trước (ngày)',
                prefixIcon: Icon(Icons.notifications),
                helperText: 'Thông báo sẽ gửi vào 9:00 sáng',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            // Category
            _buildCategorySelector(),
             const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                prefixIcon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 16),
            
            // Files
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pickFiles, 
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Đính kèm ảnh/file'),
                ),
              ],
            ),
            AttachmentViewer(
              files: _attachedFiles,
              onRemove: (f) => setState(() => _attachedFiles.remove(f)),
            ),
            
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveBill,
              icon: _isSaving
                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                 : const Icon(Icons.save),
              label: const Text('Lưu Hóa đơn'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    // Simplified for brevity, use same logic as TransForm
    final categoriesAsync = ref.watch(categoriesProvider);
    return categoriesAsync.when(
      data: (cats) {
        final expenseCats = cats.where((c) => c.type == 'expense').toList();
        return DropdownButtonFormField<int>(
          value: _selectedCategory?.id,
          decoration: const InputDecoration(
            labelText: 'Danh mục',
            prefixIcon: Icon(Icons.category),
          ),
          items: expenseCats.map((c) => DropdownMenuItem(
            value: c.id,
            child: Text(c.name),
          )).toList(),
          onChanged: (val) {
             setState(() {
               _selectedCategory = expenseCats.firstWhere((c) => c.id == val);
             });
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_,__) => const SizedBox(),
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }
  
  Future<void> _pickFiles() async {
     final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'pdf', 'doc', 'png'],
    );
    if (result != null) {
      setState(() {
        _attachedFiles.addAll(result.paths.map((p) => File(p!)).toList());
      });
    }
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    try {
      final amount = double.parse(_amountController.text.replaceAll(',', ''));
      final billRepo = ref.read(billRepositoryProvider);
      final userId = ref.read(authProvider).user!.id;
      
      if (widget.bill != null) {
        // Update existing bill
        final updated = widget.bill!.copyWith(
          title: _titleController.text,
          amount: amount,
          dueDate: _dueDate,
          repeatCycle: _repeatCycle.name,
          notifyBefore: int.tryParse(_notifyDaysController.text) ?? 3,
          categoryId: drift.Value(_selectedCategory?.id),
          note: drift.Value(_noteController.text),
        );
        await billRepo.updateBill(updated);
      } else {
        // Create new bill
        final billComp = BillsCompanion(
          title: drift.Value(_titleController.text),
          amount: drift.Value(amount),
          dueDate: drift.Value(_dueDate),
          repeatCycle: drift.Value(_repeatCycle.name),
          notifyBefore: drift.Value(int.tryParse(_notifyDaysController.text) ?? 3),
          categoryId: drift.Value(_selectedCategory?.id),
          userId: drift.Value(userId),
          note: drift.Value(_noteController.text),
          isPaid: const drift.Value(false),
        );
        
        final billId = await billRepo.createBill(billComp);
        
        // Save Attachments
        if (_attachedFiles.isNotEmpty) {
          final attachmentRepo = ref.read(attachmentRepositoryProvider);
          final fileStorage = ref.read(fileStorageServiceProvider);
          
          for (final file in _attachedFiles) {
            final metadata = await fileStorage.saveFile(file);
            await attachmentRepo.createAttachment(AttachmentsCompanion(
              billId: drift.Value(billId),
              fileName: drift.Value(metadata['fileName']),
              fileType: drift.Value(metadata['format']),
              fileSize: drift.Value(metadata['size']),
              localPath: drift.Value(metadata['localPath']),
              syncStatus: const drift.Value('PENDING'),
            ));
          }
        }
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
       if (mounted) setState(() => _isSaving = false);
    }
  }
}
