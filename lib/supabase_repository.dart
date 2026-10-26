import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'supabase_config.dart';

/// Cloud data access layer. RLS uses auth.uid(), so every row is scoped to
/// the currently signed-in user.
class SupabaseRepository {
  SupabaseClient get client => SupabaseConfig.client;
  String get userId => client.auth.currentUser!.id;

  void _requireSession() {
    if (client.auth.currentSession == null) {
      throw const AuthException('Login required');
    }
  }

  Future<List<Batch>> getBatches() async {
    _requireSession();
    final rows = await client.from('batches').select().order('start_date', ascending: false);
    return rows.map((row) => Batch.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<Batch> createBatch(Batch item) async {
    _requireSession();
    final row = {
      'user_id': userId,
      'name': item.name,
      'production_type': item.productionType,
      'production_category': item.productionCategory,
      'breed': item.breed,
      'start_date': item.startDate.toIso8601String().split('T').first,
      'initial_birds': item.initialBirds,
    };
    final result = await client.from('batches').insert(row).select().single();
    return Batch.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> deleteBatch(String id) async {
    _requireSession();
    await client.from('batches').delete().eq('id', id).eq('user_id', userId);
  }

  Future<List<DailyRecord>> getDailyRecords({String? batchId}) async {
    _requireSession();
    var query = client.from('daily_records').select();
    if (batchId != null) query = query.eq('batch_id', batchId);
    final rows = await query.order('record_date', ascending: false);
    return rows.map((row) => DailyRecord.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<DailyRecord> createDailyRecord(DailyRecord item) async {
    _requireSession();
    final result = await client.from('daily_records').insert({
      'user_id': userId,
      'batch_id': item.batchId,
      'record_date': item.date.toIso8601String().split('T').first,
      'shed_number': item.shedNumber,
      'feed_type': item.feedType,
      'feed_kg': item.feedKg,
      'water_litre': item.waterLitre,
      'eggs_collected': item.eggsCollected,
      'mortality': item.mortality,
      'remarks': item.remarks,
    }).select().single();
    return DailyRecord.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> deleteDailyRecord(String id) async {
    _requireSession();
    await client.from('daily_records').delete().eq('id', id).eq('user_id', userId);
  }

  Future<List<Expense>> getExpenses({String? batchId}) async {
    _requireSession();
    var query = client.from('expenses').select();
    if (batchId != null) query = query.eq('batch_id', batchId);
    final rows = await query.order('expense_date', ascending: false);
    return rows.map((row) => Expense.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<Expense> createExpense(Expense item) async {
    _requireSession();
    final result = await client.from('expenses').insert({
      'user_id': userId,
      'batch_id': item.batchId,
      'expense_date': item.date.toIso8601String().split('T').first,
      'expense_type': item.type,
      'description': item.description,
      'amount': item.amount,
      'remarks': item.remarks,
    }).select().single();
    return Expense.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> deleteExpense(String id) async {
    _requireSession();
    await client.from('expenses').delete().eq('id', id).eq('user_id', userId);
  }

  Future<List<Sale>> getSales({String? batchId}) async {
    _requireSession();
    var query = client.from('sales').select();
    if (batchId != null) query = query.eq('batch_id', batchId);
    final rows = await query.order('sale_date', ascending: false);
    return rows.map((row) => Sale.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<Sale> createSale(Sale item) async {
    _requireSession();
    final result = await client.from('sales').insert({
      'user_id': userId,
      'batch_id': item.batchId,
      'sale_date': item.date.toIso8601String().split('T').first,
      'sale_type': item.type,
      'quantity': item.quantity,
      'weight_kg': item.weightKg,
      'unit_price': item.unitPrice,
      'buyer_name': item.buyerName,
      'remarks': item.remarks,
    }).select().single();
    return Sale.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> deleteSale(String id) async {
    _requireSession();
    await client.from('sales').delete().eq('id', id).eq('user_id', userId);
  }

  Future<List<WeeklyWeight>> getWeeklyWeights({String? batchId}) async {
    _requireSession();
    var query = client.from('weekly_weights').select();
    if (batchId != null) query = query.eq('batch_id', batchId);
    final rows = await query.order('weight_date', ascending: false);
    return rows.map((row) => WeeklyWeight.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<WeeklyWeight> createWeeklyWeight(WeeklyWeight item) async {
    _requireSession();
    final result = await client.from('weekly_weights').insert({
      'user_id': userId,
      'batch_id': item.batchId,
      'weight_date': item.date.toIso8601String().split('T').first,
      'sample_count': item.sampleCount,
      'average_weight_kg': item.averageWeightKg,
      'remarks': item.remarks,
    }).select().single();
    return WeeklyWeight.fromJson(Map<String, dynamic>.from(result));
  }

  Future<List<MarketPrice>> getMarketPrices() async {
    _requireSession();
    final rows = await client.from('market_prices').select().order('price_date', ascending: false);
    return rows.map((row) => MarketPrice.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<MarketPrice> createMarketPrice(MarketPrice item) async {
    _requireSession();
    final result = await client.from('market_prices').insert({
      'user_id': userId,
      'price_date': item.date.toIso8601String().split('T').first,
      'price_type': item.type,
      'production_category': item.category,
      'breed': item.breed,
      'unit': item.unit,
      'price': item.price,
      'market_name': item.marketName,
      'remarks': item.remarks,
    }).select().single();
    return MarketPrice.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> deleteMarketPrice(String id) async {
    _requireSession();
    await client.from('market_prices').delete().eq('id', id).eq('user_id', userId);
  }
}
