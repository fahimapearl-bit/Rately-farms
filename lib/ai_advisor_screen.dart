import 'app_colors.dart';
import 'ai_chat_screen.dart';
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
      final batchRes = await _supabase
          .from('batches')
          .select()
          .eq('id', batchId)
          .single();
      _selectedBatch = batchRes;
      _initialBirds = (batchRes['initial_birds'] as num?)?.toInt() ?? 0;
      final additionalBirds = (batchRes['additional_birds'] as num?)?.toInt() ?? 0;
      final placedBirds = _initialBirds + additionalBirds;

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
    final colors = context.colors;
    final currencyFormat = NumberFormat('#,##0.0', 'en_US');

    final isLayer = (_selectedBatch?['production_type'] ?? '')
        .toString()
        .toLowerCase()
        .contains('egg');

    final double netUnrecovered = (_totalExpenses - _totalSales).clamp(0.0, double.infinity);

    final double totalLiveWeightKg = _currentBirds * _latestAvgWeightKg;
    final double breakEvenWeightKg = (_currentBirds > 0 && _negotiatingPrice > 0)
        ? (netUnrecovered / (_currentBirds * _negotiatingPrice))
        : 0.0;
    final double breakEvenPerKg = totalLiveWeightKg > 0
        ? (netUnrecovered / totalLiveWeightKg)
        : 0.0;
    final double meatValuation = totalLiveWeightKg * _negotiatingPrice;
    final double meatRunningProfitLoss = meatValuation - netUnrecovered;

    final double breakEvenPerEgg = _totalEggsCollected > 0
        ? (_totalExpenses / _totalEggsCollected)
        : 0.0;
    final double eggTotalValuation = _totalEggsCollected * _negotiatingPrice;
    final double eggRunningMargin = eggTotalValuation - _totalExpenses;
    final double dailyEggRevenue = _latestDailyEggs * _negotiatingPrice;

    final batchName = (_selectedBatch?['name'] ?? 'Batch').toString();

    return Scaffold(
      backgroundColor: colors.soft,
      appBar: AppBar(
        backgroundColor: colors.card,
        foregroundColor: colors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'AI Advisor',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: colors.ink,
          ),
        ),
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
            icon: Icon(Icons.refresh, color: colors.ink),
            tooltip: 'Sync Live Data',
            onPressed: _selectedBatchId != null
                ? () => _fetchBatchActualMetrics(_selectedBatchId!)
                : null,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.brand))
          : _batches.isEmpty
              ? Center(
                  child: Text(
                    'No active batches found.',
                    style: TextStyle(color: colors.muted),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBatchProfileCard(isLayer, colors),
                      const SizedBox(height: 14),
                      _buildAiConsultationBanner(batchName, isLayer),
                      const SizedBox(height: 16),
                      _buildActualsGrid(isLayer, totalLiveWeightKg, colors),
                      const SizedBox(height: 16),
                      _buildBreakEvenAndValuationCard(
                        isLayer: isLayer,
                        breakEvenPerKg: breakEvenPerKg,
                        breakEvenWeightKg: breakEvenWeightKg,
                        breakEvenPerEgg: breakEvenPerEgg,
                        meatRunningProfitLoss: meatRunningProfitLoss,
                        eggRunningMargin: eggRunningMargin,
                        dailyEggRevenue: dailyEggRevenue,
                        currencyFormat: currencyFormat,
                        colors: colors,
                      ),
                      const SizedBox(height: 16),
                      _buildManagementAdviceCard(
                        isLayer: isLayer,
                        breakEvenPerKg: breakEvenPerKg,
                        breakEvenPerEgg: breakEvenPerEgg,
                        colors: colors,
                      ),
                      const SizedBox(height: 80),
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
        backgroundColor: colors.brand,
        foregroundColor: colors.onBrand,
      ),
    );
  }

  Widget _buildBatchProfileCard(bool isLayer, AppColors colors) {
    final breed = _selectedBatch?['breed']?.toString();
    final shed = _selectedBatch?['shed']?.toString();
    final startDateStr = _selectedBatch?['start_date']?.toString();
    final ageWeeks = _flockAgeDays ~/ 7;
    final ageDaysRem = _flockAgeDays % 7;

    return Card(
      elevation: colors.isDark ? 0 : 1,
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLayer
                        ? (colors.isDark ? Colors.amber.withOpacity(0.15) : Colors.amber.shade50)
                        : colors.brandSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isLayer ? Icons.egg : Icons.analytics_outlined,
                    color: isLayer ? Colors.amber : colors.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBatchId,
                      dropdownColor: colors.card,
                      isExpanded: true,
                      hint: Text('Select Batch', style: TextStyle(color: colors.muted)),
                      items: _batches.map((b) {
                        return DropdownMenuItem<String>(
                          value: b['id'].toString(),
                          child: Text(
                            '${b['name'] ?? 'Batch'} (${b['production_type'] ?? 'General'})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList>,
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
            Divider(height: 18, color: colors.line),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildProfileBadge(
                  label: 'Flock Age',
                  value: isLayer
                      ? '$ageWeeks wks $ageDaysRem d'
                      : 'Day $_flockAgeDays ($ageWeeks wks)',
                  icon: Icons.calendar_today_outlined,
                  color: Colors.indigoAccent,
                  colors: colors,
                ),
                if (breed != null && breed.isNotEmpty)
                  _buildProfileBadge(
                    label: 'Breed',
                    value: breed,
                    icon: Icons.category_outlined,
                    color: colors.isDark ? Colors.amber.shade300 : Colors.brown,
                    colors: colors,
                  ),
                if (shed != null && shed.isNotEmpty)
                  _buildProfileBadge(
                    label: 'Shed',
                    value: shed,
                    icon: Icons.warehouse_outlined,
                    color: colors.isDark ? Colors.tealAccent : Colors.blueGrey,
                    colors: colors,
                  ),
                if (startDateStr != null)
                  _buildProfileBadge(
                    label: 'Started',
                    value: DateFormat('dd MMM').format(DateTime.parse(startDateStr)),
                    icon: Icons.event,
                    color: colors.muted,
                    colors: colors,
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
    required AppColors colors,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade900, Colors.teal.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.2),
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

  Widget _buildActualsGrid(bool isLayer, double totalLiveWeightKg, AppColors colors) {
    final currency = NumberFormat('#,##0');
    final mortPercent = _initialBirds > 0 ? ((_totalMortality / _initialBirds) * 100) : 0.0;

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
        Text(
          'Real-time Farm Actuals',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink),
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
                colors: colors,
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
                      color: Colors.amber,
                      colors: colors,
                    )
                  : _buildMetricTile(
                      title: 'Avg Weight',
                      value: '${_latestAvgWeightKg.toStringAsFixed(2)} kg',
                      sub: _latestWeightDate != null
                          ? DateFormat('dd MMM').format(_latestWeightDate!)
                          : 'No weight logged',
                      icon: Icons.scale_outlined,
                      color: Colors.orange,
                      colors: colors,
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
                color: Colors.indigoAccent,
                colors: colors,
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
                      colors: colors,
                    )
                  : _buildMetricTile(
                      title: 'Standing Biomass',
                      value: '${totalLiveWeightKg.toStringAsFixed(0)} kg',
                      sub: '$_currentBirds live birds',
                      icon: Icons.fitness_center,
                      color: Colors.teal,
                      colors: colors,
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
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.isDark ? color.withOpacity(0.12) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(colors.isDark ? 0.35 : 0.2)),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.muted,
                    fontWeight: FontWeight.w600,
                  ),
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
              color: colors.isDark ? color : color.darker(),
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
    required AppColors colors,
  }) {
    final bool isMeatProfit = meatRunningProfitLoss >= 0;
    final bool isEggSurplus = eggRunningMargin >= 0;

    return Card(
      elevation: colors.isDark ? 0 : 2,
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate_outlined, color: colors.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLayer ? 'Egg Break-Even & Financials' : 'Bird Break-Even & Valuation',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: colors.line),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isLayer ? 'Break-Even Cost / Egg:' : 'Break-Even Cost / Kg:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.ink),
                ),
                Text(
                  isLayer
                      ? 'TK ${breakEvenPerEgg.toStringAsFixed(2)} / pc'
                      : 'TK ${breakEvenPerKg.toStringAsFixed(2)} / kg',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.brand,
                  ),
                ),
              ],
            ),

            if (!isLayer) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Break-Even Weight / Bird:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.ink),
                  ),
                  Text(
                    '${breakEvenWeightKg.toStringAsFixed(2)} kg / bird',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.isDark ? Colors.tealAccent : Colors.teal.shade800,
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
                color: colors.soft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.line),
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
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.ink),
                        ),
                      ),
                      Text(
                        'Admin: TK ${_adminDefaultPrice.toStringAsFixed(isLayer ? 1 : 0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.brand,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _negotiatingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: 'TK ',
                      prefixStyle: TextStyle(color: colors.muted),
                      hintText: 'Enter buyer offered rate',
                      hintStyle: TextStyle(color: colors.hint),
                      fillColor: colors.card,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.brand, width: 1.5),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.restore, size: 18, color: colors.muted),
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
                  color: isMeatProfit
                      ? (colors.isDark ? Colors.green.withOpacity(0.18) : Colors.green.shade50)
                      : (colors.isDark ? Colors.red.withOpacity(0.18) : Colors.red.shade50),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMeatProfit
                        ? (colors.isDark ? Colors.green.withOpacity(0.4) : Colors.green.shade300)
                        : (colors.isDark ? Colors.red.withOpacity(0.4) : Colors.red.shade300),
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
                            color: isMeatProfit
                                ? (colors.isDark ? Colors.greenAccent : Colors.green.shade900)
                                : (colors.isDark ? const Color(0xFFFF8A80) : Colors.red.shade900),
                          ),
                        ),
                        Text(
                          'If sold today at TK ${_negotiatingPrice.toStringAsFixed(0)}/kg',
                          style: TextStyle(fontSize: 11, color: colors.muted),
                        ),
                      ],
                    ),
                    Text(
                      '${isMeatProfit ? '+' : ''}TK ${currencyFormat.format(meatRunningProfitLoss)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isMeatProfit
                            ? (colors.isDark ? Colors.greenAccent : Colors.green.shade800)
                            : (colors.isDark ? const Color(0xFFFF8A80) : Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isEggSurplus
                      ? (colors.isDark ? Colors.green.withOpacity(0.18) : Colors.green.shade50)
                      : (colors.isDark ? Colors.blue.withOpacity(0.18) : Colors.blue.shade50),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isEggSurplus
                        ? (colors.isDark ? Colors.green.withOpacity(0.4) : Colors.green.shade300)
                        : (colors.isDark ? Colors.blue.withOpacity(0.4) : Colors.blue.shade300),
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
                            color: isEggSurplus
                                ? (colors.isDark ? Colors.greenAccent : Colors.green.shade900)
                                : (colors.isDark ? Colors.lightBlueAccent : Colors.blue.shade900),
                          ),
                        ),
                        Text(
                          _latestDailyEggs > 0
                              ? 'Today\'s egg value: TK ${dailyEggRevenue.toStringAsFixed(0)}'
                              : 'Total eggs × TK ${_negotiatingPrice.toStringAsFixed(1)}/egg',
                          style: TextStyle(fontSize: 11, color: colors.muted),
                        ),
                      ],
                    ),
                    Text(
                      '${isEggSurplus ? '+' : ''}TK ${currencyFormat.format(eggRunningMargin)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isEggSurplus
                            ? (colors.isDark ? Colors.greenAccent : Colors.green.shade800)
                            : (colors.isDark ? Colors.lightBlueAccent : Colors.indigo.shade800),
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

  Widget _buildManagementAdviceCard({
    required bool isLayer,
    required double breakEvenPerKg,
    required double breakEvenPerEgg,
    required AppColors colors,
  }) {
    final adviceList =
        _generateAdviceList(isLayer, breakEvenPerKg, breakEvenPerEgg);

    Color bg(String level) {
      switch (level) {
        case 'urgent':
          return colors.isDark ? const Color(0xFF381517) : const Color(0xFFFFEBEE);
        case 'watch':
          return colors.noticeBg;
        default:
          return colors.brandSoft;
      }
    }

    Color fg(String level) {
      switch (level) {
        case 'urgent':
          return colors.isDark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C);
        case 'watch':
          return colors.noticeText;
        default:
          return colors.brand;
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
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
        boxShadow: [
          if (!colors.isDark)
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
              Icon(Icons.psychology_outlined, color: colors.brand, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Management advice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Based on recorded batch data only.',
            style: TextStyle(fontSize: 12, color: colors.muted),
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
                border: Border.all(
                  color: fg(level).withOpacity(colors.isDark ? 0.3 : 0.15),
                ),
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
