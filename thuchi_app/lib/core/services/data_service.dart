import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:drift/drift.dart' as drift;

import '../../data/database/app_database.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';

class DataService {
  final AppDatabase _db;
  final Ref _ref;

  DataService(this._db, this._ref);

  // ──────────────────────────────────────────────
  // EXPORT
  // ──────────────────────────────────────────────

  Future<Map<String, dynamic>> exportData() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw Exception('User not logged in');
    final uid = user.id;

    final accounts = await (_db.select(_db.accounts)..where((t) => t.userId.equals(uid))).get();
    final categories = await (_db.select(_db.categories)..where((t) => t.userId.equals(uid))).get();
    final transactions = await (_db.select(_db.transactions)..where((t) => t.userId.equals(uid))).get();
    final debts = await (_db.select(_db.debts)..where((t) => t.userId.equals(uid))).get();
    final bills = await (_db.select(_db.bills)..where((t) => t.userId.equals(uid))).get();
    final budgets = await (_db.select(_db.budgets)..where((t) => t.userId.equals(uid))).get();
    final events = await (_db.select(_db.events)..where((t) => t.userId.equals(uid))).get();
    final savings = await _db.select(_db.savings).get();
    final attachments = await _db.select(_db.attachments).get();

    return {
      'version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'debts': debts.map((e) => e.toJson()).toList(),
      'bills': bills.map((e) => e.toJson()).toList(),
      'budgets': budgets.map((e) => e.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'savings': savings.map((e) => e.toJson()).toList(),
      'attachments': attachments.map((e) => e.toJson()).toList(),
    };
  }

  Future<void> exportToJson() async {
    try {
      final data = await exportData();
      final jsonString = jsonEncode(data);
      final fileName = 'thuchi_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'ThuChi Backup');
    } catch (e) {
      throw Exception('Không thể export dữ liệu: $e');
    }
  }

  // ──────────────────────────────────────────────
  // IMPORT
  // ──────────────────────────────────────────────

