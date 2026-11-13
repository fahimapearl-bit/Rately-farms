import 'ai_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'app_colors.dart';

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
          .select('id, name, production_type, breed, shed, start_date, initial_birds, chick_price, status')
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
          SnackBar(content: Text('Error loading batches: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchBatchActualMetrics(String batchId) async {
    setState(() => _isLoading = true);
    try {
      // 1. Batch info
      final batchRes = await _supabase
          .from('batches')
          .select()
          .eq('id', batchId)
          .single();
      _selectedBatch = batchRes;
      _initialBirds = (batchRes['initial_birds'] as num?)?.toInt() ?? 0;

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
            .select('mortality')
            .eq('batch_id', batchId);
        for (var row in dailyRes) {
          mort += (row['mortality'] as num?)?.toInt() ?? 0;
        }
      }

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
      _currentBirds = (_initialBirds - _totalMortality - _birdsSold).clamp(0, 9999999);

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
          SnackBar(content: Text('Error loading metrics: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
      appBar: AppBar(
        title: const Text('AI & Batch Advisor'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.auto_awesome, color: colors.warning),
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
        backgroundColor: colors.accent,
        foregroundColor: colors.card,
      ),
    );
  }

  Widget _buildBatchProfileCard(bool isLayer) {
    final colors = context.colors;
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
                    color: isLayer ? colors.warningSoft : colors.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isLayer ? Icons.egg : Icons.analytics_outlined,
                    color: isLayer ? colors.warning : colors.accent,
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
                  color: colors.info,
                ),
                if (breed != null && breed.isNotEmpty)
                  _buildProfileBadge(
                    label: 'Breed',
                    value: breed,
                    icon: Icons.category_outlined,
                    color: colors.warning,
                  ),
                if (shed != null && shed.isNotEmpty)
                  _buildProfileBadge(
                    label: 'Shed',
                    value: shed,
                    icon: Icons.warehouse_outlined,
                    color: colors.inkAlt,
                  ),
                if (startDateStr != null)
                  _buildProfileBadge(
                    label: 'Started',
                    value: DateFormat('dd MMM').format(DateTime.parse(startDateStr)),
                    icon: Icons.event,
                    color: colors.inkAlt,
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
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: colors.muted),
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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accent, colors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withOpacity(0.25),
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
                color: colors.onAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.auto_awesome, color: colors.warning, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask AI Advisor About This Batch',
                    style: TextStyle(
                      color: colors.card,
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
                      color: colors.onAccent.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: colors.card, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildActualsGrid(bool isLayer, double totalLiveWeightKg) {
    final colors = context.colors;
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
                color: colors.info,
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
                      color: colors.warning,
                    )
                  : _buildMetricTile(
                      title: 'Avg Weight',
                      value: '${_latestAvgWeightKg.toStringAsFixed(2)} kg',
                      sub: _latestWeightDate != null
                          ? DateFormat('dd MMM').format(_latestWeightDate!)
                          : 'No weight logged',
                      icon: Icons.scale_outlined,
                      color: colors.warning,
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
                color: colors.info,
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
                      color: colors.accent,
                    )
                  : _buildMetricTile(
                      title: 'Standing Biomass',
                      value: '${totalLiveWeightKg.toStringAsFixed(0)} kg',
                      sub: '$_currentBirds live birds',
                      icon: Icons.fitness_center,
                      color: colors.accent,
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
    final colors = context.colors;
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
                  style: TextStyle(fontSize: 12, color: colors.inkAlt, fontWeight: FontWeight.w600),
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
            style: TextStyle(fontSize: 11, color: colors.muted),
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
    final colors = context.colors;
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
                Icon(Icons.calculate_outlined, color: colors.info),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.info,
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
                      color: colors.accent,
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
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
            const SizedBox(height: 16),

            // Negotiating Price Input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
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
                          color: colors.accent,
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
                      fillColor: colors.card,
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
                  color: isMeatProfit ? colors.successSoft : colors.errorSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMeatProfit ? colors.brandSoft : colors.errorBorder,
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
                            color: isMeatProfit ? colors.brand : colors.error,
                          ),
                        ),
                        Text(
                          'If sold today at TK ${_negotiatingPrice.toStringAsFixed(0)}/kg',
                          style: TextStyle(fontSize: 11, color: colors.inkAlt),
                        ),
                      ],
                    ),
                    Text(
                      '${isMeatProfit ? '+' : ''}TK ${currencyFormat.format(meatRunningProfitLoss)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isMeatProfit ? colors.brand : colors.error,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isEggSurplus ? colors.successSoft : colors.infoSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isEggSurplus ? colors.brandSoft : colors.info,
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
                            color: isEggSurplus ? colors.brand : colors.info,
                          ),
                        ),
                        Text(
                          _latestDailyEggs > 0
                              ? 'Today\'s egg value: TK ${dailyEggRevenue.toStringAsFixed(0)}'
                              : 'Total eggs × TK ${_negotiatingPrice.toStringAsFixed(1)}/egg',
                          style: TextStyle(fontSize: 11, color: colors.inkAlt),
                        ),
                      ],
                    ),
                    Text(
                      '${isEggSurplus ? '+' : ''}TK ${currencyFormat.format(eggRunningMargin)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isEggSurplus ? colors.brand : colors.info,
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

  List<String> _generateAdviceList(bool isLayer, double breakEvenPerKg, double breakEvenPerEgg) {
    final List<String> adviceList = [];

    // 1. Mortality & Livability check
    final double mortRate = _initialBirds > 0 ? (_totalMortality / _initialBirds) * 100 : 0.0;
    if (mortRate > 4.5) {
      adviceList.add('🚨 High Mortality (${mortRate.toStringAsFixed(1)}%): Inspect drinking water sanitation, ventilation, and review biosecurity strictly.');
    } else {
      adviceList.add('✅ Flock Livability is healthy (${(100 - mortRate).toStringAsFixed(1)}%). Continue strict feed hygiene and dry bedding.');
    }

    // 2. Production Type specifics
    if (!isLayer) {
      // Meat advice
      if (_latestAvgWeightKg == 0.0) {
        adviceList.add('⚖️ No weight log found. Log weekly weight in "Average Weight" screen to compute live biomass & break-even accurately.');
      } else if (_negotiatingPrice > 0 && _negotiatingPrice < breakEvenPerKg) {
        final gap = (breakEvenPerKg - _negotiatingPrice).toStringAsFixed(1);
        adviceList.add('⚠️ Price Alert: Current negotiating price is TK $gap/kg below break-even! Consider holding or negotiating closer to TK ${breakEvenPerKg.toStringAsFixed(0)}/kg.');
      } else {
        adviceList.add('📈 Weight standard on target. Schedule feed withdrawal 6-8 hours before final bird catching to prevent carcass contamination.');
      }
    } else {
      // Layer advice (First laying age + laying onset)
      if (_firstLayingAgeDays != null) {
        final double weeks = _firstLayingAgeDays! / 7.0;
        if (weeks < 18.0) {
          adviceList.add('⚠️ Early Laying Onset (${weeks.toStringAsFixed(1)} wks): Birds began laying early. Ensure adequate dietary calcium and body weight to avoid prolapse and small eggs.');
        } else if (weeks <= 21.0) {
          adviceList.add('🎯 Ideal First Laying Age (${weeks.toStringAsFixed(1)} wks): Flock started laying exactly within the optimal breed standard window (18-21 weeks).');
        } else {
          adviceList.add('⏳ Delayed First Laying Age (${weeks.toStringAsFixed(1)} wks): Review uniformity of pullet body weight and artificial lighting step-up program.');
        }
      } else {
        final ageWeeks = _flockAgeDays / 7.0;
        if (ageWeeks > 21.0) {
          adviceList.add('⏳ Flock age is ${ageWeeks.toStringAsFixed(1)} weeks with no egg logs yet. Check light stimulation (14-16 hrs) and crude protein intake.');
        } else {
          adviceList.add('🐣 Pullet Rearing Phase (${ageWeeks.toStringAsFixed(1)} wks): Focus on target skeletal frame and weekly body weight gain before egg production starts.');
        }
      }

      if (_totalEggsCollected > 0 && _negotiatingPrice > 0) {
        if (_negotiatingPrice < breakEvenPerEgg) {
          final diff = (breakEvenPerEgg - _negotiatingPrice).toStringAsFixed(2);
          adviceList.add('⚠️ Egg Price Margin: Current market rate is TK $diff/egg below cumulative break-even. As peak production continues, cumulative cost per egg will drop.');
        } else {
          adviceList.add('💡 Layer Care: Provide oyster shell grit / coarse limestone in late afternoon for optimal eggshell calcification during the night.');
        }
      }
    }

    return adviceList;
  }

  Widget _buildManagementAdviceCard({
    required bool isLayer,
    required double breakEvenPerKg,
    required double breakEvenPerEgg,
  }) {
    final colors = context.colors;
    final List<String> adviceList = _generateAdviceList(isLayer, breakEvenPerKg, breakEvenPerEgg);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: colors.accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Batch Management Advice (Actuals)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            ...adviceList.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
