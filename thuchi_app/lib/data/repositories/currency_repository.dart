import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Repository for currency management
class CurrencyRepository {
  final AppDatabase _db;

  CurrencyRepository(this._db);

  /// Get all currencies
  Future<List<Currency>> getAllCurrencies() {
    return (_db.select(_db.currencies)..orderBy([(c) => OrderingTerm.asc(c.code)])).get();
  }

  /// Watch all currencies
  Stream<List<Currency>> watchAllCurrencies() {
    return (_db.select(_db.currencies)..orderBy([(c) => OrderingTerm.asc(c.code)])).watch();
  }

  /// Get currency by code
  Future<Currency?> getCurrencyByCode(String code) {
    return (_db.select(_db.currencies)..where((c) => c.code.equals(code))).getSingleOrNull();
  }

  /// Insert or update a currency
  Future<void> upsertCurrency(CurrenciesCompanion currency) async {
    await _db.into(_db.currencies).insertOnConflictUpdate(currency);
  }

  /// Delete a currency
  Future<int> deleteCurrency(int id) {
    return (_db.delete(_db.currencies)..where((c) => c.id.equals(id))).go();
  }

  /// Seed default currencies if table is empty
  Future<void> seedDefaults() async {
    final existing = await getAllCurrencies();
    if (existing.isNotEmpty) return;

    final defaults = [
      CurrenciesCompanion.insert(code: 'VND', name: 'Đồng Việt Nam', symbol: '₫', rateToBase: const Value(1.0)),
      CurrenciesCompanion.insert(code: 'USD', name: 'US Dollar', symbol: '\$', rateToBase: const Value(25000.0)),
      CurrenciesCompanion.insert(code: 'EUR', name: 'Euro', symbol: '€', rateToBase: const Value(27000.0)),
      CurrenciesCompanion.insert(code: 'JPY', name: 'Japanese Yen', symbol: '¥', rateToBase: const Value(170.0)),
      CurrenciesCompanion.insert(code: 'THB', name: 'Thai Baht', symbol: '฿', rateToBase: const Value(700.0)),
      CurrenciesCompanion.insert(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', rateToBase: const Value(18500.0)),
    ];

    for (final currency in defaults) {
      await _db.into(_db.currencies).insert(currency);
    }
  }
}
