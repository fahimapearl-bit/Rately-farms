import 'package:flutter/material.dart';

import 'models.dart';
import 'supabase_repository.dart';

String _cloudDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class CloudBatchListScreen extends StatefulWidget {
  const CloudBatchListScreen({super.key});

  @override
  State<CloudBatchListScreen> createState() => _CloudBatchListScreenState();
}

class _CloudBatchListScreenState extends State<CloudBatchListScreen> {
  final cloud = SupabaseRepository();
  List<Batch> batches = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await cloud.getBatches();
      if (!mounted) return;
      setState(() => batches = rows);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> deleteBatch(Batch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete batch?'),
        content: const Text(
          'Batch delete করলে এর Daily Records, Expenses ও Sales-ও মুছে যাবে।',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await cloud.deleteBatch(batch.id);
      if (mounted) setState(() => batches.removeWhere((item) => item.id == batch.id));
    } catch (e) {
      if (mounted) _showError('$e');
    }
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Batch action failed: $text'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch List'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(error!)))
              : batches.isEmpty
                  ? const Center(child: Text('কোনো Supabase batch নেই'))
                  : _TableFrame(
                      child: DataTable(
                        headingRowColor: MaterialStatePropertyAll(Colors.green.shade100),
                        columns: const [
                          DataColumn(label: Text('Batch')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Breed')),
                          DataColumn(label: Text('Start')),
                          DataColumn(label: Text('Birds')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: batches
                            .map((batch) => DataRow(cells: [
                                  DataCell(Text(batch.name)),
                                  DataCell(Text(batch.productionCategory)),
                                  DataCell(Text(batch.breed)),
                                  DataCell(Text(_cloudDate(batch.startDate))),
                                  DataCell(Text('${batch.initialBirds}')),
                                  DataCell(IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => deleteBatch(batch),
                                  )),
                                ]))
                            .toList(),
                      ),
                    ),
    );
  }
}

class CloudDailyRecordsScreen extends StatefulWidget {
  const CloudDailyRecordsScreen({super.key});

  @override
  State<CloudDailyRecordsScreen> createState() => _CloudDailyRecordsScreenState();
}

class _CloudDailyRecordsScreenState extends State<CloudDailyRecordsScreen> {
  final cloud = SupabaseRepository();
  List<Batch> batches = [];
  List<DailyRecord> records = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loadedBatches = await cloud.getBatches();
      final loadedRecords = await cloud.getDailyRecords();
      if (!mounted) return;
      setState(() {
        batches = loadedBatches;
        records = loadedRecords;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String batchName(String id) {
    for (final batch in batches) {
      if (batch.id == id) return batch.name;
    }
    return id;
  }

  Future<void> deleteRecord(DailyRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete daily record?'),
        content: const Text('এই daily record মুছে ফেলবেন?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await cloud.deleteDailyRecord(record.id);
      if (mounted) setState(() => records.removeWhere((item) => item.id == record.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Daily record delete হয়নি: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Records List'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(error!)))
              : records.isEmpty
                  ? const Center(child: Text('কোনো Supabase daily record নেই'))
                  : _TableFrame(
                      child: DataTable(
                        headingRowColor: MaterialStatePropertyAll(Colors.green.shade100),
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Batch')),
                          DataColumn(label: Text('Feed kg')),
                          DataColumn(label: Text('Water L')),
                          DataColumn(label: Text('Eggs')),
                          DataColumn(label: Text('Mortality')),
                          DataColumn(label: Text('Remarks')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: records
                            .map((record) => DataRow(cells: [
                                  DataCell(Text(_cloudDate(record.date))),
                                  DataCell(Text(batchName(record.batchId))),
                                  DataCell(Text(record.feedKg.toStringAsFixed(2))),
                                  DataCell(Text(record.waterLitre.toStringAsFixed(2))),
                                  DataCell(Text('${record.eggsCollected}')),
                                  DataCell(Text('${record.mortality}')),
                                  DataCell(Text(record.remarks)),
                                  DataCell(IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => deleteRecord(record),
                                  )),
                                ]))
                            .toList(),
                      ),
                    ),
    );
  }
}

class _TableFrame extends StatelessWidget {
  final Widget child;
  const _TableFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        ),
      ),
    );
  }
}
