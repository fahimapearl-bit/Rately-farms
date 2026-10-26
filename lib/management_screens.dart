import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';
import 'supabase_repository.dart';
import 'models.dart';
import 'supabase_error_handler.dart';

String _dateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _batchLabel(List<Batch> batches, String id) {
  for (final batch in batches) {
    if (batch.id == id) return batch.name;
  }
  return id;
}

Future<List<Batch>> _loadBatchesWithLegacyFallback(SupabaseRepository cloud) async {
  final current = await cloud.getBatches();
  if (current.isNotEmpty) return current;
  final prefs = await SharedPreferences.getInstance();
  final legacy = prefs.getStringList('batches') ?? <String>[];
  return legacy
      .map((value) => Batch.fromJson(jsonDecode(value) as Map<String, dynamic>))
      .toList();
}

Future<DateTime?> _chooseDate(BuildContext context, DateTime current) {
  return showDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
}

class ExpenseScreenV2 extends StatefulWidget {
  const ExpenseScreenV2({super.key});

  @override
  State<ExpenseScreenV2> createState() => _ExpenseScreenV2State();
}

class _ExpenseScreenV2State extends State<ExpenseScreenV2> {
  final cloud = SupabaseRepository();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  final remarksController = TextEditingController();
  List<Batch> batches = [];
  List<Expense> expenses = [];
  String? batchId;
  String expenseType = 'Feed';
  DateTime date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loadedBatches = await _loadBatchesWithLegacyFallback(cloud);
    final loadedExpenses = await cloud.getExpenses();
    if (!mounted) return;
    setState(() {
      batches = loadedBatches;
      expenses = loadedExpenses..sort((a, b) => b.date.compareTo(a.date));
      batchId ??= batches.isEmpty ? null : batches.first.id;
    });
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(amountController.text.trim());
    if (batchId == null || amount == null || amount <= 0) {
      _message('Batch নির্বাচন করুন এবং সঠিক amount দিন');
      return;
    }
    final saved = await SupabaseErrorHandler.run<Expense>(
      context,
      operation: 'Expense save',
      successMessage: 'Expense Supabase-এ save হয়েছে',
      action: () => cloud.createExpense(Expense(
      id: '',
      userId: cloud.userId,
      batchId: batchId!,
      date: date,
      type: expenseType,
      description: descriptionController.text.trim(),
      amount: amount,
      remarks: remarksController.text.trim(),
      )),
    );
    if (saved == null) return;
    expenses.insert(0, saved);
    amountController.clear();
    descriptionController.clear();
    remarksController.clear();
    if (mounted) setState(() {});
  }

  void _message(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _delete(Expense item) async {
    final deleted = await SupabaseErrorHandler.run<bool>(
      context,
      operation: 'Expense delete',
      action: () async {
        await cloud.deleteExpense(item.id);
        return true;
      },
    );
    if (deleted == true && mounted) {
      setState(() => expenses.remove(item));
    }
  }

  String _batchName(String id) =>
      _batchLabel(batches, id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: batches.isEmpty
          ? const Center(child: Text('আগে নতুন schema অনুযায়ী Batch তৈরি করুন'))
          : Column(children: [
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    DropdownButtonFormField<String>(
                      value: batchId,
                      decoration: const InputDecoration(labelText: 'Batch'),
                      items: batches
                          .map((b) => DropdownMenuItem(
                                value: b.id,
                                child: Text(b.name),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => batchId = value),
                    ),
                    DropdownButtonFormField<String>(
                      value: expenseType,
                      decoration: const InputDecoration(labelText: 'Expense type'),
                      items: const [
                        DropdownMenuItem(value: 'Feed', child: Text('Feed')),
                        DropdownMenuItem(value: 'Medicine', child: Text('Medicine')),
                        DropdownMenuItem(value: 'Vaccine', child: Text('Vaccine')),
                        DropdownMenuItem(value: 'Labour', child: Text('Labour')),
                        DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) => setState(() => expenseType = value!),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description (optional)'),
                    ),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount (tk)'),
                    ),
                    TextField(
                      controller: remarksController,
                      decoration: const InputDecoration(labelText: 'Remarks (optional)'),
                    ),
                    Row(children: [
                      Expanded(child: Text('Date: ${_dateText(date)}')),
                      TextButton(
                        onPressed: () async {
                          final picked = await _chooseDate(context, date);
                          if (picked != null) setState(() => date = picked);
                        },
                        child: const Text('Change'),
                      ),
                    ]),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Expense'),
                      ),
                    ),
                  ]),
                ),
              ),
              if (expenses.isNotEmpty)
                Card(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  color: Colors.green.shade100,
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: const Text('Total expense'),
                    trailing: Text(
                      '${expenses.fold<double>(0, (sum, item) => sum + item.amount).toStringAsFixed(2)} tk',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              Expanded(
                child: expenses.isEmpty
                    ? const Center(child: Text('কোনো expense নেই'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStatePropertyAll(
                                Colors.green.shade100,
                              ),
                              columns: const [
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Batch')),
                                DataColumn(label: Text('Type')),
                                DataColumn(label: Text('Description')),
                                DataColumn(label: Text('Amount')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: expenses.map((item) => DataRow(cells: [
                                    DataCell(Text(_dateText(item.date))),
                                    DataCell(Text(_batchName(item.batchId))),
                                    DataCell(Text(item.type)),
                                    DataCell(Text(item.description)),
                                    DataCell(Text('${item.amount.toStringAsFixed(2)} tk')),
                                    DataCell(IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _delete(item),
                                    )),
                                  ])).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ]),
    );
  }
}

class WeeklyWeightScreenV2 extends StatefulWidget {
  const WeeklyWeightScreenV2({super.key});

  @override
  State<WeeklyWeightScreenV2> createState() => _WeeklyWeightScreenV2State();
}

class _WeeklyWeightScreenV2State extends State<WeeklyWeightScreenV2> {
  final cloud = SupabaseRepository();
  final sampleController = TextEditingController();
  final weightController = TextEditingController();
  final remarksController = TextEditingController();
  List<Batch> batches = [];
  List<WeeklyWeight> weights = [];
  String? batchId;
  DateTime date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loadedBatches = await _loadBatchesWithLegacyFallback(cloud);
    final loadedWeights = await cloud.getWeeklyWeights();
    if (!mounted) return;
    setState(() {
      batches = loadedBatches;
      weights = loadedWeights..sort((a, b) => b.date.compareTo(a.date));
      batchId ??= batches.isEmpty ? null : batches.first.id;
    });
  }

  @override
  void dispose() {
    sampleController.dispose();
    weightController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final samples = int.tryParse(sampleController.text.trim());
    final average = double.tryParse(weightController.text.trim());
    if (batchId == null || samples == null || samples <= 0 || average == null || average <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch, sample count এবং average weight সঠিকভাবে দিন')),
      );
      return;
    }
    final saved = await cloud.createWeeklyWeight(WeeklyWeight(
      id: '',
      userId: cloud.userId,
      batchId: batchId!,
      date: date,
      sampleCount: samples,
      averageWeightKg: average,
      remarks: remarksController.text.trim(),
    ));
    weights.insert(0, saved);
    sampleController.clear();
    weightController.clear();
    remarksController.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Average Weight')),
      body: batches.isEmpty
          ? const Center(child: Text('আগে নতুন schema অনুযায়ী Batch তৈরি করুন'))
          : Column(children: [
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    DropdownButtonFormField<String>(
                      value: batchId,
                      decoration: const InputDecoration(labelText: 'Batch'),
                      items: batches
                          .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                          .toList(),
                      onChanged: (value) => setState(() => batchId = value),
                    ),
                    TextField(
                      controller: sampleController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sample count'),
                    ),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Average weight (kg/pc)'),
                    ),
                    TextField(
                      controller: remarksController,
                      decoration: const InputDecoration(labelText: 'Remarks (optional)'),
                    ),
                    Row(children: [
                      Expanded(child: Text('Date: ${_dateText(date)}')),
                      TextButton(
                        onPressed: () async {
                          final picked = await _chooseDate(context, date);
                          if (picked != null) setState(() => date = picked);
                        },
                        child: const Text('Change'),
                      ),
                    ]),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Weight'),
                      ),
                    ),
                  ]),
                ),
              ),
              Expanded(
                child: weights.isEmpty
                    ? const Center(child: Text('কোনো weekly weight নেই'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStatePropertyAll(
                                Colors.green.shade100,
                              ),
                              columns: const [
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Batch')),
                                DataColumn(label: Text('Samples')),
                                DataColumn(label: Text('Avg kg/pc')),
                              ],
                              rows: weights.map((item) => DataRow(cells: [
                                DataCell(Text(_dateText(item.date))),
                                DataCell(Text(_batchLabel(batches, item.batchId))),
                                DataCell(Text('${item.sampleCount}')),
                                DataCell(Text(item.averageWeightKg.toStringAsFixed(3))),
                              ])).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ]),
    );
  }
}

