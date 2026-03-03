import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  final Category? category;

  const CategoryFormScreen({super.key, this.category});

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late CategoryType _selectedType;
  ExpenseNature? _selectedNature;
  int _selectedIconCode = 0xe5ca; // Icons.check
  Color _selectedColor = const Color(0xFF2196F3); // Colors.blue

  final List<Color> _colorOptions = [
    const Color(0xFF2196F3), // blue
    const Color(0xFF4CAF50), // green
    const Color(0xFFF44336), // red
    const Color(0xFFFF9800), // orange
    const Color(0xFF9C27B0), // purple
    const Color(0xFF009688), // teal
    const Color(0xFF3F51B5), // indigo
    const Color(0xFFE91E63), // pink
    const Color(0xFF795548), // brown
    const Color(0xFF607D8B), // blueGrey
    const Color(0xFF00BCD4), // cyan
    const Color(0xFFFFEB3B), // yellow
  ];

  // A small subset of material icons for selection
  final List<int> _iconOptions = [
    0xe5ca, // check
    0xe84f, // account_circle
    0xe850, // account_balance
    0xe8f6, // account_balance_wallet
    0xe3c7, // restaurant
    0xe54c, // local_cafe
    0xe556, // local_dining
    0xe532, // directions_car
    0xe53a, // directions_bus
    0xe52f, // directions_bike
    0xe88a, // home
    0xe7e9, // apartment
    0xe3e3, // build
    0xe332, // work
    0xe8cc, // shopping_cart
    0xe8cb, // shopping_bag
    0xe566, // local_grocery_store
    0xe405, // movie
    0xe30a, // audiotrack
    0xe338, // gaming
    0xe0b7, // business_center
    0xe80c, // school
    0xe569, // local_hospital
    0xe548, // local_activity
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name);

    _selectedType = widget.category?.type == 'income'
        ? CategoryType.income
        : CategoryType.expense;

    if (widget.category?.nature != null) {
      _selectedNature = widget.category?.nature == 'fixed'
          ? ExpenseNature.fixed
          : ExpenseNature.variable;
    } else {
      _selectedNature = ExpenseNature.variable;
    }

    if (widget.category != null) {
      _selectedIconCode = widget.category!.iconCodepoint;
      // Load existing color
      final colorStr = widget.category!.color;
      if (colorStr != null && colorStr.isNotEmpty) {
        try {
          _selectedColor = Color(int.parse(colorStr.replaceAll('#', '0xFF')));
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2)}'; // strip alpha prefix
  }

  Future<void> _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final repo = ref.read(categoryRepositoryProvider);
      final colorHex = _colorToHex(_selectedColor);

      try {
        if (widget.category == null) {
          final userId = ref.read(authProvider).user!.id;
          await repo.insertCategory(
            CategoriesCompanion(
              name: drift.Value(name),
              type: drift.Value(_selectedType.name),
              nature: drift.Value(
                  _selectedType == CategoryType.expense ? _selectedNature?.name : null),
              iconCodepoint: drift.Value(_selectedIconCode),
              color: drift.Value(colorHex),
              userId: drift.Value(userId),
            ),
          );
        } else {
          await repo.updateCategory(
            widget.category!.copyWith(
              name: name,
              type: _selectedType.name,
              nature: drift.Value(
                  _selectedType == CategoryType.expense ? _selectedNature?.name : null),
              iconCodepoint: _selectedIconCode,
              color: drift.Value(colorHex),
            ),
          );
        }

        // Invalidate providers
        ref.invalidate(categoriesProvider);
        ref.invalidate(incomeCategoriesProvider);
        ref.invalidate(expenseCategoriesProvider);

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
        title: Text(widget.category == null ? 'Thêm danh mục' : 'Sửa danh mục'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveCategory,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên danh mục',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tên danh mục';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            Text('Loại danh mục', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<CategoryType>(
              segments: const [
                ButtonSegment(value: CategoryType.expense, label: Text('Chi tiêu')),
                ButtonSegment(value: CategoryType.income, label: Text('Thu nhập')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            if (_selectedType == CategoryType.expense) ...[
              Text('Tính chất (Chi tiêu)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<ExpenseNature>(
                segments: const [
                  ButtonSegment(value: ExpenseNature.variable, label: Text('Biến động')),
                  ButtonSegment(value: ExpenseNature.fixed, label: Text('Cố định')),
                ],
                selected: {_selectedNature ?? ExpenseNature.variable},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedNature = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),
            ],

            // Color picker
            Text('Màu sắc', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorOptions.map((color) {
                final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            )
                          : Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            Text('Biểu tượng', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 48,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _iconOptions.length,
                itemBuilder: (context, index) {
                  final code = _iconOptions[index];
                  final isSelected = _selectedIconCode == code;

                  return InkWell(
                    onTap: () => setState(() => _selectedIconCode = code),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? _selectedColor.withValues(alpha: 0.15) : null,
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected
                            ? Border.all(color: _selectedColor)
                            : null,
                      ),
                      child: Icon(
                        IconData(code, fontFamily: 'MaterialIcons'),
                        color: isSelected ? _selectedColor : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
