import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'poultry_standards.dart';

class AverageWeightScreen extends StatefulWidget {
  const AverageWeightScreen({super.key});

  @override
  State<AverageWeightScreen> createState() => _AverageWeightScreenState();
}

class _AverageWeightScreenState extends State<AverageWeightScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('dd MMM, yyyy');

  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _batches = [];
  Map<String, dynamic>? _selectedBatch;

  // Form Controllers
  DateTime _entryDate = DateTime.now();
  final TextEditingController _weightGramsController = TextEditingController();
  final TextEditingController _sampleCountController = TextEditingController(text: '10');
  final TextEditingController _remarksController = TextEditingController();

  // History weights
  List<Map<String, dynamic>> _weightHistory = [];

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  @override
  void dispose() {
    _weightGramsController.dispose();
    _sampleCountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = await _supabase
          .from('batches')
          .select('id, name, start_date, production_type, production_category, breed, status')
          .eq('user_id', user.id)
          .order('start_date', ascending: false);

      final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(data);
      if (mounted) {
        setState(() {
          _batches = list;
          // Prefer active batch first
          _selectedBatch = list.firstWhere(
            (b) => (b['status'] ?? 'Active').toString().toLowerCase() == 'active',
            orElse: () => list.isNotEmpty ? list.first : {},
          );
          if (_selectedBatch!.isEmpty) _selectedBatch = null;
          _isLoading = false;
        });

        if (_selectedBatch != null) {
          _loadWeightHistory(_selectedBatch!['id']);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading batches: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _loadWeightHistory(String batchId) async {
    try {
      final data = await _supabase
          .from('weekly_weights')
          .select()
          .eq('batch_id', batchId)
          .order('weight_date', ascending: true);

      if (mounted) {
        setState(() {
          _weightHistory = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading weights: $e');
    }
  }

  int _calculateAgeDays(DateTime startDate, DateTime onDate) {
    final diff = onDate.difference(startDate).inDays;
    return diff < 0 ? 0 : diff;
  }

  Future<void> _saveWeightEntry() async {
    if (_selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an active batch first')),
      );
      return;
    }

    final gramsText = _weightGramsController.text.trim();
    final sampleText = _sampleCountController.text.trim();

    if (gramsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter average weight in grams')),
      );
      return;
    }

    final double? grams = double.tryParse(gramsText);
    if (grams == null || grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight')),
      );
      return;
    }

    final int sampleCount = int.tryParse(sampleText) ?? 1;
    final double weightKg = grams / 1000.0;
    final user = _supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'user_id': user.id,
        'batch_id': _selectedBatch!['id'],
        'weight_date': _dateFormat.format(_entryDate),
        'sample_count': sampleCount,
        'average_weight_kg': double.parse(weightKg.toStringAsFixed(3)),
        'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      };

      await _supabase.from('weekly_weights').insert(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${grams.toStringAsFixed(0)} g (${weightKg.toStringAsFixed(3)} kg)'),
            backgroundColor: const Color(0xFF1B5E20),
          ),
        );
        _weightGramsController.clear();
        _remarksController.clear();
        _loadWeightHistory(_selectedBatch!['id']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteEntry(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Weight Record?'),
        content: const Text('This will remove the selected weight entry permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('weekly_weights').delete().eq('id', id);
      if (_selectedBatch != null) {
        _loadWeightHistory(_selectedBatch!['id']);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete error: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          'Average Weight & Growth',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _selectedBatch != null ? () => _loadWeightHistory(_selectedBatch!['id']) : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
          : _batches.isEmpty
              ? _buildNoBatchesView()
              : RefreshIndicator(
                  color: const Color(0xFF1B5E20),
                  onRefresh: () async {
                    if (_selectedBatch != null) await _loadWeightHistory(_selectedBatch!['id']);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBatchSelectorCard(),
                        const SizedBox(height: 12),
                        _buildBentoKPIGrid(),
                        const SizedBox(height: 14),
                        _buildGrowthChartCard(),
                        const SizedBox(height: 14),
                        _buildNewEntryCard(),
                        const SizedBox(height: 14),
                        _buildHistoryList(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoBatchesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No Batches Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Please add a batch first to record average weights.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBatchSelectorCard() {
    final startDateStr = _selectedBatch?['start_date']?.toString();
    DateTime? startDate;
    if (startDateStr != null) startDate = DateTime.tryParse(startDateStr);
    final ageDays = startDate != null ? _calculateAgeDays(startDate, DateTime.now()) : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.scale, color: Color(0xFF1B5E20), size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'SELECT BATCH',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 0.8),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Day $ageDays',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedBatch?['id'],
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
            ),
            items: _batches.map((b) {
              final name = b['name'] ?? 'Unnamed';
              final type = b['production_type'] ?? '';
              final breed = b['breed'] ?? '';
              final status = b['status'] ?? 'Active';
              return DropdownMenuItem<String>(
                value: b['id'],
                child: Text(
                  '$name ($type - $breed) • $status',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                final match = _batches.firstWhere((b) => b['id'] == val);
                setState(() {
                  _selectedBatch = match;
                });
                _loadWeightHistory(val);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBentoKPIGrid() {
    // 1. Calculate latest weight
    double? latestKg;
    DateTime? latestDate;
    if (_weightHistory.isNotEmpty) {
      final last = _weightHistory.last;
      latestKg = double.tryParse(last['average_weight_kg']?.toString() ?? '0');
      if (last['weight_date'] != null) {
        latestDate = DateTime.tryParse(last['weight_date'].toString());
      }
    }

    final startDateStr = _selectedBatch?['start_date']?.toString();
    DateTime? startDate;
    if (startDateStr != null) startDate = DateTime.tryParse(startDateStr);
    final int currentAgeDays = (startDate != null && latestDate != null)
        ? _calculateAgeDays(startDate, latestDate)
        : (startDate != null ? _calculateAgeDays(startDate, DateTime.now()) : 0);

    // 2. Standards evaluation
    final evaluation = PoultryStandardsService.evaluate(
      productionType: _selectedBatch?['production_type']?.toString(),
      productionCategory: _selectedBatch?['production_category']?.toString(),
      breed: _selectedBatch?['breed']?.toString(),
      ageDays: currentAgeDays,
      actualWeightKg: latestKg ?? 0.0,
    );

    // 3. Average Daily Gain (ADG)
    double? adgGrams;
    if (_weightHistory.length >= 2) {
      final last = _weightHistory.last;
      final prev = _weightHistory[_weightHistory.length - 2];
      final wLastKg = double.tryParse(last['average_weight_kg']?.toString() ?? '0') ?? 0;
      final wPrevKg = double.tryParse(prev['average_weight_kg']?.toString() ?? '0') ?? 0;
      final dLast = DateTime.tryParse(last['weight_date'].toString());
      final dPrev = DateTime.tryParse(prev['weight_date'].toString());
      if (dLast != null && dPrev != null) {
        final days = dLast.difference(dPrev).inDays;
        if (days > 0) {
          adgGrams = ((wLastKg - wPrevKg) * 1000.0) / days;
        }
      }
    }

    final double latestGrams = (latestKg ?? 0.0) * 1000.0;
    final double targetGrams = evaluation.targetWeightGrams;
    final bool hasWeight = latestKg != null && latestKg > 0;

    return Column(
      children: [
        Row(
          children: [
            // Card 1: Latest Average Weight
            Expanded(
              child: _buildKPICard(
                title: 'LATEST WEIGHT',
                mainValue: hasWeight ? '${latestGrams.toStringAsFixed(0)} g' : '--',
                subtitle: hasWeight ? '(${latestKg!.toStringAsFixed(3)} kg)' : 'No records yet',
                icon: Icons.scale_rounded,
                accentColor: const Color(0xFF1B5E20),
                bgColor: const Color(0xFFF1F8E9),
              ),
            ),
            const SizedBox(width: 10),
            // Card 2: Target Standard
            Expanded(
              child: _buildKPICard(
                title: 'TARGET (DAY $currentAgeDays)',
                mainValue: targetGrams > 0 ? '${targetGrams.toStringAsFixed(0)} g' : '--',
                subtitle: evaluation.breedBenchmarkName,
                icon: Icons.flag_circle_outlined,
                accentColor: const Color(0xFF0277BD),
                bgColor: const Color(0xFFE1F5FE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Card 3: Growth Variance / Deviation
            Expanded(
              child: _buildKPICard(
                title: 'VARIANCE',
                mainValue: hasWeight ? '${evaluation.diffPercent > 0 ? '+' : ''}${evaluation.diffPercent.toStringAsFixed(1)}%' : '--',
                subtitle: hasWeight
                    ? (evaluation.diffGrams >= 0 ? '+${evaluation.diffGrams.toStringAsFixed(0)} g ahead' : '${evaluation.diffGrams.toStringAsFixed(0)} g behind')
                    : 'Awaiting weigh-in',
                icon: evaluation.status == GrowthStatus.ahead
                    ? Icons.trending_up
                    : (evaluation.status == GrowthStatus.behind ? Icons.trending_down : Icons.check_circle_outline),
                accentColor: evaluation.status == GrowthStatus.ahead
                    ? const Color(0xFF2E7D32)
                    : (evaluation.status == GrowthStatus.behind ? const Color(0xFFC62828) : const Color(0xFFF57F17)),
                bgColor: evaluation.status == GrowthStatus.ahead
                    ? const Color(0xFFE8F5E9)
                    : (evaluation.status == GrowthStatus.behind ? const Color(0xFFFFEBEE) : const Color(0xFFFFFDE7)),
              ),
            ),
            const SizedBox(width: 10),
            // Card 4: Average Daily Gain (ADG)
            Expanded(
              child: _buildKPICard(
                title: 'DAILY GAIN (ADG)',
                mainValue: adgGrams != null ? '${adgGrams > 0 ? '+' : ''}${adgGrams.toStringAsFixed(1)} g/d' : '--',
                subtitle: adgGrams != null ? 'Gain rate per bird' : 'Need 2+ entries',
                icon: Icons.speed_rounded,
                accentColor: const Color(0xFF6A1B9A),
                bgColor: const Color(0xFFF3E5F5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String mainValue,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, color: accentColor, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mainValue,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accentColor),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthChartCard() {
    if (_weightHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.show_chart_rounded, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 6),
              const Text('Weight Growth Chart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text('Log at least 1 record to see the growth trajectory graph.', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
        ),
      );
    }

    final startDateStr = _selectedBatch?['start_date']?.toString();
    DateTime? startDate;
    if (startDateStr != null) startDate = DateTime.tryParse(startDateStr);

    // Prepare actual and target points
    final List<ChartPoint> actualPoints = [];
    final List<ChartPoint> targetPoints = [];

    for (var row in _weightHistory) {
      final dateStr = row['weight_date']?.toString();
      final kg = double.tryParse(row['average_weight_kg']?.toString() ?? '0') ?? 0;
      if (dateStr != null && kg > 0) {
        final d = DateTime.tryParse(dateStr);
        if (d != null && startDate != null) {
          final age = _calculateAgeDays(startDate, d);
          final actualGrams = kg * 1000.0;
          actualPoints.add(ChartPoint(age: age, grams: actualGrams, date: d));

          // Get target standard for this age
          final ev = PoultryStandardsService.evaluate(
            productionType: _selectedBatch?['production_type']?.toString(),
            productionCategory: _selectedBatch?['production_category']?.toString(),
            breed: _selectedBatch?['breed']?.toString(),
            ageDays: age,
            actualWeightKg: kg,
          );
          targetPoints.add(ChartPoint(age: age, grams: ev.targetWeightGrams, date: d));
        }
      }
    }

    actualPoints.sort((a, b) => a.date.compareTo(b.date));
    targetPoints.sort((a, b) => a.date.compareTo(b.date));

    if (actualPoints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text('Valid start date and weight records are required.'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.show_chart_rounded, color: Color(0xFF1B5E20), size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'GROWTH CURVE (ACTUAL vs TARGET)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Legend
          Row(
            children: [
              _buildLegendItem('Actual Weight', const Color(0xFF1B5E20), isDashed: false),
              const SizedBox(width: 14),
              _buildLegendItem('Breed Target', const Color(0xFF0277BD), isDashed: true),
            ],
          ),
          const SizedBox(height: 14),
          // Custom Canvas Chart
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: WeightCurvePainter(
                actualPoints: actualPoints,
                targetPoints: targetPoints,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {required bool isDashed}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(16, 3),
          painter: _LegendLinePainter(color: color, dashed: isDashed),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildNewEntryCard() {
    final gramsVal = double.tryParse(_weightGramsController.text.trim()) ?? 0;
    final kgPreview = gramsVal > 0 ? (gramsVal / 1000.0).toStringAsFixed(3) : '0.000';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_circle_outline, color: Color(0xFF1B5E20), size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'LOG NEW AVERAGE WEIGHT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 0.5),
              ),
              const Spacer(),
              if (gramsVal > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '= $kgPreview kg',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 1: Date & Sample Size
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _entryDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => _entryDate = picked);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFF9FAFB),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 15, color: Color(0xFF1B5E20)),
                        const SizedBox(width: 8),
                        Text(
                          _displayFormat.format(_entryDate),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _sampleCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Sample Birds',
                    labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Weight Grams
          TextField(
            controller: _weightGramsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Average Weight (in Grams)*',
              hintText: 'e.g. 450, 850, 1200',
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)),
              suffixText: 'grams',
              suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
            ),
          ),
          const SizedBox(height: 10),
          // Row 3: Remarks
          TextField(
            controller: _remarksController,
            decoration: InputDecoration(
              labelText: 'Remarks / Notes (optional)',
              hintText: 'e.g. Cobb 500, Uniformity good',
              labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 1,
              ),
              onPressed: _isSaving ? null : _saveWeightEntry,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Average Weight',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    final reversed = _weightHistory.reversed.toList();
    final startDateStr = _selectedBatch?['start_date']?.toString();
    DateTime? startDate;
    if (startDateStr != null) startDate = DateTime.tryParse(startDateStr);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history, color: Colors.blueGrey, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'WEIGHT LOG HISTORY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 0.5),
              ),
              const Spacer(),
              Text(
                '${reversed.length} records',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (reversed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No weigh-in logs recorded yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reversed.length,
              separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (ctx, idx) {
                final row = reversed[idx];
                final id = row['id']?.toString() ?? '';
                final dateStr = row['weight_date']?.toString() ?? '';
                final dateObj = DateTime.tryParse(dateStr);
                final age = (dateObj != null && startDate != null) ? _calculateAgeDays(startDate, dateObj) : null;
                final kg = double.tryParse(row['average_weight_kg']?.toString() ?? '0') ?? 0;
                final grams = kg * 1000.0;
                final sample = row['sample_count'] ?? 1;
                final remarks = row['remarks']?.toString();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F8E9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              age != null ? 'Day $age' : 'Log',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1B5E20)),
                            ),
                            Text(
                              dateObj != null ? DateFormat('dd/MM').format(dateObj) : '',
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${grams.toStringAsFixed(0)} g',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${kg.toStringAsFixed(3)} kg)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sample: $sample birds${remarks != null && remarks.isNotEmpty ? ' • $remarks' : ''}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        onPressed: id.isNotEmpty ? () => _deleteEntry(id) : null,
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  _LegendLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
      return;
    }

    const dashWidth = 4.0;
    const gap = 2.0;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dashWidth).clamp(0.0, size.width).toDouble();
      canvas.drawLine(Offset(x, 0), Offset(end, 0), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

// -------------------------------------------------------------
// Data model for custom canvas chart
// -------------------------------------------------------------
class ChartPoint {
  final int age;
  final double grams;
  final DateTime date;
  ChartPoint({required this.age, required this.grams, required this.date});
}

// -------------------------------------------------------------
// Flutter CustomPainter for interactive & fast weight curve
// -------------------------------------------------------------
class WeightCurvePainter extends CustomPainter {
  final List<ChartPoint> actualPoints;
  final List<ChartPoint> targetPoints;

  WeightCurvePainter({
    required this.actualPoints,
    required this.targetPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (actualPoints.isEmpty) return;

    final margin = const EdgeInsets.only(left: 32, right: 14, top: 12, bottom: 24);
    final chartWidth = size.width - margin.left - margin.right;
    final chartHeight = size.height - margin.top - margin.bottom;

    // Find min and max
    double maxGrams = 100.0;
    int minAge = actualPoints.first.age;
    int maxAge = actualPoints.last.age;

    for (var p in actualPoints) {
      if (p.grams > maxGrams) maxGrams = p.grams;
      if (p.age < minAge) minAge = p.age;
      if (p.age > maxAge) maxAge = p.age;
    }
    for (var p in targetPoints) {
      if (p.grams > maxGrams) maxGrams = p.grams;
      if (p.age > maxAge) maxAge = p.age;
    }

    if (maxAge == minAge) maxAge = minAge + 7;
    maxGrams = (maxGrams * 1.15); // Add 15% top padding

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    // Draw horizontal grid & Y-axis labels
    const gridCount = 3;
    for (int i = 0; i <= gridCount; i++) {
      final y = margin.top + (chartHeight / gridCount) * i;
      canvas.drawLine(Offset(margin.left, y), Offset(margin.left + chartWidth, y), gridPaint);

      final val = maxGrams - (maxGrams / gridCount) * i;
      textPainter.text = TextSpan(
        text: '${val.toInt()}g',
        style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(margin.left - textPainter.width - 4, y - 6));
    }

    // Helper functions for mapping coordinates
    double getX(int age) {
      final ratio = (age - minAge) / (maxAge - minAge);
      return margin.left + ratio * chartWidth;
    }

    double getY(double grams) {
      final ratio = grams / maxGrams;
      return margin.top + (1 - ratio) * chartHeight;
    }

    // 1. Draw Target Line (Dotted / Dashed Blue)
    if (targetPoints.length >= 2) {
      final targetPaint = Paint()
        ..color = const Color(0xFF0277BD).withOpacity(0.85)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final targetPath = Path();
      targetPath.moveTo(getX(targetPoints.first.age), getY(targetPoints.first.grams));
      for (int i = 1; i < targetPoints.length; i++) {
        targetPath.lineTo(getX(targetPoints[i].age), getY(targetPoints[i].grams));
      }
      canvas.drawPath(targetPath, targetPaint);
    }

    // 2. Draw Actual Line (Smooth Solid Green)
    final actualPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final actualDotPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.fill;

    final actualDotBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (actualPoints.length == 1) {
      final pt = actualPoints.first;
      final offset = Offset(getX(pt.age), getY(pt.grams));
      canvas.drawCircle(offset, 5, actualDotPaint);
      canvas.drawCircle(offset, 5, actualDotBorder);
    } else {
      final path = Path();
      path.moveTo(getX(actualPoints.first.age), getY(actualPoints.first.grams));
      for (int i = 1; i < actualPoints.length; i++) {
        path.lineTo(getX(actualPoints[i].age), getY(actualPoints[i].grams));
      }
      canvas.drawPath(path, actualPaint);

      // Draw points with labels
      for (var pt in actualPoints) {
        final offset = Offset(getX(pt.age), getY(pt.grams));
        canvas.drawCircle(offset, 4.5, actualDotPaint);
        canvas.drawCircle(offset, 4.5, actualDotBorder);
      }
    }

    // X-axis age markers
    for (var pt in actualPoints) {
      final x = getX(pt.age);
      textPainter.text = TextSpan(
        text: 'D${pt.age}',
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant WeightCurvePainter oldDelegate) {
    return oldDelegate.actualPoints != actualPoints || oldDelegate.targetPoints != targetPoints;
  }
}
