import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'management_screens.dart';
import 'auth_page.dart';
import 'supabase_config.dart';
import 'supabase_repository.dart';
import 'models.dart' as cloud_models;
import 'sales_screen.dart';
import 'cloud_lists_screen.dart';
import 'supabase_error_handler.dart';
import 'cloud_summary_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const RatelyFarmsApp());
}

class RatelyFarmsApp extends StatelessWidget {
  const RatelyFarmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rately Farms',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const AuthGate(child: HomePage()),
    );
  }
}

class Batch {
  String id;
  String name;
  String category;
  String breed;
  String shed;
  DateTime startDate;
  int initialBirds;
  String status;

  Batch({
    required this.id,
    required this.name,
    required this.category,
    required this.breed,
    required this.shed,
    required this.startDate,
    required this.initialBirds,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'breed': breed,
        'shed': shed,
        'startDate': startDate.toIso8601String(),
        'initialBirds': initialBirds,
        'status': status,
      };

  factory Batch.fromJson(Map<String, dynamic> json) => Batch(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        breed: json['breed'],
        shed: json['shed'],
        startDate: DateTime.parse(json['startDate']),
        initialBirds: json['initialBirds'],
        status: json['status'],
      );
}

List<Batch> batches = [];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rately Farms'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => SupabaseConfig.client.auth.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => SupabaseConfig.client.auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddBatchPage()),
                ),
                icon: const Icon(Icons.add_business),
                label: const Text('Add Batch'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CloudBatchListScreen()),
                ),
                icon: const Icon(Icons.list),
                label: const Text('Batch List'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DailyRecordPage()),
                ),
                icon: const Icon(Icons.event_note),
                label: const Text('Daily Record'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SalesScreenV2()),
                ),
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Sales (Cloud)'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CloudDailyRecordsScreen()),
                ),
                icon: const Icon(Icons.fact_check),
                label: const Text('Daily Records List'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CloudDateRangeSummaryPage()),
                ),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Date Range Summary'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CloudBatchSummaryPage()),
                ),
                icon: const Icon(Icons.pie_chart),
                label: const Text('Batch-wise Summary'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ExpenseScreenV2()),
                ),
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Expenses'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const WeeklyWeightScreenV2()),
                ),
                icon: const Icon(Icons.monitor_weight),
                label: const Text('Weekly Average Weight'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MarketPriceScreenV2()),
                ),
                icon: const Icon(Icons.trending_up),
                label: const Text('Market Price'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BatchSummaryPage extends StatefulWidget {
  const BatchSummaryPage({super.key});

  @override
  State<BatchSummaryPage> createState() => _BatchSummaryPageState();
}

class _BatchSummaryPageState extends State<BatchSummaryPage> {
  List<WeeklyWeight> weeklyWeights = [];
  List<Expense> expenses = [];
  String? selectedBatchId;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatches = prefs.getStringList('batches') ?? [];
    final savedRecords = prefs.getStringList('dailyRecords') ?? [];
    final savedEggSales = prefs.getStringList('eggSales') ?? [];
    final savedBirdSales = prefs.getStringList('birdSales') ?? [];
    setState(() {
      batches = savedBatches
          .map((e) => Batch.fromJson(jsonDecode(e)))
          .toList();
      dailyRecords = savedRecords
          .map((e) => DailyRecord.fromJson(jsonDecode(e)))
          .toList();
      eggSales = savedEggSales
          .map((e) => EggSale.fromJson(jsonDecode(e)))
          .toList();
      birdSales = savedBirdSales
          .map((e) => BirdSale.fromJson(jsonDecode(e)))
          .toList();
      expenses = (prefs.getStringList('expenses') ?? [])
          .map((e) => Expense.fromJson(jsonDecode(e)))
          .toList();
      weeklyWeights = (prefs.getStringList('weeklyWeights') ?? [])
          .map((e) => WeeklyWeight.fromJson(jsonDecode(e)))
          .toList();
      if (batches.isNotEmpty && selectedBatchId == null) {
        selectedBatchId = batches.first.id;
      }
    });
  }

  List<DailyRecord> get batchRecords => dailyRecords
      .where((r) => r.batchId == selectedBatchId)
      .toList();

  List<EggSale> get batchEggSales =>
      eggSales.where((s) => s.batchId == selectedBatchId).toList();

  List<BirdSale> get batchBirdSales =>
      birdSales.where((s) => s.batchId == selectedBatchId).toList();

  double get totalFeed => batchRecords.fold(0, (sum, r) => sum + r.feed);
  double get totalWater => batchRecords.fold(0, (sum, r) => sum + r.water);
  int get totalEggs => batchRecords.fold(0, (sum, r) => sum + r.eggs);
  int get totalMortality =>
      batchRecords.fold(0, (sum, r) => sum + r.mortality);
  double get eggSaleTotal =>
      batchEggSales.fold(0, (sum, s) => sum + s.totalAmount);
  double get birdSaleTotal =>
      batchBirdSales.fold(0, (sum, s) => sum + s.totalAmount);

  double get latestAvgWeight {
    final weights = weeklyWeights
        .where((w) => w.batchId == selectedBatchId)
        .toList();
    if (weights.isEmpty) return 0;
    weights.sort((a, b) => b.date.compareTo(a.date));
    return weights.first.averageWeight;
  }

  double get estimatedLiveWeight => currentBirds * latestAvgWeight;

  List<Expense> get batchExpenses {
    if (selectedBatchId == null) return [];
    return expenses.where((e) => e.batchId == selectedBatchId).toList();
  }

  double get totalExpense =>
      batchExpenses.fold(0, (sum, e) => sum + e.amount);

  double get profitLoss =>
      (eggSaleTotal + birdSaleTotal) - totalExpense;

  Batch? get selectedBatch {
    for (final b in batches) {
      if (b.id == selectedBatchId) return b;
    }
    return null;
  }

  int get currentBirds {
    final b = selectedBatch;
    if (b == null) return 0;
    return b.initialBirds - totalMortality;
  }

  double? get fcr {
    final b = selectedBatch;
    if (b == null) return null;
    final soldWeight = batchBirdSales.fold(
        0.0, (sum, s) => sum + (s.totalWeightKg));
    double latestWeight = 0;
    final weights = weeklyWeights
        .where((w) => w.batchId == selectedBatchId)
        .toList();
    if (weights.isNotEmpty) {
      weights.sort((a, b) => b.date.compareTo(a.date));
      latestWeight = weights.first.averageWeight;
    }
    final liveWeight = currentBirds * latestWeight;
    final totalBirdWeight = soldWeight + liveWeight;
    if (totalBirdWeight <= 0) return null;
    return totalFeed / totalBirdWeight;
  }

  Widget summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = selectedBatch;

    return Scaffold(
      appBar: AppBar(title: const Text('Batch Summary')),
      body: batches.isEmpty
          ? const Center(child: Text('আগে একটি Batch তৈরি করুন'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedBatchId,
                    decoration: const InputDecoration(
                      labelText: 'Select Batch',
                      border: OutlineInputBorder(),
                    ),
                    items: batches
                        .map((batch) => DropdownMenuItem(
                              value: batch.id,
                              child: Text(
                                  '${batch.name} (${batch.category})'),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => selectedBatchId = v),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ExpenseEntryPage()),
                      ),
                      icon: const Icon(Icons.payments),
                      label: const Text('Add Expense'),
                    ),
                  ),
                  if (b != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.name,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                                'Category: ${b.category}Breed: ${b.breed}Shed: ${b.shed}Start Date: ${b.startDate.toLocal().toString().split(' ')[0]}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            summaryRow('Initial Birds',
                                b.initialBirds.toString()),
                            summaryRow('Total Mortality',
                                totalMortality.toString()),
                            summaryRow('Current Birds',
                                currentBirds.toString()),
                            summaryRow('Total Feed',
                                '${totalFeed.toStringAsFixed(2)} kg'),
                            summaryRow('Total Water',
                                '${totalWater.toStringAsFixed(2)} L'),
                            summaryRow('Total Eggs Collected',
                                totalEggs.toString()),
                            summaryRow('Latest Avg Weight',
                                '${latestAvgWeight.toStringAsFixed(2)} kg'),
                            summaryRow('Estimated Live Weight',
                                '${estimatedLiveWeight.toStringAsFixed(2)} kg'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            summaryRow('Egg Sale Total',
                                '${eggSaleTotal.toStringAsFixed(2)} tk'),
                            summaryRow('Bird Sale Total',
                                '${birdSaleTotal.toStringAsFixed(2)} tk'),
                            summaryRow('Total Sale Amount',
                                '${(eggSaleTotal + birdSaleTotal).toStringAsFixed(2)} tk'),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            summaryRow('Total Expense',
                                '${totalExpense.toStringAsFixed(2)} tk'),
                            summaryRow(
                              profitLoss >= 0 ? 'Net Profit' : 'Net Loss',
                              '${profitLoss.abs().toStringAsFixed(2)} tk',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            summaryRow(
                              'FCR',
                              fcr == null
                                  ? 'Not available'
                                  : fcr!.toStringAsFixed(2),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'FCR এখন শুধু sold birds-এর weight থাকলে দেখাবে।',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class DailyRecordsListPage extends StatefulWidget {
  const DailyRecordsListPage({super.key});

  @override
  State<DailyRecordsListPage> createState() => _DailyRecordsListPageState();
}

class _DailyRecordsListPageState extends State<DailyRecordsListPage> {
  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatches = prefs.getStringList('batches') ?? [];
    final savedRecords = prefs.getStringList('dailyRecords') ?? [];
    setState(() {
      batches = savedBatches
          .map((e) => Batch.fromJson(jsonDecode(e)))
          .toList();
      dailyRecords = savedRecords
          .map((e) => DailyRecord.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  String batchName(String batchId) {
    for (final b in batches) {
      if (b.id == batchId) return b.name;
    }
    return 'Unknown Batch';
  }

  Future<void> saveAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'dailyRecords',
      dailyRecords.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> deleteRecord(DailyRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('আপনি কি এই daily record মুছতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        dailyRecords.remove(record);
      });
      await saveAllRecords();
    }
  }

  Future<void> editRecord(DailyRecord record) async {
    final feedController =
        TextEditingController(text: record.feed.toString());
    final waterController =
        TextEditingController(text: record.water.toString());
    final eggsController =
        TextEditingController(text: record.eggs.toString());
    final mortalityController =
        TextEditingController(text: record.mortality.toString());
    final remarksController =
        TextEditingController(text: record.remarks);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Daily Record'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: feedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Feed (kg)'),
              ),
              TextField(
                controller: waterController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Water (L)'),
              ),
              TextField(
                controller: eggsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Eggs'),
              ),
              TextField(
                controller: mortalityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Mortality'),
              ),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(labelText: 'Remarks'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final index = dailyRecords.indexOf(record);
      if (index != -1) {
        setState(() {
          dailyRecords[index] = DailyRecord(
            batchId: record.batchId,
            date: record.date,
            feed: double.tryParse(feedController.text.trim()) ?? record.feed,
            water:
                double.tryParse(waterController.text.trim()) ?? record.water,
            eggs: int.tryParse(eggsController.text.trim()) ?? record.eggs,
            mortality: int.tryParse(mortalityController.text.trim()) ??
                record.mortality,
            remarks: remarksController.text.trim(),
          );
        });
        await saveAllRecords();
      }
    }
  }

  DateTime? filterStart;
  DateTime? filterEnd;

  String formatDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day}/${d.month}/${d.year}';
  }

  void clearFilter() {
    setState(() {
      filterStart = null;
      filterEnd = null;
    });
  }

  Future<void> pickFilterDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        filterStart = picked;
      } else {
        filterEnd = picked;
      }
    });
  }

  void openFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Filter Daily Records', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text('From: ${formatDate(filterStart)}'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: filterStart ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() => filterStart = picked);
                        setState(() {});
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text('To: ${formatDate(filterEnd)}'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: filterEnd ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() => filterEnd = picked);
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            clearFilter();
                            Navigator.pop(context);
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedRecords = dailyRecords.where((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      if (filterStart != null) {
        final sd = DateTime(filterStart!.year, filterStart!.month, filterStart!.day);
        if (d.isBefore(sd)) return false;
      }
      if (filterEnd != null) {
        final ed = DateTime(filterEnd!.year, filterEnd!.month, filterEnd!.day);
        if (d.isAfter(ed)) return false;
      }
      return true;
    }).toList();
    sortedRecords.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Records List'),
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            icon: const Icon(Icons.filter_alt),
            onPressed: openFilterSheet,
          ),
        ],
      ),
      body: sortedRecords.isEmpty
          ? const Center(child: Text('কোনো daily record নেই'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sortedRecords.length,
              itemBuilder: (context, index) {
                final r = sortedRecords[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_note, color: Colors.blue),
                    title: Text(
                      '${r.date.toLocal().toString().split(' ')[0]} - ${batchName(r.batchId)}',
                    ),
                    subtitle: Text(
                      'Feed: ${r.feed.toStringAsFixed(2)} kg'
                      'Water: ${r.water.toStringAsFixed(2)} L'
                      'Eggs: ${r.eggs}'
                      'Mortality: ${r.mortality}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => editRecord(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteRecord(r),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SalesListPage extends StatefulWidget {
  const SalesListPage({super.key});

  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  @override
  void initState() {
    super.initState();
    loadSales();
  }

  Future<void> loadSales() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatches = prefs.getStringList('batches') ?? [];
    final savedEggSales = prefs.getStringList('eggSales') ?? [];
    final savedBirdSales = prefs.getStringList('birdSales') ?? [];
    setState(() {
      batches = savedBatches
          .map((e) => Batch.fromJson(jsonDecode(e)))
          .toList();
      eggSales = savedEggSales
          .map((e) => EggSale.fromJson(jsonDecode(e)))
          .toList();
      birdSales = savedBirdSales
          .map((e) => BirdSale.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  String batchName(String batchId) {
    for (final b in batches) {
      if (b.id == batchId) return b.name;
    }
    return 'Unknown Batch';
  }

  Future<void> saveSales() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'eggSales',
      eggSales.map((e) => jsonEncode(e.toJson())).toList(),
    );
    await prefs.setStringList(
      'birdSales',
      birdSales.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> deleteEggSale(EggSale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Egg Sale?'),
        content: const Text('আপনি কি এই egg sale মুছতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        eggSales.remove(sale);
      });
      await saveSales();
    }
  }

  Future<void> deleteBirdSale(BirdSale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bird Sale?'),
        content: const Text('আপনি কি এই bird sale মুছতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        birdSales.remove(sale);
      });
      await saveSales();
    }
  }

  Future<void> editEggSale(EggSale sale) async {
    final eggTypeController =
        TextEditingController(text: sale.eggType);
    final eggsController =
        TextEditingController(text: sale.eggsSold.toString());
    final rateController =
        TextEditingController(text: sale.pricePerEgg.toString());
    final buyerController =
        TextEditingController(text: sale.buyerName);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Egg Sale'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: eggTypeController,
                decoration: const InputDecoration(labelText: 'Egg Type'),
              ),
              TextField(
                controller: eggsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Eggs Sold'),
              ),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Price per Egg'),
              ),
              TextField(
                controller: buyerController,
                decoration: const InputDecoration(labelText: 'Buyer Name'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final index = eggSales.indexOf(sale);
      if (index != -1) {
        final eggs =
            int.tryParse(eggsController.text.trim()) ?? sale.eggsSold;
        final rate = double.tryParse(rateController.text.trim()) ??
            sale.pricePerEgg;
        setState(() {
          eggSales[index] = EggSale(
            batchId: sale.batchId,
            date: sale.date,
            eggType: eggTypeController.text.trim(),
            eggsSold: eggs,
            pricePerEgg: rate,
            totalAmount: eggs * rate,
            buyerName: buyerController.text.trim(),
          );
        });
        await saveSales();
      }
    }
  }

  Future<void> editBirdSale(BirdSale sale) async {
    final quantityController =
        TextEditingController(text: sale.quantity.toString());
    final weightController =
        TextEditingController(text: sale.totalWeightKg.toString());
    final rateController =
        TextEditingController(text: sale.pricePerKg.toString());
    final buyerController =
        TextEditingController(text: sale.buyerName);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bird Sale'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Total Weight (kg)'),
              ),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Price per kg'),
              ),
              TextField(
                controller: buyerController,
                decoration: const InputDecoration(labelText: 'Buyer Name'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final index = birdSales.indexOf(sale);
      if (index != -1) {
        final weight = double.tryParse(weightController.text.trim()) ??
            sale.totalWeightKg;
        final rate = double.tryParse(rateController.text.trim()) ??
            sale.pricePerKg;
        setState(() {
          birdSales[index] = BirdSale(
            batchId: sale.batchId,
            date: sale.date,
            quantity:
                int.tryParse(quantityController.text.trim()) ?? sale.quantity,
            totalWeightKg: weight,
            pricePerKg: rate,
            totalAmount: weight * rate,
            buyerName: buyerController.text.trim(),
          );
        });
        await saveSales();
      }
    }
  }

  DateTime? salesFilterStart;
  DateTime? salesFilterEnd;

  String formatSaleDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day}/${d.month}/${d.year}';
  }

  void clearSalesFilter() {
    setState(() {
      salesFilterStart = null;
      salesFilterEnd = null;
    });
  }

  void openSalesFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Filter Sales', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text('From: ${formatSaleDate(salesFilterStart)}'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: salesFilterStart ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() => salesFilterStart = picked);
                        setState(() {});
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text('To: ${formatSaleDate(salesFilterEnd)}'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: salesFilterEnd ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() => salesFilterEnd = picked);
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            clearSalesFilter();
                            Navigator.pop(context);
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool saleInRange(DateTime date) {
      final d = DateTime(date.year, date.month, date.day);
      if (salesFilterStart != null) {
        final sd = DateTime(salesFilterStart!.year, salesFilterStart!.month, salesFilterStart!.day);
        if (d.isBefore(sd)) return false;
      }
      if (salesFilterEnd != null) {
        final ed = DateTime(salesFilterEnd!.year, salesFilterEnd!.month, salesFilterEnd!.day);
        if (d.isAfter(ed)) return false;
      }
      return true;
    }

    final filteredEggSales =
        eggSales.where((sale) => saleInRange(sale.date)).toList();
    final filteredBirdSales =
        birdSales.where((sale) => saleInRange(sale.date)).toList();

    final allSales = <Widget>[];

    for (final sale in filteredEggSales) {
      allSales.add(
        Card(
          child: ListTile(
            leading: const Icon(Icons.egg, color: Colors.orange),
            title: Text(
              'Egg Sale - ${batchName(sale.batchId)}',
            ),
            subtitle: Text(
              '${sale.date.toLocal().toString().split(' ')[0]}'
              '${sale.eggType}: ${sale.eggsSold} eggs'
              'Rate: ${sale.pricePerEgg.toStringAsFixed(2)} tk'
              'Total: ${sale.totalAmount.toStringAsFixed(2)} tk',
            ),
            isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => editEggSale(sale),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteEggSale(sale),
                        ),
                      ],
                    ),
          ),
        ),
      );
    }

    for (final sale in filteredBirdSales) {
      allSales.add(
        Card(
          child: ListTile(
            leading: const Icon(Icons.sell, color: Colors.green),
            title: Text(
              'Bird Sale - ${batchName(sale.batchId)}',
            ),
            subtitle: Text(
              '${sale.date.toLocal().toString().split(' ')[0]}'
              'Quantity: ${sale.quantity}'
              'Weight: ${sale.totalWeightKg.toStringAsFixed(2)} kg'
              'Rate: ${sale.pricePerKg.toStringAsFixed(2)} tk/kg'
              'Total: ${(sale.totalWeightKg * sale.pricePerKg).toStringAsFixed(2)} tk',
            ),
            isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => editBirdSale(sale),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteBirdSale(sale),
                        ),
                      ],
                    ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales List'),
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            icon: const Icon(Icons.filter_alt),
            onPressed: openSalesFilterSheet,
          ),
        ],
      ),
      body: allSales.isEmpty
          ? const Center(child: Text('কোনো sale record নেই'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: allSales,
            ),
    );
  }
}

