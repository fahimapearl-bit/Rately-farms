import 'package:flutter/material.dart';
import 'models.dart';
import 'supabase_repository.dart';
import 'supabase_error_handler.dart';

String _salesDateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class SalesScreenV2 extends StatefulWidget {
  const SalesScreenV2({super.key});

  @override
  State<SalesScreenV2> createState() => _SalesScreenV2State();
}

class _SalesScreenV2State extends State<SalesScreenV2> {
  final cloud = SupabaseRepository();
  final quantityController = TextEditingController();
  final weightController = TextEditingController();
  final priceController = TextEditingController();
  final buyerController = TextEditingController();
  final remarksController = TextEditingController();

  List<Batch> batches = [];
  List<Sale> sales = [];
  String? selectedBatchId;
  String saleType = 'Bird';
  DateTime date = DateTime.now();
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadCloudData();
  }

  Future<void> loadCloudData() async {
    setState(() => loading = true);
    try {
      final loadedBatches = await cloud.getBatches();
      final loadedSales = await cloud.getSales();
      if (!mounted) return;
      setState(() {
        batches = loadedBatches;
        sales = loadedSales;
        selectedBatchId ??= batches.isEmpty ? null : batches.first.id;
      });
    } catch (error) {
      if (mounted) _showError('Sales data load হয়নি: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    quantityController.dispose();
    weightController.dispose();
    priceController.dispose();
    buyerController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  String batchName(String id) {
    for (final batch in batches) {
      if (batch.id == id) return batch.name;
    }
    return id;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => date = picked);
  }

  Future<void> saveSale() async {
    final quantity = int.tryParse(quantityController.text.trim());
    final unitPrice = double.tryParse(priceController.text.trim());
    final weight = saleType == 'Bird'
        ? double.tryParse(weightController.text.trim())
        : null;

    if (selectedBatchId == null) {
      _showError('Batch নির্বাচন করুন');
      return;
    }
    if (quantity == null || quantity <= 0) {
      _showError('সঠিক quantity দিন');
      return;
    }
    if (unitPrice == null || unitPrice < 0) {
      _showError('সঠিক unit price দিন');
      return;
    }
    if (saleType == 'Bird' && (weight == null || weight <= 0)) {
      _showError('Bird sale-এর জন্য total weight দিন');
      return;
    }

    setState(() => saving = true);
    final saved = await SupabaseErrorHandler.run<Sale>(
      context,
      operation: 'Sale save',
      successMessage: 'Sale Supabase-এ save হয়েছে',
      action: () => cloud.createSale(Sale(
        id: '',
        userId: cloud.userId,
        batchId: selectedBatchId!,
        date: date,
        type: saleType,
        quantity: quantity,
        weightKg: weight,
        unitPrice: unitPrice,
        buyerName: buyerController.text.trim(),
        remarks: remarksController.text.trim(),
      )),
    );
    if (saved != null && mounted) {
      setState(() => sales.insert(0, saved));
      quantityController.clear();
      weightController.clear();
      priceController.clear();
      buyerController.clear();
      remarksController.clear();
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> deleteSale(Sale sale) async {
    final deleted = await SupabaseErrorHandler.run<bool>(
      context,
      operation: 'Sale delete',
      action: () async {
        await cloud.deleteSale(sale.id);
        return true;
      },
    );
    if (deleted == true && mounted) {
      setState(() => sales.remove(sale));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales (Cloud)'),
        actions: [
          IconButton(onPressed: loadCloudData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : batches.isEmpty
              ? const Center(child: Text('আগে Supabase-এ একটি Batch তৈরি করুন'))
              : Column(children: [
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        DropdownButtonFormField<String>(
                          value: selectedBatchId,
                          decoration: const InputDecoration(labelText: 'Batch'),
                          items: batches
                              .map((batch) => DropdownMenuItem(
                                    value: batch.id,
                                    child: Text(batch.name),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => selectedBatchId = value),
                        ),
                        DropdownButtonFormField<String>(
                          value: saleType,
                          decoration: const InputDecoration(labelText: 'Sale type'),
                          items: const [
                            DropdownMenuItem(value: 'Bird', child: Text('Bird')),
                            DropdownMenuItem(value: 'Table Eggs', child: Text('Table Eggs')),
                            DropdownMenuItem(value: 'Hatching Eggs', child: Text('Hatching Eggs')),
                          ],
                          onChanged: (value) => setState(() => saleType = value!),
                        ),
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: saleType == 'Bird' ? 'Bird quantity' : 'Egg quantity',
                          ),
                        ),
                        if (saleType == 'Bird')
                          TextField(
                            controller: weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Total weight (kg)'),
                          ),
                        TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: saleType == 'Bird' ? 'Price (tk/kg)' : 'Price (tk/piece)',
                          ),
                        ),
                        TextField(
                          controller: buyerController,
                          decoration: const InputDecoration(labelText: 'Buyer name (optional)'),
                        ),
                        TextField(
                          controller: remarksController,
                          decoration: const InputDecoration(labelText: 'Remarks (optional)'),
                        ),
                        Row(children: [
                          Expanded(child: Text('Date: ${_salesDateText(date)}')),
                          TextButton(onPressed: chooseDate, child: const Text('Change')),
                        ]),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: saving ? null : saveSale,
                            icon: saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.cloud_upload),
                            label: const Text('Save Sale'),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: sales.isEmpty
                        ? const Center(child: Text('কোনো cloud sale নেই'))
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
                                    DataColumn(label: Text('Qty')),
                                    DataColumn(label: Text('Weight kg')),
                                    DataColumn(label: Text('Unit price')),
                                    DataColumn(label: Text('Total')),
                                    DataColumn(label: Text('Action')),
                                  ],
                                  rows: sales.map((sale) => DataRow(cells: [
                                        DataCell(Text(_salesDateText(sale.date))),
                                        DataCell(Text(batchName(sale.batchId))),
                                        DataCell(Text(sale.type)),
                                        DataCell(Text('${sale.quantity}')),
                                        DataCell(Text(sale.weightKg?.toStringAsFixed(2) ?? '-')),
                                        DataCell(Text(sale.unitPrice.toStringAsFixed(2))),
                                        DataCell(Text(sale.totalAmount.toStringAsFixed(2))),
                                        DataCell(IconButton(
                                          tooltip: 'Delete',
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => deleteSale(sale),
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
