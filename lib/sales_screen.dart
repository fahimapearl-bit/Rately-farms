import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';

class SalesScreenNew extends StatefulWidget {
  const SalesScreenNew({super.key});

  @override
  State<SalesScreenNew> createState() => _SalesScreenNewState();
}

/// Backward compatibility alias for main.dart
class SalesScreenV2 extends StatelessWidget {
  const SalesScreenV2({super.key});

  @override
  Widget build(BuildContext context) => const SalesScreenNew();
}

class _SalesScreenNewState extends State<SalesScreenNew> {
  final client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _qty = TextEditingController();
  final _weight = TextEditingController();
  final _price = TextEditingController();
  final _paid = TextEditingController();
  final _buyer = TextEditingController();
  final _remarks = TextEditingController();
  final _editReason = TextEditingController();

  static const types = [
    'Bird',
    'Table Eggs',
    'Hatching Eggs',
    'Damaged Eggs',
    'Litter',
  ];

  List<Map<String, dynamic>> batches = [];
  List<Map<String, dynamic>> sales = [];

  /// Per-batch aggregates loaded from Supabase.
  int _producedGood = 0;
  int _producedDamaged = 0;
  int _addedBirds = 0; // Σ bird_additions.quantity
  int _deadBirds = 0; // Σ daily_records.mortality
  /// All average-weight samples for the batch, from weekly_weights.
  List<WeightPoint> _weightPoints = [];

  String? batchId;
  String type = 'Bird';
  DateTime date = DateTime.now();
  bool loading = true;
  bool saving = false;
  bool stockLoading = false;

