import 'package:drift/drift.dart';
import 'dart:convert';

import '../database/app_database.dart';

/// Repository for Bill operations
class BillRepository {
  final AppDatabase _db;

  BillRepository(this._db);

  /// Get all bills for a user
  Stream<List<Bill>> watchBills(int userId) {
    return (_db.select(_db.bills)
          ..where((b) => b.userId.equals(userId))
          ..orderBy([(b) => OrderingTerm(expression: b.dueDate)]))
        .watch();
  }

  /// Get upcoming (unpaid) bills
  Stream<List<Bill>> watchUpcomingBills(int userId) {
    return (_db.select(_db.bills)
          ..where((b) => b.userId.equals(userId) & b.isPaid.equals(false))
          ..orderBy([(b) => OrderingTerm(expression: b.dueDate)]))
        .watch();
  }

  /// Get paid bills
  Stream<List<Bill>> watchPaidBills(int userId) {
    return (_db.select(_db.bills)
          ..where((b) => b.userId.equals(userId) & b.isPaid.equals(true))
          ..orderBy([(b) => OrderingTerm(expression: b.dueDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Get bill by ID
  Future<Bill?> getBillById(int id) {
    return (_db.select(_db.bills)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  /// Create a new bill
  Future<int> createBill(BillsCompanion bill) async {
    final id = await _db.into(_db.bills).insert(bill);

    await _logChange(
      entityType: 'Bill',
      entityId: id,
      action: 'CREATE',
      newValue: _companionToMap(bill)..['id'] = id,
      description: 'New bill: ${bill.title.value}',
    );

    return id;
  }

  /// Update a bill
  Future<void> updateBill(Bill bill) async {
    final oldBill = await getBillById(bill.id);

    await (_db.update(_db.bills)..where((b) => b.id.equals(bill.id))).write(
      BillsCompanion(
        title: Value(bill.title),
        amount: Value(bill.amount),
        dueDate: Value(bill.dueDate),
        repeatCycle: Value(bill.repeatCycle),
        notifyBefore: Value(bill.notifyBefore),
        isPaid: Value(bill.isPaid),
        categoryId: Value(bill.categoryId),
        note: Value(bill.note),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await _logChange(
      entityType: 'Bill',
      entityId: bill.id,
      action: 'UPDATE',
      oldValue: oldBill != null ? _billToMap(oldBill) : null,
      newValue: _billToMap(bill),
      description: 'Updated bill: ${bill.title}',
    );
  }

  /// Delete a bill
  Future<void> deleteBill(int id) async {
    final oldBill = await getBillById(id);

    await (_db.delete(_db.bills)..where((b) => b.id.equals(id))).go();

    await _logChange(
      entityType: 'Bill',
      entityId: id,
      action: 'DELETE',
      oldValue: oldBill != null ? _billToMap(oldBill) : null,
      description: 'Deleted bill: ${oldBill?.title}',
    );
  }

  /// Toggle bill paid status
  Future<void> toggleBillPaid(int id) async {
    final bill = await getBillById(id);
    if (bill == null) return;
    await (_db.update(_db.bills)..where((b) => b.id.equals(id))).write(
      BillsCompanion(
        isPaid: Value(!bill.isPaid),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await _logChange(
      entityType: 'Bill',
      entityId: id,
      action: 'UPDATE',
      oldValue: {'isPaid': bill.isPaid},
      newValue: {'isPaid': !bill.isPaid},
      description: 'Toggled bill paid: ${bill.title} -> ${!bill.isPaid}',
    );
  }

  /// Pay a bill - creates transaction and generates next bill if recurring
  Future<void> payBill({
    required int billId,
    required int accountId,
    String? note,
  }) async {
    final bill = await getBillById(billId);
    if (bill == null) return;

    return _db.transaction(() async {
      // 1. Create transaction for this bill payment
      await _db.into(_db.transactions).insert(TransactionsCompanion(
        amount: Value(bill.amount),
        date: Value(DateTime.now()),
        type: Value('expense'),
        note: Value(note ?? 'Thanh toán: ${bill.title}'),
        accountId: Value(accountId),
        categoryId: Value(bill.categoryId),
        userId: Value(bill.userId),
      ));

      // 2. Update account balance
      final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(accountId))).getSingle();
      await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(
          balance: Value(account.balance - bill.amount),
        ),
      );

      // 3. Mark current bill as paid
      await (_db.update(_db.bills)..where((b) => b.id.equals(billId))).write(
        BillsCompanion(
          isPaid: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // 4. Generate next bill if recurring
      if (bill.repeatCycle != 'NONE') {
        final nextDueDate = calculateNextDueDate(bill.dueDate, bill.repeatCycle);
        await _db.into(_db.bills).insert(BillsCompanion(
          title: Value(bill.title),
          amount: Value(bill.amount),
          dueDate: Value(nextDueDate),
          repeatCycle: Value(bill.repeatCycle),
          notifyBefore: Value(bill.notifyBefore),
          isPaid: const Value(false),
          categoryId: Value(bill.categoryId),
          userId: Value(bill.userId),
          note: Value(bill.note),
        ));
      }

      // 5. Audit log
      await _logChange(
        entityType: 'Bill',
        entityId: billId,
        action: 'PAY',
        oldValue: {'isPaid': false, 'amount': bill.amount},
        newValue: {'isPaid': true, 'accountId': accountId},
        description: 'Paid bill: ${bill.title}, amount: ${bill.amount}',
      );
    });
  }

  /// Calculate next due date based on repeat cycle
  DateTime calculateNextDueDate(DateTime currentDue, String cycle) {
    switch (cycle) {
      case 'WEEKLY':
        return DateTime(
          currentDue.year,
          currentDue.month,
          currentDue.day + 7,
        );
      case 'MONTHLY':
        // Handle month-end edge cases
        int nextMonth = currentDue.month + 1;
        int nextYear = currentDue.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear += 1;
        }
        // Ensure the day exists in the next month
        int day = currentDue.day;
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (day > daysInNextMonth) {
          day = daysInNextMonth;
        }
        return DateTime(nextYear, nextMonth, day);
      case 'YEARLY':
        return DateTime(
          currentDue.year + 1,
          currentDue.month,
          currentDue.day,
        );
      default:
        return currentDue;
    }
  }

  /// Get bills due in the next N days (for notifications)
  Future<List<Bill>> getBillsDueSoon(int userId, int daysAhead) async {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: daysAhead));

    return (_db.select(_db.bills)
          ..where((b) =>
              b.userId.equals(userId) &
              b.isPaid.equals(false) &
              b.dueDate.isBetweenValues(now, futureDate)))
        .get();
  }

  // -- Audit Log Helpers --

  Map<String, dynamic> _billToMap(Bill row) {
    return {
      'id': row.id,
      'title': row.title,
      'amount': row.amount,
      'dueDate': row.dueDate.toIso8601String(),
      'repeatCycle': row.repeatCycle,
      'isPaid': row.isPaid,
      'categoryId': row.categoryId,
      'userId': row.userId,
      'note': row.note,
    };
  }

  Map<String, dynamic> _companionToMap(BillsCompanion c) {
    return {
      if (c.title.present) 'title': c.title.value,
      if (c.amount.present) 'amount': c.amount.value,
      if (c.dueDate.present) 'dueDate': c.dueDate.value.toIso8601String(),
      if (c.repeatCycle.present) 'repeatCycle': c.repeatCycle.value,
      if (c.isPaid.present) 'isPaid': c.isPaid.value,
      if (c.categoryId.present) 'categoryId': c.categoryId.value,
      if (c.userId.present) 'userId': c.userId.value,
      if (c.note.present) 'note': c.note.value,
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
