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
  double _latestAvgWeightKg = 0.0;
  DateTime? _latestWeightDate;
  double _totalExpenses = 0.0;

  // Pricing & Break-even
  double _adminDefaultPrice = 0.0;
  final TextEditingController _negotiatingPriceController = TextEditingController();
  double _negotiatingPrice = 0.0;

  // Layer specific
  int _totalEggsCollected = 0;

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
          .select('id, batch_name, production_type, start_date, initial_birds, status')
          .eq('status', 'active')
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

      // 2. Mortality from Daily Records / Layer Logs
      final isLayer = (batchRes['production_type'] ?? '')
          .toString()
          .toLowerCase()
          .contains('egg');

      int mort = 0;
      int eggs = 0;

      if (isLayer) {
        final logsRes = await _supabase
            .from('layer_daily_logs')
            .select('mortality_culling, total_eggs')
            .eq('batch_id', batchId);
        for (var row in logsRes) {
          mort += (row['mortality_culling'] as num?)?.toInt() ?? 0;
          eggs += (row['total_eggs'] as num?)?.toInt() ?? 0;
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
      _currentBirds = (_initialBirds - _totalMortality).clamp(0, 9999999);

      // 3. Latest Average Weight
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

      // 4. Total Expenses (Purchases + Chick price)
      final expRes = await _supabase
          .from('expenses')
          .select('amount')
          .eq('batch_id', batchId);

      double sumExp = 0.0;
      for (var row in expRes) {
        sumExp += (row['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Add chick initial cost if present
      final chickPrice = (batchRes['chick_price'] as num?)?.toDouble() ?? 0.0;
      if (chickPrice > 0 && _initialBirds > 0) {
        sumExp += (chickPrice * _initialBirds);
      }
      _totalExpenses = sumExp;

      // 5. Fetch Admin Default Market Price
      final marketRes = await _supabase
          .from('market_prices')
          .select('price_per_unit, item_name')
          .order('price_date', ascending: false)
          .limit(10);

      double foundPrice = isLayer ? 12.0 : 210.0; // fallback default
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
      _negotiatingPriceController.text = foundPrice.toStringAsFixed(0);

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
    final currencyFormat = NumberFormat('#,##0.0', 'en_US');

    final isLayer = (_selectedBatch?['production_type'] ?? '')
        .toString()
        .toLowerCase()
        .contains('egg');

    // Meat / Broiler Metrics
    final double totalLiveWeightKg = _currentBirds * _latestAvgWeightKg;
    final double breakEvenPerKg = totalLiveWeightKg > 0
        ? (_totalExpenses / totalLiveWeightKg)
        : 0.0;
    final double standingValuation = totalLiveWeightKg * _negotiatingPrice;
    final double runningProfitLoss = standingValuation - _totalExpenses;

    // Layer Metrics
    final double breakEvenPerEgg = _totalEggsCollected > 0
        ? (_totalExpenses / _totalEggsCollected)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI & Batch Advisor'),
        centerTitle: true,
        actions: [
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
                      // Batch Selection Header
                      _buildBatchSelectorCard(),
                      const SizedBox(height: 16),

                      // Real-time Actuals Bento Grid
                      _buildActualsGrid(isLayer, totalLiveWeightKg),
                      const SizedBox(height: 16),

                      // Break-Even & Valuation Card
                      _buildBreakEvenAndValuationCard(
                        isLayer: isLayer,
                        breakEvenPerKg: breakEvenPerKg,
                        breakEvenPerEgg: breakEvenPerEgg,
                        runningProfitLoss: runningProfitLoss,
                        currencyFormat: currencyFormat,
                      ),
                      const SizedBox(height: 16),

                      // Real-Time DB Management Advice Card
                      _buildManagementAdviceCard(
                        isLayer: isLayer,
                        breakEvenPerKg: breakEvenPerKg,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBatchSelectorCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Colors.teal),
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
                        '${b['batch_name']} (${b['production_type'] ?? 'General'})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildActualsGrid(bool isLayer, double totalLiveWeightKg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Real-time Farm Actuals',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Live Flock',
                value: '$_currentBirds / $_initialBirds',
                sub: 'Mortality: $_totalMortality birds',
                icon: Icons.pets,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: isLayer ? 'Total Eggs' : 'Avg Weight',
                value: isLayer
                    ? '$_totalEggsCollected pcs'
                    : '${_latestAvgWeightKg.toStringAsFixed(2)} kg',
                sub: isLayer
                    ? 'Actual Collected'
                    : (_latestWeightDate != null
                        ? DateFormat('dd MMM').format(_latestWeightDate!)
                        : 'No weight logged'),
                icon: isLayer ? Icons.egg_outlined : Icons.scale_outlined,
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
                title: 'Total Expenses',
                value: '৳ ${NumberFormat('#,##0').format(_totalExpenses)}',
                sub: 'Feed, Meds & Chicks',
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: isLayer ? 'Flock Health' : 'Standing Biomass',
                value: isLayer
                    ? '${((_currentBirds / (_initialBirds > 0 ? _initialBirds : 1)) * 100).toStringAsFixed(1)}%'
                    : '${totalLiveWeightKg.toStringAsFixed(0)} kg',
                sub: isLayer ? 'Survival Rate' : 'Total live weight',
                icon: isLayer ? Icons.health_and_safety : Icons.fitness_center,
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
          ),
        ],
      ),
    );
  }

  Widget _buildBreakEvenAndValuationCard({
    required bool isLayer,
    required double breakEvenPerKg,
    required double breakEvenPerEgg,
    required double runningProfitLoss,
    required NumberFormat currencyFormat,
  }) {
    final bool isProfit = runningProfitLoss >= 0;

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
                Text(
                  isLayer ? 'Egg Break-Even & Financials' : 'Bird Break-Even & Running Valuation',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),

            // Break-Even metric
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isLayer ? 'Break-Even Cost / Egg:' : 'Break-Even Cost / Kg:',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  isLayer
                      ? '৳ ${breakEvenPerEgg.toStringAsFixed(2)} / pc'
                      : '৳ ${breakEvenPerKg.toStringAsFixed(2)} / kg',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Minimum selling price needed to recover all recorded expenses.',
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
                      Text(
                        isLayer ? 'Negotiating Price (৳/egg)' : 'Negotiating Price (৳/kg):',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Admin Rate: ৳ ${_adminDefaultPrice.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _negotiatingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: '৳ ',
                      hintText: 'Enter buyer offered price',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      fillColor: Colors.white,
                      filled: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.restore, size: 18),
                        tooltip: 'Reset to Admin Rate',
                        onPressed: () {
                          setState(() {
                            _negotiatingPrice = _adminDefaultPrice;
                            _negotiatingPriceController.text = _adminDefaultPrice.toStringAsFixed(0);
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

            // Running Profit / Loss Status Card
            if (!isLayer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isProfit ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isProfit ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isProfit ? 'Estimated Net Surplus' : 'Estimated Net Deficit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isProfit ? Colors.green.shade900 : Colors.red.shade900,
                          ),
                        ),
                        Text(
                          'If sold today at ৳ ${_negotiatingPrice.toStringAsFixed(0)}/kg',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    Text(
                      '${isProfit ? '+' : ''}৳ ${currencyFormat.format(runningProfitLoss)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isProfit ? Colors.green.shade800 : Colors.red.shade800,
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

  Widget _buildManagementAdviceCard({
    required bool isLayer,
    required double breakEvenPerKg,
  }) {
    // Real-time actual based rule generation
    final List<String> adviceList = [];

    // 1. Mortality check
    final double mortRate = _initialBirds > 0 ? (_totalMortality / _initialBirds) * 100 : 0.0;
    if (mortRate > 4.0) {
      adviceList.add('🚨 High Cumulative Mortality (${mortRate.toStringAsFixed(1)}%): Inspect biosecurity, water sanitation, and post-mortem symptoms immediately.');
    } else {
      adviceList.add('✅ Flock Livability is stable (${(100 - mortRate).toStringAsFixed(1)}%). Maintain standard vaccination and litter dry conditions.');
    }

    // 2. Weight / Production check
    if (!isLayer) {
      if (_latestAvgWeightKg == 0.0) {
        adviceList.add('⚖️ No weight record found recently. Log weight in "Average Weight" screen to get precise standing valuation.');
      } else if (_negotiatingPrice > 0 && _negotiatingPrice < breakEvenPerKg) {
        final gap = (breakEvenPerKg - _negotiatingPrice).toStringAsFixed(1);
        adviceList.add('⚠️ Price Alert: Current negotiating price is ৳ $gap/kg below break-even! Consider holding or negotiating closer to ৳ ${breakEvenPerKg.toStringAsFixed(0)}/kg.');
      } else {
        adviceList.add('📈 Commercial Weight on track. Align feed withdrawal timing before final bird harvesting.');
      }
    } else {
      if (_totalEggsCollected == 0) {
        adviceList.add('🥚 No egg logs recorded yet. Use "Layer Performance" to track daily production and Hen-Day % (HDP).');
      } else {
        adviceList.add('💡 Layer Care: Ensure adequate calcium grit supplementation during afternoon feeding to maintain shell thickness.');
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Batch Management Advice (Actuals)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
