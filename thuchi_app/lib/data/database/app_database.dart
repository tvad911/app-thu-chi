import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/accounts_table.dart';
import 'tables/categories_table.dart';
import 'tables/transactions_table.dart';
import 'tables/debts_table.dart';
import 'tables/budgets_table.dart';
import 'tables/users_table.dart';
import 'tables/audit_logs_table.dart';
import 'tables/savings_table.dart';
import 'tables/bills_table.dart';
import 'tables/attachments_table.dart';
import 'tables/events_table.dart';
import 'tables/currencies_table.dart';

part 'app_database.g.dart';

/// Main database class for the application
@DriftDatabase(tables: [
  Accounts, 
  Categories, 
  Transactions, 
  Debts, 
  Users, 
  Budgets, 
  AuditLogs, 
  Savings,
  Bills,
  Attachments,
  Events,
  Currencies
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing with in-memory database
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(users);
          
          // Create default user
          final userId = await into(users).insert(const UsersCompanion(
            username: Value('admin'),
            passwordHash: Value('admin'), // Placeholder
            displayName: Value('Admin User'),
          ));

          // Add columns
          await m.addColumn(accounts, accounts.userId);
          await m.addColumn(categories, categories.userId);
          await m.addColumn(transactions, transactions.userId);
          await m.addColumn(debts, debts.userId);

          // Update existing data to belong to default user
          await (update(accounts)..where((_) => const Constant(true))).write(AccountsCompanion(userId: Value(userId)));
          await (update(categories)..where((_) => const Constant(true))).write(CategoriesCompanion(userId: Value(userId)));
          await (update(transactions)..where((_) => const Constant(true))).write(TransactionsCompanion(userId: Value(userId)));
          await (update(debts)..where((_) => const Constant(true))).write(DebtsCompanion(userId: Value(userId)));
        }
        
        if (from < 3) {
          await m.createTable(budgets);
        }
        
        if (from < 4) {
          await m.createTable(auditLogs);
        }
        
        if (from < 5) {
          await m.createTable(savings);
        }
        
        if (from < 6) {
          // Phase 11: Enhanced Debt Management
          // Add new columns to Debts table
          await m.addColumn(debts, debts.interestRate);
          await m.addColumn(debts, debts.interestType);
          await m.addColumn(debts, debts.startDate);
          await m.addColumn(debts, debts.notifyDays);
          
          // Rename paidAmount to remainingAmount
          // SQLite doesn't support RENAME COLUMN directly in old versions
          // So we need to use ALTER TABLE approach with data migration
          await customStatement('''
            ALTER TABLE debts ADD COLUMN remaining_amount REAL;
          ''');
          
          // Copy data: remainingAmount = totalAmount - paidAmount
          await customStatement('''
            UPDATE debts SET remaining_amount = total_amount - paid_amount;
          ''');
          
          // Set startDate to createdAt for existing debts
          await customStatement('''
            UPDATE debts SET start_date = created_at WHERE start_date IS NULL;
          ''');
          
          // Drop old paidAmount column (SQLite limitation: need to recreate table)
          // For simplicity, we keep both columns for now and mark paidAmount as deprecated
          // Future cleanup can remove it via table recreation
          
          // Add debtId to Transactions table
          await m.addColumn(transactions, transactions.debtId);
        }
        
        if (from < 7) {
          // Phase 12: Bills & Attachments System
          await m.createTable(bills);
          await m.createTable(attachments);
        }
        
        if (from < 8) {
          // V3: Events / Travel Mode
          await m.createTable(events);
          await m.addColumn(transactions, transactions.eventId);
          // V3: Budget userId
          await m.addColumn(budgets, budgets.userId);
          // V3: Multi-currency
          await m.createTable(currencies);
          await m.addColumn(accounts, accounts.currencyCode);
          await m.addColumn(accounts, accounts.isHidden);
        }
      },
    );
  }
}

/// Opens a native database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'thuchi_app.db'));

    if (kDebugMode) {
      print('Database path: ${file.path}');
    }

    return NativeDatabase.createInBackground(file);
  });
}
