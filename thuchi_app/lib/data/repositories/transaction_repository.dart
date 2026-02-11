import 'package:drift/drift.dart';
import 'dart:convert';

import '../database/app_database.dart';
import 'account_repository.dart';

class TransactionWithDetails {
  final Transaction transaction;
  final Account account;
  final Category? category;
  final Account? toAccount;

  TransactionWithDetails({
    required this.transaction,
    required this.account,
    this.category,
    this.toAccount,
  });
}

class TransactionRepository {
  final AppDatabase _db;
  final AccountRepository _accountRepo;

  TransactionRepository(this._db, this._accountRepo);

  /// Watch recent transactions for user
  Stream<List<TransactionWithDetails>> watchRecentTransactions(int userId, int limit) {
    final query = _db.select(_db.transactions).join([
      innerJoin(_db.accounts, _db.accounts.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ])
      ..where(_db.transactions.userId.equals(userId))
      ..orderBy([OrderingTerm.desc(_db.transactions.date)])
      ..limit(limit);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithDetails(
          transaction: row.readTable(_db.transactions),
          account: row.readTable(_db.accounts),
          category: row.readTableOrNull(_db.categories),
        );
      }).toList();
    });
  }

  /// Get monthly category stats for user
  Future<List<CategoryStat>> getCategoryStats(int userId, DateTime month, String type, {bool excludeEvents = false}) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 1);

    final query = _db.select(_db.transactions).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);

    var condition = _db.transactions.userId.equals(userId) &
      _db.transactions.date.isBiggerOrEqualValue(startDate) &
      _db.transactions.date.isSmallerThanValue(endDate) &
      _db.transactions.type.equals(type);
    if (excludeEvents) {
      condition = condition & _db.transactions.eventId.isNull();
    }
    query.where(condition);

    final result = await query.get();

    final Map<int, CategoryStat> stats = {};

    for (final row in result) {
      final category = row.readTable(_db.categories);
      final amount = row.read(_db.transactions.amount)!;

      if (stats.containsKey(category.id)) {
        stats[category.id]!.totalAmount += amount;
        stats[category.id]!.transactionCount++;
      } else {
        stats[category.id] = CategoryStat(
          category: category,
          totalAmount: amount,
          transactionCount: 1,
        );
      }
    }

    return stats.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  Future<int> insertTransaction(TransactionsCompanion transaction) async {
    return _db.transaction(() async {
      final id = await _db.into(_db.transactions).insert(transaction);

      final type = transaction.type.value;
      final amount = transaction.amount.value;
      final accountId = transaction.accountId.value;

      if (type == 'income') {
        await _accountRepo.updateBalance(accountId, amount);
      } else if (type == 'expense') {
        await _accountRepo.updateBalance(accountId, -amount);
      } else if (type == 'transfer') {
         final toAccountId = transaction.toAccountId.value;
         if (toAccountId != null) {
            await _accountRepo.updateBalance(accountId, -amount);
            await _accountRepo.updateBalance(toAccountId, amount);
         }
      }
      
      // Audit Log
      await _logChange(
        entityType: 'Transaction',
        entityId: id,
        action: 'CREATE',
        newValue: _companionToMap(transaction)..['id'] = id,
        description: 'New transaction: $type $amount',
      );

      return id;
    });
  }

  Future<void> deleteTransaction(int id) async {
    return _db.transaction(() async {
      final transaction = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingle();
      
      // Revert balance
      final type = transaction.type;
      final amount = transaction.amount;
      final accountId = transaction.accountId;

      if (type == 'income') {
        await _accountRepo.updateBalance(accountId, -amount);
      } else if (type == 'expense') {
        await _accountRepo.updateBalance(accountId, amount);
      } else if (type == 'transfer') {
         final toAccountId = transaction.toAccountId;
         if (toAccountId != null) {
            await _accountRepo.updateBalance(accountId, amount);
            await _accountRepo.updateBalance(toAccountId, -amount);
         }
      }

      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();

      // Audit Log
      await _logChange(
        entityType: 'Transaction',
        entityId: id,
        action: 'DELETE',
        oldValue: _rowToMap(transaction),
        description: 'Deleted transaction: $type $amount',
      );
    });
  }

  Future<void> updateTransaction(TransactionsCompanion transaction) async {
    return _db.transaction(() async {
      final id = transaction.id.value;
      final oldTransaction = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingle();
      
      // 1. Revert old balance
      final oldType = oldTransaction.type;
      final oldAmount = oldTransaction.amount;
      final oldAccountId = oldTransaction.accountId;

      if (oldType == 'income') {
        await _accountRepo.updateBalance(oldAccountId, -oldAmount);
      } else if (oldType == 'expense') {
        await _accountRepo.updateBalance(oldAccountId, oldAmount);
      } else if (oldType == 'transfer') {
         final oldToAccountId = oldTransaction.toAccountId;
         if (oldToAccountId != null) {
            await _accountRepo.updateBalance(oldAccountId, oldAmount);
            await _accountRepo.updateBalance(oldToAccountId, -oldAmount);
         }
      }

      // 2. Update transaction
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(transaction);

      // 3. Apply new balance
      // Logic: If using companion, fields might be Value.absent() if not updated.
      // But updateTransaction usually passes full object or we need to merge.
      // Better approach for safety: Read the updated row back or use `transaction` values if present, else old values.
      // However, typical update form sends all fields. Let's assume critical fields are present or merge manually.
      // Safer: Fetch updated row.
      final updatedTransaction = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingle();
      
      final newType = updatedTransaction.type;
      final newAmount = updatedTransaction.amount;
      final newAccountId = updatedTransaction.accountId;

      if (newType == 'income') {
        await _accountRepo.updateBalance(newAccountId, newAmount);
      } else if (newType == 'expense') {
        await _accountRepo.updateBalance(newAccountId, -newAmount);
      } else if (newType == 'transfer') {
         final newToAccountId = updatedTransaction.toAccountId;
         if (newToAccountId != null) {
            await _accountRepo.updateBalance(newAccountId, -newAmount);
            await _accountRepo.updateBalance(newToAccountId, newAmount);
         }
      }

      // Audit Log
      await _logChange(
        entityType: 'Transaction',
        entityId: id,
        action: 'UPDATE',
        oldValue: _rowToMap(oldTransaction),
        newValue: _rowToMap(updatedTransaction),
        description: 'Updated transaction',
      );
    });
  }

  Map<String, dynamic> _companionToMap(TransactionsCompanion c) {
    return {
      if (c.amount.present) 'amount': c.amount.value,
      if (c.date.present) 'date': c.date.value.toIso8601String(),
      if (c.type.present) 'type': c.type.value,
      if (c.note.present) 'note': c.note.value,
      if (c.accountId.present) 'accountId': c.accountId.value,
      if (c.categoryId.present) 'categoryId': c.categoryId.value,
      if (c.toAccountId.present) 'toAccountId': c.toAccountId.value,
      if (c.userId.present) 'userId': c.userId.value,
    };
  }

  Map<String, dynamic> _rowToMap(Transaction row) {
    return {
      'id': row.id,
      'amount': row.amount,
      'date': row.date.toIso8601String(),
      'type': row.type,
      'note': row.note,
      'accountId': row.accountId,
      'categoryId': row.categoryId,
      'toAccountId': row.toAccountId,
      'userId': row.userId,
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

  /// Get monthly income/expense totals for a user
  Future<Map<String, double>> getMonthlyTotals(int userId, DateTime month, {bool excludeEvents = false}) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final query = _db.select(_db.transactions)
          ..where((t) {
              var condition = t.userId.equals(userId) &
                  t.date.isBiggerOrEqualValue(startOfMonth) &
                  t.date.isSmallerOrEqualValue(endOfMonth) &
                  t.type.isIn(['income', 'expense']);
              if (excludeEvents) {
                condition = condition & t.eventId.isNull();
              }
              return condition;
          });
    final rows = await query.get();

    double totalIncome = 0;
    double totalExpense = 0;
    for (final r in rows) {
      if (r.type == 'income') {
        totalIncome += r.amount;
      } else if (r.type == 'expense') {
        totalExpense += r.amount;
      }
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }

  /// Get daily income/expense totals for bar chart
  Future<List<Map<String, dynamic>>> getDailyTotals(int userId, DateTime month, {bool excludeEvents = false}) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final rows = await (_db.select(_db.transactions)
          ..where((t) {
              var condition = t.userId.equals(userId) &
                  t.date.isBiggerOrEqualValue(startOfMonth) &
                  t.date.isSmallerOrEqualValue(endOfMonth) &
                  t.type.isIn(['income', 'expense']);
              if (excludeEvents) {
                condition = condition & t.eventId.isNull();
              }
              return condition;
          })
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();

    // Group by day
    final Map<int, Map<String, double>> dailyMap = {};
    for (final r in rows) {
      final day = r.date.day;
      dailyMap.putIfAbsent(day, () => {'income': 0, 'expense': 0});
      dailyMap[day]![r.type] = (dailyMap[day]![r.type] ?? 0) + r.amount;
    }

    return dailyMap.entries.map((e) => {
      'day': e.key,
      'income': e.value['income'] ?? 0.0,
      'expense': e.value['expense'] ?? 0.0,
    }).toList()..sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
  }

  /// Get top transactions by amount in a month
  Future<List<Transaction>> getTopTransactions(int userId, DateTime month, {int limit = 10, bool excludeEvents = false}) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return (_db.select(_db.transactions)
          ..where((t) {
              var condition = t.userId.equals(userId) &
                  t.date.isBiggerOrEqualValue(startOfMonth) &
                  t.date.isSmallerOrEqualValue(endOfMonth) &
                  t.type.isIn(['income', 'expense']);
              if (excludeEvents) {
                condition = condition & t.eventId.isNull();
              }
              return condition;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.amount)])
          ..limit(limit))
        .get();
  }

  /// Get all transactions with details for a month
  Future<List<TransactionWithDetails>> getTransactionsForMonth(int userId, DateTime month, {bool excludeEvents = false}) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final query = _db.select(_db.transactions).join([
      innerJoin(_db.accounts, _db.accounts.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ]);

    var condition = _db.transactions.userId.equals(userId) &
        _db.transactions.date.isBiggerOrEqualValue(startOfMonth) &
        _db.transactions.date.isSmallerOrEqualValue(endOfMonth);
    
    if (excludeEvents) {
      condition = condition & _db.transactions.eventId.isNull();
    }
    
    query.where(condition);
    query.orderBy([OrderingTerm.desc(_db.transactions.date)]);

    final rows = await query.get();
    
    return rows.map((row) {
      return TransactionWithDetails(
        transaction: row.readTable(_db.transactions),
        account: row.readTable(_db.accounts),
        category: row.readTableOrNull(_db.categories),
      );
    }).toList();
  }
}

class CategoryStat {
  final Category category;
  double totalAmount;
  int transactionCount;

  CategoryStat({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
  });
}