class MarketPriceScreenV2 extends StatefulWidget {
  const MarketPriceScreenV2({super.key});

  @override
  State<MarketPriceScreenV2> createState() => _MarketPriceScreenV2State();
}

class _MarketPriceScreenV2State extends State<MarketPriceScreenV2> {
  final cloud = SupabaseRepository();
  final breedController = TextEditingController();
  final priceController = TextEditingController();
  final marketController = TextEditingController();
  final remarksController = TextEditingController();
  List<MarketPrice> prices = [];
  String type = 'Bird';
  String category = 'Broiler';
  DateTime date = DateTime.now();

  List<String> get categories => type == 'Bird'
      ? const ['Broiler', 'Sonali', 'Others']
      : const ['Table Eggs', 'Hatching Eggs'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await cloud.getMarketPrices();
    if (!mounted) return;
    setState(() => prices = loaded..sort((a, b) => b.date.compareTo(a.date)));
  }

  @override
  void dispose() {
    breedController.dispose();
    priceController.dispose();
    marketController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(priceController.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সঠিক price দিন')));
      return;
    }
    final saved = await cloud.createMarketPrice(MarketPrice(
      id: '',
      userId: cloud.userId,
      date: date,
      type: type,
      category: category,
      breed: breedController.text.trim(),
      unit: type == 'Bird' ? 'kg' : 'piece',
      price: price,
      marketName: marketController.text.trim(),
      remarks: remarksController.text.trim(),
    ));
    prices.insert(0, saved);
    priceController.clear();
    breedController.clear();
    marketController.clear();
    remarksController.clear();
    if (mounted) setState(() {});
  }

