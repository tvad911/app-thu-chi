import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import 'category_form_screen.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý Danh mục'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chi tiêu'),
              Tab(text: 'Thu nhập'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CategoryListTab(type: 'expense'),
            _CategoryListTab(type: 'income'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _CategoryListTab extends ConsumerWidget {
  final String type;

  const _CategoryListTab({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = type == 'expense' ? expenseCategoriesProvider : incomeCategoriesProvider;
    final categoriesAsync = ref.watch(provider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return const Center(child: Text('Chưa có danh mục nào'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
             final category = categories[index];
             return ListTile(
               leading: CircleAvatar(
                 child: Icon(IconData(category.iconCodepoint, fontFamily: 'MaterialIcons')),
               ),
               title: Text(category.name),
               subtitle: type == 'expense' && category.nature != null
                   ? Text(category.nature == 'fixed' ? 'Cố định' : 'Biến động')
                   : null,
               trailing: const Icon(Icons.chevron_right),
               onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryFormScreen(category: category),
                    ),
                  );
               },
             );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Lỗi: $err')),
    );
  }
}
