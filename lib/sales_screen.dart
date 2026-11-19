
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';

class SalesScreenNew extends StatefulWidget {
  const SalesScreenNew({super.key});

  @override
  State<SalesScreenNew> createState() => _SalesScreenNewState();
}

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
  String? editingSaleId;

  String type = 'Bird';
  DateTime date = DateTime.now();

  bool loading = true;
  bool saving = false;
  bool stockLoading = false;
  bool editMode = true;

  int _totalBirds = 0;
  int _mortality = 0;
  int _producedGood = 0;
  int _producedDamaged = 0;

  @override
  void initState() {
    super.initState();

    _qty.addListener(_refresh);
    _weight.addListener(_refresh);
    _price.addListener(_refresh);

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

  void _refresh() {
    if (mounted) setState(() {});
  }

  InputDecoration _dec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      border: const OutlineInputBorder(),
    );
  }

  void _msg(String message, {bool error = false}) {
    if (!mounted) return;

    final colors = context.colors;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? colors.error : colors.brand,
      ),
    );
  }

  int _int(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _double(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _dateString(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? get batch {
    for (final b in batches) {
      if (b['id']?.toString() == batchId) return b;
    }
    return null;
  }

  bool get isClosed {
    final status = (batch?['status'] ?? 'Active')
        .toString()
        .toLowerCase();

    return status != 'active' || batch?['closed_date'] != null;
  }

  bool get canEdit => editMode && !isClosed;

  bool get isEggBatch {
    final value = (batch?['production_type'] ?? '')
        .toString()
        .toLowerCase();

    return value.contains('egg');
  }

  String? get eggPurpose {
    final value = (batch?['egg_purpose'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    if (value == 'hatching') return 'hatching';
    if (value == 'table') return 'table';

    if (isEggBatch) return 'table';

    return null;
  }

  String _label(Map<String, dynamic> b) {
    final production = (b['production_type'] ?? '')
        .toString()
        .replaceAll(' Production', '');

    final category = b['production_category'] ?? '';
    final purpose = b['egg_purpose'] ?? '';

    final tag = purpose.toString().isEmpty
        ? ''
        : purpose == 'hatching'
            ? ' · Hatching'
            : ' · Table';

    return '${b['name']} ($production - $category$tag)';
  }

  List<String> get allowedTypes {
    if (!isEggBatch) {
      return const ['Bird', 'Litter'];
    }

    if (eggPurpose == 'hatching') {
      return const [
        'Hatching Eggs',
        'Damaged Eggs',
        'Litter',
      ];
    }

    return const [
      'Table Eggs',
      'Damaged Eggs',
      'Litter',
    ];
  }

  void _syncType() {
    if (!allowedTypes.contains(type)) {
      type = allowedTypes.first;
    }
  }

  // --------------------------------------------------
  // STOCK CALCULATIONS
  // --------------------------------------------------

  int get soldBirds => _soldQuantity('Bird');

  int get soldTable => _soldQuantity('Table Eggs');

  int get soldHatching => _soldQuantity('Hatching Eggs');

  int get soldDamaged => _soldQuantity('Damaged Eggs');

  int get soldLitter => _soldQuantity('Litter');

  int _soldQuantity(String saleType) {
    return sales
        .where((s) => s['sale_type'] == saleType)
        .fold(0, (sum, s) => sum + _int(s['quantity']));
  }

  int get birdStockBeforeSales {
    return (_totalBirds - _mortality).clamp(0, 1 << 30);
  }

  int get availableBirdStock {
    return (birdStockBeforeSales - soldBirds).clamp(0, 1 << 30);
  }

  int get goodEggStock {
    final sold = eggPurpose == 'hatching'
        ? soldHatching
        : soldTable;

    return (_producedGood - sold).clamp(0, 1 << 30);
  }

  int get damagedEggStock {
    return (_producedDamaged - soldDamaged).clamp(0, 1 << 30);
  }

  int get availableForCurrentType {
    switch (type) {
      case 'Bird':
        return availableBirdStock;
      case 'Table Eggs':
      case 'Hatching Eggs':
        return goodEggStock;
      case 'Damaged Eggs':
        return damagedEggStock;
      default:
        return 1 << 30;
    }
  }

  // During editing, add back the current sale quantity.
  int get stockAvailableForSave {
    int available = availableForCurrentType;

    if (editingSaleId != null) {
      for (final s in sales) {
        if (s['id']?.toString() == editingSaleId &&
            s['sale_type'] == type) {
          available += _int(s['quantity']);
          break;
        }
      }
    }

    return available;
  }

  // --------------------------------------------------
  // REVENUE
  // --------------------------------------------------

  double _calcAmount(Map<String, dynamic> s) {
    final quantity = _int(s['quantity']);
    final weight = _double(s['weight_kg']);
    final price = _double(s['unit_price']);

    if (s['sale_type'] == 'Bird' && weight > 0) {
      return weight * price;
    }

    return quantity * price;
  }

  double get currentTotal {
    final q = int.tryParse(_qty.text.trim()) ?? 0;
    final w = double.tryParse(_weight.text.trim()) ?? 0;
    final p = double.tryParse(_price.text.trim()) ?? 0;

    if (type == 'Bird') {
      return w * p;
    }

    return q * p;
  }

  double get birdSalesTotal => _revenueFor('Bird');

  double get eggSalesTotal {
    return sales
        .where((s) =>
            s['sale_type'] == 'Table Eggs' ||
            s['sale_type'] == 'Hatching Eggs' ||
            s['sale_type'] == 'Damaged Eggs')
        .fold(0.0, (sum, s) => sum + _calcAmount(s));
  }

  double get litterSalesTotal => _revenueFor('Litter');

  double _revenueFor(String saleType) {
    return sales
        .where((s) => s['sale_type'] == saleType)
        .fold(0.0, (sum, s) => sum + _calcAmount(s));
  }

  double get totalRevenue {
    return sales.fold(0.0, (sum, s) => sum + _calcAmount(s));
  }

  // --------------------------------------------------
  // LOAD DATA
  // --------------------------------------------------

  Future<void> _loadBatches() async {
    final user = client.auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    try {
      final rows = await client
          .from('batches')
          .select(
            'id, name, production_type, production_category, '
            'breed, initial_birds, additional_birds, '
            'status, egg_purpose, closed_date',
          )
          .eq('user_id', user.id)
          .order('start_date', ascending: false);

      batches = List<Map<String, dynamic>>.from(rows);

      if (batches.isNotEmpty) {
        batchId = batches.first['id'].toString();
        _syncType();
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

      // Total birds from the existing database VIEW.
      final totalRows = await client
          .from('batch_bird_totals')
          .select('total_birds')
          .eq('batch_id', batchId!);

      int totalBirds = 0;

      if (totalRows.isNotEmpty) {
        totalBirds = _int(totalRows.first['total_birds']);
      }

      // Daily mortality and egg production.
      final dailyRows = await client
          .from('daily_records')
          .select(
            'mortality, eggs_good, eggs_damaged, eggs_collected',
          )
          .eq('batch_id', batchId!);

      int mortality = 0;
      int good = 0;
      int damaged = 0;

      for (final r in List<Map<String, dynamic>>.from(dailyRows)) {
        mortality += _int(r['mortality']);

        int g = _int(r['eggs_good']);
        final d = _int(r['eggs_damaged']);

        // Support older daily records.
        if (g == 0 && d == 0) {
          g = _int(r['eggs_collected']);
        }

        good += g;
        damaged += d;
      }

      if (!mounted) return;

      setState(() {
        sales = List<Map<String, dynamic>>.from(salesRows);
        _totalBirds = totalBirds;
        _mortality = mortality;
        _producedGood = good;
        _producedDamaged = damaged;
      });
    } catch (e) {
      _msg('Failed to load sales/stock: $e', error: true);
    }

    if (mounted) {
      setState(() => stockLoading = false);
    }
  }

  // --------------------------------------------------
  // FORM RESET / EDIT
  // --------------------------------------------------

  void _clearForm() {
    editingSaleId = null;
    _qty.clear();
    _weight.clear();
    _price.clear();
    _buyer.clear();
    _remarks.clear();
    date = DateTime.now();

    if (mounted) setState(() {});
  }

  void _editSale(Map<String, dynamic> sale) {
    if (!canEdit) return;

    editingSaleId = sale['id'].toString();

    type = sale['sale_type']?.toString() ?? 'Bird';

    _qty.text = _int(sale['quantity']).toString();
    _weight.text = sale['weight_kg'] == null
        ? ''
        : _double(sale['weight_kg']).toString();

    _price.text = _double(sale['unit_price']).toString();

    _buyer.text = (sale['buyer_name'] ?? '').toString();
    _remarks.text = (sale['remarks'] ?? '').toString();

    date = DateTime.tryParse(
          sale['sale_date']?.toString() ?? '',
        ) ??
        DateTime.now();

    setState(() {});

    _msg('Editing existing sale entry');
  }

  // --------------------------------------------------
  // SAVE / UPDATE
  // --------------------------------------------------

  Future<void> _save() async {
    if (!canEdit || batchId == null) return;

    if (!_formKey.currentState!.validate()) return;

    final user = client.auth.currentUser;

    if (user == null) {
      _msg('Please login first', error: true);
      return;
    }

    final q = int.tryParse(_qty.text.trim());
    final p = double.tryParse(_price.text.trim());
    final w = type == 'Bird'
        ? double.tryParse(_weight.text.trim())
        : null;

    if (q == null || q <= 0 || p == null || p < 0) {
      _msg('Invalid quantity or price', error: true);
      return;
    }

    if (type == 'Bird' && (w == null || w <= 0)) {
      _msg('Enter total live weight in kg', error: true);
      return;
    }

    if (type != 'Damaged Eggs' && p <= 0) {
      _msg('Price must be greater than zero', error: true);
      return;
    }

    // Prevent overselling.
    if (type != 'Litter') {
      final available = stockAvailableForSave;

      if (q > available) {
        _msg(
          'Not enough stock. Available: $available',
          error: true,
        );
        return;
      }
    }

    // Egg purpose validation.
    if (type == 'Table Eggs' && eggPurpose == 'hatching') {
      _msg('This is a hatching batch', error: true);
      return;
    }

    if (type == 'Hatching Eggs' && eggPurpose == 'table') {
      _msg('This is a table egg batch', error: true);
      return;
    }

    setState(() => saving = true);

    try {
      final data = {
        'user_id': user.id,
        'batch_id': batchId,
        'sale_date': _dateString(date),
        'sale_type': type,
        'quantity': q,
        'weight_kg': w,
        'unit_price': p,
        'buyer_name': _buyer.text.trim(),
        'remarks': _remarks.text.trim(),
      };

      if (editingSaleId == null) {
        await client.from('sales').insert(data);
        _msg('Sale saved successfully');
      } else {
        await client
            .from('sales')
            .update(data)
            .eq('id', editingSaleId!)
            .eq('user_id', user.id);

        _msg('Sale updated successfully');
      }

      _clearForm();
      await _loadSalesAndStock();
    } catch (e) {
      _msg('Save failed: $e', error: true);
    }

    if (mounted) setState(() => saving = false);
  }

  // --------------------------------------------------
  // DELETE
  // --------------------------------------------------

  Future<bool> _delete(Map<String, dynamic> sale) async {
    if (!canEdit) return false;

    final colors = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete sale record?'),
        content: Text(
          '${sale['sale_type']} • '
          '${_calcAmount(sale).toStringAsFixed(2)} tk',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              'Delete',
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      final user = client.auth.currentUser;
      if (user == null) return false;

      await client
          .from('sales')
          .delete()
          .eq('id', sale['id'])
          .eq('user_id', user.id);

      _msg('Sale record deleted');

      await _loadSalesAndStock();

      return true;
    } catch (e) {
      _msg('Delete failed: $e', error: true);
      return false;
    }
  }

  // --------------------------------------------------
  // STOCK BANNER
  // --------------------------------------------------

  Widget _stockBanner(AppColors colors) {
    if (!isEggBatch) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.brandSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bird Stock',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.brand,
              ),
            ),
            const SizedBox(height: 10),

            _stockRow('Initial birds', _int(batch?['initial_birds'])),
            _stockRow('Additional birds',
                _totalBirds - _int(batch?['initial_birds'])),
            _stockRow('Total birds', _totalBirds),
            _stockRow('Mortality', -_mortality),
            _stockRow('Birds sold', -soldBirds),

            const Divider(),

            _stockRow(
              'Available birds',
              availableBirdStock,
              bold: true,
            ),

            if (stockLoading)
              const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      );
    }

    return Container(
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
            'Egg Stock',
            style: TextStyle(
              color: colors.brand,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _stockRow('Good eggs produced', _producedGood),
          _stockRow('Good eggs sold',
              eggPurpose == 'hatching' ? soldHatching : soldTable),
          _stockRow('Good eggs available', goodEggStock, bold: true),
          const Divider(),
          _stockRow('Damaged eggs produced', _producedDamaged),
          _stockRow('Damaged eggs sold', soldDamaged),
          _stockRow('Damaged eggs available', damagedEggStock,
              bold: true),
          if (stockLoading)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  Widget _stockRow(String label, int value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: bold ? context.colors.brand : null,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // ENTRY FORM
  // --------------------------------------------------

  Widget _saleForm(AppColors colors) {
    final allowed = allowedTypes;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: batchId,
            isExpanded: true,
            decoration: _dec('Batch', icon: Icons.inventory_2),
            items: batches.map((b) {
              return DropdownMenuItem<String>(
                value: b['id'].toString(),
                child: Text(
                  _label(b),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (v) async {
              if (v == null) return;

              _clearForm();

              setState(() {
                batchId = v;
                _syncType();
              });

              await _loadSalesAndStock();
            },
          ),

          const SizedBox(height: 10),

          _stockBanner(colors),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: allowed.contains(type) ? type : allowed.first,
            isExpanded: true,
            decoration: _dec('Sale type', icon: Icons.category),
            items: allowed.map((t) {
              return DropdownMenuItem(value: t, child: Text(t));
            }).toList(),
            onChanged: (v) {
              if (v == null) return;

              setState(() {
                type = v;
                _qty.clear();
                _weight.clear();
                _price.clear();
              });
            },
          ),

          const SizedBox(height: 12),

          if (type == 'Bird') ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    decoration: _dec(
                      'Bird count',
                      icon: Icons.numbers,
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());

                      if (n == null || n <= 0) {
                        return 'Enter quantity';
                      }

                      if (n > stockAvailableForSave) {
                        return 'Max $stockAvailableForSave';
                      }

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
                    decoration: _dec(
                      'Weight (kg)',
                      icon: Icons.scale,
                    ),
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
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(
                'Price (tk/kg)',
                icon: Icons.payments,
              ),
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

                      if (n == null || n <= 0) {
                        return 'Enter eggs';
                      }

                      if (n > stockAvailableForSave) {
                        return 'Max $stockAvailableForSave';
                      }

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
                      'Price (tk/pc)',
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
                color: colors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
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

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.successSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Total',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${currentTotal.toStringAsFixed(2)} tk',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colors.brand,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _buyer,
                  decoration: _dec(
                    'Buyer name',
                    icon: Icons.person,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _remarks,
                  decoration: _dec(
                    'Remarks',
                    icon: Icons.comment,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Date: ${_dateString(date)}'),
              ),
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

          const SizedBox(height: 10),

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
                      ),
                    )
                  : Icon(
                      editingSaleId == null
                          ? Icons.save
                          : Icons.edit,
                    ),
              label: Text(
                editingSaleId == null
                    ? 'Save Sale'
                    : 'Update Sale',
              ),
            ),
          ),

          if (editingSaleId != null)
            Center(
              child: TextButton.icon(
                onPressed: _clearForm,
                icon: const Icon(Icons.close),
                label: const Text('Cancel Editing'),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // SUMMARY
  // --------------------------------------------------

  Widget _summary(AppColors colors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _revenueRow('Bird sales', birdSalesTotal),
            _revenueRow('Egg sales', eggSalesTotal),
            _revenueRow('Litter sales', litterSalesTotal),
            const Divider(),
            _revenueRow(
              'Total revenue',
              totalRevenue,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _revenueRow(
    String label,
    double value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : null,
              ),
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} tk',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : null,
              color: bold ? context.colors.brand : null,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // RECENT SALES
  // --------------------------------------------------

  Widget _recentSales(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Recent Sales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        if (sales.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text('No sales records yet'),
            ),
          ),

        ...sales.map((s) {
          final saleType = (s['sale_type'] ?? '').toString();
          final amount = _calcAmount(s);

          final quantity = _int(s['quantity']);
          final weight = _double(s['weight_kg']);
          final price = _double(s['unit_price']);

          String detail;

          if (saleType == 'Bird') {
            detail =
                '$quantity birds · ${weight.toStringAsFixed(2)} kg '
                '@ $price tk/kg';
          } else if (saleType == 'Litter') {
            detail = '$quantity sacks @ $price tk/sack';
          } else {
            detail = '$quantity pcs @ $price tk/pc';
          }

          final buyer = (s['buyer_name'] ?? '').toString();

          if (buyer.isNotEmpty) {
            detail += ' · $buyer';
          }

          final tile = ListTile(
            dense: true,
            leading: Icon(
              saleType == 'Bird'
                  ? Icons.sell
                  : saleType == 'Litter'
                      ? Icons.shopping_bag
                      : Icons.egg,
              color: colors.brand,
            ),
            title: Text(
              '$saleType · ${amount.toStringAsFixed(2)} tk',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${s['sale_date']} · $detail',
            ),
            trailing: canEdit
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit sale',
                    onPressed: () => _editSale(s),
                  )
                : null,
          );

          if (!canEdit) return tile;

          return Dismissible(
            key: ValueKey(s['id']),
            direction: DismissDirection.endToStart,
            background: Container(
              color: colors.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 18),
              child: Icon(
                Icons.delete,
                color: colors.card,
              ),
            ),
            confirmDismiss: (_) => _delete(s),
            child: tile,
          );
        }),
      ],
    );
  }

  // --------------------------------------------------
  // MAIN UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (batches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sales')),
        body: const Center(
          child: Text('No batch found. Please add a batch first.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
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
            // EDIT MODE TOGGLE
            Card(
              child: SwitchListTile(
                value: editMode,
                title: const Text(
                  'Entry Edit Mode',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isClosed
                      ? 'Closed batch · Read only'
                      : editMode
                          ? 'New entry, edit and delete enabled'
                          : 'Read only · Editing disabled',
                ),
                secondary: Icon(
                  editMode && !isClosed
                      ? Icons.edit
                      : Icons.lock_outline,
                  color: colors.brand,
                ),
                onChanged: (value) {
                  setState(() {
                    editMode = value;

                    if (!canEdit) {
                      _clearForm();
                    }
                  });
                },
              ),
            ),

            if (isClosed)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'This batch is closed. Sales records are read only.',
                ),
              ),

            const SizedBox(height: 10),

            if (canEdit) ...[
              if (editingSaleId != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.brandSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'EDITING EXISTING SALE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

              _saleForm(colors),
            ] else ...[
              _stockBanner(colors),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Read Only Mode',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],

            const SizedBox(height: 16),

            _summary(colors),

            const SizedBox(height: 10),

            _recentSales(colors),
          ],
        ),
      ),
    );
  }
}
