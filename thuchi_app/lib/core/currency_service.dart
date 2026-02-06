import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurrencyService {
  static const String _rateKeyPrefix = 'currency_rate_';
  
  final SharedPreferences _prefs;

  CurrencyService(this._prefs);

  static Future<CurrencyService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return CurrencyService(prefs);
  }

  // Define supported currencies
  List<String> get availableCurrencies => ['VND', 'USD', 'EUR'];

  // Get exchange rate (VND is base = 1.0)
  double getRate(String currencyCode) {
    if (currencyCode == 'VND') return 1.0;
    
    // Default rates if not set
    // 1 USD approx 25,000 VND
    // 1 EUR approx 27,000 VND
    const defaultRates = {
      'USD': 25000.0,
      'EUR': 27000.0,
    };

    return _prefs.getDouble('$_rateKeyPrefix$currencyCode') ?? defaultRates[currencyCode] ?? 1.0;
  }

  Future<void> setRate(String currencyCode, double rate) async {
    if (currencyCode == 'VND') return; // Cannot change base
    await _prefs.setDouble('$_rateKeyPrefix$currencyCode', rate);
  }
}

// Simple provider (assuming we can initialization it in main or use a FutureProvider)
// For simplicity in this edit, I will make a FutureProvider or similar.
// Actually, since SharedPreferences is async, let's use a FutureProvider for the instance, 
// or simpler: just use Sync retrieval in UI since we might load it early.

final currencyServiceProvider = Provider<CurrencyService>((ref) {
  throw UnimplementedError('Initialize this provider in main.dart');
});
