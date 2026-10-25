import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Local repository for the first offline phase.
/// The same entity shapes can later be sent directly to Supabase.
class LocalStore {
  static const _keys = <String, String>{
    'batches': 'batches_v2',
    'dailyRecords': 'daily_records_v2',
    'expenses': 'expenses_v2',
    'sales': 'sales_v2',
    'weeklyWeights': 'weekly_weights_v2',
    'marketPrices': 'market_prices_v2',
  };

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<T>> _read<T>(String key, T Function(Map<String, dynamic>) decode) async {
    final prefs = await _prefs;
    final values = prefs.getStringList(key) ?? <String>[];
    return values
        .map((value) => decode(Map<String, dynamic>.from(jsonDecode(value) as Map)))
        .toList();
  }

  Future<void> _write<T>(String key, List<T> values, Map<String, dynamic> Function(T) encode) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      key,
      values.map((value) => jsonEncode(encode(value))).toList(),
    );
  }

  Future<List<Batch>> getBatches() => _read(_keys['batches']!, Batch.fromJson);
  Future<void> saveBatches(List<Batch> values) =>
      _write(_keys['batches']!, values, (value) => value.toJson());

  Future<List<DailyRecord>> getDailyRecords() =>
      _read(_keys['dailyRecords']!, DailyRecord.fromJson);
  Future<void> saveDailyRecords(List<DailyRecord> values) =>
      _write(_keys['dailyRecords']!, values, (value) => value.toJson());

  Future<List<Expense>> getExpenses() => _read(_keys['expenses']!, Expense.fromJson);
  Future<void> saveExpenses(List<Expense> values) =>
      _write(_keys['expenses']!, values, (value) => value.toJson());

  Future<List<Sale>> getSales() => _read(_keys['sales']!, Sale.fromJson);
  Future<void> saveSales(List<Sale> values) =>
      _write(_keys['sales']!, values, (value) => value.toJson());

  Future<List<WeeklyWeight>> getWeeklyWeights() =>
      _read(_keys['weeklyWeights']!, WeeklyWeight.fromJson);
  Future<void> saveWeeklyWeights(List<WeeklyWeight> values) =>
      _write(_keys['weeklyWeights']!, values, (value) => value.toJson());

  Future<List<MarketPrice>> getMarketPrices() =>
      _read(_keys['marketPrices']!, MarketPrice.fromJson);
  Future<void> saveMarketPrices(List<MarketPrice> values) =>
      _write(_keys['marketPrices']!, values, (value) => value.toJson());
}

String newLocalId() => DateTime.now().microsecondsSinceEpoch.toString();
