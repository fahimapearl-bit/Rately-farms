import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SalesScreenNew extends StatefulWidget {
  const SalesScreenNew({super.key});

  @override
  State<SalesScreenNew> createState() => _SalesScreenNewState();
}

// Backward compatibility alias for main.dart
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
  final _buyer = TextEditingController();
  final _remarks = TextEditingController();

  static const types = [
    'Bird',
    'Table Eggs',
    'Hatching Eggs',
    'Litter',
  ];

  List<Map<String, dynamic>> batches = [];
  List<Map<String, dynamic>> sales = [];
  String? batchId;
  String type = 'Bird';
  DateTime date = DateTime.now();
  bool loading = true;
  bool saving = false;

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: const OutlineInputBorder(),
      );

  @override
  void initState() {
    super.initState();
    _qty.addListener(() => setState(() {}));
    _weight.addListener(() => setState(() {}));
    _price.addListener(() => setState(() {}));
    _loadBatches();
  }

  @override
  void dispose() {
    _qty.dispose();
    _weight.dispose();
    _price.dispose();
    _buyer.dispose();
    _remarks.dispose();
    super.dispose();
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _loadBatches() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await client
          .from('batches')
          .select('id, name, production_type, production_category, breed, initial_birds, status')
          .eq('user_id', user.id)
          .order('start_date', ascending: false);
      batches = List<Map<String, dynamic>>.from(rows)
          .where((b) => (b['status'] ?? 'Active') == 'Active')
          .toList();
      if (batches.isNotEmpty) batchId = batches.first['id'];
      await _loadSales();
    } catch (e) {
      _msg('Failed to load batches: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadSales() async {
    if (batchId == null) return;
    try {
      final rows = await client
          .from('sales')
          .select()
          .eq('batch_id', batchId!)
          .order('sale_date', ascending: false);
      if (mounted) {
        setState(() => sales = List<Map<String, dynamic>>.from(rows));
      }
    } catch (e) {
      _msg('Failed to load sales: $e', error: true);
    }
  }

  Map<String, dynamic>? get batch =>
      batches.where((b) => b['id'] == batchId).firstOrNull;

  String _label(Map<String, dynamic> b) {
    final t = (b['production_type'] ?? '')
        .toString()
        .replaceAll(' Production', '');
    final c = (b['production_category'] ?? '').toString();
    return '${b['name']} ($t - $c)';
  }

  // Live total calculation
  double get currentTotal {
    final q = int.tryParse(_qty.text.trim()) ?? 0;
    final w = double.tryParse(_weight.text.trim()) ?? 0.0;
    final p = double.tryParse(_price.text.trim()) ?? 0.0;

    if (type == 'Bird') {
      if (w > 0) return w * p;
      return q * p;
    }
    return q * p;
  }

  // Calculate amount for recorded sale
  double _calcAmount(Map<String, dynamic> s) {
    final q = (s['quantity'] ?? 0) as num;
    final w = (s['weight_kg'] as num?)?.toDouble();
    final p = ((s['unit_price'] ?? 0) as num).toDouble();
    final t = s['sale_type'] ?? '';

    if (t == 'Bird' && w != null && w > 0) {
      return w * p;
    }
    return q * p;
  }

  double get birdSalesTotal => sales
      .where((s) => s['sale_type'] == 'Bird')
      .fold(0.0, (sum, s) => sum + _calcAmount(s));

  int get birdsSoldQty => sales
      .where((s) => s['sale_type'] == 'Bird')
      .fold(0, (sum, s) => sum + ((s['quantity'] ?? 0) as int));

  double get eggSalesTotal => sales
      .where((s) => s['sale_type'] == 'Table Eggs' || s['sale_type'] == 'Hatching Eggs')
      .fold(0.0, (sum, s) => sum + _calcAmount(s));

  double get litterSalesTotal => sales
      .where((s) => s['sale_type'] == 'Litter')
      .fold(0.0, (sum, s) => sum + _calcAmount(s));

  double get totalRevenue =>
      sales.fold(0.0, (sum, s) => sum + _calcAmount(s));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || batchId == null) return;

    final q = int.tryParse(_qty.text.trim());
    final p = double.tryParse(_price.text.trim());
    final w = type == 'Bird' ? double.tryParse(_weight.text.trim()) : null;

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

    setState(() => saving = true);
    try {
      await client.from('sales').insert({
        'user_id': client.auth.currentUser!.id,
        'batch_id': batchId,
        'sale_date': date.toIso8601String().split('T').first,
        'sale_type': type,
        'quantity': q,
        'weight_kg': w,
        'unit_price': p,
        'buyer_name': _buyer.text.trim(),
        'remarks': _remarks.text.trim(),
      });

      _qty.clear();
      _weight.clear();
      _price.clear();
      _buyer.clear();
      _remarks.clear();

      _msg('Sale saved successfully');
      await _loadSales();
    } catch (e) {
      _msg('Save failed: $e', error: true);
    }
    if (mounted) setState(() => saving = false);
  }

  Future<bool> _delete(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete sale record?'),
        content: Text(
            '${s['sale_type']} • ${_calcAmount(s).toStringAsFixed(2)} tk'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return false;

    try {
      await client.from('sales').delete().eq('id', s['id']);
      setState(() => sales.remove(s));
      _msg('Record deleted');
      return true;
    } catch (e) {
      _msg('Delete failed: $e', error: true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
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

    final curBatch = batch;
    final initialBirds = (curBatch?['initial_birds'] ?? 0) as int;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSales,
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
                        .map((b) => DropdownMenuItem(
                              value: b['id'] as String,
                              child: Text(
                                _label(b),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => batchId = v);
                      _loadSales();
                    },
                  ),
                  if (curBatch != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Initial Birds: $initialBirds | Sold so far: $birdsSoldQty birds',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: type,
                    isExpanded: true,
                    decoration: _dec('Sale type', icon: Icons.category),
                    items: types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: 10),
                  if (type == 'Bird') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            decoration: _dec('Birds count', icon: Icons.numbers),
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
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: _dec('Weight (kg)', icon: Icons.scale),
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
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: _dec('Price (tk/kg)', icon: Icons.payments),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) return 'Enter rate';
                        return null;
                      },
                    ),
                  ] else if (type == 'Table Eggs' || type == 'Hatching Eggs') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            decoration: _dec('Egg count (pcs)', icon: Icons.egg),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'Enter eggs';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                _dec('Price (tk/pc)', icon: Icons.payments),
                            validator: (v) {
                              final n = double.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'Enter rate';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Litter
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            decoration:
                                _dec('Sacks (বস্তা)', icon: Icons.shopping_bag),
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
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                _dec('Price (tk/sack)', icon: Icons.payments),
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
                  // Live Total Card
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estimated Total:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          '${currentTotal.toStringAsFixed(2)} tk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
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
                          decoration:
                              _dec('Buyer name (optional)', icon: Icons.person),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _remarks,
                          decoration: _dec('Remarks', icon: Icons.comment),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text('Date: ${date.toIso8601String().split('T').first}'),
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
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save Sale'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Summary Card
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Recent sales (swipe left to delete)',
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
              String detail = '';
              if (t == 'Bird') {
                final q = s['quantity'] ?? 0;
                final w = (s['weight_kg'] as num?)?.toDouble() ?? 0.0;
                final p = s['unit_price'] ?? 0;
                detail = '$q birds, ${w.toStringAsFixed(1)} kg @ $p tk/kg';
              } else if (t == 'Table Eggs' || t == 'Hatching Eggs') {
                final q = s['quantity'] ?? 0;
                final p = s['unit_price'] ?? 0;
                detail = '$q pcs @ $p tk/pc';
              } else {
                final q = s['quantity'] ?? 0;
                final p = s['unit_price'] ?? 0;
                detail = '$q sacks @ $p tk/sack';
              }
              if (buyer.isNotEmpty) detail += ' • $buyer';

              return Dismissible(
                key: ValueKey(s['id']),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
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
                    color: t == 'Bird'
                        ? Colors.green
                        : t == 'Litter'
                            ? Colors.brown
                            : Colors.orange,
                  ),
                  title: Text(
                    '$t  •  ${amt.toStringAsFixed(2)} tk',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('$dateStr  |  $detail'),
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