  Future<void> _delete(MarketPrice item) async {
    await cloud.deleteMarketPrice(item.id);
    prices.remove(item);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Market Price')),
      body: Column(children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Price type'),
                items: const [
                  DropdownMenuItem(value: 'Bird', child: Text('Bird price (per kg)')),
                  DropdownMenuItem(value: 'Egg', child: Text('Egg price (per piece)')),
                ],
                onChanged: (value) => setState(() {
                  type = value!;
                  category = categories.first;
                }),
              ),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: (value) => setState(() => category = value!),
              ),
              TextField(
                controller: breedController,
                decoration: const InputDecoration(labelText: 'Breed (optional, written field)'),
              ),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: type == 'Bird' ? 'Price (tk/kg)' : 'Price (tk/piece)'),
              ),
              TextField(
                controller: marketController,
                decoration: const InputDecoration(labelText: 'Market name (optional)'),
              ),
              Row(children: [
                Expanded(child: Text('Date: ${_dateText(date)}')),
                TextButton(
                  onPressed: () async {
                    final picked = await _chooseDate(context, date);
                    if (picked != null) setState(() => date = picked);
                  },
                  child: const Text('Change'),
                ),
              ]),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Market Price'),
                ),
              ),
            ]),
          ),
        ),
        Expanded(
          child: prices.isEmpty
              ? const Center(child: Text('কোনো market price নেই'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStatePropertyAll(
                          Colors.green.shade100,
                        ),
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Breed')),
                          DataColumn(label: Text('Market')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: prices.map((item) => DataRow(cells: [
                              DataCell(Text(_dateText(item.date))),
                              DataCell(Text(item.type)),
                              DataCell(Text(item.category)),
                              DataCell(Text(item.breed)),
                              DataCell(Text(item.marketName)),
                              DataCell(Text('${item.price.toStringAsFixed(2)} tk/${item.unit}')),
                              DataCell(IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _delete(item),
                              )),
                            ])).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}
