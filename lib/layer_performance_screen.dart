import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'app_colors.dart';

class LayerPerformanceScreen extends StatefulWidget {
  final String? initialBatchId;

  const LayerPerformanceScreen({super.key, this.initialBatchId});

  @override
  State<LayerPerformanceScreen> createState() => _LayerPerformanceScreenState();
}

class _LayerPerformanceScreenState extends State<LayerPerformanceScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('dd MMM, yyyy');

  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _batches = [];
  Map<String, dynamic>? _selectedBatch;

  List<Map<String, dynamic>> _dailyLogs = [];

  @override
  void initState() {
    super.initState();
    _loadBatches();
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
          .select('id, name, start_date, production_type, production_category, breed, status, initial_birds')
          .eq('user_id', user.id)
          .order('start_date', ascending: false);

      final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(data);
      if (mounted) {
        setState(() {
          _batches = list;
          if (widget.initialBatchId != null) {
            _selectedBatch = list.firstWhere(
              (b) => b['id'].toString() == widget.initialBatchId,
              orElse: () => list.isNotEmpty ? list.first : {},
            );
          } else {
            // Prefer active layer batches or the latest active batch
            _selectedBatch = list.firstWhere(
              (b) {
                final cat = (b['production_category'] ?? '').toString().toLowerCase();
                final type = (b['production_type'] ?? '').toString().toLowerCase();
                final status = (b['status'] ?? 'active').toString().toLowerCase();
                return status == 'active' && (cat.contains('layer') || type.contains('egg') || cat.contains('egg'));
              },
              orElse: () => list.firstWhere(
                (b) => (b['status'] ?? 'active').toString().toLowerCase() == 'active',
                orElse: () => list.isNotEmpty ? list.first : {},
              ),
            );
          }

          if (_selectedBatch != null && _selectedBatch!.isEmpty) {
            _selectedBatch = null;
          }
          _isLoading = false;
        });

        if (_selectedBatch != null) {
          _loadDailyLogs(_selectedBatch!['id'].toString());
        }
      }
    } catch (e) {
      if (mounted) {
        final colors = context.colors;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading batches: $e'), backgroundColor: colors.error),
        );
      }
    }
  }

  Future<void> _loadDailyLogs(String batchId) async {
    try {
      final data = await _supabase
          .from('layer_daily_logs')
          .select()
          .eq('batch_id', batchId)
          .order('log_date', ascending: false)
          ;

      if (mounted) {
        setState(() {
          _dailyLogs = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading layer daily logs: $e');
    }
  }

  int _getInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? 0;
  }

  double _getDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int _calculateActiveBirds() {
    if (_selectedBatch == null) return 0;
    final initial = _getInt(_selectedBatch!['initial_birds'] ?? _selectedBatch!['total_birds'] ?? 1000);
    int totalMortality = 0;
    int totalCulling = 0;
    for (final log in _dailyLogs) {
      totalMortality += _getInt(log['mortality_count']);
      totalCulling += _getInt(log['culling_count']);
    }
    final remaining = initial - totalMortality - totalCulling;
    return remaining > 0 ? remaining : 0;
  }

  // Open Bottom Sheet Form to Log Today's or Selected Date's Production
  void _openLogEntrySheet([Map<String, dynamic>? existingLog]) {
    final colors = context.colors;
    if (_selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an active batch first')),
      );
      return;
    }

    DateTime selectedDate = existingLog != null
        ? DateTime.tryParse(existingLog['log_date'].toString()) ?? DateTime.now()
        : DateTime.now();

    final goodEggsCtrl = TextEditingController(
      text: existingLog != null ? existingLog['good_eggs'].toString() : '',
    );
    final damagedEggsCtrl = TextEditingController(
      text: existingLog != null ? existingLog['damaged_eggs'].toString() : '0',
    );
    final feedCtrl = TextEditingController(
      text: existingLog != null ? existingLog['feed_consumed_kg'].toString() : '',
    );
    final mortalityCtrl = TextEditingController(
      text: existingLog != null ? existingLog['mortality_count'].toString() : '0',
    );
    final cullingCtrl = TextEditingController(
      text: existingLog != null ? existingLog['culling_count'].toString() : '0',
    );
    final eggWeightCtrl = TextEditingController(
      text: existingLog != null && existingLog['avg_egg_weight_g'] != null
          ? existingLog['avg_egg_weight_g'].toString()
          : '',
    );
    final notesCtrl = TextEditingController(
      text: existingLog != null ? (existingLog['notes'] ?? '').toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existingLog != null ? 'Edit Egg & Feed Log' : 'Log Daily Eggs & Feed',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.inkAlt),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 12),

                    // Date Picker Tile
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.line),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, size: 18, color: colors.warning),
                            const SizedBox(width: 8),
                            Text(
                              'Date: ${_displayFormat.format(selectedDate)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const Spacer(),
                            Text('Change', style: TextStyle(color: colors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Good Eggs & Damaged Eggs
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: goodEggsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Good Eggs *',
                              hintText: 'e.g. 850',
                              prefixIcon: Icon(Icons.egg_outlined, color: colors.brand),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: damagedEggsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Damaged / Broken',
                              hintText: '0',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Feed & Avg Weight
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: feedCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Feed Consumed (kg) *',
                              hintText: 'e.g. 110.5',
                              prefixIcon: Icon(Icons.restaurant_outlined, color: colors.warning),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: eggWeightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Avg Egg Weight (g)',
                              hintText: 'e.g. 62.5',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Mortality & Culling
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: mortalityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Mortality (Birds)',
                              hintText: '0',
                              prefixIcon: Icon(Icons.warning_amber_rounded, color: colors.error),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: cullingCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Culling (Sold/Removed)',
                              hintText: '0',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Notes (Vaccine, health, remarks)',
                        hintText: 'Optional notes...',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.warning,
                          foregroundColor: colors.card,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isSaving
                            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: colors.card, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Daily Record',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final goodEggs = int.tryParse(goodEggsCtrl.text.trim()) ?? 0;
                                final damagedEggs = int.tryParse(damagedEggsCtrl.text.trim()) ?? 0;
                                final feedKg = double.tryParse(feedCtrl.text.trim()) ?? 0.0;
                                final mortality = int.tryParse(mortalityCtrl.text.trim()) ?? 0;
                                final culling = int.tryParse(cullingCtrl.text.trim()) ?? 0;
                                final avgWeight = double.tryParse(eggWeightCtrl.text.trim());
                                final notes = notesCtrl.text.trim();

                                if (goodEggsCtrl.text.trim().isEmpty && feedCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter egg count or feed amount')),
                                  );
                                  return;
                                }

                                final totalEggs = goodEggs + damagedEggs;
                                final activeBirds = _calculateActiveBirds();
                                if (activeBirds > 0 && totalEggs > activeBirds) {
                                  final colors = context.colors;
                                  final proceed = await showDialog<bool>(
                                    context: ctx,
                                    barrierDismissible: false,
                                    builder: (dCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      title: Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded, color: colors.warning, size: 28),
                                          SizedBox(width: 8),
                                          Text('Egg Count Warning'),
                                        ],
                                      ),
                                      content: Text(
                                        'Total eggs ($totalEggs) exceeds current live birds ($activeBirds).\n\n'
                                        'Hen-Day Production will exceed 100%. Are you sure this entry is correct?',
                                        style: const TextStyle(fontSize: 14, height: 1.4),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dCtx, false),
                                          child: Text('Review Input', style: TextStyle(color: colors.muted)),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: colors.warning,
                                            foregroundColor: colors.card,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => Navigator.pop(dCtx, true),
                                          child: const Text('Proceed Anyway'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (proceed != true) return;
                                }

                                Navigator.pop(ctx);
                                await _saveLog(
                                  date: _dateFormat.format(selectedDate),
                                  goodEggs: goodEggs,
                                  damagedEggs: damagedEggs,
                                  feedKg: feedKg,
                                  mortality: mortality,
                                  culling: culling,
                                  avgWeight: avgWeight,
                                  notes: notes,
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveLog({
    required String date,
    required int goodEggs,
    required int damagedEggs,
    required double feedKg,
    required int mortality,
    required int culling,
    double? avgWeight,
    String? notes,
  }) async {
    if (_selectedBatch == null) return;
    setState(() => _isSaving = true);

    try {
      final payload = {
        'batch_id': _selectedBatch!['id'],
        'log_date': date,
        'good_eggs': goodEggs,
        'damaged_eggs': damagedEggs,
        'feed_consumed_kg': feedKg,
        'mortality_count': mortality,
        'culling_count': culling,
        'avg_egg_weight_g': avgWeight,
        'notes': notes?.isEmpty == true ? null : notes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase.from('layer_daily_logs').upsert(
            payload,
            onConflict: 'batch_id, log_date',
          );

      if (mounted) {
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Daily log saved successfully!'), backgroundColor: colors.brand),
        );
        _loadDailyLogs(_selectedBatch!['id'].toString());
      }
    } catch (e) {
      if (mounted) {
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save log: $e'), backgroundColor: colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteLog(String logId) async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to delete this daily egg record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.card),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('layer_daily_logs').delete().eq('id', logId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record deleted')),
        );
        _loadDailyLogs(_selectedBatch!['id'].toString());
      }
    } catch (e) {
      if (mounted) {
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting record: $e'), backgroundColor: colors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surfaceAlt,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Layer Performance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Daily Egg & Feed Production Board',
              style: TextStyle(fontSize: 12, color: colors.onAccentMuted),
            ),
          ],
        ),
        backgroundColor: colors.warning, // Warm amber-bronze for egg layer
        foregroundColor: colors.card,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _selectedBatch != null
                ? () => _loadDailyLogs(_selectedBatch!['id'].toString())
                : _loadBatches,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.warning,
        foregroundColor: colors.card,
        icon: const Icon(Icons.add),
        label: const Text('Log Today', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openLogEntrySheet(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (_selectedBatch != null) {
                  await _loadDailyLogs(_selectedBatch!['id'].toString());
                } else {
                  await _loadBatches();
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                children: [
                  _buildBatchSelector(),
                  const SizedBox(height: 12),
                  if (_selectedBatch == null)
                    _buildEmptyState('No active batches found. Please create a layer batch.')
                  else ...[
                    _buildTodayKpiSection(),
                    const SizedBox(height: 14),
                    _buildTrendChartSection(),
                    const SizedBox(height: 14),
                    _buildHistorySection(),
                    const SizedBox(height: 70), // Spacing for FAB
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildBatchSelector() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, color: colors.warning, size: 20),
          const SizedBox(width: 10),
          const Text('Batch: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedBatch?['id']?.toString(),
                hint: const Text('Select Batch', style: TextStyle(fontSize: 13)),
                items: _batches.map((batch) {
                  final name = batch['name'] ?? 'Batch';
                  final cat = batch['production_category'] ?? '';
                  return DropdownMenuItem<String>(
                    value: batch['id'].toString(),
                    child: Text(
                      '$name ($cat)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (newId) {
                  if (newId == null) return;
                  final match = _batches.firstWhere((b) => b['id'].toString() == newId);
                  setState(() {
                    _selectedBatch = match;
                  });
                  _loadDailyLogs(newId);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayKpiSection() {
    final colors = context.colors;
    final activeBirds = _calculateActiveBirds();
    final todayStr = _dateFormat.format(DateTime.now());

    // Find today's log or latest log
    Map<String, dynamic>? latestLog;
    if (_dailyLogs.isNotEmpty) {
      latestLog = _dailyLogs.firstWhere(
        (log) => log['log_date'] == todayStr,
        orElse: () => _dailyLogs.first,
      );
    }

    final isToday = latestLog != null && latestLog['log_date'] == todayStr;
    final totalEggs = latestLog != null ? _getInt(latestLog['total_eggs']) : 0;
    final goodEggs = latestLog != null ? _getInt(latestLog['good_eggs']) : 0;
    final damagedEggs = latestLog != null ? _getInt(latestLog['damaged_eggs']) : 0;
    final feedKg = latestLog != null ? _getDouble(latestLog['feed_consumed_kg']) : 0.0;
    final mortality = latestLog != null ? _getInt(latestLog['mortality_count']) : 0;

    // Laying Percentage (HDP %)
    final hdp = activeBirds > 0 ? (totalEggs / activeBirds) * 100 : 0.0;

    // Feed per bird in grams
    final feedPerBirdGrams = activeBirds > 0 && feedKg > 0 ? (feedKg * 1000.0) / activeBirds : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  isToday ? "Today's Performance" : "Latest Recorded Status",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.inkAlt),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isToday ? colors.successSoft : colors.warningSoft,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isToday ? colors.brandSoft : colors.warningBorder),
                  ),
                  child: Text(
                    isToday ? 'Live Today' : (latestLog != null ? _displayFormat.format(DateTime.parse(latestLog['log_date'])) : 'No data'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isToday ? colors.brand : colors.warning,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Birds: $activeBirds',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.inkAlt),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Bento KPI Grid
        Row(
          children: [
            // KPI 1: Laying Rate (HDP)
            Expanded(
              flex: 3,
              child: _buildKpiCard(
                title: 'Laying Rate (HDP)',
                value: latestLog != null ? '${hdp.toStringAsFixed(1)}%' : '---',
                subtitle: hdp >= 80 ? 'Optimal Production' : (hdp > 50 ? 'Moderate' : 'Low / Rising'),
                badgeColor: hdp >= 80 ? colors.brand : (hdp > 50 ? colors.warning : colors.muted),
                icon: Icons.trending_up,
                accentColor: colors.brand,
              ),
            ),
            const SizedBox(width: 8),
            // KPI 2: Total Eggs Today
            Expanded(
              flex: 3,
              child: _buildKpiCard(
                title: 'Total Eggs',
                value: latestLog != null ? NumberFormat('#,###').format(totalEggs) : '0',
                subtitle: 'Good: $goodEggs | Bad: $damagedEggs',
                badgeColor: colors.warning,
                icon: Icons.egg_rounded,
                accentColor: colors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // KPI 3: Feed per Bird
            Expanded(
              child: _buildKpiCard(
                title: 'Feed / Bird',
                value: feedPerBirdGrams > 0 ? '${feedPerBirdGrams.toStringAsFixed(0)} g' : '---',
                subtitle: 'Total: ${feedKg.toStringAsFixed(1)} kg',
                badgeColor: colors.inkAlt,
                icon: Icons.restaurant,
                accentColor: colors.info,
              ),
            ),
            const SizedBox(width: 8),
            // KPI 4: Mortality Today
            Expanded(
              child: _buildKpiCard(
                title: 'Mortality',
                value: '$mortality birds',
                subtitle: mortality == 0 ? 'Healthy Flock' : 'Check bio-security',
                badgeColor: mortality > 2 ? colors.error : colors.accent,
                icon: Icons.healing,
                accentColor: mortality > 2 ? colors.error : colors.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color badgeColor,
    required IconData icon,
    required Color accentColor,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.inkAlt),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: accentColor),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: badgeColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChartSection() {
    final colors = context.colors;
    if (_dailyLogs.isEmpty) return const SizedBox.shrink();

    // Take recent 7 logs and reverse so oldest is left, latest is right
    final recentLogs = _dailyLogs.take(7).toList().reversed.toList();
    final activeBirds = _calculateActiveBirds();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 18, color: colors.warning),
                  SizedBox(width: 6),
                  Text(
                    '7-Day Laying Trend',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.inkAlt),
                  ),
                ],
              ),
              Text(
                'Eggs & HDP %',
                style: TextStyle(fontSize: 11, color: colors.muted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recentLogs.map((log) {
                final eggs = _getInt(log['total_eggs']);
                final hdp = activeBirds > 0 ? (eggs / activeBirds) * 100 : 0.0;
                final dt = DateTime.tryParse(log['log_date'].toString()) ?? DateTime.now();
                final dayLabel = DateFormat('E').format(dt); // Mon, Tue...

                // Scale bar height (max 100%)
                final double barPercent = (hdp / 100.0).clamp(0.08, 1.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${hdp.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colors.warning),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 22,
                      height: 70 * barPercent,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.warning,
                            colors.warning,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayLabel,
                      style: TextStyle(fontSize: 10, color: colors.muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Records History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.inkAlt),
            ),
            Text(
              '${_dailyLogs.length} entries',
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_dailyLogs.isEmpty)
          _buildEmptyState('No daily logs entered yet. Tap "+ Log Today" to add the first egg record.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dailyLogs.length,
            itemBuilder: (context, index) {
              final row = _dailyLogs[index];
              return _buildHistoryCard(row);
            },
          ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> row) {
    final colors = context.colors;
    final logId = row['id'].toString();
    final dateStr = _displayFormat.format(DateTime.tryParse(row['log_date'].toString()) ?? DateTime.now());
    final totalEggs = _getInt(row['total_eggs']);
    final goodEggs = _getInt(row['good_eggs']);
    final damagedEggs = _getInt(row['damaged_eggs']);
    final feedKg = _getDouble(row['feed_consumed_kg']);
    final mortality = _getInt(row['mortality_count']);
    final notes = (row['notes'] ?? '').toString().trim();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: colors.warning),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${NumberFormat('#,###').format(totalEggs)} eggs',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: colors.warning),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 16, color: colors.muted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _deleteLog(logId),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildMiniBadge('Good: $goodEggs', colors.brand, colors.successSoft),
                const SizedBox(width: 6),
                if (damagedEggs > 0) ...[
                  _buildMiniBadge('Broken: $damagedEggs', colors.error, colors.errorSoft),
                  const SizedBox(width: 6),
                ],
                _buildMiniBadge('Feed: ${feedKg.toStringAsFixed(1)} kg', colors.inkAlt, colors.inkAlt),
                if (mortality > 0) ...[
                  const SizedBox(width: 6),
                  _buildMiniBadge('Dead: $mortality', colors.error, colors.errorSoft),
                ],
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Note: $notes',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: colors.inkAlt),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.egg_outlined, size: 40, color: colors.hint),
            const SizedBox(height: 10),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
