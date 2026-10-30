import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyRecordPageNew extends StatefulWidget {
  const DailyRecordPageNew({super.key});

  @override
  State<DailyRecordPageNew> createState() => _DailyRecordPageNewState();
}

class _DailyRecordPageNewState extends State<DailyRecordPageNew> {
  final _formKey = GlobalKey<FormState>();

  final feedController = TextEditingController();
  final waterController = TextEditingController();
  final eggsController = TextEditingController();
  final mortalityController = TextEditingController();
  final remarksController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String? selectedBatchId;

  List<Map<String, dynamic>> batches = [];
  List<Map<String, dynamic>> recentRecords = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCloudData();
  }

  @override
  void dispose() {
    feedController.dispose();
    waterController.dispose();
    eggsController.dispose();
    mortalityController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadCloudData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // 1. Load Batches from Cloud
      final batchData = await client
          .from('batches')
          .select('id, name, production_type, production_category')
          .eq('user_id', user.id)
          .order('start_date', ascending: false);

      // 2. Load Recent Daily Records
      final recordData = await client
          .from('daily_records')
          .select('id, batch_id, record_date, feed_kg, water_litre, eggs_collected, mortality, remarks')
          .eq('user_id', user.id)
          .order('record_date', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          batches = List<Map<String, dynamic>>.from(batchData);
          if (batches.isNotEmpty && selectedBatchId == null) {
            selectedBatchId = batches.first['id'] as String;
          }
          recentRecords = List<Map<String, dynamic>>.from(recordData);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data load error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a batch')),
      );
      return;
    }

    final feedKg = double.tryParse(feedController.text.trim()) ?? 0.0;
    final waterLitre = double.tryParse(waterController.text.trim()) ?? 0.0;
    final eggs = int.tryParse(eggsController.text.trim()) ?? 0;
    final mortality = int.tryParse(mortalityController.text.trim()) ?? 0;

    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await client.from('daily_records').insert({
        'user_id': user.id,
        'batch_id': selectedBatchId,
        'record_date': selectedDate.toIso8601String().split('T').first,
        'feed_kg': feedKg,
        'water_litre': waterLitre,
        'eggs_collected': eggs,
        'mortality': mortality,
        'remarks': remarksController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily Record saved to Cloud!'),
            backgroundColor: Colors.green,
          ),
        );
        // Clear fields
        feedController.clear();
        waterController.clear();
        eggsController.clear();
        mortalityController.clear();
        remarksController.clear();
        _loadCloudData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _sleekInput(String label, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      suffixIcon: suffix,
    );
  }

  String _getBatchName(String batchId) {
    final b = batches.firstWhere((item) => item['id'] == batchId, orElse: () => {});
    return b['name'] ?? batchId.substring(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Record'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCloudData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : batches.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                        const SizedBox(height: 12),
                        const Text(
                          'No Batches Found!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Please add a batch first before creating daily records.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Go Back & Add Batch'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Batch Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedBatchId,
                          decoration: _sleekInput('Select Batch *'),
                          items: batches.map((b) {
                            return DropdownMenuItem<String>(
                              value: b['id'] as String,
                              child: Text('${b['name']} (${b['production_category'] ?? ''})'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => selectedBatchId = val),
                        ),
                        const SizedBox(height: 12),

                        // Date Selector
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Date: ${selectedDate.toLocal()}'.split(' ')[0],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: const Text('Change'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Feed and Water in 2 columns
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: feedController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _sleekInput('Feed (kg) *', hint: '0.0'),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: waterController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _sleekInput('Water (Litre) *', hint: '0.0'),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Eggs and Mortality in 2 columns
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: eggsController,
                                keyboardType: TextInputType.number,
                                decoration: _sleekInput('Eggs Collected', hint: '0'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: mortalityController,
                                keyboardType: TextInputType.number,
                                decoration: _sleekInput('Mortality (Death)', hint: '0'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Remarks
                        TextFormField(
                          controller: remarksController,
                          decoration: _sleekInput('Remarks (optional)', hint: 'Vaccine, health notes...'),
                        ),
                        const SizedBox(height: 18),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _saveRecord,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cloud_upload),
                            label: Text(_isSaving ? 'Saving to Cloud...' : 'Save Daily Record'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Recent Records List
                        if (recentRecords.isNotEmpty) ...[
                          const Text(
                            'Recent Cloud Records',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStatePropertyAll(Colors.green.shade50),
                                headingRowHeight: 40,
                                dataRowHeight: 42,
                                columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Batch')),
                                  DataColumn(label: Text('Feed(kg)')),
                                  DataColumn(label: Text('Water(L)')),
                                  DataColumn(label: Text('Eggs')),
                                  DataColumn(label: Text('Mort.')),
                                ],
                                rows: recentRecords.map((r) {
                                  return DataRow(cells: [
                                    DataCell(Text('${r['record_date']}')),
                                    DataCell(Text(_getBatchName(r['batch_id'] ?? ''))),
                                    DataCell(Text('${r['feed_kg']}')),
                                    DataCell(Text('${r['water_litre']}')),
                                    DataCell(Text('${r['eggs_collected']}')),
                                    DataCell(Text('${r['mortality']}')),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}
