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
  List<Map<String, dynamic>> _batches = [];
  Map<String, dynamic>? _selectedBatch;

  DateTime _selectedDate = DateTime.now();
  final _weightController = TextEditingController();
  final _sampleCountController = TextEditingController(text: '10');
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _weightHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchBatches();
    _weightController.addListener(() => setState(() {}));
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
      final res = await supabase
          .from('batches')
          .select()
          .order('start_date', ascending: false);

      final list = List<Map<String, dynamic>>.from(res);
      final active = list.where((b) {
        final st = (b['status'] ?? 'Active').toString().toLowerCase();
        return st == 'active';
      }).toList();

      setState(() {
        _batches = active.isNotEmpty ? active : list;
        if (_batches.isNotEmpty) {
          _selectedBatch = _batches.first;
        }
        _loading = false;
      });

      if (_selectedBatch != null) {
        _fetchHistory(_selectedBatch!['id']);
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
      final res = await supabase
          .from('daily_records')
          .select()
          .eq('batch_id', batchId)
          .not('average_weight', 'is', null)
          .order('record_date', ascending: false);

      setState(() {
        _weightHistory = List<Map<String, dynamic>>.from(res);
      });
    } catch (_) {
      // যদি daily_records এ average_weight কলাম সরাসরি না থাকে, কোনো ক্র্যাশ হবে না
    }
  }

  int _calculateAge(String? startDateStr, DateTime targetDate) {
    if (startDateStr == null) return 0;
    try {
      final start = DateTime.parse(startDateStr);
      final diff = targetDate.difference(start).inDays;
      return diff >= 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _saveWeight() async {
    if (!_formKey.currentState!.validate() || _selectedBatch == null) return;

    final weightVal = double.tryParse(_weightController.text.trim());
    if (weightVal == null || weightVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight in grams')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final batchId = _selectedBatch!['id'];

      // ১. daily_records টেবিলে রেকর্ডটি আপডেট বা ইনসার্ট করা
      final existing = await supabase
          .from('daily_records')
          .select('id')
          .eq('batch_id', batchId)
          .eq('record_date', dateStr)
          .maybeSingle();

      if (existing != null) {
        await supabase.from('daily_records').update({
          'average_weight': weightVal,
          'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        }).eq('id', existing['id']);
      } else {
        await supabase.from('daily_records').insert({
          'batch_id': batchId,
          'record_date': dateStr,
          'average_weight': weightVal,
          'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Average weight saved successfully!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        _weightController.clear();
        _notesController.clear();
        _fetchHistory(batchId);
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

    final age = _calculateAge(_selectedBatch?['start_date'], _selectedDate);
    final category = _selectedBatch?['production_category']?.toString();
    final breed = _selectedBatch?['breed']?.toString();
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
              // ১. ব্যাচ সিলেক্টর কার্ড
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
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedBatch,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _batches.map((b) {
                        final name = b['batch_name'] ?? 'Unnamed';
                        final cat = b['production_category'] ?? '';
                        return DropdownMenuItem(
                          value: b,
                          child: Text('$name ($cat)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedBatch = val;
                        });
                        if (val != null) _fetchHistory(val['id']);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _tagBadge('Age: $age Days', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        if (breed != null && breed.isNotEmpty)
                          _tagBadge(breed, const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        if (category != null && category.isNotEmpty)
                          _tagBadge(category, const Color(0xFFFFF3E0), const Color(0xFFE65100)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ২. ইন্টেলিজেন্ট বেঞ্চমার্ক ও লাইভ তুলনা Bento কার্ড
              Row(
                children: [
                  // টার্গেট স্ট্যান্ডার্ড কার্ড
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
                              Text('Standard Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
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
                  // লাইভ ভ্যারিয়েন্স কার্ড
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
                              Text('Comparison', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: evaluation != null ? Color(evaluation.colorHex) : Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            evaluation != null
                                ? '${evaluation.diffGrams >= 0 ? '+' : ''}${evaluation.diffGrams.toStringAsFixed(0)} g'
                                : '--',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: evaluation != null ? Color(evaluation.colorHex) : Colors.black45,
                            ),
                          ),
                          Text(
                            evaluation != null ? '${evaluation.diffPercent >= 0 ? '+' : ''}${evaluation.diffPercent.toStringAsFixed(1)}%' : 'Type weight below',
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

              // ৩. ইনপুট ফর্ম কার্ড
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
                    // তারিখ নির্বাচন
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
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

                    // গড় ওজন ইনপুট
                    TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Average Weight (in Grams) *',
                        hintText: 'e.g. 850',
                        suffixText: 'g',
                        prefixIcon: const Icon(Icons.scale),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter average weight';
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Enter a positive number';
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // স্যাম্পল পাখির সংখ্যা ও নোট
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sampleCountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Sample Count',
                              hintText: '10',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
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

              // ৪. রেকর্ড হিস্ট্রি
              const Text('Weight History (This Batch)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (_weightHistory.isEmpty)
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
                    final date = item['record_date']?.toString() ?? '';
                    final w = item['average_weight'];
                    final notes = item['notes']?.toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.scale, color: Color(0xFF2E7D32)),
                        ),
                        title: Text(
                          '$w g',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Date: $date ${notes != null && notes.isNotEmpty ? '• $notes' : ''}',
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
