import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'poultry_standards.dart';

class AverageWeightScreen extends StatefulWidget {
  const AverageWeightScreen({super.key});

  @override
  State<AverageWeightScreen> createState() => _AverageWeightScreenState();
}

class _AverageWeightScreenState extends State<AverageWeightScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  String? _historyError;
  List<Map<String, dynamic>> _batches = [];
  String? _selectedBatchId;

  DateTime _selectedDate = DateTime.now();
  final _weightController = TextEditingController();
  final _sampleCountController = TextEditingController(text: '10');
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _weightHistory = [];

  Map<String, dynamic>? get _selectedBatch {
    for (final batch in _batches) {
      if (batch['id'] == _selectedBatchId) return batch;
    }
    return _batches.isEmpty ? null : _batches.first;
  }

  @override
  void initState() {
    super.initState();
    _fetchBatches();
    _weightController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _sampleCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchBatches() async {
    setState(() => _loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in first');

      final res = await supabase
          .from('batches')
          .select()
          .eq('user_id', user.id)
          .order('start_date', ascending: false);

      final list = List<Map<String, dynamic>>.from(res);
      final active = list.where((b) {
        final st = (b['status'] ?? 'Active').toString().toLowerCase();
        return st == 'active';
      }).toList();
      final batches = active.isNotEmpty ? active : list;

      setState(() {
        _batches = batches;
        if (batches.isNotEmpty &&
            (_selectedBatchId == null ||
                !batches.any((b) => b['id'] == _selectedBatchId))) {
          _selectedBatchId = batches.first['id']?.toString();
        }
        _loading = false;
      });

      final selected = _selectedBatch;
      if (selected != null) {
        await _fetchHistory(selected['id']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load batches: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _fetchHistory(dynamic batchId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in first');

      final res = await supabase
          .from('weekly_weights')
          .select()
          .eq('user_id', user.id)
          .eq('batch_id', batchId)
          .order('weight_date', ascending: false);

      if (!mounted) return;
      setState(() {
        _weightHistory = List<Map<String, dynamic>>.from(res);
        _historyError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weightHistory = [];
        _historyError = '$e';
      });
    }
  }

  int _calculateAge(String? startDateStr, DateTime targetDate) {
    if (startDateStr == null || startDateStr.isEmpty) return 0;
    try {
      final start = DateTime.parse(startDateStr);
      final startDay = DateTime(start.year, start.month, start.day);
      final targetDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final diff = targetDay.difference(startDay).inDays;
      return diff >= 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }

  double? _gramsFromRow(Map<String, dynamic> row) {
    final kg = row['average_weight_kg'];
    if (kg is num && kg > 0) return kg.toDouble() * 1000;
    return null;
  }

  Future<void> _saveWeight() async {
    if (!_formKey.currentState!.validate() || _selectedBatch == null) return;

    final weightGrams = double.tryParse(_weightController.text.trim());
    final sampleCount = int.tryParse(_sampleCountController.text.trim());
    if (weightGrams == null || weightGrams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight in grams')),
      );
      return;
    }
    if (sampleCount == null || sampleCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample count must be at least 1')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Please log in first');

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final batchId = _selectedBatch!['id'];
      final weightKg = double.parse((weightGrams / 1000).toStringAsFixed(3));
      final remarks = _notesController.text.trim();
      final payload = {
        'sample_count': sampleCount,
        'average_weight_kg': weightKg,
        'remarks': remarks.isEmpty ? null : remarks,
      };

      final existing = await supabase
          .from('weekly_weights')
          .select('id')
          .eq('user_id', user.id)
          .eq('batch_id', batchId)
          .eq('weight_date', dateStr)
          .limit(1);

      final existingRows = List<Map<String, dynamic>>.from(existing);
      if (existingRows.isNotEmpty) {
        await supabase
            .from('weekly_weights')
            .update(payload)
            .eq('id', existingRows.first['id'])
            .eq('user_id', user.id);
      } else {
        await supabase.from('weekly_weights').insert({
          'user_id': user.id,
          'batch_id': batchId,
          'weight_date': dateStr,
          ...payload,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved \( {weightGrams.toStringAsFixed(0)} g ( \){weightKg.toStringAsFixed(3)} kg)',
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        _weightController.clear();
        _notesController.clear();
        await _fetchHistory(batchId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Average Weight')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_batches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Average Weight')),
        body: const Center(
          child: Text('No active batches found. Please add a batch first.'),
        ),
      );
    }

    final batch = _selectedBatch;
    final age = _calculateAge(batch?['start_date']?.toString(), _selectedDate);
    final category = batch?['production_category']?.toString();
    final breed = batch?['breed']?.toString();
    final stdWeight = PoultryStandards.getStandardWeight(
      ageInDays: age,
      category: category,
      breed: breed,
    );

    final inputWeight = double.tryParse(_weightController.text.trim());
    WeightEvaluation? evaluation;
    if (inputWeight != null && inputWeight > 0 && stdWeight != null) {
      evaluation = PoultryStandards.evaluate(
        actualWeight: inputWeight,
        standardWeight: stdWeight,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Average Weight', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Batch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedBatchId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _batches.map((b) {
                        final name = (b['name'] ?? b['batch_name'] ?? 'Unnamed').toString();
                        final cat = (b['production_category'] ?? '').toString();
                        return DropdownMenuItem(
                          value: b['id'].toString(),
                          child: Text(cat.isEmpty ? name : '$name ($cat)', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedBatchId = val);
                        if (val != null) _fetchHistory(val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _tagBadge('Age: $age Days', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                        if (breed != null && breed.isNotEmpty)
                          _tagBadge(breed, const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
                        if (category != null && category.isNotEmpty)
                          _tagBadge(category, const Color(0xFFFFF3E0), const Color(0xFFE65100)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.flag_outlined, size: 16, color: Colors.indigo),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text('Standard Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stdWeight != null ? '${stdWeight.toStringAsFixed(0)} g' : 'N/A',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                          Text('For Day $age', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: evaluation != null ? Color(evaluation.colorHex).withOpacity(0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: evaluation != null ? Color(evaluation.colorHex).withOpacity(0.4) : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.compare_arrows, size: 16, color: evaluation != null ? Color(evaluation.colorHex) : Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Comparison',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: evaluation != null ? Color(evaluation.colorHex) : Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            evaluation != null
                                ? '\( {evaluation.diffGrams >= 0 ? '+' : ''} \){evaluation.diffGrams.toStringAsFixed(0)} g'
                                : '--',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: evaluation != null ? Color(evaluation.colorHex) : Colors.black45,
                            ),
                          ),
                          Text(
                            evaluation != null ? '\( {evaluation.diffPercent >= 0 ? '+' : ''} \){evaluation.diffPercent.toStringAsFixed(1)}%' : 'Type weight below',
                            style: TextStyle(fontSize: 11, color: evaluation != null ? Color(evaluation.colorHex) : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if (evaluation != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(evaluation.colorHex).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Color(evaluation.colorHex)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${evaluation.status}: ${evaluation.advice}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(evaluation.colorHex)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (d != null) setState(() => _selectedDate = d);
                          },
                          child: const Text('Change Date'),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Average Weight (grams per bird) *',
                        hintText: 'e.g. 850',
                        helperText: '850 g is saved as 0.850 kg',
                        suffixText: 'g',
                        prefixIcon: const Icon(Icons.scale),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter average weight';
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Enter a positive number';
                        if (n > 20000) return 'Weight looks too high for one bird';
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sampleCountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Sample Count *',
                              hintText: '10',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'At least 1';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              labelText: 'Notes (optional)',
                              hintText: 'e.g. Fasting weight',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveWeight,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save Average Weight', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text('Weight History (This Batch)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (_historyError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Could not load history: $_historyError', style: const TextStyle(color: Color(0xFFC62828))),
                )
              else if (_weightHistory.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('No average weight recorded yet for this batch.', style: TextStyle(color: Colors.grey)),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _weightHistory.length,
                  itemBuilder: (ctx, i) {
                    final item = _weightHistory[i];
                    final dateRaw = item['weight_date']?.toString() ?? '';
                    final grams = _gramsFromRow(item);
                    final kg = grams == null ? null : grams / 1000;
                    final samples = item['sample_count'];
                    final notes = item['remarks']?.toString();
                    DateTime? recordDay;
                    try {
                      recordDay = DateTime.parse(dateRaw);
                    } catch (_) {}
                    final recordAge = recordDay == null
                        ? null
                        : _calculateAge(batch?['start_date']?.toString(), recordDay);
                    final recordStd = recordAge == null
                        ? null
                        : PoultryStandards.getStandardWeight(
                            ageInDays: recordAge,
                            category: category,
                            breed: breed,
                          );
                    WeightEvaluation? past;
                    if (grams != null && recordStd != null) {
                      past = PoultryStandards.evaluate(
                        actualWeight: grams,
                        standardWeight: recordStd,
                      );
                    }
                    final dateLabel = recordDay == null
                        ? dateRaw
                        : DateFormat('dd MMM yyyy').format(recordDay);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: past == null
                              ? const Color(0xFFE8F5E9)
                              : Color(past.colorHex).withOpacity(0.15),
                          child: Icon(
                            Icons.scale,
                            color: past == null ? const Color(0xFF2E7D32) : Color(past.colorHex),
                          ),
                        ),
                        title: Text(
                          grams == null
                              ? '—'
                              : '\( {grams.toStringAsFixed(0)} g  ( \){kg!.toStringAsFixed(3)} kg)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            dateLabel,
                            if (recordAge != null) 'Day $recordAge',
                            if (samples != null) '$samples birds',
                            if (past != null)
                              '\( {past.status} ( \){past.diffGrams >= 0 ? '+' : ''}${past.diffGrams.toStringAsFixed(0)} g)',
                            if (notes != null && notes.isNotEmpty) notes,
                          ].join(' • '),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textCol)),
    );
  }
}