class AddBatchPage extends StatefulWidget {
  const AddBatchPage({super.key});

  @override
  State<AddBatchPage> createState() => _AddBatchPageState();
}

class _AddBatchPageState extends State<AddBatchPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final shedController = TextEditingController();
  final initialBirdsController = TextEditingController();

  String? category;
  String? breed;
  DateTime startDate = DateTime.now();

  final broilerBreeds = ['Ross 308', 'Cobb 500', 'Hubbard', 'Vencob'];
  final layerBreeds = ['Hy-Line Brown', 'ISA Brown', 'Lohmann', 'White Leghorn', 'Sonali'];
  final dualBreeds = ['Rhode Island Red', 'Plymouth Rock', 'Deshi'];

  List<String> get breedList {
    if (category == 'Broiler') return broilerBreeds;
    if (category == 'Layer') return layerBreeds;
    if (category == 'Dual Purpose') return dualBreeds;
    return [];
  }

  @override
  void dispose() {
    nameController.dispose();
    shedController.dispose();
    initialBirdsController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => startDate = picked);
  }

  Future<void> saveBatch() async {
    if (_formKey.currentState!.validate()) {
      final initialBirds = int.tryParse(initialBirdsController.text.trim());
      if (initialBirds == null || initialBirds <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Initial Birds-এ 0-এর বেশি সংখ্যা দিন')),
        );
        return;
      }

      try {
        final cloud = SupabaseRepository();
        final cloudBatch = await cloud.createBatch(cloud_models.Batch(
          id: '',
          userId: cloud.userId,
          name: nameController.text.trim(),
          productionType: 'Bird Production',
          productionCategory: category!,
          breed: breed!,
          startDate: startDate,
          initialBirds: initialBirds,
        ));
        final batch = Batch(
          id: cloudBatch.id,
          name: nameController.text.trim(),
          category: category!,
          breed: breed!,
          shed: shedController.text.trim(),
          startDate: startDate,
          initialBirds: initialBirds,
          status: 'Active',
        );

        batches.add(batch);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          'batches',
          batches.map((e) => jsonEncode(e.toJson())).toList(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch Supabase-এ save হয়েছে')),
        );
        Navigator.pop(context);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch save হয়নি: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Batch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Batch Name',
                  hintText: 'B-2026-01',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Batch Name দিন' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Broiler', child: Text('Broiler')),
                  DropdownMenuItem(value: 'Layer', child: Text('Layer')),
                  DropdownMenuItem(value: 'Dual Purpose', child: Text('Dual Purpose')),
                ],
                onChanged: (v) {
                  setState(() {
                    category = v;
                    breed = null;
                  });
                },
                validator: (v) => v == null ? 'Category নির্বাচন করুন' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: breed,
                decoration: const InputDecoration(
                  labelText: 'Breed',
                  border: OutlineInputBorder(),
                ),
                items: breedList
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => breed = v),
                validator: (v) => v == null ? 'Breed নির্বাচন করুন' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: shedController,
                decoration: const InputDecoration(
                  labelText: 'Shed / House (optional)',
                  hintText: 'Shed-1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: initialBirdsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial Birds',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Initial Birds দিন' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Start Date: ${startDate.toLocal()}'.split(' ')[0]),
                  ),
                  TextButton(
                    onPressed: pickDate,
                    child: const Text('Change Date'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saveBatch,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Batch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BatchListPage extends StatefulWidget {
  const BatchListPage({super.key});

  @override
  State<BatchListPage> createState() => _BatchListPageState();
}

class _BatchListPageState extends State<BatchListPage> {
  @override
  void initState() {
    super.initState();
    loadBatches();
  }

  Future<void> loadBatches() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('batches') ?? [];
    setState(() {
      batches = saved.map((e) => Batch.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> saveBatches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'batches',
      batches.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> confirmDelete(BuildContext context, int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Batch?'),
        content: const Text('আপনি কি এই batch মুছতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() {
        batches.removeAt(index);
      });
      await saveBatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch List')),
      body: batches.isEmpty
          ? const Center(child: Text('কোনো batch নেই'))
          : ListView.builder(
              itemCount: batches.length,
              itemBuilder: (context, index) {
                final b = batches[index];
                return ListTile(
                  leading: const Icon(Icons.business),
                  title: Text('${b.name} (${b.category})'),
                  subtitle: Text(
                      '${b.breed} - ${b.initialBirds} birds - ${b.shed}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => confirmDelete(context, index),
                  ),
                );
              },
            ),
    );
  }
}

class DailyRecord {
  String batchId;
  DateTime date;
  double feed;
  double water;
  int eggs;
  int mortality;
  String remarks;

  DailyRecord({
    required this.batchId,
    required this.date,
    required this.feed,
    required this.water,
    required this.eggs,
    required this.mortality,
    required this.remarks,
  });

  Map<String, dynamic> toJson() => {
        'batchId': batchId,
        'date': date.toIso8601String(),
        'feed': feed,
        'water': water,
        'eggs': eggs,
        'mortality': mortality,
        'remarks': remarks,
      };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
        batchId: json['batchId'],
        date: DateTime.parse(json['date']),
        feed: (json['feed'] as num).toDouble(),
        water: (json['water'] as num).toDouble(),
        eggs: json['eggs'],
        mortality: json['mortality'],
        remarks: json['remarks'],
      );
}

List<DailyRecord> dailyRecords = [];

class DailyRecordPage extends StatefulWidget {
  const DailyRecordPage({super.key});

  @override
  State<DailyRecordPage> createState() => _DailyRecordPageState();
}

class _DailyRecordPageState extends State<DailyRecordPage> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    loadSavedData();
  }

  Future<void> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatches = prefs.getStringList('batches') ?? [];
    final savedRecords = prefs.getStringList('dailyRecords') ?? [];
    setState(() {
      batches = savedBatches
          .map((e) => Batch.fromJson(jsonDecode(e)))
          .toList();
      dailyRecords = savedRecords
          .map((e) => DailyRecord.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  String? selectedBatchId;
  final feedController = TextEditingController();
  final waterController = TextEditingController();
  final eggsController = TextEditingController();
  final mortalityController = TextEditingController();
  final remarksController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  @override
  void dispose() {
    feedController.dispose();
    waterController.dispose();
    eggsController.dispose();
    mortalityController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> saveRecord() async {
    if (_formKey.currentState!.validate()) {
      final feedKg = double.tryParse(feedController.text.trim());
      final waterLitre = double.tryParse(waterController.text.trim());
      if (feedKg == null || feedKg < 0 || waterLitre == null || waterLitre < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feed এবং Water-এর সঠিক সংখ্যা দিন')),
        );
        return;
      }

      final cloud = SupabaseRepository();
      final saved = await SupabaseErrorHandler.run<bool>(
        context,
        operation: 'Daily record save',
        successMessage: 'Daily record Supabase-এ save হয়েছে',
        action: () async {
          await cloud.createDailyRecord(cloud_models.DailyRecord(
            id: '',
            userId: cloud.userId,
            batchId: selectedBatchId!,
            date: selectedDate,
            shedNumber: '',
            feedType: '',
            feedKg: feedKg,
            waterLitre: waterLitre,
            eggsCollected: int.tryParse(eggsController.text.trim()) ?? 0,
            mortality: int.tryParse(mortalityController.text.trim()) ?? 0,
            remarks: remarksController.text.trim(),
          ));
          return true;
        },
      );
      if (saved != true) return;

      dailyRecords.add(DailyRecord(
        batchId: selectedBatchId!,
        date: selectedDate,
        feed: feedKg,
        water: waterLitre,
        eggs: int.tryParse(eggsController.text.trim()) ?? 0,
        mortality: int.tryParse(mortalityController.text.trim()) ?? 0,
        remarks: remarksController.text.trim(),
      ));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'dailyRecords',
        dailyRecords.map((e) => jsonEncode(e.toJson())).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Record')),
      body: batches.isEmpty
          ? const Center(child: Text('আগে একটি Batch তৈরি করুন'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedBatchId,
                      decoration: const InputDecoration(
                        labelText: 'Select Batch',
                        border: OutlineInputBorder(),
                      ),
                      items: batches
                          .map((b) => DropdownMenuItem(
                                value: b.id,
                                child: Text('${b.name} (${b.category})'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => selectedBatchId = v),
                      validator: (v) =>
                          v == null ? 'Batch নির্বাচন করুন' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: feedController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Feed Used (kg)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Feed দিন' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: waterController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Water Used (L)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Water দিন' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: eggsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Eggs Collected (Layer only)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: mortalityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Mortality',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              'Date: ${selectedDate.toLocal()}'.split(' ')[0]),
                        ),
                        TextButton(
                          onPressed: pickDate,
                          child: const Text('Change Date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saveRecord,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Record'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class EggSale {
  String batchId;
  DateTime date;
  String eggType;
  int eggsSold;
  double pricePerEgg;
  double totalAmount;
  String buyerName;

  EggSale({
    required this.batchId,
    required this.date,
    required this.eggType,
    required this.eggsSold,
    required this.pricePerEgg,
    required this.totalAmount,
    required this.buyerName,
  });

  Map<String, dynamic> toJson() => {
        'batchId': batchId,
        'date': date.toIso8601String(),
        'eggType': eggType,
        'eggsSold': eggsSold,
        'pricePerEgg': pricePerEgg,
        'totalAmount': totalAmount,
        'buyerName': buyerName,
      };

  factory EggSale.fromJson(Map<String, dynamic> json) => EggSale(
        batchId: json['batchId'],
        date: DateTime.parse(json['date']),
        eggType: json['eggType'],
        eggsSold: json['eggsSold'],
        pricePerEgg: (json['pricePerEgg'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        buyerName: json['buyerName'],
      );
}

List<EggSale> eggSales = [];

class EggSalePage extends StatefulWidget {
  const EggSalePage({super.key});

  @override
  State<EggSalePage> createState() => _EggSalePageState();
}

class _EggSalePageState extends State<EggSalePage> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    loadSavedData();
  }

  Future<void> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatches = prefs.getStringList('batches') ?? [];
    final savedSales = prefs.getStringList('eggSales') ?? [];
    setState(() {
      batches = savedBatches
          .map((e) => Batch.fromJson(jsonDecode(e)))
          .toList();
      eggSales = savedSales
          .map((e) => EggSale.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  String? selectedBatchId;
  String? eggType;
  final eggsSoldController = TextEditingController();
  final pricePerEggController = TextEditingController();
  final buyerNameController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  double get totalAmount {
    final eggs = int.tryParse(eggsSoldController.text) ?? 0;
    final price = double.tryParse(pricePerEggController.text) ?? 0;
    return eggs * price;
  }

  @override
  void dispose() {
    eggsSoldController.dispose();
    pricePerEggController.dispose();
    buyerNameController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> saveSale() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        eggSales.add(
          EggSale(
            batchId: selectedBatchId!,
            date: selectedDate,
            eggType: eggType!,
            eggsSold: int.parse(eggsSoldController.text.trim()),
            pricePerEgg: double.parse(pricePerEggController.text.trim()),
            totalAmount: totalAmount,
            buyerName: buyerNameController.text.trim(),
          ),
        );
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'eggSales',
        eggSales.map((e) => jsonEncode(e.toJson())).toList(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Egg sale saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Egg Sale')),
      body: batches.isEmpty
          ? const Center(child: Text('আগে একটি Batch তৈরি করুন'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedBatchId,
                      decoration: const InputDecoration(
                        labelText: 'Select Batch',
                        border: OutlineInputBorder(),
                      ),
                      items: batches
                          .map((b) => DropdownMenuItem(
                                value: b.id,
                                child: Text('${b.name} (${b.category})'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => selectedBatchId = v),
                      validator: (v) =>
                          v == null ? 'Batch নির্বাচন করুন' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: eggType,
                      decoration: const InputDecoration(
                        labelText: 'Egg Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Table Egg', child: Text('Table Egg')),
                        DropdownMenuItem(
                            value: 'Hatching Egg', child: Text('Hatching Egg')),
                      ],
                      onChanged: (v) => setState(() => eggType = v),
                      validator: (v) =>
                          v == null ? 'Egg Type নির্বাচন করুন' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: eggsSoldController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Eggs Sold',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Eggs sold দিন' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: pricePerEggController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price per Egg',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Price দিন' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: buyerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Buyer Name (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              'Date: ${selectedDate.toLocal()}'.split(' ')[0]),
                        ),
                        TextButton(
                          onPressed: pickDate,
                          child: const Text('Change Date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total: ${totalAmount.toStringAsFixed(2)} tk',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saveSale,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Sale'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class BirdSale {
  String batchId;
  DateTime date;
  int quantity;
  double totalWeightKg;
  double pricePerKg;
  double totalAmount;
  String buyerName;

  BirdSale({
    required this.batchId,
    required this.date,
    required this.quantity,
    required this.totalWeightKg,
    required this.pricePerKg,
    required this.totalAmount,
    required this.buyerName,
  });

  Map<String, dynamic> toJson() => {
        'batchId': batchId,
        'date': date.toIso8601String(),
        'quantity': quantity,
        'totalWeightKg': totalWeightKg,
        'pricePerKg': pricePerKg,
        'totalAmount': totalAmount,
        'buyerName': buyerName,
      };

  factory BirdSale.fromJson(Map<String, dynamic> json) => BirdSale(
        batchId: json['batchId'],
        date: DateTime.parse(json['date']),
        quantity: json['quantity'],
        totalWeightKg: (json['totalWeightKg'] as num).toDouble(),
        pricePerKg: (json['pricePerKg'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        buyerName: json['buyerName'],
      );
}

List<BirdSale> birdSales = [];

class BirdSalePage extends StatefulWidget {
  const BirdSalePage({super.key});

  @override
  State<BirdSalePage> createState() => _BirdSalePageState();
}

class _BirdSalePageState extends State<BirdSalePage> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    loadSavedData();
  }

  Future<void> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatches = prefs.getStringList('batches') ?? [];
    final savedSales = prefs.getStringList('birdSales') ?? [];
    setState(() {
      batches = savedBatches
          .map((e) => Batch.fromJson(jsonDecode(e)))
          .toList();
      birdSales = savedSales
          .map((e) => BirdSale.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  String? selectedBatchId;
  final quantityController = TextEditingController();
  final totalWeightController = TextEditingController();
  final pricePerKgController = TextEditingController();
  final buyerNameController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  double get totalAmount {
    final weight = double.tryParse(totalWeightController.text) ?? 0;
    final price = double.tryParse(pricePerKgController.text) ?? 0;
    return weight * price;
  }

  @override
  void dispose() {
    quantityController.dispose();
    totalWeightController.dispose();
    pricePerKgController.dispose();
    buyerNameController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> saveSale() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        birdSales.add(
          BirdSale(
            batchId: selectedBatchId!,
            date: selectedDate,
            quantity: int.parse(quantityController.text.trim()),
            totalWeightKg: double.parse(totalWeightController.text.trim()),
            pricePerKg: double.parse(pricePerKgController.text.trim()),
            totalAmount: totalAmount,
            buyerName: buyerNameController.text.trim(),
          ),
        );
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'birdSales',
        birdSales.map((e) => jsonEncode(e.toJson())).toList(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bird sale saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bird Sale')),
      body: batches.isEmpty
          ? const Center(child: Text('আগে একটি Batch তৈরি করুন'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedBatchId,
                      decoration: const InputDecoration(
                        labelText: 'Select Batch',
                        border: OutlineInputBorder(),
                      ),
                      items: batches
                          .map((b) => DropdownMenuItem(
                                value: b.id,
                                child: Text('${b.name} (${b.category})'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => selectedBatchId = v),
                      validator: (v) =>
                          v == null ? 'Batch নির্বাচন করুন' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity (birds)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Quantity দিন' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: totalWeightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Weight দিন' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: pricePerKgController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price per kg',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Price per kg দিন' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: buyerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Buyer Name (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              'Date: ${selectedDate.toLocal()}'.split(' ')[0]),
                        ),
                        TextButton(
                          onPressed: pickDate,
                          child: const Text('Change Date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total: ${totalAmount.toStringAsFixed(2)} tk',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saveSale,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Sale'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}


class MonthlySummaryPage extends StatefulWidget {
  const MonthlySummaryPage({super.key});

  @override
  State<MonthlySummaryPage> createState() => _MonthlySummaryPageState();
}

class _MonthlySummaryPageState extends State<MonthlySummaryPage> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<DailyRecord> dailyRecords = [];
  List<Batch> batches = [];
  List<EggSale> eggSales = [];
  List<BirdSale> birdSales = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatches = prefs.getStringList('batches') ?? [];
    final savedRecords = prefs.getStringList('dailyRecords') ?? [];
    final savedEggSales = prefs.getStringList('eggSales') ?? [];
    final savedBirdSales = prefs.getStringList('birdSales') ?? [];

    setState(() {
      batches = savedBatches
          .map((e) => Batch.fromJson(jsonDecode(e)))
          .toList();
      dailyRecords = savedRecords
          .map((e) => DailyRecord.fromJson(jsonDecode(e)))
          .toList();
      eggSales = savedEggSales
          .map((e) => EggSale.fromJson(jsonDecode(e)))
          .toList();
      birdSales = savedBirdSales
          .map((e) => BirdSale.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  bool isSameMonth(DateTime date) {
    return date.year == selectedMonth.year &&
        date.month == selectedMonth.month;
  }

  double get totalFeed {
    return dailyRecords
        .where((r) => isSameMonth(r.date))
        .fold(0, (sum, r) => sum + r.feed);
  }

  double get totalWater {
    return dailyRecords
        .where((r) => isSameMonth(r.date))
        .fold(0, (sum, r) => sum + r.water);
  }

  int get totalEggs {
    return dailyRecords
        .where((r) => isSameMonth(r.date))
        .fold(0, (sum, r) => sum + r.eggs);
  }

  int get totalMortality {
    return dailyRecords
        .where((r) => isSameMonth(r.date))
        .fold(0, (sum, r) => sum + r.mortality);
  }

  double get eggIncome {
    return eggSales
        .where((s) => isSameMonth(s.date))
        .fold(0, (sum, s) => sum + s.totalAmount);
  }

  double get birdIncome {
    return birdSales
        .where((s) => isSameMonth(s.date))
        .fold(0, (sum, s) => sum + s.totalAmount);
  }

  double get totalIncome => eggIncome + birdIncome;

  Future<void> pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      selectedMonth = DateTime(picked.year, picked.month);
    });
  }

  Widget summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Summary'),
        actions: [
          IconButton(
            tooltip: 'Select month',
            icon: const Icon(Icons.calendar_month),
            onPressed: pickMonth,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Month: ${selectedMonth.month}/${selectedMonth.year}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    summaryRow('Total Feed', '${totalFeed.toStringAsFixed(2)} kg'),
                    summaryRow('Total Water', '${totalWater.toStringAsFixed(2)} L'),
                    summaryRow('Total Eggs', '$totalEggs'),
                    summaryRow('Total Mortality', '$totalMortality'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Income',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    summaryRow(
                        'Egg Sale Income', '${eggIncome.toStringAsFixed(2)} tk'),
                    summaryRow(
                        'Bird Sale Income', '${birdIncome.toStringAsFixed(2)} tk'),
                    const Divider(),
                    summaryRow(
                        'Total Income', '${totalIncome.toStringAsFixed(2)} tk'),
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


class MarketPrice {
  DateTime date;
  String itemType;
  String name;
  double price;

  MarketPrice({
    required this.date,
    required this.itemType,
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'itemType': itemType,
        'name': name,
        'price': price,
      };

  factory MarketPrice.fromJson(Map<String, dynamic> json) => MarketPrice(
        date: DateTime.parse(json['date']),
        itemType: json['itemType'],
        name: json['name'],
        price: (json['price'] as num).toDouble(),
      );
}

List<MarketPrice> marketPrices = [];

class MarketPricePage extends StatefulWidget {
  const MarketPricePage({super.key});

  @override
  State<MarketPricePage> createState() => _MarketPricePageState();
}

class _MarketPricePageState extends State<MarketPricePage> {
  DateTime selectedDate = DateTime.now();
  String selectedItemType = 'Egg';
  String selectedEggType = 'Table Egg';
  final birdTypeController = TextEditingController();
  final priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadPrices();
  }

  Future<void> loadPrices() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('marketPrices') ?? [];
    setState(() {
      marketPrices = saved
          .map((e) => MarketPrice.fromJson(jsonDecode(e)))
          .toList();
      marketPrices.sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<void> savePrices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'marketPrices',
      marketPrices.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      selectedDate = picked;
    });
  }

  Future<void> addPrice() async {
    final price = double.tryParse(priceController.text.trim());
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সঠিক দাম লিখুন')),
      );
      return;
    }

    String name;
    if (selectedItemType == 'Egg') {
      name = selectedEggType;
    } else {
      name = birdTypeController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('মুরগির জাত লিখুন')),
        );
        return;
      }
    }

    final dateKey = DateTime(
        selectedDate.year, selectedDate.month, selectedDate.day);
    final existingIndex = marketPrices.indexWhere((m) =>
        m.date.year == dateKey.year &&
        m.date.month == dateKey.month &&
        m.date.day == dateKey.day &&
        m.itemType == selectedItemType &&
        m.name == name);

    setState(() {
      if (existingIndex != -1) {
        marketPrices[existingIndex] = MarketPrice(
          date: dateKey,
          itemType: selectedItemType,
          name: name,
          price: price,
        );
      } else {
        marketPrices.add(MarketPrice(
          date: dateKey,
          itemType: selectedItemType,
          name: name,
          price: price,
        ));
      }
      marketPrices.sort((a, b) => b.date.compareTo(a.date));
    });

    priceController.clear();
    birdTypeController.clear();
    await savePrices();
  }

  Future<void> deletePrice(MarketPrice price) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Market Price?'),
        content: const Text('আপনি কি এই market price মুছতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        marketPrices.remove(price);
      });
      await savePrices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Market Price')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedItemType,
                    decoration:
                        const InputDecoration(labelText: 'Select Type'),
                    items: const [
                      DropdownMenuItem(value: 'Egg', child: Text('Egg Price')),
                      DropdownMenuItem(value: 'Bird', child: Text('Bird Price')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedItemType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  if (selectedItemType == 'Egg')
                    DropdownButtonFormField<String>(
                      value: selectedEggType,
                      decoration:
                          const InputDecoration(labelText: 'Egg Type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Table Egg', child: Text('Table Egg')),
                        DropdownMenuItem(
                            value: 'Hatching Egg',
                            child: Text('Hatching Egg')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedEggType = value!;
                        });
                      },
                    )
                  else
                    TextField(
                      controller: birdTypeController,
                      decoration: const InputDecoration(
                          labelText:
                              'Bird Type (Broiler, Sonali, Desi etc.)'),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: selectedItemType == 'Egg'
                          ? 'Price (tk per piece)'
                          : 'Price (tk per kg)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: addPrice,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Price'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: marketPrices.isEmpty
                ? const Center(child: Text('কোনো market price নেই'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: marketPrices.length,
                    itemBuilder: (context, index) {
                      final m = marketPrices[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            m.itemType == 'Egg' ? Icons.egg : Icons.sell,
                            color: m.itemType == 'Egg'
                                ? Colors.orange
                                : Colors.green,
                          ),
                          title: Text('${m.itemType} - ${m.name}'),
                          subtitle: Text(
                              '${m.date.toLocal().toString().split(' ')[0]}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.itemType == 'Egg'
                                    ? '${m.price.toStringAsFixed(2)} tk/pc'
                                    : '${m.price.toStringAsFixed(2)} tk/kg',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () => deletePrice(m),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


class Expense {
  String batchId;
  DateTime date;
  String category;
  double amount;
  String note;

  Expense({
    required this.batchId,
    required this.date,
    required this.category,
    required this.amount,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'batchId': batchId,
        'date': date.toIso8601String(),
        'category': category,
        'amount': amount,
        'note': note,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        batchId: json['batchId'],
        date: DateTime.parse(json['date']),
        category: json['category'],
        amount: (json['amount'] as num).toDouble(),
        note: json['note'] ?? '',
      );
}

List<Expense> expenses = [];

class ExpenseEntryPage extends StatefulWidget {
  const ExpenseEntryPage({super.key});

  @override
  State<ExpenseEntryPage> createState() => _ExpenseEntryPageState();
}

class _ExpenseEntryPageState extends State<ExpenseEntryPage> {
  String? selectedBatchId;
  String selectedCategory = 'Chick';
  DateTime selectedDate = DateTime.now();
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  List<Batch> batches = [];
  List<Expense> expenses = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatches = prefs.getStringList('batches') ?? [];
    final savedExpenses = prefs.getStringList('expenses') ?? [];
    setState(() {
      batches = savedBatches
          .map((e) => Batch.fromJson(jsonDecode(e)))
          .toList();
      expenses = savedExpenses
          .map((e) => Expense.fromJson(jsonDecode(e)))
          .toList();
      expenses.sort((a, b) => b.date.compareTo(a.date));
      if (batches.isNotEmpty && selectedBatchId == null) {
        selectedBatchId = batches.first.id;
      }
    });
  }

  Future<void> saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'expenses',
      expenses.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      selectedDate = picked;
    });
  }

  Future<void> addExpense() async {
    final amount = double.tryParse(amountController.text.trim());
    if (selectedBatchId == null || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch ও সঠিক amount দিন')),
      );
      return;
    }

    setState(() {
      expenses.add(Expense(
        batchId: selectedBatchId!,
        date: selectedDate,
        category: selectedCategory,
        amount: amount,
        note: noteController.text.trim(),
      ));
      expenses.sort((a, b) => b.date.compareTo(a.date));
    });

    amountController.clear();
    noteController.clear();
    await saveExpenses();
  }

  Future<void> deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('আপনি কি এই খরচটি মুছতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        expenses.remove(expense);
      });
      await saveExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: batches.isEmpty
          ? const Center(child: Text('কোনো batch নেই'))
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedBatchId,
                          decoration:
                              const InputDecoration(labelText: 'Batch'),
                          items: batches
                              .map((b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(b.name),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedBatchId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: pickDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                          items: const [
                            DropdownMenuItem(
                                value: 'Chick', child: Text('Chick')),
                            DropdownMenuItem(
                                value: 'Feed', child: Text('Feed')),
                            DropdownMenuItem(
                                value: 'Medicine', child: Text('Medicine')),
                            DropdownMenuItem(
                                value: 'Vaccine', child: Text('Vaccine')),
                            DropdownMenuItem(
                                value: 'Litter', child: Text('Litter')),
                            DropdownMenuItem(
                                value: 'Labor', child: Text('Labor')),
                            DropdownMenuItem(
                                value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Amount (tk)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                              labelText: 'Note (optional)'),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: addExpense,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Expense'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: expenses.isEmpty
                      ? const Center(child: Text('কোনো expense নেই'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: expenses.length,
                          itemBuilder: (context, index) {
                            final e = expenses[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.payments,
                                    color: Colors.red),
                                title: Text(
                                    '${e.category} - ${e.amount.toStringAsFixed(2)} tk'),
                                subtitle: Text(
                                    '${e.date.toLocal().toString().split(' ')[0]}'
                                    '${e.note.isEmpty ? '' : ' - ${e.note}'}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => deleteExpense(e),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}


class WeeklyWeight {
  String batchId;
  DateTime date;
  int sampleCount;
  double averageWeight;

  WeeklyWeight({
    required this.batchId,
    required this.date,
    required this.sampleCount,
    required this.averageWeight,
  });

  Map<String, dynamic> toJson() => {
        'batchId': batchId,
        'date': date.toIso8601String(),
        'sampleCount': sampleCount,
        'averageWeight': averageWeight,
      };

  factory WeeklyWeight.fromJson(Map<String, dynamic> json) => WeeklyWeight(
        batchId: json['batchId'],
        date: DateTime.parse(json['date']),
        sampleCount: json['sampleCount'],
        averageWeight: (json['averageWeight'] as num).toDouble(),
      );
}

List<WeeklyWeight> weeklyWeights = [];

class WeightEntryPage extends StatefulWidget {
  const WeightEntryPage({super.key});

  @override
  State<WeightEntryPage> createState() => _WeightEntryPageState();
}

class _WeightEntryPageState extends State<WeightEntryPage> {
  String? selectedBatchId;
  DateTime selectedDate = DateTime.now();
  final sampleController = TextEditingController();
  final weightController = TextEditingController();
  List<Batch> batches = [];
  List<WeeklyWeight> weights = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBatches = prefs.getStringList('batches') ?? [];
    final savedWeights = prefs.getStringList('weeklyWeights') ?? [];
    setState(() {
      batches = savedBatches
          .map((e) => Batch.fromJson(jsonDecode(e)))
          .toList();
      weights = savedWeights
          .map((e) => WeeklyWeight.fromJson(jsonDecode(e)))
          .toList();
      weights.sort((a, b) => b.date.compareTo(a.date));
      if (batches.isNotEmpty && selectedBatchId == null) {
        selectedBatchId = batches.first.id;
      }
    });
  }

  Future<void> saveWeights() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'weeklyWeights',
      weights.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      selectedDate = picked;
    });
  }

  Future<void> addWeight() async {
    final sampleCount = int.tryParse(sampleController.text.trim());
    final averageWeight = double.tryParse(weightController.text.trim());

    if (selectedBatchId == null ||
        sampleCount == null ||
        averageWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Batch, sample count ও সঠিক weight দিন')),
      );
      return;
    }

    setState(() {
      weights.add(WeeklyWeight(
        batchId: selectedBatchId!,
        date: selectedDate,
        sampleCount: sampleCount,
        averageWeight: averageWeight,
      ));
      weights.sort((a, b) => b.date.compareTo(a.date));
    });

    sampleController.clear();
    weightController.clear();
    await saveWeights();
  }

  Future<void> deleteWeight(WeeklyWeight w) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Weight Entry?'),
        content: const Text('আপনি কি এই weight entry মুছতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        weights.remove(w);
      });
      await saveWeights();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Weight')),
      body: batches.isEmpty
          ? const Center(child: Text('কোনো batch নেই'))
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedBatchId,
                          decoration:
                              const InputDecoration(labelText: 'Batch'),
                          items: batches
                              .map((b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(b.name),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedBatchId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: pickDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: sampleController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Sample Count (কতটি মুরগি ওজন করলেন)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: weightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Average Weight (kg)'),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: addWeight,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Weight'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: weights.isEmpty
                      ? const Center(child: Text('কোনো weight entry নেই'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: weights.length,
                          itemBuilder: (context, index) {
                            final w = weights[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.monitor_weight,
                                    color: Colors.blue),
                                title: Text(
                                    '${w.date.toLocal().toString().split(' ')[0]} - ${w.averageWeight.toStringAsFixed(2)} kg'),
                                subtitle: Text(
                                    'Sample: ${w.sampleCount} birds'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => deleteWeight(w),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
