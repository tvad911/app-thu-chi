import 'package:drift/drift.dart';

/// Currencies table - stores exchange rates and currency info
class Currencies extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// ISO 4217 currency code (e.g., VND, USD, EUR)
  TextColumn get code => text().withLength(min: 3, max: 3)();

  /// Display name (e.g., "Đồng Việt Nam", "US Dollar")
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Symbol (e.g., ₫, $, €)
  TextColumn get symbol => text().withLength(min: 1, max: 5)();

  /// Exchange rate to base currency (VND)
  RealColumn get rateToBase => real().withDefault(const Constant(1.0))();

  /// Last updated timestamp
  DateTimeColumn get lastUpdated => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'UNIQUE(code)'
  ];
}
