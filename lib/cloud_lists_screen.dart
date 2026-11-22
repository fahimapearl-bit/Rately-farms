import 'package:flutter/material.dart';

import 'models.dart';
import 'supabase_repository.dart';

import 'app_colors.dart';
import 'daily_record_screen.dart';

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
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Batch action failed: $text'), backgroundColor: colors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                        headingRowColor: MaterialStatePropertyAll(colors.brandSoft),
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
                                    icon: Icon(Icons.delete_outline, color: colors.error),
                                    onPressed: () => deleteBatch(batch),
                                  )),
                                ]))
                            .toList(),
                      ),
                    ),
    );
  }
}

// ───────────────────────── Daily Records (card list) ─────────────────────────

const String _taka = '৳';

double _n(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

String _fmt(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class CloudDailyRecordsScreen extends StatefulWidget {
  const CloudDailyRecordsScreen({super.key});

  @override
  State<CloudDailyRecordsScreen> createState() => _CloudDailyRecordsScreenState();
}

class _CloudDailyRecordsScreenState extends State<CloudDailyRecordsScreen> {
  final cloud = SupabaseRepository();
  List<Batch> batches = [];
  List<Map<String, dynamic>> records = []; // daily_records এর কাঁচা row (session, cost সহ)
  bool loading = true;
  String? error;

  String? selectedBatchId; // null = সব batch
  DateTimeRange? range; // null = সব তারিখ

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
      if (cloud.client.auth.currentSession == null) throw Exception('Login required');
      final loadedBatches = await cloud.getBatches();
      final rows = await cloud.client
          .from('daily_records')
          .select()
          .order('record_date', ascending: false);
      if (!mounted) return;
      setState(() {
        batches = loadedBatches;
        records = List<Map<String, dynamic>>.from(rows.map((e) => Map<String, dynamic>.from(e)));
        if (selectedBatchId != null && !batches.any((b) => b.id == selectedBatchId)) {
          selectedBatchId = null;
        }
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

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _dateOf(Map<String, dynamic> r) =>
      DateTime.tryParse('${r['record_date']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
  int _sessionIdx(Map<String, dynamic> r) => RecordSessionX.fromDb(r['session']).index;

  List<Map<String, dynamic>> get filtered {
    final list = records.where((r) {
      if (selectedBatchId != null && '${r['batch_id']}' != selectedBatchId) return false;
      if (range != null) {
        final d = _day(_dateOf(r));
        if (d.isBefore(_day(range!.start)) || d.isAfter(_day(range!.end))) return false;
      }
      return true;
    }).toList();
    // নতুন তারিখ আগে; একই দিনে Morning → Noon → Evening
    list.sort((a, b) {
      final c = _day(_dateOf(b)).compareTo(_day(_dateOf(a)));
      return c != 0 ? c : _sessionIdx(a).compareTo(_sessionIdx(b));
    });
    return list;
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: range,
    );
    if (picked != null) setState(() => range = picked);
  }

  void _snack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? context.colors.error : null),
    );
  }

  // ── Delete (swipe ও মেনু দুটোই) ──
  Future<bool> _confirmAndDelete(Map<String, dynamic> r) async {
    final session = RecordSessionX.fromDb(r['session']).label;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete daily record?'),
        content: Text(
          '${batchName('${r['batch_id']}')} • ${_cloudDate(_dateOf(r))} • $session\nDelete this daily record?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      await cloud.deleteDailyRecord('${r['id']}');
      return true;
    } catch (e) {
      _snack('Could not delete daily record: $e', isError: true);
      return false;
    }
  }

  Future<void> _deleteFromMenu(Map<String, dynamic> r) async {
    if (await _confirmAndDelete(r) && mounted) {
      setState(() => records.removeWhere((x) => x['id'] == r['id']));
    }
  }

  // ── Edit: আসল Daily Record form-এ খোলে (cost হিসাব সহ) ──
  Future<void> _edit(Map<String, dynamic> r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyRecordPageNew(
          initialBatchId: '${r['batch_id']}',
          initialRecordId: '${r['id']}',
        ),
      ),
    );
    if (mounted) load();
  }

  // ── UI ──
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
                  ? const Center(child: Text('No daily records yet'))
                  : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final list = filtered;

    final items = <Object>[];
    DateTime? currentDay;
    for (final r in list) {
      final d = _day(_dateOf(r));
      if (currentDay == null || d != currentDay) {
        currentDay = d;
        final dayRows = list.where((x) => _day(_dateOf(x)) == d).toList();
        final dayCost = dayRows.fold<double>(0, (sum, x) => sum + _n(x['total_cost']));
        items.add(_DayHeader(d, dayRows.length, dayCost));
      }
      items.add(r);
    }

    return Column(
      children: [
        _filterBar(context),
        _summaryBar(context, list),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No records match this filter'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    if (item is _DayHeader) return _dayHeader(context, item);
                    return _recordCard(context, item as Map<String, dynamic>);
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterBar(BuildContext context) {
    final rangeText = range == null
        ? 'All dates'
        : '${_cloudDate(range!.start)} – ${_cloudDate(range!.end)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          DropdownButtonFormField<String?>(
            value: selectedBatchId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Batch',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All batches')),
              ...batches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name))),
            ],
            onChanged: (v) => setState(() => selectedBatchId = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(rangeText, overflow: TextOverflow.ellipsis),
                ),
              ),
              if (range != null)
                IconButton(
                  tooltip: 'Clear date filter',
                  onPressed: () => setState(() => range = null),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBar(BuildContext context, List<Map<String, dynamic>> list) {
    double sum(String k) => list.fold<double>(0, (t, r) => t + _n(r[k]));
    final eggs = sum('eggs_collected');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Card(
        color: context.colors.brandSoft,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text('${list.length} record', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Feed ${_fmt(sum('feed_kg'))} kg'),
              if (eggs > 0) Text('Eggs ${eggs.round()}'),
              Text('Mortality ${sum('mortality').round()}'),
              Text('Cost $_taka${_fmt(sum('total_cost').round())}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayHeader(BuildContext context, _DayHeader h) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_cloudDate(h.day)}  •  ${h.count} ${h.count == 1 ? 'record' : 'records'}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (h.cost > 0)
            Text('$_taka${_fmt(h.cost.round())}', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _recordCard(BuildContext context, Map<String, dynamic> r) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final session = RecordSessionX.fromDb(r['session']);
    final remarks = '${r['remarks'] ?? ''}'.trim();

    final feedKg = _n(r['feed_kg']);
    final feedType = '${r['feed_type'] ?? ''}'.trim();
    final water = _n(r['water_litre']);
    final eggs = _n(r['eggs_collected']);
    final damaged = _n(r['eggs_damaged']);
    final dead = _n(r['mortality']);
    final avgW = _n(r['avg_weight_kg']);
    final medCost = _n(r['medicine_cost']);
    final vacCost = _n(r['vaccine_cost']);
    final total = _n(r['total_cost']);

    return Dismissible(
      key: ValueKey('${r['id']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmAndDelete(r),
      onDismissed: (_) => setState(() => records.removeWhere((x) => x['id'] == r['id'])),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: colors.error, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _edit(r),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(session.icon, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(session.shortLabel,
                        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        batchName('${r['batch_id']}'),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _edit(r);
                        if (v == 'delete') _deleteFromMenu(r);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (feedKg > 0 || feedType.isNotEmpty)
                        _chip(
                          context,
                          Icons.restaurant,
                          feedType.isEmpty
                              ? '${_fmt(feedKg)} kg'
                              : (feedKg > 0 ? '$feedType • ${_fmt(feedKg)} kg' : feedType),
                        ),
                      if (water > 0) _chip(context, Icons.water_drop_outlined, '${_fmt(water)} L'),
                      if (eggs > 0)
                        _chip(context, Icons.egg_outlined,
                            damaged > 0 ? '${eggs.round()} (${damaged.round()} damaged)' : '${eggs.round()}'),
                      if (avgW > 0) _chip(context, Icons.scale_outlined, '${avgW.toStringAsFixed(2)} kg'),
                      if (medCost > 0) _chip(context, Icons.medication_outlined, '$_taka${_fmt(medCost.round())}'),
                      if (vacCost > 0) _chip(context, Icons.vaccines_outlined, '$_taka${_fmt(vacCost.round())}'),
                      if (dead > 0)
                        _chip(context, Icons.warning_amber_rounded, 'Dead ${dead.round()}',
                            color: colors.error),
                      if (total > 0)
                        _chip(context, Icons.payments_outlined, '$_taka${_fmt(total.round())}',
                            color: theme.colorScheme.primary),
                    ],
                  ),
                ),
                if (remarks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: Text(remarks,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text, {Color? color}) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12.5, color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DayHeader {
  final DateTime day;
  final int count;
  final double cost;
  _DayHeader(this.day, this.count, this.cost);
}

// ───────────────────────── Batch list এর জন্য table frame ─────────────────────────

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
