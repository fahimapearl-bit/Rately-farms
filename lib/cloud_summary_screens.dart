import 'package:flutter/material.dart';

import 'models.dart' as cloud;
import 'supabase_repository.dart';

class _SummaryData {
  final List<cloud.Batch> batches;
  final List<cloud.DailyRecord> records;
  final List<cloud.Expense> expenses;
  final List<cloud.Sale> sales;
  final List<cloud.WeeklyWeight> weights;

  const _SummaryData({
    required this.batches,
    required this.records,
    required this.expenses,
    required this.sales,
    required this.weights,
  });
}

Future<_SummaryData> _loadSummaryData() async {
  final repo = SupabaseRepository();
  final results = await Future.wait([
    repo.getBatches(),
    repo.getDailyRecords(),
    repo.getExpenses(),
    repo.getSales(),
    repo.getWeeklyWeights(),
  ]);
  return _SummaryData(
    batches: results[0] as List<cloud.Batch>,
    records: results[1] as List<cloud.DailyRecord>,
    expenses: results[2] as List<cloud.Expense>,
    sales: results[3] as List<cloud.Sale>,
    weights: results[4] as List<cloud.WeeklyWeight>,
  );
}

String _date(DateTime value) => value.toLocal().toIso8601String().split('T').first;
String _money(double value) => '${value.toStringAsFixed(2)} tk';

Widget _summaryRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label)),
        const SizedBox(width: 12),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