  /// Non-null while a correction (edit) is in progress.
  /// Edit = reverse the old row + insert a corrected row.
  Map<String, dynamic>? _reversalTarget;

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: const OutlineInputBorder(),
      );

  @override
  void initState() {
    super.initState();
    _qty.addListener(() => setState(() {}));
    _weight.addListener(() => setState(() {}));
    _price.addListener(() => setState(() {}));
    _paid.addListener(() => setState(() {}));
    _loadBatches();
  }

  @override
  void dispose() {
    _qty.dispose();
    _weight.dispose();
    _price.dispose();
    _paid.dispose();
    _buyer.dispose();
    _remarks.dispose();
    _editReason.dispose();
    super.dispose();
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? colors.error : colors.brand,
      ),
    );
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Batch helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? get batch =>
      batches.where((b) => b['id'] == batchId).firstOrNull;

  bool get isEggBatch {
    final t = (batch?['production_type'] ?? '').toString().toLowerCase();
    return t.contains('egg');
  }

  /// 'table' | 'hatching' | null (meat / unknown)
  String? get eggPurpose {
    final p = (batch?['egg_purpose'] ?? '').toString().toLowerCase().trim();
    if (p == 'hatching') return 'hatching';
    if (p == 'table') return 'table';
    if (isEggBatch) return 'table';
    return null;
  }

  String _label(Map<String, dynamic> b) {
    final t =
        (b['production_type'] ?? '').toString().replaceAll(' Production', '');
    final c = (b['production_category'] ?? '').toString();
    final purpose = (b['egg_purpose'] ?? '').toString();
    final purposeTag = purpose.isEmpty
        ? ''
        : purpose == 'hatching'
            ? ' · Hatching'
            : ' · Table';
    return '${b['name']} ($t - $c$purposeTag)';
  }

  /// Sale types allowed for the currently selected batch.
  List<String> get allowedTypes {
    if (!isEggBatch) {
      return const ['Bird', 'Litter'];
    }
    if (eggPurpose == 'hatching') {
      return const ['Hatching Eggs', 'Damaged Eggs', 'Litter'];
    }
    return const ['Table Eggs', 'Damaged Eggs', 'Litter'];
  }

  // ---------------------------------------------------------------------------
  // Live stock (computed from daily_records + bird_additions + sales)
  // ---------------------------------------------------------------------------

  /// Only active (non-reversed) sales count towards stock & revenue.
  List<Map<String, dynamic>> get activeSales =>
      sales.where((s) => s['is_reversed'] != true).toList();

  int _sumQty(String saleType) => activeSales
      .where((s) => s['sale_type'] == saleType)
      .fold(0, (sum, s) => sum + _int(s['quantity']));

  int get soldTable => _sumQty('Table Eggs');
  int get soldHatching => _sumQty('Hatching Eggs');
  int get soldDamaged => _sumQty('Damaged Eggs');
  int get soldBirds => _sumQty('Bird');

  /// Birds currently in the flock:
  /// initial + Σ additions − Σ mortality − Σ birds sold
  int get flockCount {
    final initial = _int(batch?['initial_birds']);
    final c = initial + _addedBirds - _deadBirds - soldBirds;
    return c.clamp(0, 1 << 30);
  }

  /// Flock weight for today: exact weekly_weights record, otherwise linear
  /// interpolation between the nearest earlier and later records; the
  /// nearest one-sided value when only one side exists; null when the
  /// batch has no weight data at all. Never stored, so it can't drift.
  InterpWeight? get _weightToday =>
      interpolateWeight(_weightPoints, DateTime.now());

  double get flockWeightKg => (_weightToday?.kg ?? 0) * flockCount;

  int get goodEggStock {
    final produced = _producedGood;
    if (eggPurpose == 'hatching') {
      return (produced - soldHatching).clamp(0, 1 << 30);
    }
    return (produced - soldTable).clamp(0, 1 << 30);
  }

  int get damagedEggStock =>
      (_producedDamaged - soldDamaged).clamp(0, 1 << 30);

  int get availableForCurrentType {
    switch (type) {
      case 'Table Eggs':
      case 'Hatching Eggs':
        return goodEggStock;
      case 'Damaged Eggs':
        return damagedEggStock;
      default:
        return 1 << 30; // no stock limit for Bird / Litter here
    }
  }

  // ---------------------------------------------------------------------------
  // Money helpers
  // ---------------------------------------------------------------------------

  double get currentTotal {
    final q = int.tryParse(_qty.text.trim()) ?? 0;
    final w = double.tryParse(_weight.text.trim()) ?? 0.0;
    final p = double.tryParse(_price.text.trim()) ?? 0.0;
    if (type == 'Bird' && w > 0) return w * p;
    return q * p;
  }

  double _calcAmount(Map<String, dynamic> s) {
    final q = (s['quantity'] ?? 0) as num;
    final w = (s['weight_kg'] as num?)?.toDouble();
    final p = ((s['unit_price'] ?? 0) as num).toDouble();
    final t = s['sale_type'] ?? '';
    if (t == 'Bird' && w != null && w > 0) return w * p;
    return q * p;
  }

  double _sumRevenue(String saleType) => activeSales
      .where((s) => s['sale_type'] == saleType)
      .fold(0.0, (sum, s) => sum + _calcAmount(s));

  double get birdSalesTotal => _sumRevenue('Bird');

  double get eggSalesTotal => activeSales
      .where((s) =>
          s['sale_type'] == 'Table Eggs' ||
          s['sale_type'] == 'Hatching Eggs' ||
          s['sale_type'] == 'Damaged Eggs')
      .fold(0.0, (sum, s) => sum + _calcAmount(s));

  double get litterSalesTotal => _sumRevenue('Litter');

  double get totalRevenue =>
      activeSales.fold(0.0, (sum, s) => sum + _calcAmount(s));

  double get totalPaid => activeSales.fold(
      0.0, (sum, s) => sum + ((s['paid_amount'] ?? 0) as num).toDouble());

  double get totalDue => activeSales.fold(
      0.0, (sum, s) => sum + ((s['due_amount'] ?? 0) as num).toDouble());

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  Future<void> _loadBatches() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await client
          .from('batches')
          .select(
            'id, name, production_type, production_category, breed, '
            'initial_birds, status, egg_purpose',
          )
          .eq('user_id', user.id)
          .order('start_date', ascending: false);

      batches = List<Map<String, dynamic>>.from(rows)
          .where((b) => (b['status'] ?? 'Active') == 'Active')
          .toList();

      if (batches.isNotEmpty) {
        batchId = batches.first['id']?.toString();
        _syncTypeToBatch();
        await _loadSalesAndStock();
      }
    } catch (e) {
      _msg('Failed to load batches: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadSalesAndStock() async {
    if (batchId == null) return;
    setState(() => stockLoading = true);
    try {
      final salesRows = await client
          .from('sales')
          .select()
          .eq('batch_id', batchId!)
          .order('sale_date', ascending: false);

      int good = 0;
      int damaged = 0;
      int dead = 0;
      try {
        final dailyRows = await client
            .from('daily_records')
            .select('eggs_good, eggs_damaged, eggs_collected, mortality')
            .eq('batch_id', batchId!);

        for (final r in List<Map<String, dynamic>>.from(dailyRows)) {
          var g = _int(r['eggs_good']);
          final d = _int(r['eggs_damaged']);
          // Legacy rows: only eggs_collected filled
          if (g == 0 && d == 0) {
            g = _int(r['eggs_collected']);
          }
          good += g;
          damaged += d;
          dead += _int(r['mortality']);
        }
      } catch (_) {
        // daily_records columns may vary; stock stays 0
      }

      int added = 0;
      try {
        final addRows = await client
            .from('bird_additions')
            .select('quantity')
            .eq('batch_id', batchId!);
        added = List<Map<String, dynamic>>.from(addRows)
            .fold(0, (sum, r) => sum + _int(r['quantity']));
      } catch (_) {
        // bird_additions may not exist for very old installs
      }

      List<WeightPoint> wPoints = [];
      try {
        final wRows = await client
            .from('weekly_weights')
            .select('weight_date, average_weight_kg')
            .eq('batch_id', batchId!);
        for (final r in List<Map<String, dynamic>>.from(wRows)) {
          final d = DateTime.tryParse('${r['weight_date']}');
          final w = (r['average_weight_kg'] as num?)?.toDouble();
          if (d != null && w != null && w > 0) {
            wPoints.add(WeightPoint(d, w));
          }
        }
      } catch (_) {
        // weekly_weights may be empty; weight card shows —
      }

      if (!mounted) return;
      setState(() {
        sales = List<Map<String, dynamic>>.from(salesRows);
        _producedGood = good;
        _producedDamaged = damaged;
        _deadBirds = dead;
        _addedBirds = added;
        _weightPoints = wPoints;
      });
    } catch (e) {
      _msg('Failed to load sales/stock: $e', error: true);
    }
    if (mounted) setState(() => stockLoading = false);
  }

  void _syncTypeToBatch() {
    final allowed = allowedTypes;
    if (!allowed.contains(type)) {
      type = allowed.first;
    }
  }

  // ---------------------------------------------------------------------------
  // Save / Edit (reversal) / Delete
  // ---------------------------------------------------------------------------

  void _fillFormFromSale(Map<String, dynamic> s) {
    type = s['sale_type'] ?? type;
    _qty.text = '${_int(s['quantity'])}';
    final w = (s['weight_kg'] as num?)?.toDouble();
    _weight.text = w == null ? '' : w.toString();
    _price.text = '${((s['unit_price'] ?? 0) as num).toDouble()}';
    _paid.text = '${((s['paid_amount'] ?? 0) as num).toDouble()}';
    _buyer.text = (s['buyer_name'] ?? '').toString();
    _remarks.text = (s['remarks'] ?? '').toString();
    final d = s['sale_date']?.toString();
    if (d != null && d.length >= 10) {
      date = DateTime.tryParse(d) ?? date;
    }
  }

  void _clearForm() {
    _qty.clear();
    _weight.clear();
    _price.clear();
    _paid.clear();
    _buyer.clear();
    _remarks.clear();
    _editReason.clear();
    _reversalTarget = null;
    date = DateTime.now();
  }

  /// Starts an edit: asks for a reason, fills the form with the old values.
  Future<void> _startEdit(Map<String, dynamic> s) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The old record will be marked as reversed (kept for audit) '
              'and a corrected record will be saved.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editReason,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              c,
              _editReason.text.trim(),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() {
      _reversalTarget = s;
      _fillFormFromSale(s);
      _editReason.clear();
    });
    _msg('Correct the values and press Save');
  }

  void _cancelEdit() {
    setState(_clearForm);
    _msg('Edit cancelled');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || batchId == null) return;

    final q = int.tryParse(_qty.text.trim());
    final p = double.tryParse(_price.text.trim());
    final w = type == 'Bird' ? double.tryParse(_weight.text.trim()) : null;
    final paid = double.tryParse(_paid.text.trim()) ?? 0;

    if (q == null || q <= 0) {
      _msg('Enter valid quantity', error: true);
      return;
    }
    if (p == null || p < 0) {
      _msg('Enter valid price', error: true);
      return;
    }
    if (type == 'Bird' && (w == null || w <= 0)) {
      _msg('Please enter total live weight in kg', error: true);
      return;
    }

    final total = type == 'Bird' && (w ?? 0) > 0 ? w! * p : q * p;
    if (paid > total) {
      _msg('Paid amount cannot exceed total ($total tk)', error: true);
      return;
    }
    final due = total - paid;

    // Egg stock validation — excludes reversed rows and, while editing,
    // the row being corrected (its quantity is going back to stock).
    if (type == 'Table Eggs' ||
        type == 'Hatching Eggs' ||
        type == 'Damaged Eggs') {
      final editingQty =
          _reversalTarget != null ? _int(_reversalTarget!['quantity']) : 0;
      final editingIsSameType =
          _reversalTarget != null && _reversalTarget!['sale_type'] == type;
      final effectiveAvailable =
          availableForCurrentType + (editingIsSameType ? editingQty : 0);
      if (q > effectiveAvailable) {
        _msg('Not enough stock. Available: $effectiveAvailable pcs',
            error: true);
        return;
      }
      // Purpose mismatch guard
      if (type == 'Table Eggs' && eggPurpose == 'hatching') {
        _msg('This is a Hatching batch. Use Hatching Eggs sale type.',
            error: true);
        return;
      }
      if (type == 'Hatching Eggs' && eggPurpose == 'table') {
        _msg('This is a Table batch. Use Table Eggs sale type.', error: true);
        return;
      }
    }

    // Bird count validation: cannot sell more birds than are in the flock.
    if (type == 'Bird') {
      final editingQty = _reversalTarget != null
          ? _int(_reversalTarget!['quantity'])
          : 0;
      final editingIsSameType =
          _reversalTarget != null && _reversalTarget!['sale_type'] == 'Bird';
      final effectiveFlock =
          flockCount + (editingIsSameType ? editingQty : 0);
      if (q > effectiveFlock) {
        _msg('Only $effectiveFlock birds in flock. Cannot sell $q.',
            error: true);
        return;
      }
    }

    setState(() => saving = true);
    try {
      final row = {
        'user_id': client.auth.currentUser!.id,
        'batch_id': batchId,
        'sale_date': date.toIso8601String().split('T').first,
        'sale_type': type,
        'quantity': q,
        'weight_kg': w,
        'unit_price': p,
        'paid_amount': paid,
        'due_amount': due,
        'buyer_name': _buyer.text.trim(),
        'remarks': _remarks.text.trim(),
      };

      if (_reversalTarget != null) {
        // 1) reverse the old row, 2) insert the corrected row.
        await client.from('sales').update({
          'is_reversed': true,
          'edit_reason': _reversalTarget!['edit_reason'] ??
              'corrected on ${DateTime.now().toIso8601String()}',
          'edited_at': DateTime.now().toIso8601String(),
        }).eq('id', _reversalTarget!['id']);

        await client
            .from('sales')
            .insert({...row, 'corrected_from_id': _reversalTarget!['id']});

        _msg('Sale corrected (old record kept as reversed)');
      } else {
        await client.from('sales').insert(row);
        _msg('Sale saved successfully');
      }

      setState(_clearForm);
      await _loadSalesAndStock();
    } catch (e) {
      _msg('Save failed: $e', error: true);
      // If the insert after reversal failed, un-reverse the old row so
      // stock is not silently lost.
      if (_reversalTarget != null) {
        try {
          await client.from('sales').update({
            'is_reversed': false,
            'edited_at': null,
          }).eq('id', _reversalTarget!['id']);
        } catch (_) {}
      }
    }
    if (mounted) setState(() => saving = false);
  }

  Future<bool> _delete(Map<String, dynamic> s) async {
    final colors = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete sale record?'),
        content: Text(
          '${s['sale_type']} • ${_calcAmount(s).toStringAsFixed(2)} tk',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Delete', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );

    if (ok != true) return false;

    try {
      await client.from('sales').delete().eq('id', s['id']);
      _msg('Record deleted');
      await _loadSalesAndStock();
      return true;
    } catch (e) {
      _msg('Delete failed: $e', error: true);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _stockCard(AppColors colors) {
    final w = _weightToday;
    if (!isEggBatch) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.brandSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.line),
        ),
        child: stockLoading
            ? const LinearProgressIndicator(minHeight: 2)
            : Row(
                children: [
                  Expanded(
                    child: _stat(
                      'Birds in flock',
                      '$flockCount',
                      'init ${_int(batch?['initial_birds'])} + add $_addedBirds − dead $_deadBirds − sold $soldBirds',
                      colors,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _stat(
                      'Flock weight',
                      w == null
                          ? '—'
                          : '${(w.kg * flockCount).toStringAsFixed(1)} kg'
                              '${w.isEstimated ? ' [est.]' : ''}',
                      w == null
                          ? 'no weight records yet'
                          : '@ ${w.kg.toStringAsFixed(3)} kg/bird'
                              '${w.isEstimated ? ' [est.]' : ''}',
                      colors,
                    ),
                  ),
                ],
              ),
      );
    }

    final purposeLabel =
        eggPurpose == 'hatching' ? 'Hatching eggs' : 'Table eggs';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.successSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Egg stock ($purposeLabel)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.brand,
            ),
          ),
          const SizedBox(height: 6),
          if (stockLoading)
            const LinearProgressIndicator(minHeight: 2)
          else
            Row(
              children: [
                Expanded(
                  child: _stat(
                    'Good in stock',
                    '$goodEggStock',
                    'produced $_producedGood − sold ${eggPurpose == 'hatching' ? soldHatching : soldTable}',
                    colors,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    'Damaged in stock',
                    '$damagedEggStock',
                    'produced $_producedDamaged − sold $soldDamaged',
                    colors,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String sub, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colors.muted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: colors.ink,
          ),
        ),
        Text(
          sub,
          style: TextStyle(fontSize: 10, color: colors.muted),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (batches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sales')),
        body: const Center(
          child: Text('No active batch found. Please add a batch first.'),
        ),
      );
    }

    final allowed = allowedTypes;
    final typeValue = allowed.contains(type) ? type : allowed.first;
    final editing = _reversalTarget != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Sales — correcting…' : 'Sales'),
        actions: [
          if (editing)
            TextButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel edit'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSalesAndStock,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSalesAndStock,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: batchId,
                    isExpanded: true,
                    decoration: _dec('Batch', icon: Icons.inventory_2),
                    items: batches
                        .map(
                          (b) => DropdownMenuItem(
                            value: b['id']?.toString(),
                            child: Text(
                              _label(b),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: editing
                        ? null
                        : (v) async {
                            setState(() {
                              batchId = v;
                              _syncTypeToBatch();
                            });
                            await _loadSalesAndStock();
                          },
                  ),
                  const SizedBox(height: 10),
                  _stockCard(colors),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: typeValue,
                    isExpanded: true,
                    decoration: _dec('Sale type', icon: Icons.category),
                    items: allowed
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: 10),

                  // ---- fields by type ----
                  if (type == 'Bird') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            decoration: _dec('Birds count',
                                icon: Icons.numbers),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'Enter quantity';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _weight,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration:
                                _dec('Weight (kg)', icon: Icons.scale),
                            validator: (v) {
                              final n = double.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'Enter weight';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          _dec('Price (tk/kg)', icon: Icons.payments),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) return 'Enter rate';
                        return null;
                      },
                    ),
                  ] else if (type == 'Table Eggs' ||
                      type == 'Hatching Eggs' ||
                      type == 'Damaged Eggs') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            decoration: _dec(
                              'Egg count (pcs)',
                              icon: Icons.egg,
                            ),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'Enter eggs';
                              final editingQty = _reversalTarget != null &&
                                      _reversalTarget!['sale_type'] == type
                                  ? _int(_reversalTarget!['quantity'])
                                  : 0;
                              final avail =
                                  availableForCurrentType + editingQty;
                              if (n > avail) return 'Max $avail in stock';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _price,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _dec(
                              type == 'Hatching Eggs'
                                  ? 'Price (tk/pc) \~35+'
                                  : type == 'Damaged Eggs'
                                      ? 'Price (tk/pc)'
                                      : 'Price (tk/pc) \~12',
                              icon: Icons.payments,
                            ),
                            validator: (v) {
                              final n = double.tryParse((v ?? '').trim());
                              if (n == null || n < 0) return 'Enter rate';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Available: $availableForCurrentType pcs',
                      style: TextStyle(
                        fontSize: 12,
                        color: availableForCurrentType > 0
                            ? colors.brand
                            : colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    // Litter
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            decoration: _dec(
                              'Sacks (বস্তা)',
                              icon: Icons.shopping_bag,
                            ),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'Enter sacks';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _price,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _dec(
                              'Price (tk/sack)',
                              icon: Icons.payments,
                            ),
                            validator: (v) {
                              final n = double.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'Enter rate';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.successSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.brandSoft),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.brand,
                              ),
                            ),
                            Text(
                              '${currentTotal.toStringAsFixed(2)} tk',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.brand,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _paid,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _dec('Paid amount (tk)',
                              icon: Icons.request_quote),
                          validator: (v) {
                            final n = double.tryParse((v ?? '').trim());
                            if (n == null || n < 0) return 'Enter paid amount';
                            if (n > currentTotal) {
                              return 'Cannot exceed total';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Due: ${(currentTotal - (double.tryParse(_paid.text.trim()) ?? 0)).toStringAsFixed(2)} tk',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _buyer,
                          decoration: _dec(
                            'Buyer name (optional)',
                            icon: Icons.person,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _remarks,
                          decoration:
                              _dec('Remarks', icon: Icons.comment),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Date: ${date.toIso8601String().split('T').first}',
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => date = d);
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.card,
                              ),
                            )
                          : Icon(editing ? Icons.fact_check : Icons.save),
                      label: Text(editing ? 'Save Correction' : 'Save Sale'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Bird sales', birdSalesTotal),
                    _row('Egg sales', eggSalesTotal),
                    _row('Litter sales', litterSalesTotal),
                    const Divider(),
                    _row('Total revenue', totalRevenue, bold: true),
                    _row('Total paid', totalPaid),
                    _row('Total due', totalDue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All sales — tap ✎ to edit (kept as reversal), swipe left to delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (sales.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No sales records yet')),
              ),
            ...sales.map((s) {
              final amt = _calcAmount(s);
              final t = s['sale_type'] ?? '';
              final dateStr = s['sale_date'] ?? '';
              final buyer = (s['buyer_name'] ?? '').toString();
              final reversed = s['is_reversed'] == true;
              String detail = '';
              if (t == 'Bird') {
                final q = s['quantity'] ?? 0;
                final w = (s['weight_kg'] as num?)?.toDouble() ?? 0.0;
                final p = s['unit_price'] ?? 0;
                detail = '$q birds, ${w.toStringAsFixed(1)} kg @ $p tk/kg';
              } else if (t == 'Table Eggs' ||
                  t == 'Hatching Eggs' ||
                  t == 'Damaged Eggs') {
                detail =
                    '${s['quantity']} pcs @ ${s['unit_price']} tk/pc';
              } else {
                detail =
                    '${s['quantity']} sacks @ ${s['unit_price']} tk/sack';
              }
              if (buyer.isNotEmpty) detail += ' • $buyer';
              final paid = ((s['paid_amount'] ?? 0) as num).toDouble();
              final due = ((s['due_amount'] ?? 0) as num).toDouble();
              if (due > 0) detail += ' • due ${due.toStringAsFixed(0)} tk';

              return Opacity(
                opacity: reversed ? 0.45 : 1.0,
                child: Dismissible(
                  key: ValueKey(s['id']),
                  direction: reversed
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: Container(
                    color: colors.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(Icons.delete, color: colors.card),
                  ),
                  confirmDismiss: (_) => _delete(s),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      t == 'Bird'
                          ? Icons.sell
                          : t == 'Litter'
                              ? Icons.shopping_bag
                              : Icons.egg,
                      color: reversed
                          ? colors.muted
                          : t == 'Bird'
                              ? colors.brand
                              : colors.warning,
                    ),
                    title: Text(
                      reversed
                          ? '$t • REVERSED (corrected)'
                          : '$t  •  ${amt.toStringAsFixed(2)} tk',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$dateStr  |  $detail\npaid ${paid.toStringAsFixed(0)} / due ${due.toStringAsFixed(0)} tk',
                    ),
                    isThreeLine: true,
                    trailing: reversed
                        ? const Icon(Icons.undo, size: 18)
                        : IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: 'Edit (reversal + correction)',
                            onPressed: saving ? null : () => _startEdit(s),
                          ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double val, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '${val.toStringAsFixed(2)} tk',
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}

/// One (date, kg) sample from weekly_weights.
class WeightPoint {
  final DateTime date;
  final double kg;
  const WeightPoint(this.date, this.kg);
}

/// Result of a weight lookup: the value plus whether it was estimated.
class InterpWeight {
  final double kg;
  final bool isEstimated;
  const InterpWeight(this.kg, this.isEstimated);
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Linear interpolation of the batch's average weight on [day].
///
/// - Exact record on that date -> (record value, isEstimated: false).
/// - Between two records       -> linear interpolation, isEstimated: true.
/// - Only one side exists      -> nearest value, no extrapolation, est.
/// - No records at all         -> null.
InterpWeight? interpolateWeight(List<WeightPoint> points, DateTime day) {
  if (points.isEmpty) return null;
  final target = _dayOnly(day);
  final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));

  WeightPoint? before;
  WeightPoint? after;
  for (final p in sorted) {
    final d = _dayOnly(p.date);
    if (d.isBefore(target)) {
      before = p;
    } else if (d.isAfter(target)) {
      after = p;
      break;
    } else {
      return InterpWeight(p.kg, false); // exact match
    }
  }

  if (before != null && after != null) {
    final d1 = _dayOnly(before.date);
    final d2 = _dayOnly(after.date);
    final span = d2.difference(d1).inDays;
    if (span <= 0) return InterpWeight(before.kg, true);
    final elapsed = target.difference(d1).inDays;
    final kg = before.kg + (after.kg - before.kg) * elapsed / span;
    return InterpWeight(kg, true);
  }

  // One-sided: use the nearest record, never extrapolate.
  return InterpWeight((before ?? after)!.kg, true);
}
