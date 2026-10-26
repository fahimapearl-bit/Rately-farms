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
          IconButton(onPressed: loadData, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: pickFromDate, icon: const Icon(Icons.date_range)),
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
    final feed = records.fold(0.0, (sum, item) => sum + item.feedKg);
    final water = records.fold(0.0, (sum, item) => sum + item.waterLitre);
    final eggs = records.fold(0, (sum, item) => sum + item.eggsCollected);
    final mortality = records.fold(0, (sum, item) => sum + item.mortality);
    final income = sales.fold(0.0, (sum, item) => sum + item.totalAmount);
    final expense = expenses.fold(0.0, (sum, item) => sum + item.amount);
    final birdIncome = sales
        .where((item) => item.type == 'Bird')
        .fold(0.0, (sum, item) => sum + item.totalAmount);
    final tableEggIncome = sales
        .where((item) => item.type == 'Table Eggs')
        .fold(0.0, (sum, item) => sum + item.totalAmount);
    final hatchingEggIncome = sales
        .where((item) => item.type == 'Hatching Eggs')
        .fold(0.0, (sum, item) => sum + item.totalAmount);

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Report: ${_date(fromDate)} to ${_date(toDate)}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickFromDate,
                          icon: const Icon(Icons.event),
                          label: Text('From: ${_date(fromDate)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickToDate,
                          icon: const Icon(Icons.event),
                          label: Text('To: ${_date(toDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _summaryRow('Daily records', '${records.length}'),
                  _summaryRow('Total feed', '${feed.toStringAsFixed(2)} kg'),
                  _summaryRow('Total water', '${water.toStringAsFixed(2)} L'),
                  _summaryRow('Eggs collected', '$eggs'),
                  _summaryRow('Mortality', '$mortality'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Financial Summary', style: Theme.of(context).textTheme.titleMedium),
                  _summaryRow('Bird sales', _money(birdIncome)),
                  _summaryRow('Table egg sales', _money(tableEggIncome)),
                  _summaryRow('Hatching egg sales', _money(hatchingEggIncome)),
                  _summaryRow('Total sales', _money(income)),
                  _summaryRow('Total expense', _money(expense)),
                  const Divider(),
                  _summaryRow(income - expense >= 0 ? 'Net profit' : 'Net loss',
                      _money((income - expense).abs())),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DateRangeBatchTable(
            batches: current.batches,
            records: records,
            expenses: expenses,
            sales: sales,
          ),
        ],
      ),
    );
  }
}

class _DateRangeBatchTable extends StatelessWidget {
  final List<cloud.Batch> batches;
  final List<cloud.DailyRecord> records;
  final List<cloud.Expense> expenses;
  final List<cloud.Sale> sales;

  const _DateRangeBatchTable({required this.batches, required this.records, required this.expenses, required this.sales});

  @override
  Widget build(BuildContext context) {
    final rows = batches.map((batch) {
      final batchRecords = records.where((item) => item.batchId == batch.id);
      final batchExpenses = expenses.where((item) => item.batchId == batch.id);
      final batchSales = sales.where((item) => item.batchId == batch.id);
      final feed = batchRecords.fold(0.0, (sum, item) => sum + item.feedKg);
      final eggs = batchRecords.fold(0, (sum, item) => sum + item.eggsCollected);
      final income = batchSales.fold(0.0, (sum, item) => sum + item.totalAmount);
      final expense = batchExpenses.fold(0.0, (sum, item) => sum + item.amount);
      return DataRow(cells: [
        DataCell(Text(batch.name)),
        DataCell(Text('${batchRecords.length}')),
        DataCell(Text(feed.toStringAsFixed(2))),
        DataCell(Text('$eggs')),
        DataCell(Text(_money(income))),
        DataCell(Text(_money(expense))),
        DataCell(Text(_money(income - expense))),
      ]);
    }).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Batch-wise breakdown for selected dates', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (rows.isEmpty) const Text('এই মাসে কোনো batch data নেই') else SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStatePropertyAll<Color?>(Colors.green.shade100),
              columns: const [
                DataColumn(label: Text('Batch')),
                DataColumn(label: Text('Records')),
                DataColumn(label: Text('Feed kg')),
                DataColumn(label: Text('Eggs')),
                DataColumn(label: Text('Sales')),
                DataColumn(label: Text('Expense')),
                DataColumn(label: Text('Profit/Loss')),
              ],
              rows: rows,
            ),
          ),
        ]),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final current = data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch-wise Summary (Cloud)'),
        actions: [IconButton(onPressed: loadData, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _ErrorView(message: '$error', onRetry: loadData)
              : current == null || current.batches.isEmpty
                  ? const Center(child: Text('আগে একটি Batch তৈরি করুন'))
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
    final currentBirds = (batch.initialBirds - mortality).clamp(0, batch.initialBirds);

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: selectedBatchId,
            decoration: const InputDecoration(labelText: 'Select batch', border: OutlineInputBorder()),
            items: current.batches.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.name} (${item.breed})'))).toList(),
            onChanged: (value) => setState(() => selectedBatchId = value),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Align(alignment: Alignment.centerLeft, child: Text(batch.name, style: Theme.of(context).textTheme.titleLarge)),
                _summaryRow('Production', '${batch.productionType} / ${batch.productionCategory}'),
                _summaryRow('Start date', _date(batch.startDate)),
                _summaryRow('Batch running days', '${_runningDays(batch.startDate)} days'),
                _summaryRow('Initial birds', '${batch.initialBirds}'),
                _summaryRow('Current birds', '$currentBirds'),
                _summaryRow('Mortality', '$mortality'),
                _summaryRow('Daily records', '${records.length}'),
                _summaryRow('Total feed', '${feed.toStringAsFixed(2)} kg'),
                _summaryRow('Total water', '${water.toStringAsFixed(2)} L'),
                _summaryRow('Eggs collected', '$eggs'),
                _summaryRow('Latest average weight', '${avgWeight.toStringAsFixed(2)} kg'),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('Financial Summary', style: Theme.of(context).textTheme.titleMedium),
                _summaryRow('Sales', _money(income)),
                _summaryRow('Expenses', _money(expense)),
                const Divider(),
                _summaryRow(income - expense >= 0 ? 'Net profit' : 'Net loss', _money((income - expense).abs())),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sales breakdown', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStatePropertyAll<Color?>(Colors.blue.shade100),
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Amount')),
                    ],
                    rows: sales.map((item) => DataRow(cells: [
                      DataCell(Text(_date(item.date))),
                      DataCell(Text(item.type)),
                      DataCell(Text('${item.quantity}')),
                      DataCell(Text(_money(item.totalAmount))),
                    ])).toList(),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 42),
          const SizedBox(height: 12),
          Text('Summary load হয়নি: $message', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]),
      ),
    );
  }
}