int _runningDays(DateTime startDate) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final today = DateTime.now();
  final end = DateTime(today.year, today.month, today.day);
  if (end.isBefore(start)) return 0;
  return end.difference(start).inDays + 1;
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 42),
            const SizedBox(height: 12),
            Text('Summary load হয়নি: $message', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Bento KPI Card Widget
// -------------------------------------------------------------
class _BentoKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  const _BentoKpiCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subtitle!,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: iconColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 1. Cloud Date Range Summary Page (Bento KPI Grid Layout)
// -------------------------------------------------------------
class CloudDateRangeSummaryPage extends StatefulWidget {
  const CloudDateRangeSummaryPage({super.key});

  @override
  State<CloudDateRangeSummaryPage> createState() => _CloudDateRangeSummaryPageState();
}

class _CloudDateRangeSummaryPageState extends State<CloudDateRangeSummaryPage> {
  DateTime fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime toDate = DateTime.now();
  _SummaryData? data;
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await _loadSummaryData();
      if (!mounted) return;
      setState(() {
        data = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  void _setToday() {
    final now = DateTime.now();
    setState(() {
      fromDate = DateTime(now.year, now.month, now.day);
      toDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _setThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      fromDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      toDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _setThisMonth() {
    final now = DateTime.now();
    setState(() {
      fromDate = DateTime(now.year, now.month, 1);
      toDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _setLast30Days() {
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 30));
    setState(() {
      fromDate = DateTime(past.year, past.month, past.day);
      toDate = DateTime(now.year, now.month, now.day);
    });
  }

  Future<void> pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        fromDate = picked;
        if (toDate.isBefore(fromDate)) toDate = fromDate;
      });
    }
  }

  Future<void> pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: toDate,
      firstDate: fromDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => toDate = picked);
  }

  bool inRange(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final end = DateTime(toDate.year, toDate.month, toDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    final current = data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Date Range Summary (Cloud)'),
        actions: [
          IconButton(
            onPressed: loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _ErrorView(message: '$error', onRetry: loadData)
              : current == null
                  ? const Center(child: Text('কোনো data পাওয়া যায়নি'))
                  : _buildBody(current),
    );
  }

  Widget _buildBody(_SummaryData current) {
    final records = current.records.where((item) => inRange(item.date)).toList();
    final expenses = current.expenses.where((item) => inRange(item.date)).toList();
    final sales = current.sales.where((item) => inRange(item.date)).toList();

    // Production KPIs
    final feed = records.fold(0.0, (sum, item) => sum + item.feedKg);
    final water = records.fold(0.0, (sum, item) => sum + item.waterLitre);
    final eggs = records.fold(0, (sum, item) => sum + item.eggsCollected);
    final mortality = records.fold(0, (sum, item) => sum + item.mortality);

    // Cash Flow KPIs
    final income = sales.fold(0.0, (sum, item) => sum + item.totalAmount);
    final expense = expenses.fold(0.0, (sum, item) => sum + item.amount);
    final cashFlow = income - expense;

    final birdIncome = sales
        .where((item) => item.type == 'Bird')
        .fold(0.0, (sum, item) => sum + item.totalAmount);
    final tableEggIncome = sales
        .where((item) => item.type == 'Table Eggs')
        .fold(0.0, (sum, item) => sum + item.totalAmount);
    final hatchingEggIncome = sales
        .where((item) => item.type == 'Hatching Eggs')
        .fold(0.0, (sum, item) => sum + item.totalAmount);
    final litterIncome = sales
        .where((item) => item.type == 'Litter')
        .fold(0.0, (sum, item) => sum + item.totalAmount);

    final durationDays = toDate.difference(fromDate).inDays + 1;

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -------------------------------------------------------------
          // 1. Date Range Picker Card with Quick Chips
          // -------------------------------------------------------------
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 20, color: Colors.green.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'Select Date Range',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          '$durationDays Days',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Quick Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _quickChip('This Month', _setThisMonth),
                        const SizedBox(width: 6),
                        _quickChip('This Week', _setThisWeek),
                        const SizedBox(width: 6),
                        _quickChip('Last 30 Days', _setLast30Days),
                        const SizedBox(width: 6),
                        _quickChip('Today', _setToday),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Date Picker Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickFromDate,
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(_date(fromDate), style: const TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickToDate,
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(_date(toDate), style: const TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // -------------------------------------------------------------
          // 2. Production Snapshot (Bento KPI Grid)
          // -------------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Production Snapshot',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${records.length} logs recorded',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2x2 Bento Grid
          Row(
            children: [
              Expanded(
                child: _BentoKpiCard(
                  title: 'Feed Consumed',
                  value: '${feed.toStringAsFixed(1)} kg',
                  subtitle: 'Daily Feed',
                  icon: Icons.grain_outlined,
                  iconColor: Colors.amber.shade800,
                  bgColor: const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoKpiCard(
                  title: 'Water Given',
                  value: '${water.toStringAsFixed(1)} L',
                  subtitle: 'Intake',
                  icon: Icons.water_drop_outlined,
                  iconColor: Colors.blue.shade700,
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BentoKpiCard(
                  title: 'Eggs Collected',
                  value: '$eggs pcs',
                  subtitle: 'Production',
                  icon: Icons.egg_outlined,
                  iconColor: Colors.purple.shade700,
                  bgColor: const Color(0xFFFAF5FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoKpiCard(
                  title: 'Mortality',
                  value: '$mortality birds',
                  subtitle: 'Loss',
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.red.shade700,
                  bgColor: const Color(0xFFFEF2F2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // -------------------------------------------------------------
          // 3. Cash Flow Overview (Bento Financial Snapshot)
          // -------------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cash Flow Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'Cash basis',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Sales & Expenses Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.point_of_sale_outlined, color: Colors.green.shade800, size: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Inflow',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Total Sales', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _money(income),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${sales.length} transactions', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.receipt_long_outlined, color: Colors.orange.shade800, size: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Outflow',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Total Expenses', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _money(expense),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${expenses.length} entries', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Net Cash Flow Card (Surplus / Deficit without misleading Net Profit)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cashFlow >= 0 ? const Color(0xFFF7FEE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cashFlow >= 0 ? Colors.lightGreen.shade300 : Colors.amber.shade300,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cashFlow >= 0 ? Colors.lightGreen.shade100 : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    cashFlow >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: cashFlow >= 0 ? Colors.green.shade800 : Colors.amber.shade900,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cashFlow >= 0 ? 'Net Cash Surplus' : 'Net Cash Deficit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cashFlow >= 0 ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cashFlow >= 0 ? '+ ${_money(cashFlow)}' : '- ${_money(cashFlow.abs())}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cashFlow >= 0 ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Excludes unsold birds valuation. Cash receipts minus payments.',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Sales Breakdown List Tile Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue Sources Breakdown',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 6),
                  _summaryRow('Bird Sales', _money(birdIncome)),
                  _summaryRow('Table Egg Sales', _money(tableEggIncome)),
                  _summaryRow('Hatching Egg Sales', _money(hatchingEggIncome)),
                  _summaryRow('Poultry Litter Sales', _money(litterIncome)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // -------------------------------------------------------------
          // 4. Batch-wise Breakdown Table
          // -------------------------------------------------------------
          _DateRangeBatchTable(
            batches: current.batches,
            records: records,
            expenses: expenses,
            sales: sales,
            fromDate: fromDate,
            toDate: toDate,
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: onTap,
    );
  }
}

// -------------------------------------------------------------
// Batch-wise Table for Selected Date Range
// -------------------------------------------------------------
class _DateRangeBatchTable extends StatelessWidget {
  final List<cloud.Batch> batches;
  final List<cloud.DailyRecord> records;
  final List<cloud.Expense> expenses;
  final List<cloud.Sale> sales;
  final DateTime fromDate;
  final DateTime toDate;

  const _DateRangeBatchTable({
    required this.batches,
    required this.records,
    required this.expenses,
    required this.sales,
    required this.fromDate,
    required this.toDate,
  });

  @override
  Widget build(BuildContext context) {
    final rows = batches.map((batch) {
      final batchRecords = records.where((item) => item.batchId == batch.id);
      final batchExpenses = expenses.where((item) => item.batchId == batch.id);
      final batchSales = sales.where((item) => item.batchId == batch.id);

      final feed = batchRecords.fold(0.0, (sum, item) => sum + item.feedKg);
      final water = batchRecords.fold(0.0, (sum, item) => sum + item.waterLitre);
      final mortality = batchRecords.fold(0, (sum, item) => sum + item.mortality);
      final eggs = batchRecords.fold(0, (sum, item) => sum + item.eggsCollected);
      final income = batchSales.fold(0.0, (sum, item) => sum + item.totalAmount);
      final expense = batchExpenses.fold(0.0, (sum, item) => sum + item.amount);
      final cashFlow = income - expense;

      return DataRow(cells: [
        DataCell(Text(batch.name, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text('${batchRecords.length}')),
        DataCell(Text(feed.toStringAsFixed(1))),
        DataCell(Text(water.toStringAsFixed(1))),
        DataCell(Text('$mortality')),
        DataCell(Text('$eggs')),
        DataCell(Text(_money(income))),
        DataCell(Text(_money(expense))),
        DataCell(
          Text(
            _money(cashFlow),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cashFlow >= 0 ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ),
      ]);
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Batches · Selected Date Range',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Activity recorded between ${_date(fromDate)} and ${_date(toDate)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('এই সময়সীমায় কোনো batch data পাওয়া যায়নি'),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStatePropertyAll<Color?>(Colors.green.shade50),
                  dataRowMinHeight: 38,
                  dataRowMaxHeight: 44,
                  columns: const [
                    DataColumn(label: Text('Batch')),
                    DataColumn(label: Text('Records')),
                    DataColumn(label: Text('Feed (kg)')),
                    DataColumn(label: Text('Water (L)')),
                    DataColumn(label: Text('Mortality')),
                    DataColumn(label: Text('Eggs')),
                    DataColumn(label: Text('Sales')),
                    DataColumn(label: Text('Expense')),
                    DataColumn(label: Text('Cash Flow')),
                  ],
                  rows: rows,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. Cloud Batch Summary Page (Batch-wise Detail View)
// -------------------------------------------------------------
class CloudBatchSummaryPage extends StatefulWidget {
  const CloudBatchSummaryPage({super.key});

  @override
  State<CloudBatchSummaryPage> createState() => _CloudBatchSummaryPageState();
}

class _CloudBatchSummaryPageState extends State<CloudBatchSummaryPage> {
  _SummaryData? data;
  String? selectedBatchId;
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await _loadSummaryData();
      if (!mounted) return;
      setState(() {
        data = result;
        if (selectedBatchId == null || !result.batches.any((item) => item.id == selectedBatchId)) {
          selectedBatchId = result.batches.isEmpty ? null : result.batches.first.id;
        }
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _batchBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = data;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Batch-wise Summary'),
        actions: [
          IconButton(
            onPressed: loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _ErrorView(message: '$error', onRetry: loadData)
              : current == null || current.batches.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'কোনো ব্যাচ পাওয়া যায়নি',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text('সঠিক সামারি দেখতে আগে একটি ব্যাচ তৈরি করুন।'),
                          ],
                        ),
                      ),
                    )
                  : _buildBody(current),
    );
  }

  Widget _buildBody(_SummaryData current) {
    final batch = current.batches.firstWhere((item) => item.id == selectedBatchId);
    final records = current.records.where((item) => item.batchId == batch.id).toList();
    final expenses = current.expenses.where((item) => item.batchId == batch.id).toList();
    final sales = current.sales.where((item) => item.batchId == batch.id).toList();
    final weights = current.weights.where((item) => item.batchId == batch.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final feed = records.fold(0.0, (sum, item) => sum + item.feedKg);
    final water = records.fold(0.0, (sum, item) => sum + item.waterLitre);
    final eggs = records.fold(0, (sum, item) => sum + item.eggsCollected);
    final mortality = records.fold(0, (sum, item) => sum + item.mortality);
    final income = sales.fold(0.0, (sum, item) => sum + item.totalAmount);
    final expense = expenses.fold(0.0, (sum, item) => sum + item.amount);
    final avgWeight = weights.isEmpty ? 0.0 : weights.first.averageWeightKg;

    final birdsSold = sales.where((s) => s.type == 'Bird').fold(0, (sum, s) => sum + s.quantity);
    final currentBirds = (batch.initialBirds - mortality - birdsSold).clamp(0, batch.initialBirds);
    final netCash = income - expense;
    final isSurplus = netCash >= 0;

    final survivalPct = batch.initialBirds > 0 ? (currentBirds / batch.initialBirds) * 100 : 0.0;
    final mortalityPct = batch.initialBirds > 0 ? (mortality / batch.initialBirds) * 100 : 0.0;
    final soldPct = batch.initialBirds > 0 ? (birdsSold / batch.initialBirds) * 100 : 0.0;

    // Group expenses by type
    final Map<String, double> expenseByType = {};
    for (final exp in expenses) {
      final key = exp.type.isEmpty ? 'General' : exp.type;
      expenseByType[key] = (expenseByType[key] ?? 0.0) + exp.amount;
    }

    // Standing biomass calculation
    final standingBiomassKg = currentBirds > 0 && avgWeight > 0 ? currentBirds * avgWeight : 0.0;

    // FCR estimation if broiler / meat
    final isEggType = batch.productionType.toLowerCase().contains('egg');
    final double? fcr = (!isEggType && avgWeight > 0 && currentBirds > 0 && feed > 0)
        ? (feed / ((currentBirds * avgWeight) + (birdsSold * (avgWeight > 0 ? avgWeight : 1.5))))
        : null;

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Batch Selector & Metadata Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedBatchId,
                  decoration: InputDecoration(
                    labelText: 'Select Batch',
                    prefixIcon: const Icon(Icons.layers_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: current.batches
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.name} (${item.breed})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedBatchId = value),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _batchBadge(
                      '${batch.productionType} • ${batch.productionCategory.isEmpty ? "General" : batch.productionCategory}',
                      Colors.teal.shade700,
                    ),
                    _batchBadge(
                      batch.breed.isEmpty ? 'Mixed Breed' : batch.breed,
                      Colors.indigo.shade700,
                    ),
                    _batchBadge(
                      '${_runningDays(batch.startDate)} Days Running',
                      Colors.orange.shade800,
                    ),
                    _batchBadge(
                      'Start: ${_date(batch.startDate)}',
                      Colors.blueGrey.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Flock Dynamics (Bento KPI 2x2)
          _buildSectionHeader('Flock Dynamics (পাখির স্থিতি)', Icons.pets, Colors.teal),
          Row(
            children: [
              Expanded(
                child: _BentoKpiCard(
                  title: 'Current Live Birds',
                  value: '$currentBirds',
                  subtitle: '${survivalPct.toStringAsFixed(1)}% alive',
                  icon: Icons.favorite,
                  iconColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoKpiCard(
                  title: 'Initial Birds',
                  value: '${batch.initialBirds}',
                  subtitle: 'Start flock',
                  icon: Icons.inventory_2_outlined,
                  iconColor: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BentoKpiCard(
                  title: 'Mortality',
                  value: '$mortality',
                  subtitle: '${mortalityPct.toStringAsFixed(1)}% loss',
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.red.shade700,
                  bgColor: Colors.red.shade50,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoKpiCard(
                  title: 'Birds Sold',
                  value: '$birdsSold',
                  subtitle: '${soldPct.toStringAsFixed(1)}% sold',
                  icon: Icons.shopping_cart_checkout,
                  iconColor: Colors.purple.shade700,
                  bgColor: Colors.purple.shade50,
                ),
              ),
            ],
          ),

          // 3. Feed & Production Bento Grid (2x2)
          _buildSectionHeader('Feed & Production (খাদ্য ও ওজন)', Icons.restaurant, Colors.amber.shade800),
          Row(
            children: [
              Expanded(
                child: _BentoKpiCard(
                  title: 'Total Feed',
                  value: '${feed.toStringAsFixed(1)} kg',
                  subtitle: batch.initialBirds > 0
                      ? '${(feed / batch.initialBirds).toStringAsFixed(2)} kg/bird'
                      : null,
                  icon: Icons.grain,
                  iconColor: Colors.amber.shade800,
                  bgColor: Colors.amber.shade50,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoKpiCard(
                  title: 'Total Water',
                  value: '${water.toStringAsFixed(0)} L',
                  subtitle: feed > 0 ? '${(water / feed).toStringAsFixed(1)} L/kg feed' : null,
                  icon: Icons.water_drop,
                  iconColor: Colors.cyan.shade700,
                  bgColor: Colors.cyan.shade50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BentoKpiCard(
                  title: 'Avg Weight',
                  value: avgWeight > 0 ? '${avgWeight.toStringAsFixed(2)} kg' : 'N/A',
                  subtitle: fcr != null && fcr > 0 && fcr < 10
                      ? 'Est. FCR: ${fcr.toStringAsFixed(2)}'
                      : weights.isNotEmpty
                          ? '${weights.length} weigh-ins'
                          : 'No weigh-ins',
                  icon: Icons.scale,
                  iconColor: Colors.indigo.shade700,
                  bgColor: Colors.indigo.shade50,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isEggType
                    ? _BentoKpiCard(
                        title: 'Eggs Collected',
                        value: '$eggs',
                        subtitle: '${records.length} logs',
                        icon: Icons.egg_outlined,
                        iconColor: Colors.orange.shade800,
                        bgColor: Colors.orange.shade50,
                      )
                    : _BentoKpiCard(
                        title: 'Daily Logs',
                        value: '${records.length}',
                        subtitle: 'Log entries',
                        icon: Icons.assignment_turned_in_outlined,
                        iconColor: Colors.teal.shade700,
                        bgColor: Colors.teal.shade50,
                      ),
              ),
            ],
          ),

          // 4. Financial Snapshot & Standing Flock Asset
          _buildSectionHeader('Financial Snapshot (আর্থিক স্থিতি)', Icons.account_balance_wallet, Colors.green.shade800),
          Row(
            children: [
              Expanded(
                child: _BentoKpiCard(
                  title: 'Total Sales',
                  value: _money(income),
                  subtitle: '${sales.length} invoices',
                  icon: Icons.trending_up,
                  iconColor: Colors.green.shade700,
                  bgColor: Colors.green.shade50,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BentoKpiCard(
                  title: 'Total Expenses',
                  value: _money(expense),
                  subtitle: '${expenses.length} entries',
                  icon: Icons.trending_down,
                  iconColor: Colors.red.shade700,
                  bgColor: Colors.red.shade50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Cash Flow & Standing Asset Banner Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSurplus ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSurplus ? Colors.green.shade300 : Colors.amber.shade300,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSurplus ? 'Net Cash Surplus' : 'Net Cash Deficit (Investment)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSurplus ? Colors.green.shade800 : Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${isSurplus ? "+" : ""}${_money(netCash)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSurplus ? Colors.green.shade900 : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSurplus
                            ? Colors.green.withOpacity(0.15)
                            : Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSurplus ? Icons.check_circle_outline : Icons.schedule,
                        color: isSurplus ? Colors.green.shade800 : Colors.amber.shade900,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                if (standingBiomassKg > 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                      color: (isSurplus ? Colors.green : Colors.amber).shade200,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.inventory_2, size: 16, color: Colors.blueGrey.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Standing Flock Asset: $currentBirds birds (~${standingBiomassKg.toStringAsFixed(1)} kg live biomass on farm)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 5. Expense Breakdown by Category
          if (expenseByType.isNotEmpty) ...[
            _buildSectionHeader('Expense by Category (খরচ বিভাজন)', Icons.pie_chart_outline, Colors.blueGrey),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: expenseByType.entries.map((entry) {
                  final pct = expense > 0 ? (entry.value / expense) * 100 : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${pct.toStringAsFixed(1)}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _money(entry.value),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // 6. Sales Breakdown DataTable
          _buildSectionHeader('Sales Invoices (বিক্রয় বিবরণী)', Icons.receipt_long, Colors.blue),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: sales.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'এই ব্যাচে এখনো কোনো সেল রেকর্ড নেই',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowHeight: 46,
                      headingRowColor: MaterialStatePropertyAll<Color?>(Colors.blue.shade50),
                      columns: const [
                        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Qty / Weight', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: sales.map((item) {
                        final qtyOrWt = item.type == 'Bird' && item.weightKg != null
                            ? '${item.quantity} pcs (${item.weightKg!.toStringAsFixed(1)} kg)'
                            : '${item.quantity}';
                        final rate = '${item.unitPrice.toStringAsFixed(1)} tk';
                        return DataRow(cells: [
                          DataCell(Text(_date(item.date), style: const TextStyle(fontSize: 12))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(item.type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          )),
                          DataCell(Text(qtyOrWt, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(rate, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_money(item.totalAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
