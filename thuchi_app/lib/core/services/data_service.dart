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

  Future<Map<String, dynamic>> _exportData() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw Exception('User not logged in');

    final accounts = await (_db.select(_db.accounts)..where((t) => t.userId.equals(user.id))).get();
    final categories = await (_db.select(_db.categories)..where((t) => t.userId.equals(user.id))).get();
    final transactions = await (_db.select(_db.transactions)..where((t) => t.userId.equals(user.id))).get();
    final debts = await (_db.select(_db.debts)..where((t) => t.userId.equals(user.id))).get();

    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'debts': debts.map((e) => e.toJson()).toList(),
    };
  }

  Future<void> exportToJson() async {
    try {
      final data = await _exportData();
      final jsonString = jsonEncode(data);
      final fileName = 'thuchi_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      // Share file
      await Share.shareXFiles([XFile(file.path)], text: 'ThuChi Backup');

    } catch (e) {
      throw Exception('Không thể export dữ liệu: $e');
    }
  }

  Future<void> importFromJson() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

      if (result != null) {
        try {
          File file = File(result.files.single.path!);
          String content = await file.readAsString();
          Map<String, dynamic> data = jsonDecode(content);
          
          final user = _ref.read(currentUserProvider);
          if (user == null) throw Exception('User not logged in');
          final userId = user.id;

          await _db.transaction(() async {
            // 1. Clear existing data for USER ONLY
            await (_db.delete(_db.transactions)..where((t) => t.userId.equals(userId))).go();
            await (_db.delete(_db.debts)..where((t) => t.userId.equals(userId))).go();
            await (_db.delete(_db.accounts)..where((t) => t.userId.equals(userId))).go();
            await (_db.delete(_db.categories)..where((t) => t.userId.equals(userId))).go();

            // 2. Import Accounts
            for (var item in data['accounts']) {
              await _db.into(_db.accounts).insert(
                AccountsCompanion(
                  id: drift.Value(item['id']),
                  name: drift.Value(item['name']),
                  balance: drift.Value(item['balance']),
                  type: drift.Value(item['type']),
                  color: drift.Value(item['color']),
                  isArchived: drift.Value(item['isArchived']),
                  createdAt: drift.Value(DateTime.parse(item['createdAt'])),
                  userId: drift.Value(userId),
                ),
                mode: drift.InsertMode.insertOrReplace,
              );
            }

            // 3. Import Categories
            for (var item in data['categories']) {
              await _db.into(_db.categories).insert(
                CategoriesCompanion(
                  id: drift.Value(item['id']),
                  name: drift.Value(item['name']),
                  type: drift.Value(item['type']),
                  nature: drift.Value(item['nature']),
                  iconCodepoint: drift.Value(item['iconCodepoint']),
                  sortOrder: drift.Value(item['sortOrder']),
                  userId: drift.Value(userId),
                ),
                mode: drift.InsertMode.insertOrReplace,
              );
            }

            // 4. Import Transactions
            for (var item in data['transactions']) {
              await _db.into(_db.transactions).insert(
                TransactionsCompanion(
                  id: drift.Value(item['id']),
                  amount: drift.Value(item['amount']),
                  date: drift.Value(DateTime.parse(item['date'])),
                  type: drift.Value(item['type']),
                  note: drift.Value(item['note']),
                  accountId: drift.Value(item['accountId']),
                  categoryId: drift.Value(item['categoryId']),
                  toAccountId: drift.Value(item['toAccountId']),
                  debtId: drift.Value(item['debtId']),
                  imagePath: drift.Value(item['imagePath']),
                  userId: drift.Value(userId),
                ),
                mode: drift.InsertMode.insertOrReplace,
              );
            }

            // 5. Import Debts
            if (data.containsKey('debts')) {
               for (var item in data['debts']) {
                 await _db.into(_db.debts).insert(
                   DebtsCompanion(
                     id: drift.Value(item['id']),
                     person: drift.Value(item['person']),
                     totalAmount: drift.Value(item['totalAmount']),
                     remainingAmount: drift.Value(item['remainingAmount'] ?? (item['totalAmount'] - (item['paidAmount'] ?? 0))),
                     interestRate: drift.Value(item['interestRate'] ?? 0.0),
                     interestType: drift.Value(item['interestType'] ?? 'PERCENT_YEAR'),
                     startDate: drift.Value(item['startDate'] != null ? DateTime.parse(item['startDate']) : DateTime.now()),
                     dueDate: drift.Value(item['dueDate'] != null ? DateTime.parse(item['dueDate']) : null),
                     notifyDays: drift.Value(item['notifyDays'] ?? 3),
                     type: drift.Value(item['type']),
                     note: drift.Value(item['note']),
                     isFinished: drift.Value(item['isFinished']),
                     userId: drift.Value(userId),
                   ),
                   mode: drift.InsertMode.insertOrReplace,
                 );
               }
            }
          });

          // Invalidate all providers
          _ref.invalidate(accountsProvider);
          _ref.invalidate(categoriesProvider);
          _ref.invalidate(recentTransactionsProvider);
          _ref.invalidate(totalBalanceProvider);
          _ref.invalidate(activeDebtsProvider);
        
      } catch (e) {
        throw Exception('File backup không hợp lệ hoặc bị lỗi: $e');
      }
    }
  }
}

final dataServiceProvider = Provider<DataService>((ref) {
  final db = ref.watch(databaseProvider);
  return DataService(db, ref);
});