  Future<void> importFromJson() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      await importFromFile(file);
    }
  }

  Future<void> importFromFile(File file) async {
    try {
      String content = await file.readAsString();
      Map<String, dynamic> data = jsonDecode(content);
      await importFromData(data);
    } catch (e) {
      throw Exception('File backup không hợp lệ hoặc bị lỗi: $e');
    }
  }

  Future<void> importFromData(Map<String, dynamic> data) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw Exception('User not logged in');
    final userId = user.id;

    try {
      // Disable FK checks to avoid constraint violations during bulk delete/insert
      await _db.customStatement('PRAGMA foreign_keys = OFF');

      await _db.transaction(() async {
        // 1. Clear ALL user data — reverse-dependency order (leaf → parent)
        await (_db.delete(_db.attachments)).go();
        await (_db.delete(_db.auditLogs)).go();
        await (_db.delete(_db.transactions)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.budgets)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.bills)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.savings)).go();
        await (_db.delete(_db.debts)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.events)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.accounts)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.categories)..where((t) => t.userId.equals(userId))).go();

        // 2. Import in dependency order: parent → child

        // Accounts
        if (data.containsKey('accounts')) {
          for (var item in data['accounts']) {
            await _db.into(_db.accounts).insert(
              AccountsCompanion(
                id: drift.Value(item['id']),
                name: drift.Value(item['name']),
                balance: drift.Value((item['balance'] as num?)?.toDouble() ?? 0.0),
                type: drift.Value(item['type']),
                color: drift.Value(item['color']),
                isArchived: drift.Value(item['isArchived'] ?? false),
                currencyCode: drift.Value(item['currencyCode'] ?? 'VND'),
                isHidden: drift.Value(item['isHidden'] ?? false),
                createdAt: drift.Value(DateTime.tryParse(item['createdAt'].toString()) ?? DateTime.now()),
                userId: drift.Value(userId),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // Categories
        if (data.containsKey('categories')) {
          for (var item in data['categories']) {
            await _db.into(_db.categories).insert(
              CategoriesCompanion(
                id: drift.Value(item['id']),
                name: drift.Value(item['name']),
                type: drift.Value(item['type']),
                nature: drift.Value(item['nature']),
                iconCodepoint: drift.Value(item['iconCodepoint']),
                sortOrder: drift.Value(item['sortOrder'] ?? 0),
                isDefault: drift.Value(item['isDefault'] ?? false),
                userId: drift.Value(userId),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // Debts
        if (data.containsKey('debts')) {
          for (var item in data['debts']) {
            await _db.into(_db.debts).insert(
              DebtsCompanion(
                id: drift.Value(item['id']),
                person: drift.Value(item['person']),
                totalAmount: drift.Value((item['totalAmount'] as num?)?.toDouble() ?? 0.0),
                remainingAmount: drift.Value(item['remainingAmount'] != null
                    ? (item['remainingAmount'] as num).toDouble()
                    : (item['totalAmount'] as num).toDouble() - ((item['paidAmount'] as num?)?.toDouble() ?? 0)),
                interestRate: drift.Value((item['interestRate'] as num?)?.toDouble() ?? 0.0),
                interestType: drift.Value(item['interestType'] ?? 'PERCENT_YEAR'),
                startDate: drift.Value(DateTime.tryParse(item['startDate'].toString()) ?? DateTime.now()),
                dueDate: drift.Value(DateTime.tryParse(item['dueDate'].toString())),
                notifyDays: drift.Value(item['notifyDays'] ?? 3),
                type: drift.Value(item['type']),
                note: drift.Value(item['note']),
                isFinished: drift.Value(item['isFinished'] ?? false),
                userId: drift.Value(userId),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // Events
        if (data.containsKey('events')) {
          for (var item in data['events']) {
            bool isFinished = item['isFinished'] ?? !(item['isActive'] ?? true);
            await _db.into(_db.events).insert(
              EventsCompanion(
                id: drift.Value(item['id']),
                name: drift.Value(item['name']),
                note: drift.Value(item['note']),
                startDate: drift.Value(DateTime.tryParse(item['startDate'].toString()) ?? DateTime.now()),
                endDate: drift.Value(DateTime.tryParse(item['endDate'].toString())),
                isFinished: drift.Value(isFinished),
                budget: drift.Value((item['budget'] as num?)?.toDouble() ?? 0),
                userId: drift.Value(userId),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // Transactions
        if (data.containsKey('transactions')) {
          for (var item in data['transactions']) {
            await _db.into(_db.transactions).insert(
              TransactionsCompanion(
                id: drift.Value(item['id']),
                amount: drift.Value((item['amount'] as num?)?.toDouble() ?? 0.0),
                date: drift.Value(DateTime.tryParse(item['date'].toString()) ?? DateTime.now()),
                type: drift.Value(item['type']),
                note: drift.Value(item['note']),
                accountId: drift.Value(item['accountId']),
                categoryId: drift.Value(item['categoryId']),
                toAccountId: drift.Value(item['toAccountId']),
                debtId: drift.Value(item['debtId']),
                eventId: drift.Value(item['eventId']),
                imagePath: drift.Value(item['imagePath']),
                userId: drift.Value(userId),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // Bills
        if (data.containsKey('bills')) {
          for (var item in data['bills']) {
            await _db.into(_db.bills).insert(
              BillsCompanion(
                id: drift.Value(item['id']),
                title: drift.Value(item['title']),
                amount: drift.Value((item['amount'] as num?)?.toDouble() ?? 0.0),
                dueDate: drift.Value(DateTime.tryParse(item['dueDate'].toString()) ?? DateTime.now()),
                repeatCycle: drift.Value(item['repeatCycle']),
                notifyBefore: drift.Value(item['notifyBefore'] ?? 3),
                categoryId: drift.Value(item['categoryId']),
                note: drift.Value(item['note']),
                isPaid: drift.Value(item['isPaid'] ?? false),
                userId: drift.Value(userId),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // Budgets
        if (data.containsKey('budgets')) {
          for (var item in data['budgets']) {
            // Handle legacy 'amount' field
            double amount = (item['amountLimit'] as num?)?.toDouble() ?? (item['amount'] as num?)?.toDouble() ?? 0.0;
            
            await _db.into(_db.budgets).insert(
              BudgetsCompanion(
                id: drift.Value(item['id']),
                categoryId: drift.Value(item['categoryId']),
                amountLimit: drift.Value(amount),
                isRecurring: drift.Value(item['isRecurring'] ?? item['spent'] == null), // minimal inference, default false
                month: drift.Value(item['month']),
                year: drift.Value(item['year']),
                userId: drift.Value(userId),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // Savings
        if (data.containsKey('savings')) {
          for (var item in data['savings']) {
             // Handle legacy 'isMatured'
            String status = item['status'] ?? (item['isMatured'] == true ? 'SETTLED' : 'ACTIVE');
            
            await _db.into(_db.savings).insert(
              SavingsCompanion(
                id: drift.Value(item['id']),
                accountId: drift.Value(item['accountId']),
                interestRate: drift.Value((item['interestRate'] as num?)?.toDouble() ?? 0.0),
                termMonths: drift.Value(item['termMonths']),
                startDate: drift.Value(DateTime.tryParse(item['startDate'].toString()) ?? DateTime.now()),
                maturityDate: drift.Value(DateTime.tryParse(item['maturityDate'].toString()) ?? DateTime.now()),
                expectedInterest: drift.Value((item['expectedInterest'] as num?)?.toDouble() ?? 0.0),
                status: drift.Value(status),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }

        // Attachments
        if (data.containsKey('attachments')) {
          for (var item in data['attachments']) {
            await _db.into(_db.attachments).insert(
              AttachmentsCompanion(
                id: drift.Value(item['id']),
                transactionId: drift.Value(item['transactionId']),
                debtId: drift.Value(item['debtId']),
                billId: drift.Value(item['billId']),
                fileName: drift.Value(item['fileName']),
                fileType: drift.Value(item['fileType']),
                fileSize: drift.Value(item['fileSize']),
                localPath: drift.Value(item['localPath']),
                driveFileId: drift.Value(item['driveFileId']),
                syncStatus: drift.Value(item['syncStatus']),
                createdAt: drift.Value(DateTime.tryParse(item['createdAt'].toString()) ?? DateTime.now()),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
          }
        }
      });

      // Re-enable FK checks
      await _db.customStatement('PRAGMA foreign_keys = ON');

      _invalidateAllProviders();
    } catch (e) {
      await _db.customStatement('PRAGMA foreign_keys = ON');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  // RESET
  // ──────────────────────────────────────────────

  Future<void> resetToDefault({bool seedData = true}) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw Exception('User not logged in');
    final userId = user.id;

    try {
      await _db.customStatement('PRAGMA foreign_keys = OFF');

      await _db.transaction(() async {
        // Delete in reverse-dependency order (leaf → parent)
        await (_db.delete(_db.attachments)).go();
        await (_db.delete(_db.auditLogs)).go();
        await (_db.delete(_db.transactions)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.budgets)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.bills)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.savings)).go();
        await (_db.delete(_db.debts)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.events)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.accounts)..where((t) => t.userId.equals(userId))).go();
        await (_db.delete(_db.categories)..where((t) => t.userId.equals(userId))).go();

        if (seedData) {
          await _db.into(_db.accounts).insert(AccountsCompanion.insert(
            name: 'Tiền mặt',
            balance: const drift.Value(0),
            type: 'cash',
            userId: userId,
            currencyCode: const drift.Value('VND'),
            color: const drift.Value('0xFF4CAF50'),
          ));

          final defaultCategories = [
            CategoriesCompanion.insert(userId: userId, name: 'Tiền nhà', type: 'expense', nature: const drift.Value('fixed'), iconCodepoint: const drift.Value(0xe88a), sortOrder: const drift.Value(1), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Điện nước', type: 'expense', nature: const drift.Value('fixed'), iconCodepoint: const drift.Value(0xe63c), sortOrder: const drift.Value(2), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Internet', type: 'expense', nature: const drift.Value('fixed'), iconCodepoint: const drift.Value(0xe894), sortOrder: const drift.Value(3), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Ăn uống', type: 'expense', nature: const drift.Value('variable'), iconCodepoint: const drift.Value(0xe56c), sortOrder: const drift.Value(10), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Di chuyển', type: 'expense', nature: const drift.Value('variable'), iconCodepoint: const drift.Value(0xe531), sortOrder: const drift.Value(11), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Mua sắm', type: 'expense', nature: const drift.Value('variable'), iconCodepoint: const drift.Value(0xe8cc), sortOrder: const drift.Value(12), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Giải trí', type: 'expense', nature: const drift.Value('variable'), iconCodepoint: const drift.Value(0xe40f), sortOrder: const drift.Value(13), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Khác', type: 'expense', nature: const drift.Value('variable'), iconCodepoint: const drift.Value(0xe5d3), sortOrder: const drift.Value(99), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Lương', type: 'income', iconCodepoint: const drift.Value(0xe263), sortOrder: const drift.Value(1), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Thưởng', type: 'income', iconCodepoint: const drift.Value(0xe8f6), sortOrder: const drift.Value(2), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Đầu tư', type: 'income', iconCodepoint: const drift.Value(0xe6df), sortOrder: const drift.Value(4), isDefault: const drift.Value(true)),
            CategoriesCompanion.insert(userId: userId, name: 'Khác', type: 'income', iconCodepoint: const drift.Value(0xe5d3), sortOrder: const drift.Value(99), isDefault: const drift.Value(true)),
          ];

          await _db.batch((batch) {
            batch.insertAll(_db.categories, defaultCategories);
          });
        }
      });

      await _db.customStatement('PRAGMA foreign_keys = ON');
      _invalidateAllProviders();
    } catch (e) {
      await _db.customStatement('PRAGMA foreign_keys = ON');
      throw Exception('Không thể reset dữ liệu: $e');
    }
  }

  // ──────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────

  void _invalidateAllProviders() {
    _ref.invalidate(accountsProvider);
    _ref.invalidate(categoriesProvider);
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(totalBalanceProvider);
    _ref.invalidate(spendableBalanceProvider);
    _ref.invalidate(activeDebtsProvider);
    _ref.invalidate(activeSavingsProvider);
    _ref.invalidate(activeEventsProvider);
    _ref.invalidate(recentAuditLogsProvider);
  }
}

final dataServiceProvider = Provider<DataService>((ref) {
  final db = ref.watch(databaseProvider);
  return DataService(db, ref);
});
