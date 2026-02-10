import 'package:drift/drift.dart';
import 'dart:convert';

import '../database/app_database.dart';

/// Repository for Category operations
class CategoryRepository {
  final AppDatabase _db;

  CategoryRepository(this._db);

  /// Get all categories for user
  Future<List<Category>> getAllCategories(int userId) async {
    return (_db.select(_db.categories)
          ..where((c) => c.userId.equals(userId))
          ..orderBy([
            (c) => OrderingTerm.asc(c.type),
            (c) => OrderingTerm.asc(c.sortOrder),
          ]))
        .get();
  }

  /// Get categories by type
  Future<List<Category>> getCategoriesByType(int userId, String type) async {
    return (_db.select(_db.categories)
          ..where((c) => c.userId.equals(userId) & c.type.equals(type))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  /// Watch all categories
  Stream<List<Category>> watchAllCategories(int userId) {
    return (_db.select(_db.categories)
          ..where((c) => c.userId.equals(userId))
          ..orderBy([
            (c) => OrderingTerm.asc(c.type),
            (c) => OrderingTerm.asc(c.sortOrder),
          ]))
        .watch();
  }

  /// Watch categories by type
  Stream<List<Category>> watchCategoriesByType(int userId, String type) {
    return (_db.select(_db.categories)
          ..where((c) => c.userId.equals(userId) & c.type.equals(type))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .watch();
  }

  /// Get category by ID
  Future<Category?> getCategoryById(int id) async {
    return (_db.select(_db.categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert new category
  Future<int> insertCategory(CategoriesCompanion category) async {
    final id = await _db.into(_db.categories).insert(category);

    await _logChange(
      entityType: 'Category',
      entityId: id,
      action: 'CREATE',
      newValue: _companionToMap(category)..['id'] = id,
      description: 'New category: ${category.name.value} (${category.type.value})',
    );

    return id;
  }

  /// Seed default categories for a new user
  Future<void> seedDefaultCategories(int userId) async {
    final defaultCategories = [
      // Expense
      CategoriesCompanion.insert(userId: userId, name: 'Tiền nhà', type: 'expense', nature: const Value('fixed'), iconCodepoint: const Value(0xe88a), sortOrder: const Value(1), isDefault: const Value(true)),
      CategoriesCompanion.insert(userId: userId, name: 'Điện nước', type: 'expense', nature: const Value('fixed'), iconCodepoint: const Value(0xe63c), sortOrder: const Value(2), isDefault: const Value(true)),
      CategoriesCompanion.insert(userId: userId, name: 'Internet', type: 'expense', nature: const Value('fixed'), iconCodepoint: const Value(0xe894), sortOrder: const Value(3), isDefault: const Value(true)),
      CategoriesCompanion.insert(userId: userId, name: 'Ăn uống', type: 'expense', nature: const Value('variable'), iconCodepoint: const Value(0xe56c), sortOrder: const Value(10), isDefault: const Value(true)),
      CategoriesCompanion.insert(userId: userId, name: 'Di chuyển', type: 'expense', nature: const Value('variable'), iconCodepoint: const Value(0xe531), sortOrder: const Value(11), isDefault: const Value(true)),
      CategoriesCompanion.insert(userId: userId, name: 'Mua sắm', type: 'expense', nature: const Value('variable'), iconCodepoint: const Value(0xe8cc), sortOrder: const Value(12), isDefault: const Value(true)),
      CategoriesCompanion.insert(userId: userId, name: 'Giải trí', type: 'expense', nature: const Value('variable'), iconCodepoint: const Value(0xe40f), sortOrder: const Value(13), isDefault: const Value(true)),
      CategoriesCompanion.insert(userId: userId, name: 'Khác', type: 'expense', nature: const Value('variable'), iconCodepoint: const Value(0xe5d3), sortOrder: const Value(99), isDefault: const Value(true)),
      
      // Income
      CategoriesCompanion.insert(userId: userId, name: 'Lương', type: 'income', iconCodepoint: const Value(0xe263), sortOrder: const Value(1), isDefault: const Value(true)),
      CategoriesCompanion.insert(userId: userId, name: 'Thưởng', type: 'income', iconCodepoint: const Value(0xe8f6), sortOrder: const Value(2), isDefault: const Value(true)),
      CategoriesCompanion.insert(userId: userId, name: 'Đầu tư', type: 'income', iconCodepoint: const Value(0xe6df), sortOrder: const Value(4), isDefault: const Value(true)),
      CategoriesCompanion.insert(userId: userId, name: 'Khác', type: 'income', iconCodepoint: const Value(0xe5d3), sortOrder: const Value(99), isDefault: const Value(true)),
    ];

    await _db.batch((batch) {
      batch.insertAll(_db.categories, defaultCategories);
    });
  }

  /// Update existing category
  Future<bool> updateCategory(Category category) async {
    final oldCategory = await getCategoryById(category.id);

    final result = await _db.update(_db.categories).replace(category);

    if (result) {
      await _logChange(
        entityType: 'Category',
        entityId: category.id,
        action: 'UPDATE',
        oldValue: oldCategory != null ? _categoryToMap(oldCategory) : null,
        newValue: _categoryToMap(category),
        description: 'Updated category: ${category.name}',
      );
    }

    return result;
  }

  /// Delete category
  Future<int> deleteCategory(int categoryId) async {
    final oldCategory = await getCategoryById(categoryId);

    final rows = await (_db.delete(_db.categories)..where((c) => c.id.equals(categoryId)))
        .go();

    if (rows > 0) {
      await _logChange(
        entityType: 'Category',
        entityId: categoryId,
        action: 'DELETE',
        oldValue: oldCategory != null ? _categoryToMap(oldCategory) : null,
        description: 'Deleted category: ${oldCategory?.name}',
      );
    }

    return rows;
  }

  // -- Audit Log Helpers --

  Map<String, dynamic> _categoryToMap(Category row) {
    return {
      'id': row.id,
      'name': row.name,
      'type': row.type,
      'nature': row.nature,
      'iconCodepoint': row.iconCodepoint,
      'sortOrder': row.sortOrder,
      'isDefault': row.isDefault,
      'userId': row.userId,
    };
  }

  Map<String, dynamic> _companionToMap(CategoriesCompanion c) {
    return {
      if (c.name.present) 'name': c.name.value,
      if (c.type.present) 'type': c.type.value,
      if (c.nature.present) 'nature': c.nature.value,
      if (c.iconCodepoint.present) 'iconCodepoint': c.iconCodepoint.value,
      if (c.sortOrder.present) 'sortOrder': c.sortOrder.value,
      if (c.userId.present) 'userId': c.userId.value,
    };
  }

  Future<void> _logChange({
    required String entityType,
    required int entityId,
    required String action,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? description,
  }) async {
    await _db.into(_db.auditLogs).insert(AuditLogsCompanion(
      entityType: Value(entityType),
      entityId: Value(entityId),
      action: Value(action),
      oldValue: Value(oldValue != null ? jsonEncode(oldValue) : null),
      newValue: Value(newValue != null ? jsonEncode(newValue) : null),
      description: Value(description),
      timestamp: Value(DateTime.now()),
    ));
  }
}
