import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_batch_screen.dart';
import 'app_colors.dart';
import 'average_weight_screen.dart';
import 'daily_record_screen.dart';

class ExpenseScreenNew extends StatefulWidget {
  const ExpenseScreenNew({super.key});

  @override
  State<ExpenseScreenNew> createState() => _ExpenseScreenNewState();
}

class _ExpenseScreenNewState extends State<ExpenseScreenNew> {
  final _client = Supabase.instance.client;
  final _money = NumberFormat('#,##0.##');

  Future<void> _navigateToDailyRecord([String? batchId]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyRecordPageNew(initialBatchId: batchId),
      ),
    );
    if (mounted) {
      _load();
    }
  }

  Future<void> _navigateToWeight([String? batchId]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AverageWeightScreen(initialBatchId: batchId),
      ),
    );
    if (mounted) {
      _load();
    }
  }


  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _adjustments = [];
  List<Map<String, dynamic>> _weights = [];
  String? _selectedActiveBatchId;
  String? _selectedClosedBatchId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _n(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  int _i(dynamic value) => _n(value).round();

  DateTime? _date(dynamic value) => DateTime.tryParse('$value');

  List<Map<String, dynamic>> get _activeBatches =>
      _batches.where((b) => '${b['status'] ?? 'Active'}'.toLowerCase() != 'closed').toList();

  List<Map<String, dynamic>> get _closedBatches =>
      _batches.where((b) => '${b['status'] ?? 'Active'}'.toLowerCase() == 'closed').toList();

  Map<String, dynamic>? get _selectedActive {
    for (final batch in _activeBatches) {
      if ('${batch['id']}' == _selectedActiveBatchId) return batch;
    }
    return _activeBatches.isNotEmpty ? _activeBatches.first : null;
  }

  Map<String, dynamic>? get _selectedClosed {
    for (final batch in _closedBatches) {
      if ('${batch['id']}' == _selectedClosedBatchId) return batch;
    }
    return _closedBatches.isNotEmpty ? _closedBatches.first : null;
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      final results = await Future.wait([
        _client.from('batches').select('*').eq('user_id', user.id).order('start_date', ascending: false),
        _client.from('daily_records').select('*').eq('user_id', user.id).order('record_date', ascending: false),
        _client.from('sales').select('*').eq('user_id', user.id).order('sale_date', ascending: false),
        _client.from('expenses').select('*').eq('user_id', user.id).order('expense_date', ascending: false),
        _client.from('weekly_weights').select('*').eq('user_id', user.id).order('weight_date', ascending: false),
      ]);
      if (!mounted) return;
      final batches = List<Map<String, dynamic>>.from(results[0] as List);
      final active = batches.where((b) => '${b['status'] ?? 'Active'}'.toLowerCase() != 'closed').toList();
      final closed = batches.where((b) => '${b['status'] ?? 'Active'}'.toLowerCase() == 'closed').toList();

      setState(() {
        _batches = batches;
        _records = List<Map<String, dynamic>>.from(results[1] as List);
        _sales = List<Map<String, dynamic>>.from(results[2] as List);
        _adjustments = List<Map<String, dynamic>>.from(results[3] as List);
        _weights = List<Map<String, dynamic>>.from(results[4] as List);

        if (_selectedActiveBatchId == null || !active.any((b) => '${b['id']}' == _selectedActiveBatchId)) {
          _selectedActiveBatchId = active.isNotEmpty ? '${active.first['id']}' : null;
        }
        if (_selectedClosedBatchId == null || !closed.any((b) => '${b['id']}' == _selectedClosedBatchId)) {
          _selectedClosedBatchId = closed.isNotEmpty ? '${closed.first['id']}' : null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<Map<String, dynamic>> _forBatch(String batchId, List<Map<String, dynamic>> source) =>
      source.where((row) => '${row['batch_id']}' == batchId).toList();

  double _recordCost(Map<String, dynamic> r) {
    final stored = r['total_cost'];
    if (stored != null) return _n(stored);
    return _n(r['feed_cost']) +
        _n(r['medicine_cost']) +
        _n(r['vaccine_cost']) +
        _n(r['others_cost']) +
        _n(r['labour_cost']) +
        _n(r['electricity_cost']) +
        _n(r['transport_cost']);
  }

  double _saleAmount(Map<String, dynamic> s) {
    final type = '${s['sale_type'] ?? ''}';
    final weight = _n(s['weight_kg']);
    final quantity = _n(s['quantity']);
    final price = _n(s['unit_price']);
    return type == 'Bird' && weight > 0 ? weight * price : quantity * price;
  }

  List<_SeriesPoint> _series(
    List<Map<String, dynamic>> records,
    double Function(Map<String, dynamic>) valueOf,
  ) {
    final totals = <String, double>{};
    for (final record in records) {
      final date = _date(record['record_date']);
      if (date == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(date);
      totals[key] = (totals[key] ?? 0) + valueOf(record);
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((entry) => _SeriesPoint(DateTime.parse(entry.key), entry.value))
        .toList();
  }

  List<_SeriesPoint> _fcrSeries(List<Map<String, dynamic>> records) {
    final dated = records
        .map((record) {
          final date = _date(record['record_date']);
          return date == null ? null : (date: date, record: record);
        })
        .whereType<({DateTime date, Map<String, dynamic> record})>()
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final points = <_SeriesPoint>[];
    double? previousWeight;
    for (final item in dated) {
      final feed = _n(item.record['feed_kg']);
      final weight = _n(item.record['avg_weight_kg']);
      final priorWeight = previousWeight;
      if (weight > 0 && priorWeight != null) {
        final gain = weight - priorWeight;
        if (gain > 0 && feed > 0) {
          points.add(_SeriesPoint(item.date, feed / gain));
        }
      }
      if (weight > 0) previousWeight = weight;
    }
    return points;
  }

  String _batchType(Map<String, dynamic> b) {
    final type = '${b['production_type'] ?? ''}'.toLowerCase();
    final category = '${b['production_category'] ?? ''}'.toLowerCase();
    return type.contains('egg') || category == 'layer' ? 'Layer' : 'Meat';
  }

  int _age(Map<String, dynamic> b) {
    final start = _date(b['start_date']);
    if (start == null) return 0;
    final today = DateTime.now();
    final a = DateTime(start.year, start.month, start.day);
    final z = DateTime(today.year, today.month, today.day);
    return math.max(0, z.difference(a).inDays + 1);
  }

  String _batchLabel(Map<String, dynamic> b) =>
      '${b['name'] ?? 'Unnamed batch'} · ${_batchType(b)} (Day ${_age(b)})';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeCount = _activeBatches.length;
    final closedCount = _closedBatches.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.soft,
        appBar: AppBar(
          title: const Text('Cost & Revenue', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
          bottom: TabBar(
            indicatorColor: colors.brand,
            indicatorWeight: 3,
            labelColor: colors.ink,
            unselectedLabelColor: colors.muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(
                icon: const Icon(Icons.autorenew, size: 20),
                text: 'Active Batches ($activeCount)',
              ),
              Tab(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                text: 'Closed Batches ($closedCount)',
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView(colors)
                : _batches.isEmpty
                    ? const Center(child: Text('কোনো batch পাওয়া যায়নি'))
                    : TabBarView(
                        children: [
                          RefreshIndicator(
                            onRefresh: _load,
                            child: _activeBatchesView(colors),
                          ),
                          RefreshIndicator(
                            onRefresh: _load,
                            child: _closedBatchesView(colors),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _errorView(AppColors colors) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colors.error, size: 44),
              const SizedBox(height: 10),
              Text('Report load হয়নি: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _emptyState(AppColors colors, {required String title, required String subtitle, required IconData icon, Widget? action}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: colors.muted),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: colors.muted),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                action,
              ],
            ],
          ),
        ),
      );

  // ==========================================
  // 1. ACTIVE BATCHES VIEW
  // ==========================================
  Widget _activeBatchesView(AppColors colors) {
    if (_activeBatches.isEmpty) {
      return _emptyState(
        colors,
        title: 'কোনো চলমান (Active) ব্যাচ নেই',
        subtitle: 'নতুন ব্যাচ শুরু করতে নিচের বাটনে চাপ দিন অথবা Home ড্যাশবোর্ড থেকে "Add Batch" এ যান।',
        icon: Icons.inventory_2_outlined,
        action: ElevatedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddBatchPageNew()),
            );
            if (mounted) _load();
          },
          icon: const Icon(Icons.add),
          label: const Text('নতুন ব্যাচ যোগ করুন'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    final batch = _selectedActive;
    if (batch == null) return const SizedBox.shrink();

    final batchId = '${batch['id']}';
    final records = _forBatch(batchId, _records);
    final sales = _forBatch(batchId, _sales);
    final adjustments = _forBatch(batchId, _adjustments);
    final weights = _forBatch(batchId, _weights)
      ..sort((a, b) => '${b['weight_date']}'.compareTo('${a['weight_date']}'));

    final initialBirds = _i(batch['initial_birds']);
    final chickPrice = _n(batch['chick_price']);
    final initialCost = initialBirds * chickPrice;
    final dailyCost = records.fold<double>(0, (sum, r) => sum + _recordCost(r));
    final adjustmentCost = adjustments.fold<double>(0, (sum, e) => sum + _n(e['amount']));
    final totalRunningCost = initialCost + dailyCost + adjustmentCost;

    final mortality = records.fold<int>(0, (sum, r) => sum + _i(r['mortality']));
    final birdsSold = sales.where((s) => s['sale_type'] == 'Bird').fold<int>(0, (sum, s) => sum + _i(s['quantity']));
    final remainingLiveBirds = math.max(0, initialBirds - mortality - birdsSold).toInt();
    final costPerLiveBird = remainingLiveBirds > 0
        ? totalRunningCost / remainingLiveBirds
        : (initialBirds > 0 ? totalRunningCost / initialBirds : 0.0);

    final latestWeight = weights.isNotEmpty
        ? _n(weights.first['average_weight_kg'])
        : (records.isNotEmpty ? _n(records.first['avg_weight_kg']) : 0.0);
    final totalLiveWeightKg = remainingLiveBirds * latestWeight;
    final costPerKg = totalLiveWeightKg > 0 ? totalRunningCost / totalLiveWeightKg : 0.0;
    final marketPrice = records.isNotEmpty ? _n(records.first['market_price_per_kg']) : 0.0;
    final estimatedLiveValuation = totalLiveWeightKg * marketPrice;

    final isLayer = _batchType(batch) == 'Layer';
    final eggsCollected = records.fold<int>(0, (sum, r) => sum + _i(r['eggs_good'] ?? r['eggs_collected']));
    final eggsSold = sales.where((s) => '${s['sale_type']}'.contains('Egg')).fold<int>(0, (sum, s) => sum + _i(s['quantity']));
    final currentEggStock = math.max(0, eggsCollected - eggsSold).toInt();
    final eggPrice = records.isNotEmpty ? _n(records.first['egg_price_per_piece']) : 0.0;
    final eggValuation = currentEggStock * eggPrice;

    final partialRevenue = sales.fold<double>(0, (sum, s) => sum + _saleAmount(s));

    final feedSeries = _series(records, (record) => _n(record['feed_kg']));
    final dailyCostSeries = _series(records, _recordCost);
    final eggSeries = _series(records, (record) => _n(record['eggs_good'] ?? record['eggs_collected']));
    final fcrSeries = _fcrSeries(records);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // Batch Dropdown Picker (Active only)
        _batchPicker(
          colors: colors,
          batches: _activeBatches,
          selectedId: _selectedActiveBatchId,
          onChanged: (val) => setState(() => _selectedActiveBatchId = val),
        ),
        const SizedBox(height: 14),

        // CURRENT RUNNING COST HERO CARD
        _currentRunningCostCard(
          colors: colors,
          batch: batch,
          totalCost: totalRunningCost,
          initialCost: initialCost,
          dailyCost: dailyCost,
          adjustmentCost: adjustmentCost,
          remainingLiveBirds: remainingLiveBirds,
          initialBirds: initialBirds,
          mortality: mortality,
          costPerLiveBird: costPerLiveBird,
          latestWeight: latestWeight,
          costPerKg: costPerKg,
          estimatedValuation: isLayer ? estimatedLiveValuation + eggValuation : estimatedLiveValuation,
          marketPrice: marketPrice,
          partialRevenue: partialRevenue,
          isLayer: isLayer,
          currentEggStock: currentEggStock,
          recordsCount: records.length,
        ),
        const SizedBox(height: 18),

        // Cost Breakdown (Donut Chart & Details)
        _sectionTitle('Cost Breakdown', Icons.pie_chart_outline, colors.warning),
        const SizedBox(height: 8),
        _costSummary(colors, initialCost, dailyCost, adjustmentCost, totalRunningCost, records),
        const SizedBox(height: 18),

        // Time Series (Feed & Daily Cost)
        _timeSeriesSection(colors, feedSeries, dailyCostSeries, batchId),
        const SizedBox(height: 18),

        // Production Analysis (Broiler FCR or Layer Eggs)
        _productionAnalysisSection(colors, isLayer, eggSeries, fcrSeries, records, batchId),

        if (partialRevenue > 0) ...[
          const SizedBox(height: 18),
          _sectionTitle('Partial Sales Received', Icons.payments_outlined, colors.brand),
          const SizedBox(height: 8),
          _partialSalesCard(colors, partialRevenue, birdsSold),
        ],

        if (_activeBatches.length > 1) ...[
          const SizedBox(height: 18),
          _sectionTitle('Other Active Batches', Icons.dashboard_outlined, colors.info),
          const SizedBox(height: 8),
          _batchesQuickList(colors, _activeBatches, _selectedActiveBatchId, (id) {
            setState(() => _selectedActiveBatchId = id);
          }),
        ],
      ],
    );
  }

  // ==========================================
  // 2. CLOSED BATCHES VIEW
  // ==========================================
  Widget _closedBatchesView(AppColors colors) {
    if (_closedBatches.isEmpty) {
      return _emptyState(
        colors,
        title: 'কোনো সমাপ্ত (Closed) ব্যাচ নেই',
        subtitle: 'ব্যাচ বিক্রি সম্পন্ন হলে ব্যাচ স্ট্যাটাস Closed করুন, তখন এখানে চূড়ান্ত হিসাব দেখা যাবে।',
        icon: Icons.check_circle_outline,
      );
    }

    final batch = _selectedClosed;
    if (batch == null) return const SizedBox.shrink();

    final batchId = '${batch['id']}';
    final records = _forBatch(batchId, _records);
    final sales = _forBatch(batchId, _sales);
    final adjustments = _forBatch(batchId, _adjustments);
    final weights = _forBatch(batchId, _weights)
      ..sort((a, b) => '${b['weight_date']}'.compareTo('${a['weight_date']}'));

    final initialBirds = _i(batch['initial_birds']);
    final chickPrice = _n(batch['chick_price']);
    final initialCost = initialBirds * chickPrice;
    final dailyCost = records.fold<double>(0, (sum, r) => sum + _recordCost(r));
    final adjustmentCost = adjustments.fold<double>(0, (sum, e) => sum + _n(e['amount']));
    final totalCost = initialCost + dailyCost + adjustmentCost;

    final totalRevenue = sales.fold<double>(0, (sum, s) => sum + _saleAmount(s));
    final birdRevenue = sales.where((s) => s['sale_type'] == 'Bird').fold<double>(0, (sum, s) => sum + _saleAmount(s));
    final eggRevenue = sales.where((s) => '${s['sale_type']}'.contains('Egg')).fold<double>(0, (sum, s) => sum + _saleAmount(s));
    final litterRevenue = sales.where((s) => s['sale_type'] == 'Litter').fold<double>(0, (sum, s) => sum + _saleAmount(s));
    final birdsSold = sales.where((s) => s['sale_type'] == 'Bird').fold<int>(0, (sum, s) => sum + _i(s['quantity']));
    final soldWeight = sales.where((s) => s['sale_type'] == 'Bird').fold<double>(0, (sum, s) => sum + _n(s['weight_kg']));
    final eggsCollected = records.fold<int>(0, (sum, r) => sum + _i(r['eggs_good'] ?? r['eggs_collected']));
    final eggsSold = sales.where((s) => '${s['sale_type']}'.contains('Egg')).fold<int>(0, (sum, s) => sum + _i(s['quantity']));
    final mortality = records.fold<int>(0, (sum, r) => sum + _i(r['mortality']));
    final remainingBirds = math.max(0, initialBirds - mortality - birdsSold).toInt();
    final latestWeight = weights.isEmpty ? 0.0 : _n(weights.first['average_weight_kg']);
    final marketPrice = records.isEmpty ? 0.0 : _n(records.first['market_price_per_kg']);
    final liveValue = remainingBirds * latestWeight * marketPrice;
    final currentEggStock = math.max(0, eggsCollected - eggsSold).toInt();
    final eggPrice = records.isEmpty ? 0.0 : _n(records.first['egg_price_per_piece']);
    final eggValue = currentEggStock * eggPrice;
    final isLayer = _batchType(batch) == 'Layer';
    final netProfit = totalRevenue - totalCost;
    final profitColor = netProfit >= 0 ? colors.brand : colors.error;

    final feedSeries = _series(records, (record) => _n(record['feed_kg']));
    final dailyCostSeries = _series(records, _recordCost);
    final eggSeries = _series(records, (record) => _n(record['eggs_good'] ?? record['eggs_collected']));
    final fcrSeries = _fcrSeries(records);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // Batch Dropdown Picker (Closed only)
        _batchPicker(
          colors: colors,
          batches: _closedBatches,
          selectedId: _selectedClosedBatchId,
          onChanged: (val) => setState(() => _selectedClosedBatchId = val),
        ),
        const SizedBox(height: 14),

        // Closed Batch Final P&L Hero Card
        _closedBatchHeroCard(
          colors: colors,
          batch: batch,
          totalCost: totalCost,
          totalRevenue: totalRevenue,
          netProfit: netProfit,
          profitColor: profitColor,
          initialBirds: initialBirds,
          birdsSold: birdsSold,
          soldWeight: soldWeight,
          isLayer: isLayer,
        ),
        const SizedBox(height: 18),

        _sectionTitle('Final Cost Summary', Icons.receipt_long_outlined, colors.warning),
        const SizedBox(height: 8),
        _costSummary(colors, initialCost, dailyCost, adjustmentCost, totalCost, records),
        const SizedBox(height: 18),

        _sectionTitle('Revenue Summary', Icons.point_of_sale_outlined, colors.brand),
        const SizedBox(height: 8),
        _revenueSummary(
          colors,
          isLayer,
          totalRevenue,
          birdRevenue,
          eggRevenue,
          litterRevenue,
          birdsSold,
          soldWeight,
          eggsCollected,
          eggsSold,
          remainingBirds,
          latestWeight,
          liveValue,
          currentEggStock,
          eggValue,
        ),
        const SizedBox(height: 18),

        _timeSeriesSection(colors, feedSeries, dailyCostSeries, null),
        const SizedBox(height: 18),

        _productionAnalysisSection(colors, isLayer, eggSeries, fcrSeries, records, null),
        const SizedBox(height: 18),

        _sectionTitle('All Closed Batches History', Icons.history, colors.info),
        const SizedBox(height: 8),
        _batchesQuickList(colors, _closedBatches, _selectedClosedBatchId, (id) {
          setState(() => _selectedClosedBatchId = id);
        }),
      ],
    );
  }

  // ==========================================
  // HERO CARD: CURRENT RUNNING COST
  // ==========================================
  Widget _currentRunningCostCard({
    required AppColors colors,
    required Map<String, dynamic> batch,
    required double totalCost,
    required double initialCost,
    required double dailyCost,
    required double adjustmentCost,
    required int remainingLiveBirds,
    required int initialBirds,
    required int mortality,
    required double costPerLiveBird,
    required double latestWeight,
    required double costPerKg,
    required double estimatedValuation,
    required double marketPrice,
    required double partialRevenue,
    required bool isLayer,
    required int currentEggStock,
    required int recordsCount,
  }) {
    final batchId = '${batch['id']}';
    final age = _age(batch);
    final type = _batchType(batch);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.warning.withOpacity(0.35), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top title & Day badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_balance_wallet, color: colors.warning, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Running Cost',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.ink,
                        ),
                      ),
                      Text(
                        'বর্তমান মোট চলতি ব্যয় · $type Batch',
                        style: TextStyle(fontSize: 11, color: colors.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.info.withOpacity(0.25)),
                  ),
                  child: Text(
                    'Day $age',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.info,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Big Total Running Cost Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: colors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.warning.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL PRODUCTION COST (চলতি খরচ)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.warning,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '৳${_money.format(totalCost)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colors.ink,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.trending_up, color: colors.warning, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3 key production metrics with quick tap-to-entry
            Row(
              children: [
                Expanded(
                  child: _activeMetricPill(
                    title: 'জীবিত পাখি',
                    value: '$remainingLiveBirds টি',
                    subtitle: 'মর্টালিটি: $mortality',
                    color: colors.brand,
                    icon: Icons.pets,
                    onTap: () => _navigateToDailyRecord(batchId),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _activeMetricPill(
                    title: 'পাখি প্রতি খরচ',
                    value: '৳${_money.format(costPerLiveBird)}',
                    subtitle: 'চলতি গড় খরচ',
                    color: colors.purple,
                    icon: Icons.price_check,
                    onTap: () => _navigateToDailyRecord(batchId),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _activeMetricPill(
                    title: 'কেজি প্রতি খরচ',
                    value: latestWeight > 0 ? '৳${_money.format(costPerKg)}' : '—',
                    subtitle: latestWeight > 0 ? 'ওজন ${_money.format(latestWeight)}kg' : 'ওজন দিন ➔',
                    color: colors.accent,
                    icon: Icons.scale,
                    onTap: () => _navigateToWeight(batchId),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // DIRECT SHORTCUTS: Always visible quick action banner for daily expense & weight
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.brand.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.brand.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt, size: 16, color: colors.brand),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          recordsCount == 0 || latestWeight == 0
                              ? 'পারফর্মেন্স ও সঠিক হিসেব দেখতে দ্রুত এন্ট্রি দিন:'
                              : 'আজকের হিসাব দ্রুত যোগ করুন:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToDailyRecord(batchId),
                          icon: const Icon(Icons.receipt_long, size: 15),
                          label: const Text('দৈনিক খরচ ও ফিড'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToWeight(batchId),
                          icon: const Icon(Icons.scale, size: 15),
                          label: const Text('গড় ওজন এন্ট্রি'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.accent,
                            side: BorderSide(color: colors.accent),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Asset Valuation Banner (if weight & market price available)
            if (estimatedValuation > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.brand.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.brand.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.storefront, color: colors.brand, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'সম্ভাব্য বাজারমূল্য (Live Valuation): ',
                                style: TextStyle(fontSize: 11, color: colors.muted),
                              ),
                              Text(
                                '৳${_money.format(estimatedValuation)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.brand,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLayer
                                ? 'পাখির মূল্য + ডিমের মজুদ ($currentEggStock টি)'
                                : 'বাজারদর ৳${_money.format(marketPrice)}/kg হিসেবে মোট আনুমানিক মূল্য',
                            style: TextStyle(fontSize: 10, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HERO CARD: CLOSED BATCH P&L
  // ==========================================
  Widget _closedBatchHeroCard({
    required AppColors colors,
    required Map<String, dynamic> batch,
    required double totalCost,
    required double totalRevenue,
    required double netProfit,
    required Color profitColor,
    required int initialBirds,
    required int birdsSold,
    required double soldWeight,
    required bool isLayer,
  }) {
    final profitPerBird = birdsSold > 0
        ? netProfit / birdsSold
        : (initialBirds > 0 ? netProfit / initialBirds : 0.0);
    final roi = totalCost > 0 ? (netProfit / totalCost) * 100 : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: profitColor.withOpacity(0.35), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: profitColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batch Performance (Closed)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.ink),
                      ),
                      Text(
                        '${batch['name'] ?? 'Unnamed'} · Final Settlement',
                        style: TextStyle(fontSize: 11, color: colors.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.muted.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Closed',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Big Net Profit or Loss Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: profitColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: profitColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        netProfit >= 0 ? 'NET PROFIT (নিট লাভ)' : 'NET LOSS (নিট ক্ষতি)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: profitColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '৳${_money.format(netProfit.abs())}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: profitColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('ROI / মার্জিন', style: TextStyle(fontSize: 11, color: colors.muted)),
                      const SizedBox(height: 2),
                      Text(
                        '${roi.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: profitColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _activeMetricPill(
                    title: 'মোট ব্যয়',
                    value: '৳${_money.format(totalCost)}',
                    subtitle: 'সব খরচ মিলিয়ে',
                    color: colors.warning,
                    icon: Icons.receipt_long,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _activeMetricPill(
                    title: 'মোট বিক্রয়',
                    value: '৳${_money.format(totalRevenue)}',
                    subtitle: 'সব রেভিনিউ',
                    color: colors.brand,
                    icon: Icons.point_of_sale,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _activeMetricPill(
                    title: 'পাখি প্রতি লাভ/ক্ষতি',
                    value: '৳${_money.format(profitPerBird.abs())}',
                    subtitle: netProfit >= 0 ? 'লাভ / পাখি' : 'ক্ষতি / পাখি',
                    color: profitColor,
                    icon: Icons.trending_up,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Metric pill widget
  Widget _activeMetricPill({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios, size: 9, color: color.withOpacity(0.7)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: context.colors.ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9.5,
              color: context.colors.muted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: pill,
      );
    }
    return pill;
  }

  Widget _partialSalesCard(AppColors colors, double partialRevenue, int birdsSold) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Received Revenue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.brand),
                  ),
                  Text(
                    '৳${_money.format(partialRevenue)}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.brand),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'এই অ্যাক্টিভ ব্যাচ থেকে ইতিমধ্যে $birdsSold টি পাখি বিক্রি বাবদ এই রেভিনিউ যুক্ত হয়েছে।',
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
            ],
          ),
        ),
      );

  Widget _batchPicker({
    required AppColors colors,
    required List<Map<String, dynamic>> batches,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
  }) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            value: selectedId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select batch',
              prefixIcon: Icon(Icons.inventory_2_outlined),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: batches
                .map((b) => DropdownMenuItem(
                      value: '${b['id']}',
                      child: Text(_batchLabel(b), overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );

  Widget _batchesQuickList(
    AppColors colors,
    List<Map<String, dynamic>> batches,
    String? selectedId,
    ValueChanged<String> onSelect,
  ) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: batches.map((b) {
              final id = '${b['id']}';
              final records = _records.where((r) => '${r['batch_id']}' == id);
              final sales = _sales.where((s) => '${s['batch_id']}' == id);
              final cost = _i(b['initial_birds']) * _n(b['chick_price']) +
                  records.fold<double>(0, (sum, r) => sum + _recordCost(r)) +
                  _adjustments.where((e) => '${e['batch_id']}' == id).fold<double>(0, (sum, e) => sum + _n(e['amount']));
              final revenue = sales.fold<double>(0, (sum, s) => sum + _saleAmount(s));
              final closed = '${b['status'] ?? 'Active'}'.toLowerCase() == 'closed';
              final result = revenue - cost;
              final color = result >= 0 ? colors.brand : colors.error;
              final isSelected = id == selectedId;

              return InkWell(
                onTap: () => onSelect(id),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.info.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: (closed ? colors.muted : colors.info).withOpacity(.14),
                        child: Icon(
                          closed ? Icons.lock_outline : Icons.autorenew,
                          size: 17,
                          color: closed ? colors.muted : colors.info,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${b['name'] ?? 'Unnamed'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isSelected ? colors.brand : colors.ink,
                              ),
                            ),
                            Text(
                              '${_batchType(b)} · Day ${_age(b)} · ${closed ? 'Closed' : 'Active'}',
                              style: TextStyle(fontSize: 11, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('৳${_money.format(cost)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(
                            closed
                                ? '${result >= 0 ? 'Profit' : 'Loss'} ৳${_money.format(result.abs())}'
                                : 'Revenue ৳${_money.format(revenue)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: closed ? color : colors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );

  Widget _sectionTitle(String title, IconData icon, Color color) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      );
  Widget _costSummary(AppColors colors, double initial, double daily, double adjustment, double total, List<Map<String, dynamic>> records) {
    final categories = <String, double>{'Initial Birds': initial, 'Feed': 0, 'Medicine': 0, 'Vaccine': 0, 'Labour': 0, 'Electricity': 0, 'Transport': 0, 'Other': 0};
    for (final r in records) {
      categories['Feed'] = categories['Feed']! + _n(r['feed_cost']);
      categories['Medicine'] = categories['Medicine']! + _n(r['medicine_cost']);
      categories['Vaccine'] = categories['Vaccine']! + _n(r['vaccine_cost']);
      categories['Labour'] = categories['Labour']! + _n(r['labour_cost']);
      categories['Electricity'] = categories['Electricity']! + _n(r['electricity_cost']);
      categories['Transport'] = categories['Transport']! + _n(r['transport_cost']);
      categories['Other'] = categories['Other']! + _n(r['others_cost']);
    }
    categories['Other'] = categories['Other']! + adjustment;
    final visible = categories.entries.where((e) => e.value > 0).toList();
    return Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      _bigMetric('Total Batch Cost', '৳${_money.format(total)}', colors.warning),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _miniMetric('Initial Birds', initial, colors.purple)), const SizedBox(width: 8), Expanded(child: _miniMetric('Daily Records', daily, colors.warning))]),
      if (adjustment > 0) ...[const SizedBox(height: 8), _metricRow('Batch adjustments', adjustment, colors)],
      const SizedBox(height: 14),
      SizedBox(height: 180, child: Row(children: [Expanded(child: _DonutChart(values: visible.map((e) => e.value).toList(), colors: [colors.purple, colors.brand, colors.error, colors.warning, colors.info, colors.accent, colors.muted, colors.inkAlt])), const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: visible.take(6).map((e) => _legend(e.key, e.value, colors, visible.indexOf(e))).toList()))])),
      const Divider(height: 20),
      ...visible.map((e) => _metricRow(e.key, e.value, colors)),
    ])));
  }

  Widget _timeSeriesSection(
    AppColors colors,
    List<_SeriesPoint> feed,
    List<_SeriesPoint> dailyCost,
    String? batchId,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline_outlined, color: colors.info, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Batch time series',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Daily records',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TimeSeriesChart(
              title: 'Daily feed applied',
              unit: 'kg',
              points: feed,
              color: colors.info,
            ),
            const SizedBox(height: 18),
            _TimeSeriesChart(
              title: 'Total daily cost',
              unit: '৳',
              points: dailyCost,
              color: colors.warning,
            ),
            if (feed.isEmpty && dailyCost.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.warning.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.warning.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.show_chart, color: colors.warning, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'কোনো দৈনিক খরচ বা ফিড রেকর্ড নেই',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'প্রতিদিনের ফিড ও খরচ যোগ করলে এখানে স্বয়ংক্রিয় গ্রাফ তৈরি হবে।',
                            style: TextStyle(fontSize: 11, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (batchId != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToDailyRecord(batchId),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('ফিড/খরচ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.warning,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _productionAnalysisSection(
    AppColors colors,
    bool isLayer,
    List<_SeriesPoint> eggs,
    List<_SeriesPoint> fcr,
    List<Map<String, dynamic>> records,
    String? batchId,
  ) {
    if (isLayer) {
      final totalEggs = eggs.fold<double>(0, (sum, point) => sum + point.value);
      final averageEggs = eggs.isEmpty ? 0.0 : totalEggs / eggs.length;
      final eggDaysLabel = eggs.isEmpty
          ? 'Not available'
          : '${eggs.length} day${eggs.length == 1 ? '' : 's'}';
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.egg_outlined, color: colors.warning, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Layer egg production analysis',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text('Good eggs / day', style: TextStyle(fontSize: 11, color: colors.muted)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: eggs.isEmpty
                        ? _miniTextMetric('Total good eggs', 'Not available', colors.warning)
                        : _miniMetric('Total good eggs', totalEggs, colors.warning),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: eggs.isEmpty
                        ? _miniTextMetric('Average / record', 'Not available', colors.brand)
                        : _miniMetric('Average / record', averageEggs, colors.brand),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TimeSeriesChart(
                title: 'Daily egg production',
                unit: 'eggs',
                points: eggs,
                color: colors.warning,
              ),
              if (eggs.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.warning.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.warning.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.egg_outlined, color: colors.warning, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ডিম উৎপাদনের রেকর্ড নেই',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Daily Records থেকে ডিম সংগ্রহের এন্ট্রি দিন।',
                              style: TextStyle(fontSize: 11, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                      if (batchId != null) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _navigateToDailyRecord(batchId),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('ডিম এন্ট্রি'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.warning,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else if (eggs.length < 3)
                _analysisNote(
                  'এখন $eggDaysLabel data আছে। অর্থপূর্ণ trend-এর জন্য কমপক্ষে ৩ দিনের egg record যোগ করুন।',
                  colors,
                )
              else
                _analysisNote('Trend based on $eggDaysLabel of egg records.', colors),
            ],
          ),
        ),
      );
    }

    final totalFeed = records.fold<double>(
      0,
      (sum, record) => sum + _n(record['feed_kg']),
    );
    final averageFcr = fcr.isEmpty
        ? 0.0
        : fcr.fold<double>(0, (sum, point) => sum + point.value) / fcr.length;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_outlined, color: colors.info, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Broiler feed conversion analysis',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('FCR · kg/kg', style: TextStyle(fontSize: 11, color: colors.muted)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _miniMetric('Total feed', totalFeed, colors.info)),
                const SizedBox(width: 8),
                Expanded(
                  child: fcr.isEmpty
                      ? _miniTextMetric('Average FCR', 'Not available', colors.purple)
                      : _miniMetric('Average FCR', averageFcr, colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TimeSeriesChart(
              title: 'Daily feed conversion ratio',
              unit: 'kg feed / kg gain',
              points: fcr,
              color: colors.info,
            ),
            _analysisNote(
              fcr.isEmpty
                  ? 'FCR chart-এর জন্য অন্তত দুইটি dated average-weight record প্রয়োজন।'
                  : 'FCR = ওই দিনের feed kg ÷ আগের weight sample থেকে পাওয়া weight gain kg। কম FCR ভালো।',
              colors,
            ),
            if (fcr.isEmpty && batchId != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.accent.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined, color: colors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'FCR ও রূপান্তর দক্ষতা পেতে ডাটা এন্ট্রি দিন',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'কমপক্ষে ২টি ভিন্ন দিনের ওজন এবং ফিড এন্ট্রি দিলে স্বয়ংক্রিয়ভাবে FCR ও এফিসিয়েন্সি গ্রাফ ফুটে উঠবে।',
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _navigateToWeight(batchId),
                          icon: const Icon(Icons.scale, size: 14),
                          label: const Text('+ ওজন এন্ট্রি'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _navigateToDailyRecord(batchId),
                          icon: const Icon(Icons.receipt_long, size: 14),
                          label: const Text('+ দৈনিক খরচ ও ফিড'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.brand,
                            side: BorderSide(color: colors.brand),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _analysisNote(String message, AppColors colors) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message, style: TextStyle(fontSize: 11, color: colors.muted)),
      );

  Widget _miniTextMetric(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: context.colors.muted)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      );

  Widget _revenueSummary(AppColors colors, bool isLayer, double total, double bird, double egg, double litter, int birdsSold, double soldWeight, int eggsCollected, int eggsSold, int remaining, double latestWeight, double liveValue, int eggStock, double eggValue) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _bigMetric('Total Revenue', '৳${_money.format(total)}', colors.brand),
    const SizedBox(height: 12),
    SizedBox(height: 160, child: _BarChart(items: {'Bird sales': bird, 'Egg sales': egg, 'Litter': litter}, color: colors.brand, muted: colors.muted)),
    const Divider(height: 20),
    _metricRow('Bird sales · $birdsSold birds · ${_money.format(soldWeight)} kg', bird, colors),
    _metricRow('Egg sales', egg, colors),
    _metricRow('Litter sales', litter, colors),
    if (isLayer) ...[
      const SizedBox(height: 10),
      Text('Live stock & egg stock', style: TextStyle(fontWeight: FontWeight.bold, color: colors.ink)),
      _metricRow('$remaining birds × ${latestWeight.toStringAsFixed(2)} kg · estimated live value', liveValue, colors),
      _metricRow('$eggStock eggs · collected $eggsCollected / sold $eggsSold · estimated value', eggValue, colors),
    ],
  ])));

  Widget _analytics(AppColors colors, bool isLayer, bool isClosed, double cost, double revenue, double realized, double position, int initial, int sold) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
    Row(children: [Expanded(child: _bigMetric(isClosed && !isLayer ? 'Actual Profit/Loss' : 'Realized Margin', '৳${_money.format(realized)}', realized >= 0 ? colors.brand : colors.error)), const SizedBox(width: 10), Expanded(child: _bigMetric(isLayer ? 'Estimated Position' : 'Recovery', isLayer ? '৳${_money.format(position)}' : '${cost <= 0 ? 0 : (revenue / cost * 100).toStringAsFixed(1)}%', isLayer ? (position >= 0 ? colors.brand : colors.error) : colors.info))]),
    const SizedBox(height: 16),
    SizedBox(height: 150, child: _BarChart(items: {'Cost': cost, 'Revenue': revenue, if (isLayer) 'Live stock': position - revenue + cost}, color: colors.brand, muted: colors.warning)),
    const SizedBox(height: 8),
    _metricRow('Cost per initial bird', initial == 0 ? 0 : cost / initial, colors),
    _metricRow('Birds sold', sold.toDouble(), colors, suffix: ' birds'),
    Text(isLayer ? 'Layer batch: live stock and egg stock values are estimates.' : (isClosed ? 'Closed meat batch: revenue minus total cost is the actual result.' : 'Meat batch: close the batch after all birds are sold to finalize actual profit/loss.'), style: TextStyle(fontSize: 11, color: colors.muted)),
  ])));

  Widget _bigMetric(String label, String value, Color color) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(.18))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)), const SizedBox(height: 4), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)))]));

  Widget _miniMetric(String label, double value, Color color) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(.06), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, color: colorsFor(context).muted)), const SizedBox(height: 3), Text('৳${_money.format(value)}', style: TextStyle(fontWeight: FontWeight.bold, color: color))]));

  Widget _metricRow(String label, double value, AppColors colors, {String suffix = ''}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 12))), Text('৳${_money.format(value)}$suffix', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))]));

  Widget _legend(String label, double value, AppColors colors, int index) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: [colors.purple, colors.brand, colors.error, colors.warning, colors.info, colors.accent][index % 6], shape: BoxShape.circle)), const SizedBox(width: 5), Expanded(child: Text(label, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)), Text('৳${_money.format(value)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))]));
}

