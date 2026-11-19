import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';

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
    'Damaged Eggs',
    'Litter',
  ];

  List<Map<String, dynamic>> batches = [];
  List<Map<String, dynamic>> sales = [];
  String? batchId;
  String type = 'Bird';
  DateTime date = DateTime.now();
  bool loading = true;
  bool saving = false;

  // Daily records stats for current batch
  int totalGoodEggsCollected = 0;
  int totalDamagedEggsCollected = 0;
  int totalEggsCollected = 0;
  int totalMortality = 0;
  bool loadingStats = false;

  InputDecoration _dec(
    String label, {
    IconData? icon,
    String? helperText,
    String? suffixText,
  }) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        helperText: helperText,
        suffixText: suffixText,
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
    final colors = context.colors;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? colors.error : colors.brand,
      ),
    );
  }

  Future<void> _loadBatches() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await client
          .from('batches')
          .select(
              'id, name, production_type, production_category, breed, initial_birds, additional_birds, status')
          .eq('user_id', user.id)
          .order('start_date', ascending: false);
      batches = List<Map<String, dynamic>>.from(rows)
          .where((b) => (b['status'] ?? 'Active') == 'Active')
          .toList();
      if (batches.isNotEmpty) {
        batchId = batches.first['id'] as String;
      }
      await _loadBatchData();
    } catch (e) {
      _msg('Failed to load batches: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadBatchData() async {
    await Future.wait([
      _loadSales(),
      _loadBatchStats(),
    ]);
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

  Future<void> _loadBatchStats() async {
    if (batchId == null) return;
    if (mounted) setState(() => loadingStats = true);
    try {
      final records = await client
          .from('daily_records')
          .select('eggs_collected, eggs_good, eggs_damaged, mortality')
          .eq('batch_id', batchId!);

      int good = 0;
      int damaged = 0;
      int total = 0;
      int mort = 0;

      for (final r in records) {
        final g = (r['eggs_good'] as num?)?.toInt() ?? 0;
        final d = (r['eggs_damaged'] as num?)?.toInt() ?? 0;
        final t = (r['eggs_collected'] as num?)?.toInt() ?? 0;
        final m = (r['mortality'] as num?)?.toInt() ?? 0;

        good += (g > 0 ? g : (t - d > 0 ? t - d : 0));
        damaged += d;
        total += (t > 0 ? t : (g + d));
        mort += m;
      }

      if (mounted) {
        setState(() {
          totalGoodEggsCollected = good;
          totalDamagedEggsCollected = damaged;
          totalEggsCollected = total;
          totalMortality = mort;
        });
      }
    } catch (e) {
      debugPrint('Failed to load batch daily records: $e');
    } finally {
      if (mounted) setState(() => loadingStats = false);
    }
  }

  Map<String, dynamic>? get batch =>
      batches.where((b) => b['id'] == batchId).firstOrNull;

  bool get isEggBatch {
    final cur = batch;
    if (cur == null) return false;
    final t = (cur['production_type'] ?? '').toString().toLowerCase();
    final c = (cur['production_category'] ?? '').toString().toLowerCase();
    return t.contains('egg') ||
        t.contains('layer') ||
        c.contains('layer') ||
        c.contains('breeder') ||
        totalEggsCollected > 0;
  }

  String _label(Map<String, dynamic> b) {
    final t = (b['production_type'] ?? '')
        .toString()
        .replaceAll(' Production', '');
    final c = (b['production_category'] ?? '').toString();
    return '${b['name']} ($t - $c)';
  }

  // Live total calculation for main entry form
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

  // Calculate amount for any sale record
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

  // Sales totals
  double get birdSalesTotal => sales
      .where((s) => s['sale_type'] == 'Bird')
      .fold(0.0, (sum, s) => sum + _calcAmount(s));

  int get birdsSoldQty => sales
      .where((s) => s['sale_type'] == 'Bird')
      .fold(0, (sum, s) => sum + ((s['quantity'] ?? 0) as int));

  double get tableEggSalesTotal => sales
      .where((s) => s['sale_type'] == 'Table Eggs')
      .fold(0.0, (sum, s) => sum + _calcAmount(s));

  double get hatchingEggSalesTotal => sales
      .where((s) => s['sale_type'] == 'Hatching Eggs')
      .fold(0.0, (sum, s) => sum + _calcAmount(s));

  double get damagedEggSalesTotal => sales
      .where((s) => s['sale_type'] == 'Damaged Eggs')
      .fold(0.0, (sum, s) => sum + _calcAmount(s));

  double get eggSalesTotal =>
      tableEggSalesTotal + hatchingEggSalesTotal + damagedEggSalesTotal;

  double get litterSalesTotal => sales
      .where((s) => s['sale_type'] == 'Litter')
      .fold(0.0, (sum, s) => sum + _calcAmount(s));

  double get totalRevenue =>
      sales.fold(0.0, (sum, s) => sum + _calcAmount(s));

  // Egg sales quantities
  int get soldTableEggsQty => sales
      .where((s) => s['sale_type'] == 'Table Eggs')
      .fold(0, (sum, s) => sum + ((s['quantity'] as num?)?.toInt() ?? 0));

  int get soldHatchingEggsQty => sales
      .where((s) => s['sale_type'] == 'Hatching Eggs')
      .fold(0, (sum, s) => sum + ((s['quantity'] as num?)?.toInt() ?? 0));

  int get soldGoodEggsQty => soldTableEggsQty + soldHatchingEggsQty;

  int get soldDamagedEggsQty => sales
      .where((s) => s['sale_type'] == 'Damaged Eggs')
      .fold(0, (sum, s) => sum + ((s['quantity'] as num?)?.toInt() ?? 0));

  int get soldTotalEggsQty => soldGoodEggsQty + soldDamagedEggsQty;

  // Available in-stock eggs
  int get availableGoodEggs =>
      (totalGoodEggsCollected - soldGoodEggsQty).clamp(0, 99999999);

  int get availableDamagedEggs =>
      (totalDamagedEggsCollected - soldDamagedEggsQty).clamp(0, 99999999);

  int get availableTotalEggs =>
      (totalEggsCollected - soldTotalEggsQty).clamp(0, 99999999);

  // Helper for available egg stock when creating or editing
  int _availableStockFor(String saleType, {int currentEditingQty = 0}) {
    if (saleType == 'Table Eggs' || saleType == 'Hatching Eggs') {
      final base = totalGoodEggsCollected - soldGoodEggsQty + currentEditingQty;
      return base < 0 ? 0 : base;
    } else if (saleType == 'Damaged Eggs') {
      final base =
          totalDamagedEggsCollected - soldDamagedEggsQty + currentEditingQty;
      return base < 0 ? 0 : base;
    }
    return 0;
  }

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

    // Egg stock validation
    if (type == 'Table Eggs' || type == 'Hatching Eggs') {
      final avail = _availableStockFor(type);
      if (totalGoodEggsCollected > 0 && q > avail) {
        _msg(
          'পর্যাপ্ত ভালো ডিম স্টকে নেই! স্টকে অবশিষ্ট: $avail টি (অনুরোধ: $q টি)',
          error: true,
        );
        return;
      }
    } else if (type == 'Damaged Eggs') {
      final avail = _availableStockFor(type);
      if (totalDamagedEggsCollected > 0 && q > avail) {
        _msg(
          'পর্যাপ্ত ভাঙা ডিম স্টকে নেই! স্টকে অবশিষ্ট: $avail টি (অনুরোধ: $q টি)',
          error: true,
        );
        return;
      }
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
      await _loadBatchData();
    } catch (e) {
      _msg('Save failed: $e', error: true);
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> _openEditSaleSheet(Map<String, dynamic> sale) async {
    final colors = context.colors;
    final editQtyCtrl =
        TextEditingController(text: '${sale['quantity'] ?? ''}');
    final editWeightCtrl =
        TextEditingController(text: '${sale['weight_kg'] ?? ''}');
    final editPriceCtrl =
        TextEditingController(text: '${sale['unit_price'] ?? ''}');
    final editBuyerCtrl =
        TextEditingController(text: '${sale['buyer_name'] ?? ''}');
    final editRemarksCtrl =
        TextEditingController(text: '${sale['remarks'] ?? ''}');

    String editType = (sale['sale_type'] ?? 'Bird').toString();
    if (!types.contains(editType)) {
      editType = types.first;
    }

    DateTime editDate = DateTime.tryParse('${sale['sale_date']}') ?? DateTime.now();
    final originalQty = (sale['quantity'] as num?)?.toInt() ?? 0;
    final originalType = sale['sale_type']?.toString();
    final formKey = GlobalKey<FormState>();
    bool isUpdating = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double calcEditTotal() {
              final q = int.tryParse(editQtyCtrl.text.trim()) ?? 0;
              final w = double.tryParse(editWeightCtrl.text.trim()) ?? 0.0;
              final p = double.tryParse(editPriceCtrl.text.trim()) ?? 0.0;
              if (editType == 'Bird') {
                if (w > 0) return w * p;
                return q * p;
              }
              return q * p;
            }

            final editAvailStock = _availableStockFor(
              editType,
              currentEditingQty: (editType == originalType) ? originalQty : 0,
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.edit_note, color: colors.brand),
                              const SizedBox(width: 8),
                              Text(
                                'Edit Sale Record',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colors.ink,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: editType,
                        isExpanded: true,
                        decoration: _dec('Sale type', icon: Icons.category),
                        items: types
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setSheetState(() => editType = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // Stock hint for egg sales
                      if (editType == 'Table Eggs' ||
                          editType == 'Hatching Eggs' ||
                          editType == 'Damaged Eggs') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.noticeBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.noticeBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 16, color: colors.noticeIcon),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  editType == 'Damaged Eggs'
                                      ? 'Available Damaged Eggs: $editAvailStock pcs (incl. current record)'
                                      : 'Available Good Eggs: $editAvailStock pcs (incl. current record)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.noticeText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (editType == 'Bird') ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: editQtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration:
                                    _dec('Birds count', icon: Icons.numbers),
                                onChanged: (_) => setSheetState(() {}),
                                validator: (v) {
                                  final n = int.tryParse((v ?? '').trim());
                                  if (n == null || n <= 0) {
                                    return 'Enter quantity';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: editWeightCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration:
                                    _dec('Weight (kg)', icon: Icons.scale),
                                onChanged: (_) => setSheetState(() {}),
                                validator: (v) {
                                  final n = double.tryParse((v ?? '').trim());
                                  if (n == null || n <= 0) {
                                    return 'Enter weight';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: editPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              _dec('Price (tk/kg)', icon: Icons.payments),
                          onChanged: (_) => setSheetState(() {}),
                          validator: (v) {
                            final n = double.tryParse((v ?? '').trim());
                            if (n == null || n <= 0) return 'Enter rate';
                            return null;
                          },
                        ),
                        // Live avg weight preview
                        Builder(
                          builder: (_) {
                            final q = int.tryParse(editQtyCtrl.text.trim()) ?? 0;
                            final w =
                                double.tryParse(editWeightCtrl.text.trim()) ??
                                    0.0;
                            if (q > 0 && w > 0) {
                              final avg = w / q;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Avg Weight: ${avg.toStringAsFixed(2)} kg/bird',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.brand,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ] else if (editType == 'Table Eggs' ||
                          editType == 'Hatching Eggs' ||
                          editType == 'Damaged Eggs') ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: editQtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration:
                                    _dec('Egg count (pcs)', icon: Icons.egg),
                                onChanged: (_) => setSheetState(() {}),
                                validator: (v) {
                                  final n = int.tryParse((v ?? '').trim());
                                  if (n == null || n <= 0) {
                                    return 'Enter eggs';
                                  }
                                  final maxStock = _availableStockFor(
                                    editType,
                                    currentEditingQty: (editType == originalType)
                                        ? originalQty
                                        : 0,
                                  );
                                  final totalRef = (editType == 'Damaged Eggs')
                                      ? totalDamagedEggsCollected
                                      : totalGoodEggsCollected;
                                  if (totalRef > 0 && n > maxStock) {
                                    return 'Max available: $maxStock';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: editPriceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration:
                                    _dec('Price (tk/pc)', icon: Icons.payments),
                                onChanged: (_) => setSheetState(() {}),
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
                                controller: editQtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _dec('Sacks (বস্তা)',
                                    icon: Icons.shopping_bag),
                                onChanged: (_) => setSheetState(() {}),
                                validator: (v) {
                                  final n = int.tryParse((v ?? '').trim());
                                  if (n == null || n <= 0) {
                                    return 'Enter sacks';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: editPriceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: _dec('Price (tk/sack)',
                                    icon: Icons.payments),
                                onChanged: (_) => setSheetState(() {}),
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
                      // Live Edit Total Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.successSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.brandSoft),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Updated Total:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.brand,
                              ),
                            ),
                            Text(
                              '${calcEditTotal().toStringAsFixed(2)} tk',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.brand,
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
                              controller: editBuyerCtrl,
                              decoration: _dec('Buyer name (optional)',
                                  icon: Icons.person),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: editRemarksCtrl,
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
                          Text(
                              'Date: ${editDate.toIso8601String().split('T').first}'),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: editDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) {
                                setSheetState(() => editDate = d);
                              }
                            },
                            child: const Text('Change Date'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: isUpdating
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      final nq = int.tryParse(
                                          editQtyCtrl.text.trim());
                                      final np = double.tryParse(
                                          editPriceCtrl.text.trim());
                                      final nw = editType == 'Bird'
                                          ? double.tryParse(
                                              editWeightCtrl.text.trim())
                                          : null;

                                      if (nq == null || nq <= 0) return;
                                      if (np == null || np < 0) return;

                                      // Stock check
                                      if (editType == 'Table Eggs' ||
                                          editType == 'Hatching Eggs' ||
                                          editType == 'Damaged Eggs') {
                                        final maxAvail = _availableStockFor(
                                          editType,
                                          currentEditingQty:
                                              (editType == originalType)
                                                  ? originalQty
                                                  : 0,
                                        );
                                        final totalRef =
                                            (editType == 'Damaged Eggs')
                                                ? totalDamagedEggsCollected
                                                : totalGoodEggsCollected;
                                        if (totalRef > 0 && nq > maxAvail) {
                                          _msg(
                                            'Cannot exceed available stock ($maxAvail pcs)',
                                            error: true,
                                          );
                                          return;
                                        }
                                      }

                                      setSheetState(() => isUpdating = true);
                                      try {
                                        await client
                                            .from('sales')
                                            .update({
                                              'sale_type': editType,
                                              'quantity': nq,
                                              'weight_kg': nw,
                                              'unit_price': np,
                                              'buyer_name':
                                                  editBuyerCtrl.text.trim(),
                                              'remarks':
                                                  editRemarksCtrl.text.trim(),
                                              'sale_date': editDate
                                                  .toIso8601String()
                                                  .split('T')
                                                  .first,
                                            })
                                            .eq('id', sale['id']);

                                        if (mounted) {
                                          Navigator.pop(ctx);
                                          _msg('Sale updated successfully');
                                          await _loadBatchData();
                                        }
                                      } catch (e) {
                                        _msg('Update failed: $e', error: true);
                                      } finally {
                                        setSheetState(() => isUpdating = false);
                                      }
                                    },
                              icon: isUpdating
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.card,
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: const Text('Update Sale'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    editQtyCtrl.dispose();
    editWeightCtrl.dispose();
    editPriceCtrl.dispose();
    editBuyerCtrl.dispose();
    editRemarksCtrl.dispose();
  }

  Future<bool> _delete(Map<String, dynamic> s) async {
    final colors = context.colors;
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
            child: Text('Delete', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );

    if (ok != true) return false;

    try {
      await client.from('sales').delete().eq('id', s['id']);
      setState(() => sales.remove(s));
      _msg('Record deleted');
      await _loadBatchData();
      return true;
    } catch (e) {
      _msg('Delete failed: $e', error: true);
      return false;
    }
  }

  // Stock inventory card
  Widget _buildInventoryBalanceCard(AppColors colors) {
    final curBatch = batch;
    final initialBirds = (curBatch?['initial_birds'] ?? 0) as int;
    final addBirds = (curBatch?['additional_birds'] ?? 0) as int;
    final totalBirdsIn = initialBirds + addBirds;
    final remainingBirds = totalBirdsIn - totalMortality - birdsSoldQty;

    return Card(
      elevation: 0,
      color: colors.soft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, size: 18, color: colors.brand),
                const SizedBox(width: 8),
                Text(
                  'স্টক ও ইনভেন্টরি সমন্বয় (Live Stock Balance)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Bird stock line
            Row(
              children: [
                Icon(Icons.pets, size: 15, color: colors.inkAlt),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'মুরগি: মোট $totalBirdsIn | মৃত্যু $totalMortality | বিক্রি $birdsSoldQty | বাকি: $remainingBirds পাখি',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                ),
              ],
            ),

            if (isEggBatch || totalEggsCollected > 0) ...[
              const Divider(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.egg, size: 15, color: colors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ভালো ডিম: সংগ্রহ $totalGoodEggsCollected | বিক্রি $soldGoodEggsQty (টেবিল: $soldTableEggsQty, হ্যাচিং: $soldHatchingEggsQty)',
                          style: TextStyle(fontSize: 12, color: colors.inkAlt),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '👉 স্টকে অবশিষ্ট ভালো ডিম: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.ink,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: availableGoodEggs > 0
                                    ? colors.successSoft
                                    : colors.errorSoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$availableGoodEggs টি',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: availableGoodEggs > 0
                                      ? colors.brand
                                      : colors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.egg_outlined, size: 15, color: colors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'ভাঙা ডিম: সংগ্রহ $totalDamagedEggsCollected | বিক্রি $soldDamagedEggsQty | বাকি: ',
                          style: TextStyle(fontSize: 12, color: colors.inkAlt),
                        ),
                        Text(
                          '$availableDamagedEggs টি',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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

    final isEgg =
        (type == 'Table Eggs' || type == 'Hatching Eggs' || type == 'Damaged Eggs');
    final activeStockAvail = _availableStockFor(type);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales & Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBatchData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBatchData,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Batch selector
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
                _loadBatchData();
              },
            ),
            const SizedBox(height: 10),

            // Live Stock Balance Card
            _buildInventoryBalanceCard(colors),
            const SizedBox(height: 12),

            // Sales Entry Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  // Stock indicator for selected egg type
                  if (isEgg) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: activeStockAvail > 0
                            ? colors.noticeBg
                            : colors.errorSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: activeStockAvail > 0
                              ? colors.noticeBorder
                              : colors.errorBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            activeStockAvail > 0
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_outlined,
                            size: 18,
                            color: activeStockAvail > 0
                                ? colors.noticeIcon
                                : colors.errorText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              type == 'Damaged Eggs'
                                  ? 'স্টকে অবশিষ্ট ভাঙা ডিম: $activeStockAvail টি'
                                  : 'স্টকে অবশিষ্ট ভালো ডিম: $activeStockAvail টি',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: activeStockAvail > 0
                                    ? colors.noticeText
                                    : colors.errorText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (type == 'Bird') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            decoration:
                                _dec('Birds count', icon: Icons.numbers),
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
                    // Live Avg Weight Preview
                    Builder(
                      builder: (_) {
                        final q = int.tryParse(_qty.text.trim()) ?? 0;
                        final w = double.tryParse(_weight.text.trim()) ?? 0.0;
                        if (q > 0 && w > 0) {
                          final avg = w / q;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'গড় ওজন: ${avg.toStringAsFixed(2)} kg/bird',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.brand,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ] else if (isEgg) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            decoration: _dec(
                              'Egg count (pcs)',
                              icon: Icons.egg,
                              helperText: '১ খাঁচি = ৩০ টি ডিম',
                            ),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'Enter eggs';
                              final refTotal = (type == 'Damaged Eggs')
                                  ? totalDamagedEggsCollected
                                  : totalGoodEggsCollected;
                              if (refTotal > 0 && n > activeStockAvail) {
                                return 'স্টকে বাকি মাত্র $activeStockAvail টি';
                              }
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
                            decoration: _dec('Sacks (বস্তা)',
                                icon: Icons.shopping_bag),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.successSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.brandSoft),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estimated Total:',
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
                        child: const Text('Change Date'),
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
                    _row('Table Egg sales', tableEggSalesTotal),
                    _row('Hatching Egg sales', hatchingEggSalesTotal),
                    if (damagedEggSalesTotal > 0)
                      _row('Damaged Egg sales', damagedEggSalesTotal),
                    _row('Litter sales', litterSalesTotal),
                    const Divider(),
                    _row('Total revenue', totalRevenue, bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sales Records (${sales.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.ink,
                  ),
                ),
                Text(
                  'Tap or Edit button to update',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.inkAlt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (sales.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, size: 40, color: colors.muted),
                      const SizedBox(height: 8),
                      Text(
                        'No sales records yet for this batch',
                        style: TextStyle(color: colors.inkAlt),
                      ),
                    ],
                  ),
                ),
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
                final avg = (q > 0 && w > 0) ? (w / q) : 0.0;
                detail =
                    '$q birds, ${w.toStringAsFixed(1)} kg @ $p tk/kg (${avg.toStringAsFixed(2)} kg/bird)';
              } else if (t == 'Table Eggs' ||
                  t == 'Hatching Eggs' ||
                  t == 'Damaged Eggs') {
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
                  color: colors.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(Icons.delete, color: colors.card),
                ),
                confirmDismiss: (_) => _delete(s),
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 0,
                  color: colors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: colors.line),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 2),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: t == 'Bird'
                          ? colors.brandSoft
                          : t == 'Damaged Eggs'
                              ? colors.errorSoft
                              : t.toString().contains('Egg')
                                  ? colors.warningSoft
                                  : colors.soft,
                      child: Icon(
                        t == 'Bird'
                            ? Icons.sell
                            : t == 'Litter'
                                ? Icons.shopping_bag
                                : Icons.egg,
                        size: 18,
                        color: t == 'Bird'
                            ? colors.brand
                            : t == 'Damaged Eggs'
                                ? colors.error
                                : t.toString().contains('Egg')
                                    ? colors.warning
                                    : colors.inkAlt,
                      ),
                    ),
                    title: Text(
                      '$t  •  ${amt.toStringAsFixed(2)} tk',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                    subtitle: Text(
                      '$dateStr  |  $detail',
                      style: TextStyle(color: colors.inkAlt, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 18, color: colors.brand),
                          tooltip: 'Edit sale',
                          onPressed: () => _openEditSaleSheet(s),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: colors.error),
                          tooltip: 'Delete sale',
                          onPressed: () => _delete(s),
                        ),
                      ],
                    ),
                    onTap: () => _openEditSaleSheet(s),
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
