import 'ai_chat_screen.dart';
import 'poultry_standards.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _batches = [];
  String? _selectedBatchId;
  Map<String, dynamic>? _selectedBatch;

  // Real-time Actual Metrics
  int _initialBirds = 0;
  int _currentBirds = 0;
  int _totalMortality = 0;
  int _birdsSold = 0;
  int _flockAgeDays = 0;
  double _latestAvgWeightKg = 0.0;
  DateTime? _latestWeightDate;
  double _totalFeedKg = 0.0;
  double _totalExpenses = 0.0;
  double _totalSales = 0.0;

  // Layer specific
  int _totalEggsCollected = 0;
  int _latestDailyEggs = 0;
  DateTime? _firstLayingDate;
  int? _firstLayingAgeDays;

  // Pricing & Break-even
  double _adminDefaultPrice = 0.0;
  final TextEditingController _negotiatingPriceController = TextEditingController();
  double _negotiatingPrice = 0.0;

  static const _ink = Color(0xFF102A1F);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E9E6);
  static const _soft = Color(0xFFF4F7F5);
  static const _brand = Color(0xFF1B5E20);
  static const _brandSoft = Color(0xFFE8F2E9);

  @override
  void initState() {
    super.initState();
    _fetchBatches();
  }

  @override
  void dispose() {
    _negotiatingPriceController.dispose();
    super.dispose();
  }

  Future<void> _fetchBatches() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('batches')
          .select('id, name, production_type, breed, shed, start_date, initial_birds, additional_birds, chick_price, status')
          .eq('status', 'Active')
          .order('start_date', ascending: false);

      _batches = List<Map<String, dynamic>>.from(res);
      if (_batches.isNotEmpty) {
        _selectedBatchId = _batches.first['id'].toString();
        _selectedBatch = _batches.first;
        await _fetchBatchActualMetrics(_selectedBatchId!);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load batches: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchBatchActualMetrics(String batchId) async {
    setState(() => _isLoading = true);
    try {
      _totalFeedKg = 0.0;
      // 1. Batch info
      final batchRes = await _supabase
          .from('batches')
          .select()
          .eq('id', batchId)
          .single();
      _selectedBatch = batchRes;
      _initialBirds = (batchRes['initial_birds'] as num?)?.toInt() ?? 0;
      final additionalBirds = (batchRes['additional_birds'] as num?)?.toInt() ?? 0;
      final placedBirds = _initialBirds + additionalBirds;

      // Age calculation
      DateTime? startDate;
      if (batchRes['start_date'] != null) {
        startDate = DateTime.tryParse(batchRes['start_date'].toString());
      }
      if (startDate != null) {
        _flockAgeDays = DateTime.now().difference(startDate).inDays;
      } else {
        _flockAgeDays = 0;
      }

      final isLayer = (batchRes['production_type'] ?? '')
          .toString()
          .toLowerCase()
          .contains('egg');

      // 2. Mortality, Eggs & First Laying Date
      int mort = 0;
      double feedSum = 0.0;
      int eggs = 0;
      int latestEggs = 0;
      DateTime? firstEggDate;
      int? firstEggAgeDays;

      if (isLayer) {
        final logsRes = await _supabase
            .from('layer_daily_logs')
            .select('log_date, mortality_count, culling_count, total_eggs, good_eggs')
            .eq('batch_id', batchId)
            .order('log_date', ascending: true);

        for (var row in logsRes) {
          mort += ((row['mortality_count'] ?? 0) as num).toInt() +
              ((row['culling_count'] ?? 0) as num).toInt();
          final int rowEggs = ((row['total_eggs'] ?? row['good_eggs'] ?? 0) as num).toInt();
          eggs += rowEggs;
          latestEggs = rowEggs;

          // First Laying Date detection
          if (firstEggDate == null && rowEggs > 0 && row['log_date'] != null) {
            firstEggDate = DateTime.tryParse(row['log_date'].toString());
            if (firstEggDate != null && startDate != null) {
              firstEggAgeDays = firstEggDate.difference(startDate).inDays;
            }
          }
        }
      } else {
        final dailyRes = await _supabase
            .from('daily_records')
            .select('mortality, feed_kg')
            .eq('batch_id', batchId);
        for (var row in dailyRes) {
          mort += (row['mortality'] as num?)?.toInt() ?? 0;
          feedSum += (row['feed_kg'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // Feed total for FCR (layers may also log feed in daily_records)
      if (isLayer) {
        final feedRes = await _supabase
            .from('daily_records')
            .select('feed_kg')
            .eq('batch_id', batchId);
        for (var row in feedRes) {
          feedSum += (row['feed_kg'] as num?)?.toDouble() ?? 0.0;
        }
      }

      _totalFeedKg = feedSum;
      _totalMortality = mort;
      _totalEggsCollected = eggs;
      _latestDailyEggs = latestEggs;
      _firstLayingDate = firstEggDate;
      _firstLayingAgeDays = firstEggAgeDays;

      // 3. Sales (revenue + sold birds count)
      final salesRes = await _supabase
          .from('sales')
          .select('sale_type, quantity, weight_kg, unit_price')
          .eq('batch_id', batchId);

      double sumSales = 0.0;
      int soldCount = 0;
      for (var s in salesRes) {
        final qty = (s['quantity'] as num?)?.toDouble() ?? 0.0;
        final price = (s['unit_price'] as num?)?.toDouble() ?? 0.0;
        final wt = (s['weight_kg'] as num?)?.toDouble();
        if (s['sale_type'] == 'Bird' && wt != null && wt > 0) {
          sumSales += (wt * price);
        } else {
          sumSales += (qty * price);
        }
        if (s['sale_type'] == 'Bird') {
          soldCount += qty.toInt();
        }
      }
      _birdsSold = soldCount;
      _totalSales = sumSales;
      _currentBirds = (placedBirds - _totalMortality - _birdsSold).clamp(0, 9999999);

      // 4. Latest Average Weight (Meat & Layer)
      final weightRes = await _supabase
          .from('weekly_weights')
          .select('average_weight_kg, weight_date')
          .eq('batch_id', batchId)
          .order('weight_date', ascending: false)
          .limit(1);

      if (weightRes.isNotEmpty) {
        _latestAvgWeightKg = (weightRes.first['average_weight_kg'] as num?)?.toDouble() ?? 0.0;
        if (weightRes.first['weight_date'] != null) {
          _latestWeightDate = DateTime.tryParse(weightRes.first['weight_date'].toString());
        }
      } else {
        _latestAvgWeightKg = 0.0;
        _latestWeightDate = null;
      }

      // 5. Total Expenses (chick cost + expenses)
      final expRes = await _supabase
          .from('expenses')
          .select('amount')
          .eq('batch_id', batchId);

      double sumExp = 0.0;
      for (var row in expRes) {
        sumExp += (row['amount'] as num?)?.toDouble() ?? 0.0;
      }

      final chickPrice = (batchRes['chick_price'] as num?)?.toDouble() ?? 0.0;
      if (chickPrice > 0 && _initialBirds > 0) {
        sumExp += (chickPrice * _initialBirds);
      }
      _totalExpenses = sumExp;

      // 6. Admin Default Market Price
      final marketRes = await _supabase
          .from('market_prices')
          .select('price_per_unit, item_name')
          .order('price_date', ascending: false)
          .limit(10);

      double foundPrice = isLayer ? 12.0 : 210.0;
      if (marketRes.isNotEmpty) {
        for (var m in marketRes) {
          final itemName = (m['item_name'] ?? '').toString().toLowerCase();
          if (isLayer && (itemName.contains('egg') || itemName.contains('ডিম'))) {
            foundPrice = (m['price_per_unit'] as num?)?.toDouble() ?? 12.0;
            break;
          } else if (!isLayer && (itemName.contains('broiler') || itemName.contains('মুরগি') || itemName.contains('meat'))) {
            foundPrice = (m['price_per_unit'] as num?)?.toDouble() ?? 210.0;
            break;
          }
        }
      }

      _adminDefaultPrice = foundPrice;
      _negotiatingPrice = foundPrice;
      _negotiatingPriceController.text = foundPrice.toStringAsFixed(isLayer ? 1 : 0);

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load batch metrics: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0.0', 'en_US');

    final isLayer = (_selectedBatch?['production_type'] ?? '')
        .toString()
        .toLowerCase()
        .contains('egg');

    final double netUnrecovered = (_totalExpenses - _totalSales).clamp(0.0, double.infinity);

    // Meat / Broiler Metrics
    final double totalLiveWeightKg = _currentBirds * _latestAvgWeightKg;
    final double breakEvenWeightKg = (_currentBirds > 0 && _negotiatingPrice > 0)
        ? (netUnrecovered / (_currentBirds * _negotiatingPrice))
        : 0.0;
    final double breakEvenPerKg = totalLiveWeightKg > 0
        ? (netUnrecovered / totalLiveWeightKg)
        : 0.0;
    final double meatValuation = totalLiveWeightKg * _negotiatingPrice;
    final double meatRunningProfitLoss = meatValuation - netUnrecovered;

    // Layer Metrics
    final double breakEvenPerEgg = _totalEggsCollected > 0
        ? (_totalExpenses / _totalEggsCollected)
        : 0.0;
    final double eggTotalValuation = _totalEggsCollected * _negotiatingPrice;
    final double eggRunningMargin = eggTotalValuation - _totalExpenses;
    final double dailyEggRevenue = _latestDailyEggs * _negotiatingPrice;

    final batchName = (_selectedBatch?['name'] ?? 'Batch').toString();

    return Scaffold(
      backgroundColor: _soft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'AI Advisor',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.amber),
            tooltip: 'Open AI Window',
            onPressed: _selectedBatchId == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiChatScreen(
                          batchId: _selectedBatchId!,
                          batchName: batchName,
                        ),
                      ),
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync Live Data',
            onPressed: _selectedBatchId != null
                ? () => _fetchBatchActualMetrics(_selectedBatchId!)
                : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _batches.isEmpty
              ? const Center(child: Text('No active batches found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Batch Selection & Profile Header Card
                      _buildBatchProfileCard(isLayer),
                      const SizedBox(height: 14),

                      // 2. AI Quick Chat Consultation Banner
                      _buildAiConsultationBanner(batchName, isLayer),
                      const SizedBox(height: 16),

                      // 3. Real-time Actuals Bento Grid
                      _buildActualsGrid(isLayer, totalLiveWeightKg),
                      const SizedBox(height: 16),

                      _buildFcrCard(totalLiveWeightKg),
                      const SizedBox(height: 16),

                      _buildStandardCompareCard(),
                      const SizedBox(height: 16),

                      // 4. Financials & Break-Even Card
                      _buildBreakEvenAndValuationCard(
                        isLayer: isLayer,
                        breakEvenPerKg: breakEvenPerKg,
                        breakEvenWeightKg: breakEvenWeightKg,
                        breakEvenPerEgg: breakEvenPerEgg,
                        meatRunningProfitLoss: meatRunningProfitLoss,
                        eggRunningMargin: eggRunningMargin,
                        dailyEggRevenue: dailyEggRevenue,
                        currencyFormat: currencyFormat,
                      ),
                      const SizedBox(height: 16),

                      // 5. Real-Time DB Management Advice Card
                      _buildManagementAdviceCard(
                        isLayer: isLayer,
                        breakEvenPerKg: breakEvenPerKg,
                        breakEvenPerEgg: breakEvenPerEgg,
                      ),
                      const SizedBox(height: 80), // spacing for FAB
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedBatchId == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiChatScreen(
                      batchId: _selectedBatchId!,
                      batchName: batchName,
                    ),
                  ),
                ),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Open AI Window'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBatchProfileCard(bool isLayer) {
    final breed = _selectedBatch?['breed']?.toString();
    final shed = _selectedBatch?['shed']?.toString();
    final startDateStr = _selectedBatch?['start_date']?.toString();
    final ageWeeks = _flockAgeDays ~/ 7;
    final ageDaysRem = _flockAgeDays % 7;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLayer ? Colors.amber.shade50 : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isLayer ? Icons.egg : Icons.analytics_outlined,
                    color: isLayer ? Colors.amber.shade800 : Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBatchId,
                      isExpanded: true,
                      hint: const Text('Select Batch'),
                      items: _batches.map((b) {
                        return DropdownMenuItem<String>(
                          value: b['id'].toString(),
                          child: Text(
                            '${b['name'] ?? 'Batch'} (${b['production_type'] ?? 'General'})',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedBatchId) {
                          setState(() => _selectedBatchId = val);
                          _fetchBatchActualMetrics(val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildProfileBadge(
                  label: 'Flock Age',
                  value: isLayer
                      ? '$ageWeeks wks $ageDaysRem d'
                      : 'Day $_flockAgeDays ($ageWeeks wks)',
                  icon: Icons.calendar_today_outlined,
                  color: Colors.indigo,
                ),
                if (breed != null && breed.isNotEmpty)
                  _buildProfileBadge(
                    label: 'Breed',
                    value: breed,
                    icon: Icons.category_outlined,
                    color: Colors.brown,
                  ),
                if (shed != null && shed.isNotEmpty)
                  _buildProfileBadge(
                    label: 'Shed',
                    value: shed,
                    icon: Icons.warehouse_outlined,
                    color: Colors.blueGrey,
                  ),
                if (startDateStr != null)
                  _buildProfileBadge(
                    label: 'Started',
                    value: DateFormat('dd MMM').format(DateTime.parse(startDateStr)),
                    icon: Icons.event,
                    color: Colors.grey.shade700,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBadge({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAiConsultationBanner(String batchName, bool isLayer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AiChatScreen(
              batchId: _selectedBatchId!,
              batchName: batchName,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ask AI Advisor About This Batch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLayer
                        ? 'Analyzes first laying age, egg break-even & flock health'
                        : 'Analyzes weight standards, break-even price & profit margins',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildActualsGrid(bool isLayer, double totalLiveWeightKg) {
    final currency = NumberFormat('#,##0');
    final mortPercent = _initialBirds > 0 ? ((_totalMortality / _initialBirds) * 100) : 0.0;

    // Layer first egg string
    String firstEggText;
    String firstEggSub;
    if (_firstLayingAgeDays != null && _firstLayingDate != null) {
      final double weeks = _firstLayingAgeDays! / 7.0;
      firstEggText = '${weeks.toStringAsFixed(1)} Weeks';
      firstEggSub = 'Day $_firstLayingAgeDays (${DateFormat('dd MMM').format(_firstLayingDate!)})';
    } else {
      firstEggText = 'Not Started';
      firstEggSub = 'Pullet growing phase';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Real-time Farm Actuals',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Live Birds',
                value: '$_currentBirds / $_initialBirds',
                sub: 'Mort: $_totalMortality (${mortPercent.toStringAsFixed(1)}%)' +
                    (_birdsSold > 0 ? ' | Sold: $_birdsSold' : ''),
                icon: Icons.pets,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isLayer
                  ? _buildMetricTile(
                      title: 'First Laying Age',
                      value: firstEggText,
                      sub: firstEggSub,
                      icon: Icons.egg,
                      color: Colors.amber.shade800,
                    )
                  : _buildMetricTile(
                      title: 'Avg Weight',
                      value: '${_latestAvgWeightKg.toStringAsFixed(2)} kg',
                      sub: _latestWeightDate != null
                          ? DateFormat('dd MMM').format(_latestWeightDate!)
                          : 'No weight logged',
                      icon: Icons.scale_outlined,
                      color: Colors.orange,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Expenses & Sales',
                value: 'TK ${currency.format(_totalExpenses)}',
                sub: 'Sales: TK ${currency.format(_totalSales)} | Net: TK ${currency.format(_totalExpenses - _totalSales)}',
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isLayer
                  ? _buildMetricTile(
                      title: 'Egg Production',
                      value: '${currency.format(_totalEggsCollected)} pcs',
                      sub: _currentBirds > 0
                          ? 'Avg ${(_totalEggsCollected / _currentBirds).toStringAsFixed(1)} eggs/hen'
                          : 'Actual logged',
                      icon: Icons.bar_chart_outlined,
                      color: Colors.teal,
                    )
                  : _buildMetricTile(
                      title: 'Standing Biomass',
                      value: '${totalLiveWeightKg.toStringAsFixed(0)} kg',
                      sub: '$_currentBirds live birds',
                      icon: Icons.fitness_center,
                      color: Colors.teal,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.darker(),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakEvenAndValuationCard({
    required bool isLayer,
    required double breakEvenPerKg,
    required double breakEvenWeightKg,
    required double breakEvenPerEgg,
    required double meatRunningProfitLoss,
    required double eggRunningMargin,
    required double dailyEggRevenue,
    required NumberFormat currencyFormat,
  }) {
    final bool isMeatProfit = meatRunningProfitLoss >= 0;
    final bool isEggSurplus = eggRunningMargin >= 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_outlined, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLayer ? 'Egg Break-Even & Financials' : 'Bird Break-Even & Valuation',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Break-Even Metric Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isLayer ? 'Break-Even Cost / Egg:' : 'Break-Even Cost / Kg:',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  isLayer
                      ? 'TK ${breakEvenPerEgg.toStringAsFixed(2)} / pc'
                      : 'TK ${breakEvenPerKg.toStringAsFixed(2)} / kg',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),

            if (!isLayer) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Break-Even Weight / Bird:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${breakEvenWeightKg.toStringAsFixed(2)} kg / bird',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 6),
            Text(
              isLayer
                  ? 'Total expenses divided by collected eggs to date.'
                  : 'Target weight per bird needed to break even at current negotiating price.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            // Negotiating Price Input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isLayer ? 'Negotiating Price (TK /egg):' : 'Negotiating Price (TK /kg):',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        'Admin: TK ${_adminDefaultPrice.toStringAsFixed(isLayer ? 1 : 0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _negotiatingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: 'TK ',
                      hintText: 'Enter buyer offered rate',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      fillColor: Colors.white,
                      filled: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.restore, size: 18),
                        tooltip: 'Reset to Admin Rate',
                        onPressed: () {
                          setState(() {
                            _negotiatingPrice = _adminDefaultPrice;
                            _negotiatingPriceController.text =
                                _adminDefaultPrice.toStringAsFixed(isLayer ? 1 : 0);
                          });
                        },
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _negotiatingPrice = double.tryParse(val) ?? 0.0;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Financial Status Banner
            if (!isLayer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isMeatProfit ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMeatProfit ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMeatProfit ? 'Estimated Net Surplus' : 'Estimated Net Deficit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isMeatProfit ? Colors.green.shade900 : Colors.red.shade900,
                          ),
                        ),
                        Text(
                          'If sold today at TK ${_negotiatingPrice.toStringAsFixed(0)}/kg',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    Text(
                      '${isMeatProfit ? '+' : ''}TK ${currencyFormat.format(meatRunningProfitLoss)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isMeatProfit ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isEggSurplus ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isEggSurplus ? Colors.green.shade300 : Colors.blue.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEggSurplus ? 'Egg Value Surplus' : 'Unrecovered Investment',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isEggSurplus ? Colors.green.shade900 : Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          _latestDailyEggs > 0
                              ? 'Today\'s egg value: TK ${dailyEggRevenue.toStringAsFixed(0)}'
                              : 'Total eggs × TK ${_negotiatingPrice.toStringAsFixed(1)}/egg',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    Text(
                      '${isEggSurplus ? '+' : ''}TK ${currencyFormat.format(eggRunningMargin)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isEggSurplus ? Colors.green.shade800 : Colors.indigo.shade800,
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

  List<Map<String, String>> _generateAdviceList(
    bool isLayer,
    double breakEvenPerKg,
    double breakEvenPerEgg,
  ) {
    final List<Map<String, String>> adviceList = [];
    final placed = _initialBirds + ((_selectedBatch?['additional_birds'] as num?)?.toInt() ?? 0);
    final mortRate = placed > 0 ? (_totalMortality * 100.0 / placed) : 0.0;

    if (mortRate >= 8) {
      adviceList.add({
        'level': 'urgent',
        'title': 'High mortality',
        'body':
            'Mortality is ${mortRate.toStringAsFixed(1)}%. Check water sanitation, ventilation, and biosecurity immediately.',
      });
    } else if (mortRate >= 4) {
      adviceList.add({
        'level': 'watch',
        'title': 'Mortality elevated',
        'body':
            'Mortality is ${mortRate.toStringAsFixed(1)}%. Review daily deaths and isolate weak birds.',
      });
    } else {
      adviceList.add({
        'level': 'good',
        'title': 'Livability healthy',
        'body':
            'Survival is solid (${(100 - mortRate).toStringAsFixed(1)}%). Keep feed hygiene and dry litter.',
      });
    }

    final liveBiomass = _currentBirds * _latestAvgWeightKg;
    final fcr = (_totalFeedKg > 0 && liveBiomass > 0) ? _totalFeedKg / liveBiomass : null;
    if (fcr != null) {
      if (fcr > 1.85) {
        adviceList.add({
          'level': 'urgent',
          'title': 'High FCR',
          'body':
              'FCR is ${fcr.toStringAsFixed(2)}. Review feed wastage, disease pressure, and ration quality.',
        });
      } else if (fcr > 1.55) {
        adviceList.add({
          'level': 'watch',
          'title': 'FCR watch',
          'body':
              'FCR is ${fcr.toStringAsFixed(2)}. Acceptable, but tighten feeding routine if possible.',
        });
      } else {
        adviceList.add({
          'level': 'good',
          'title': 'Strong FCR',
          'body':
              'FCR is ${fcr.toStringAsFixed(2)}. Feed conversion is efficient.',
        });
      }
    } else if (_totalFeedKg <= 0) {
      adviceList.add({
        'level': 'watch',
        'title': 'Feed not logged',
        'body':
            'Add daily feed (kg) so FCR can guide ration decisions.',
      });
    }

    if (!isLayer) {
      if (_latestAvgWeightKg <= 0) {
        adviceList.add({
          'level': 'watch',
          'title': 'No weight log',
          'body':
              'Log weekly weight in Average Weight so biomass and break-even stay accurate.',
        });
      } else if (_negotiatingPrice > 0 &&
          breakEvenPerKg > 0 &&
          _negotiatingPrice < breakEvenPerKg) {
        final gap = (breakEvenPerKg - _negotiatingPrice).toStringAsFixed(0);
        adviceList.add({
          'level': 'urgent',
          'title': 'Price below break-even',
          'body':
              'Negotiating price is about TK $gap/kg under break-even (TK ${breakEvenPerKg.toStringAsFixed(0)}/kg). Hold or renegotiate if possible.',
        });
      } else {
        adviceList.add({
          'level': 'good',
          'title': 'Weight tracking OK',
          'body':
              'Keep feed consistent. Withdraw feed 6–8 hours before catch to protect carcass quality.',
        });
      }
    } else {
      if (_firstLayingAgeDays != null) {
        final weeks = _firstLayingAgeDays! / 7.0;
        if (weeks < 18) {
          adviceList.add({
            'level': 'watch',
            'title': 'Early laying onset',
            'body':
                'First eggs at ${weeks.toStringAsFixed(1)} weeks. Ensure calcium and body weight to reduce prolapse risk.',
          });
        } else if (weeks <= 21) {
          adviceList.add({
            'level': 'good',
            'title': 'Ideal first lay age',
            'body':
                'Flock started laying at ${weeks.toStringAsFixed(1)} weeks — within the usual 18–21 week window.',
          });
        } else {
          adviceList.add({
            'level': 'watch',
            'title': 'Delayed first lay',
            'body':
                'First eggs at ${weeks.toStringAsFixed(1)} weeks. Review pullet uniformity and lighting step-up.',
          });
        }
      } else {
        final ageWeeks = _flockAgeDays / 7.0;
        if (ageWeeks >= 18) {
          adviceList.add({
            'level': 'watch',
            'title': 'No egg logs yet',
            'body':
                'Flock is ${ageWeeks.toStringAsFixed(1)} weeks with no egg records. Check light (14–16 hrs) and protein intake.',
          });
        } else {
          adviceList.add({
            'level': 'good',
            'title': 'Pullet rearing phase',
            'body':
                'Age ${ageWeeks.toStringAsFixed(1)} weeks. Focus on frame size and steady weekly weight gain before lay.',
          });
        }
      }

      if (_negotiatingPrice > 0 && breakEvenPerEgg > 0) {
        if (_negotiatingPrice < breakEvenPerEgg) {
          final diff = (breakEvenPerEgg - _negotiatingPrice).toStringAsFixed(2);
          adviceList.add({
            'level': 'watch',
            'title': 'Egg price margin',
            'body':
                'Market rate is about TK $diff/egg under cumulative break-even. Cost per egg usually falls as peak production continues.',
          });
        } else {
          adviceList.add({
            'level': 'good',
            'title': 'Shell quality care',
            'body':
                'Offer coarse limestone or oyster shell in late afternoon for overnight shell formation.',
          });
        }
      }
    }

    if (_currentBirds <= 0) {
      adviceList.insert(0, {
        'level': 'urgent',
        'title': 'No birds on hand',
        'body':
            'Current birds are zero after mortality and sales. Confirm records or close the batch.',
      });
    }

    return adviceList;
  }

  Widget _buildFcrCard(double totalLiveWeightKg) {
    final hasFeed = _totalFeedKg > 0;
    final hasBiomass = totalLiveWeightKg > 0;
    final fcr = (hasFeed && hasBiomass) ? (_totalFeedKg / totalLiveWeightKg) : null;

    String status;
    Color statusColor;
    String detail;
    if (fcr == null) {
      status = 'Unavailable';
      statusColor = _muted;
      detail = !hasFeed
          ? 'Log daily feed (kg) to calculate FCR.'
          : 'Log average weight to calculate live biomass and FCR.';
    } else if (fcr <= 1.55) {
      status = 'Excellent';
      statusColor = const Color(0xFF2E7D32);
      detail = 'Feed is converting efficiently into body weight.';
    } else if (fcr <= 1.85) {
      status = 'Acceptable';
      statusColor = const Color(0xFF1565C0);
      detail = 'FCR is within a workable farm range. Watch wastage.';
    } else {
      status = 'High';
      statusColor = const Color(0xFFC62828);
      detail = 'Feed use is high vs biomass. Check spillage, disease, and feed quality.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _brandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.speed, color: _brand, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feed conversion (FCR)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Total feed ÷ live biomass',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            fcr == null ? '—' : fcr.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: fcr == null ? _muted : _ink,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _miniStat('Feed', '${_totalFeedKg.toStringAsFixed(0)} kg'),
                ),
                Container(width: 1, height: 28, color: _line),
                Expanded(
                  child: _miniStat(
                    'Biomass',
                    hasBiomass ? '${totalLiveWeightKg.toStringAsFixed(0)} kg' : '—',
                  ),
                ),
                Container(width: 1, height: 28, color: _line),
                Expanded(
                  child: _miniStat('Birds', '$_currentBirds'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(detail, style: const TextStyle(fontSize: 13, height: 1.35, color: _muted)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
        ),
      ],
    );
  }

  Widget _buildStandardCompareCard() {
    final category = (_selectedBatch?['production_category'] ?? '').toString();
    final breed = (_selectedBatch?['breed'] ?? '').toString();
    final productionType = (_selectedBatch?['production_type'] ?? '').toString();
    final hasWeight = _latestAvgWeightKg > 0;

    final evaluation = PoultryStandardsService.evaluate(
      productionType: productionType,
      productionCategory: category,
      breed: breed,
      ageDays: _flockAgeDays,
      actualWeightKg: hasWeight ? _latestAvgWeightKg : 0,
    );

    final standardKg = evaluation.targetWeightGrams / 1000.0;
    final hasStandard = evaluation.targetWeightGrams > 0;
    final statusColor = Color(evaluation.colorHex);

    String statusLabel;
    switch (evaluation.status) {
      case GrowthStatus.ahead:
        statusLabel = 'Ahead';
        break;
      case GrowthStatus.behind:
        statusLabel = 'Behind';
        break;
      case GrowthStatus.onTarget:
        statusLabel = 'On target';
        break;
    }

    final pctText = !hasWeight || !hasStandard
        ? '—'
        : '${evaluation.diffPercent >= 0 ? '+' : ''}${evaluation.diffPercent.toStringAsFixed(1)}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.monitor_weight_outlined, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Standard vs actual',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Day $_flockAgeDays · ${evaluation.breedBenchmarkName}',
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hasWeight && hasStandard ? statusLabel : 'No data',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: hasWeight && hasStandard ? statusColor : _muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _compareBox(
                  label: 'Standard',
                  value: hasStandard ? '${standardKg.toStringAsFixed(2)} kg' : '—',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _compareBox(
                  label: 'Actual',
                  value: hasWeight ? '${_latestAvgWeightKg.toStringAsFixed(2)} kg' : '—',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _compareBox(
                  label: 'Gap',
                  value: pctText,
                  valueColor: hasWeight && hasStandard ? statusColor : _ink,
                ),
              ),
            ],
          ),
          if (hasWeight && hasStandard) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: (standardKg <= 0)
                    ? 0
                    : (_latestAvgWeightKg / standardKg).clamp(0.0, 1.3) / 1.3,
                backgroundColor: _soft,
                color: statusColor,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            !hasWeight
                ? 'Log average weight to compare against the breed curve.'
                : !hasStandard
                    ? 'No standard curve matched this breed/category.'
                    : evaluation.advice,
            style: const TextStyle(fontSize: 13, height: 1.35, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _compareBox({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: valueColor ?? _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementAdviceCard({
    required bool isLayer,
    required double breakEvenPerKg,
    required double breakEvenPerEgg,
  }) {
    final adviceList =
        _generateAdviceList(isLayer, breakEvenPerKg, breakEvenPerEgg);

    Color bg(String level) {
      switch (level) {
        case 'urgent':
          return const Color(0xFFFFEBEE);
        case 'watch':
          return const Color(0xFFFFF8E8);
        default:
          return _brandSoft;
      }
    }

    Color fg(String level) {
      switch (level) {
        case 'urgent':
          return const Color(0xFFB71C1C);
        case 'watch':
          return const Color(0xFF8A6A1A);
        default:
          return _brand;
      }
    }

    IconData icon(String level) {
      switch (level) {
        case 'urgent':
          return Icons.error_outline;
        case 'watch':
          return Icons.visibility_outlined;
        default:
          return Icons.check_circle_outline;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_outlined, color: _brand, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Management advice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Based on recorded batch data only.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 14),
          ...adviceList.map((item) {
            final level = item['level'] ?? 'good';
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg(level),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon(level), size: 20, color: fg(level)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? '',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: fg(level),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item['body'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: fg(level).withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

}

extension ColorUtils on Color {
  Color darker([double factor = 0.2]) {
    return Color.fromARGB(
      alpha,
      (red * (1.0 - factor)).round().clamp(0, 255),
      (green * (1.0 - factor)).round().clamp(0, 255),
      (blue * (1.0 - factor)).round().clamp(0, 255),
    );
  }
}