AppColors colorsFor(BuildContext context) => context.colors;

class _SeriesPoint {
  final DateTime date;
  final double value;

  const _SeriesPoint(this.date, this.value);
}

class _TimeSeriesChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<_SeriesPoint> points;
  final Color color;

  const _TimeSeriesChart({
    required this.title,
    required this.unit,
    required this.points,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(unit, style: TextStyle(fontSize: 11, color: colors.muted)),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 170,
          width: double.infinity,
          child: points.isEmpty
              ? Center(
                  child: Text(
                    'No data',
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                )
              : CustomPaint(
                  painter: _TimeSeriesPainter(
                    points: points,
                    color: color,
                    gridColor: colors.line,
                    labelColor: colors.muted,
                    unit: unit,
                  ),
                ),
        ),
      ],
    );
  }
}

class _TimeSeriesPainter extends CustomPainter {
  final List<_SeriesPoint> points;
  final Color color;
  final Color gridColor;
  final Color labelColor;
  final String unit;

  const _TimeSeriesPainter({
    required this.points,
    required this.color,
    required this.gridColor,
    required this.labelColor,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 42.0;
    const right = 10.0;
    const top = 8.0;
    const bottom = 28.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final maxValue = points.fold<double>(0, (max, point) => math.max(max, point.value).toDouble());
    final scaleMax = maxValue <= 0 ? 1.0 : maxValue * 1.15;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    final gridPaint = Paint()
      ..color = gridColor.withOpacity(.75)
      ..strokeWidth = 1;
    for (var row = 0; row <= 3; row++) {
      final y = chart.top + chart.height * row / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = scaleMax * (3 - row) / 3;
      textPainter.text = TextSpan(
        text: value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
        style: TextStyle(fontSize: 9, color: labelColor),
      );
      textPainter.layout(maxWidth: left - 5);
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    final line = Path();
    final pointPaint = Paint()..color = color;
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (points.length - 1);
      final y = chart.bottom - (point.value / scaleMax) * chart.height;
      if (index == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, pointPaint);
      if (index == 0 || index == points.length - 1 || points.length <= 5) {
        textPainter.text = TextSpan(
          text: DateFormat('dd MMM').format(point.date),
          style: TextStyle(fontSize: 9, color: labelColor),
        );
        textPainter.layout(maxWidth: 54);
        final labelX = (x - textPainter.width / 2)
            .clamp(0.0, size.width - textPainter.width)
            .toDouble();
        textPainter.paint(canvas, Offset(labelX, chart.bottom + 8));
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TimeSeriesPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

class _DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  const _DonutChart({required this.values, required this.colors});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DonutPainter(values, colors), child: const Center(child: Icon(Icons.pie_chart_outline, size: 24)));
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _DonutPainter(this.values, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, Paint()..color = colors[i % colors.length]..style = PaintingStyle.stroke..strokeWidth = 25);
      start += sweep;
    }
  }
  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.values != values;
}

class _BarChart extends StatelessWidget {
  final Map<String, double> items;
  final Color color;
  final Color muted;
  const _BarChart({required this.items, required this.color, required this.muted});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BarPainter(items, color, muted), child: const SizedBox.expand());
}

class _BarPainter extends CustomPainter {
  final Map<String, double> items;
  final Color color;
  final Color muted;
  _BarPainter(this.items, this.color, this.muted);
  @override
  void paint(Canvas canvas, Size size) {
    final values = items.values.toList();
    final maxValue = values.fold<double>(0, (a, b) => math.max(a, b).toDouble());
    if (maxValue <= 0) return;
    final barWidth = size.width / (items.length * 2 + 1);
    var index = 0;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    for (final entry in items.entries) {
      final x = barWidth * (index * 2 + 1);
      final h = (entry.value / maxValue) * (size.height - 38);
      final rect = Rect.fromLTWH(x, size.height - 24 - h, barWidth, h);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), Paint()..color = entry.value > 0 ? color.withOpacity(.75) : muted.withOpacity(.25));
      textPainter.text = TextSpan(text: entry.key, style: TextStyle(fontSize: 10, color: muted));
      textPainter.layout(maxWidth: barWidth + 28);
      textPainter.paint(canvas, Offset(x - 10, size.height - 20));
      index++;
    }
  }
  @override
  bool shouldRepaint(covariant _BarPainter old) => old.items != items;
}
