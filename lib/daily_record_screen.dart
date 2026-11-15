import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';
import 'average_weight_screen.dart';
import 'layer_performance_screen.dart';
import 'market_price_screen.dart';

/// Which part of the day this entry belongs to.
/// One batch can have several entries per day (morning / afternoon / evening).
enum RecordSession { morning, afternoon, evening }

extension RecordSessionX on RecordSession {
  String get dbValue => name;

  String get label => switch (this) {
    RecordSession.morning => 'Morning',
    RecordSession.afternoon => 'Afternoon',
    RecordSession.evening => 'Evening',
  };

  String get shortLabel => switch (this) {
    RecordSession.morning => 'AM',
    RecordSession.afternoon => 'Noon',
    RecordSession.evening => 'PM',
  };

  IconData get icon => switch (this) {
    RecordSession.morning => Icons.wb_twilight,
    RecordSession.afternoon => Icons.wb_sunny_outlined,
    RecordSession.evening => Icons.nights_stay_outlined,
  };

  static RecordSession fromDb(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    return RecordSession.values.firstWhere(
      (e) => e.name == s,
      orElse: () => RecordSession.morning,
    );
  }
}

/// Daily Records — batch-centric costing with multiple sessions per day.
///
/// Design rules for this screen:
///  * **No central store / inventory.** Whatever is applied to the batch in a
///    session *is* the expense (`quantity x unit price = total`).
///  * **One screen, two batch types.** Sections adapt to the batch:
///    egg collection only for egg-production (layer) batches, weight sample
///    for every batch.
///  * **Eggs are edited here.** The Layer Performance screen is opened only to
///    read HDP / trend analysis, so eggs are never counted twice.
class DailyRecordPageNew extends StatefulWidget {
  const DailyRecordPageNew({super.key, this.initialBatchId});

  /// Optional: open directly on a specific batch.
  final String? initialBatchId;

  @override
  State<DailyRecordPageNew> createState() => _DailyRecordPageNewState();
}

class _DailyRecordPageNewState extends State<DailyRecordPageNew> {
  static const String _currency = '৳';

  final SupabaseClient _supabase = Supabase.instance.client;
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFmt = DateFormat('dd MMM, yyyy');
  final NumberFormat _money = NumberFormat('#,##0.##');

  // ---------------------------------------------------------------- state ---
  bool _isLoading = true;
  bool _isSaving = false;
  bool _schemaReady = true;
  String? _schemaWarning;

  List<Map<String, dynamic>> _batches = [];
  Map<String, dynamic>? _selectedBatch;

  DateTime _selectedDate = DateTime.now();
  RecordSession _session = _defaultSession();

  /// Every daily record row of the selected batch (all dates, all sessions).
  List<Map<String, dynamic>> _records = [];

  /// Batch-level expenses booked on the Expenses screen.
  double _batchExpenses = 0;

  /// Set when a row for (batch, date, session) already exists.
  String? _editingRecordId;
  double _editingSavedTotal = 0;

  // ------------------------------------------------------------ controllers ---
  final _feedKgCtrl = TextEditingController();
  final _feedPriceCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  final _mortalityCtrl = TextEditingController();

  final _eggsGoodCtrl = TextEditingController();
  final _eggsDamagedCtrl = TextEditingController();

  final _sampleSizeCtrl = TextEditingController(text: '10');
  final _avgWeightCtrl = TextEditingController();

  final _medQtyCtrl = TextEditingController();
  final _medPriceCtrl = TextEditingController();
  final _vacQtyCtrl = TextEditingController();
  final _vacPriceCtrl = TextEditingController();
  final _othersCtrl = TextEditingController();

  final _labourCtrl = TextEditingController();
  final _electricityCtrl = TextEditingController();
  final _transportCtrl = TextEditingController();

  final _marketPriceCtrl = TextEditingController();
  final _eggPriceCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  List<TextEditingController> get _allControllers => [
    _feedKgCtrl,
    _feedPriceCtrl,
    _waterCtrl,
    _mortalityCtrl,
    _eggsGoodCtrl,
    _eggsDamagedCtrl,
    _sampleSizeCtrl,
    _avgWeightCtrl,
    _medQtyCtrl,
    _medPriceCtrl,
    _vacQtyCtrl,
    _vacPriceCtrl,
    _othersCtrl,
    _labourCtrl,
    _electricityCtrl,
    _transportCtrl,
    _marketPriceCtrl,
    _eggPriceCtrl,
    _remarksCtrl,
  ];

  static RecordSession _defaultSession() {
    final h = DateTime.now().hour;
    if (h < 11) return RecordSession.morning;
    if (h < 16) return RecordSession.afternoon;
    return RecordSession.evening;
  }

  @override
  void initState() {
    super.initState();
    for (final c in _allControllers) {
      c.addListener(_recalc);
    }
    _loadBatches();
  }

  void _recalc() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _allControllers) {
      c.removeListener(_recalc);
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------- helpers ---
  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  int _parseInt(TextEditingController c) =>
      int.tryParse(c.text.trim()) ?? _parse(c).round();

  String _money0(num v) => _money.format(v);

  static String _dateKeyOf(dynamic raw) {
    final d = DateTime.tryParse('${raw ?? ''}');
    if (d == null) return '${raw ?? ''}';
    return DateFormat('yyyy-MM-dd').format(d);
  }

  /// Egg-production batch? `production_type` is 'Egg Production' or
  /// 'Bird Production' in the database.
  bool get isLayerBatch {
    final t = (_selectedBatch?['production_type'] ?? '')
        .toString()
        .toLowerCase();
    if (t.contains('egg')) return true;
    if (t.contains('bird') || t.contains('meat')) return false;
    final c = (_selectedBatch?['production_category'] ?? '')
        .toString()
        .toLowerCase();
    return c == 'layer';
  }

  // ------------------------------------------------------ cost computations ---
  double get feedApplied => _parse(_feedKgCtrl) * _parse(_feedPriceCtrl);
  double get medicineApplied => _parse(_medQtyCtrl) * _parse(_medPriceCtrl);
  double get vaccineApplied => _parse(_vacQtyCtrl) * _parse(_vacPriceCtrl);
  double get othersApplied => _parse(_othersCtrl);

  double get labourCost => _parse(_labourCtrl);
  double get electricityCost => _parse(_electricityCtrl);
  double get transportCost => _parse(_transportCtrl);

  double get appliedCost =>
      feedApplied + medicineApplied + vaccineApplied + othersApplied;
  double get otherExpenseCost => labourCost + electricityCost + transportCost;

  /// What this single session costs.
  double get sessionTotal => appliedCost + otherExpenseCost;

  int get eggsGood => _parseInt(_eggsGoodCtrl);
  int get eggsDamaged => _parseInt(_eggsDamagedCtrl);
  int get eggsTotal => isLayerBatch ? eggsGood + eggsDamaged : 0;

  double get avgWeightKg => _parse(_avgWeightCtrl);
  double get marketPricePerKg => _parse(_marketPriceCtrl);
  double get eggPricePerPiece => _parse(_eggPriceCtrl);

  int get _initialBirds =>
      _int(_selectedBatch?['initial_birds'] ?? _selectedBatch?['total_birds']);

  int get _totalMortality =>
      _records.fold<int>(0, (s, r) => s + _int(r['mortality']));

  int get activeBirds {
    final a = _initialBirds - _totalMortality;
    return a < 0 ? 0 : a;
  }

  int get batchAgeDays {
    final raw = _selectedBatch?['start_date'];
    if (raw == null) return 0;
    final start = DateTime.tryParse(raw.toString());
    if (start == null) return 0;
    final s = DateTime(start.year, start.month, start.day);
    final d = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final diff = d.difference(s).inDays + 1;
    return diff < 0 ? 0 : diff;
  }

  double _rowApplied(Map<String, dynamic> r) =>
      _num(r['feed_cost']) +
      _num(r['medicine_cost']) +
      _num(r['vaccine_cost']) +
      _num(r['others_cost']);

  double _rowOther(Map<String, dynamic> r) =>
      _num(r['labour_cost']) +
      _num(r['electricity_cost']) +
      _num(r['transport_cost']);

  /// Stored total, or rebuilt for legacy rows saved before the cost columns.
  double _rowTotal(Map<String, dynamic> r) {
    final stored = r['total_cost'];
    if (stored != null) return _num(stored);
    return _rowApplied(r) + _rowOther(r);
  }

  /// Rows belonging to the selected date (regardless of session).
  List<Map<String, dynamic>> get _rowsOfSelectedDay => _records.where((r) {
    return _dateKeyOf(r['record_date']) == _dateFmt.format(_selectedDate);
  }).toList();

  /// The row that would be overwritten by saving right now (if any).
  Map<String, dynamic>? get _existingSessionRow {
    for (final r in _rowsOfSelectedDay) {
      if (RecordSessionX.fromDb(r['session']) == _session) return r;
    }
    return null;
  }

  /// Everything already saved for the selected date, excluding the row being
  /// edited (so the live total never doubles it).
  double get daySavedTotal => _rowsOfSelectedDay
      .where((r) => r['id']?.toString() != _editingRecordId)
      .fold<double>(0, (s, r) => s + _rowTotal(r));

  /// Day total across all sessions, including the form's live value.
  double get dayTotal => daySavedTotal + sessionTotal;

  double get batchCumulative =>
      _records.fold<double>(0, (s, r) => s + _rowTotal(r)) + _batchExpenses;

  /// Cleaner, explicit version used by the UI.
  double get batchCumulativeAfterSave {
    final otherRowsTotal =
        _records.fold<double>(0, (s, r) => s + _rowTotal(r)) -
        daySavedTotal -
        _editingSavedTotal;
    return otherRowsTotal + dayTotal + _batchExpenses;
  }

  /// Live birds x average weight x selling price per kg.
  double get estimatedFlockValue =>
      activeBirds * avgWeightKg * marketPricePerKg;

  /// Today's eggs at today's egg rate (layer batches only).
  double get eggRevenueToday => eggsTotal * eggPricePerPiece;

  double get costPerBird =>
      activeBirds == 0 ? 0 : batchCumulativeAfterSave / activeBirds;

  // -------------------------------------------------------------- loading ---
  Future<void> _probeSchema() async {
    try {
      await _supabase
          .from('daily_records')
          .select('total_cost, session')
          .limit(1);
      _schemaReady = true;
      _schemaWarning = null;
    } catch (_) {
      _schemaReady = false;
      _schemaWarning = 'Cost/session columns are missing in Supabase. Run supabase_daily_cost_migration.sql first.';
    }
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _probeSchema();

      final data = await _supabase
          .from('batches')
          .select(
            'id, name, start_date, status, production_type, production_category, breed, initial_birds',
          )
          .eq('user_id', user.id)
          .order('start_date', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);

      if (!mounted) return;
      setState(() {
        _batches = list;
        if (list.isEmpty) {
          _selectedBatch = null;
        } else if (widget.initialBatchId != null) {
          _selectedBatch = list.firstWhere(
            (b) => b['id'].toString() == widget.initialBatchId,
            orElse: () => _firstActive(list),
          );
        } else {
          _selectedBatch = _firstActive(list);
        }
        _isLoading = false;
      });

      if (_selectedBatch != null) {
        await _loadBatchContext(
          _selectedBatch!['id'].toString(),
          prefill: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Load error: $e', isError: true);
    }
  }

  Map<String, dynamic> _firstActive(List<Map<String, dynamic>> list) {
    for (final b in list) {
      if ((b['status'] ?? 'Active').toString().toLowerCase() == 'active')
        return b;
    }
    return list.first;
  }

  /// Loads every record of the batch, the batch expenses, and (optionally)
  /// prefills market price / weight from other screens.
  Future<void> _loadBatchContext(String batchId, {bool prefill = false}) async {
    try {
      final rows = await _supabase
          .from('daily_records')
          .select('*')
          .eq('batch_id', batchId)
          .order('record_date', ascending: false);

      double exp = 0;
      try {
        final expenses = await _supabase
            .from('expenses')
            .select('amount')
            .eq('batch_id', batchId);
        for (final e in List<Map<String, dynamic>>.from(expenses)) {
          exp += _num(e['amount']);
        }
      } catch (_) {
        // Expenses table is optional for this screen.
      }

      final records = List<Map<String, dynamic>>.from(rows);

      if (!mounted) return;
      setState(() {
        _records = records;
        _batchExpenses = exp;
      });

      _syncFormWithExistingRow();

      if (prefill) await _prefillFromCloud(batchId);
    } catch (e) {
      if (mounted) _snack('History load error: $e', isError: true);
    }
  }

  /// If a row already exists for the selected date + session, load it so the
  /// user edits instead of creating a duplicate.
  void _syncFormWithExistingRow({bool announce = false}) {
    final existing = _existingSessionRow;
    if (existing != null) {
      _loadRecordIntoForm(existing, announce: announce);
    } else {
      setState(() {
        _editingRecordId = null;
        _editingSavedTotal = 0;
      });
    }
  }

  Future<void> _prefillFromCloud(String batchId) async {
    // Live-bird market rate (price/kg).
    try {
      if (_marketPriceCtrl.text.trim().isEmpty) {
        final mp = await _supabase
            .from('market_prices')
            .select(
              'price, price_per_unit, price_date, unit, production_category',
            )
            .order('price_date', ascending: false)
            .limit(6);
        for (final row in List<Map<String, dynamic>>.from(mp)) {
          final cat = (row['production_category'] ?? '')
              .toString()
              .toLowerCase();
          final unit = (row['unit'] ?? '').toString().toLowerCase();
          if (!(cat.contains('bird') ||
              cat.contains('broiler') ||
              cat.contains('sonali') ||
              unit == 'kg')) {
            continue;
          }
          final raw = _num(row['price_per_unit']);
          final p = raw > 0 ? raw : _num(row['price']);
          if (p > 0 && mounted) _marketPriceCtrl.text = p.toStringAsFixed(0);
          break;
        }
      }
    } catch (_) {}

    // Egg rate per piece (layer batches only).
    try {
      if (isLayerBatch && _eggPriceCtrl.text.trim().isEmpty) {
        final mp = await _supabase
            .from('market_prices')
            .select(
              'price, price_per_unit, price_date, unit, production_category',
            )
            .filter('unit', 'in', '("piece","pcs","egg")')
            .order('price_date', ascending: false)
            .limit(3);
        for (final row in List<Map<String, dynamic>>.from(mp)) {
          final raw = _num(row['price_per_unit']);
          final p = raw > 0 ? raw : _num(row['price']);
          if (p > 0 && mounted) _eggPriceCtrl.text = p.toStringAsFixed(2);
          break;
        }
      }
    } catch (_) {}

    // Last recorded average weight.
    try {
      if (_avgWeightCtrl.text.trim().isEmpty) {
        final w = await _supabase
            .from('weekly_weights')
            .select('average_weight_kg, sample_count, weight_date')
            .eq('batch_id', batchId)
            .order('weight_date', ascending: false)
            .limit(1);
        final list = List<Map<String, dynamic>>.from(w);
        if (list.isNotEmpty && mounted) {
          final kg = _num(list.first['average_weight_kg']);
          if (kg > 0) _avgWeightCtrl.text = kg.toStringAsFixed(3);
          final sc = _int(list.first['sample_count']);
          if (sc > 0) _sampleSizeCtrl.text = sc.toString();
        }
      }
    } catch (_) {}

    // Last feed rate paid for this batch.
    try {
      if (_feedPriceCtrl.text.trim().isEmpty) {
        final r = await _supabase
            .from('daily_records')
            .select('feed_unit_price')
            .eq('batch_id', batchId)
            .order('record_date', ascending: false)
            .limit(5);
        for (final row in List<Map<String, dynamic>>.from(r)) {
          final p = _num(row['feed_unit_price']);
          if (p > 0 && mounted) {
            _feedPriceCtrl.text = p.toStringAsFixed(2);
            break;
          }
        }
      }
    } catch (_) {}
  }

  /// Fills the form from a stored row.
  void _loadRecordIntoForm(Map<String, dynamic> r, {bool announce = false}) {
    setState(() {
      _editingRecordId = r['id']?.toString();
      _editingSavedTotal = _rowTotal(r);

      final d = DateTime.tryParse('${r['record_date']}');
      if (d != null) _selectedDate = d;
      _session = RecordSessionX.fromDb(r['session']);

      _feedKgCtrl.text = _num(r['feed_kg']) == 0
          ? ''
          : _num(r['feed_kg']).toString();
      _feedPriceCtrl.text = _num(r['feed_unit_price']) == 0
          ? ''
          : _num(r['feed_unit_price']).toString();
      _waterCtrl.text = _num(r['water_litre']) == 0
          ? ''
          : _num(r['water_litre']).toString();
      _mortalityCtrl.text = _int(r['mortality']) == 0
          ? ''
          : _int(r['mortality']).toString();

      var good = _int(r['eggs_good']);
      if (good == 0 && _int(r['eggs_damaged']) == 0) {
        good = _int(r['eggs_collected']);
      }
      _eggsGoodCtrl.text = good == 0 ? '' : good.toString();
      _eggsDamagedCtrl.text = _int(r['eggs_damaged']) == 0
          ? ''
          : _int(r['eggs_damaged']).toString();

      _sampleSizeCtrl.text = _int(r['sample_size']) == 0
          ? '10'
          : _int(r['sample_size']).toString();
      _avgWeightCtrl.text = _num(r['avg_weight_kg']) == 0
          ? ''
          : _num(r['avg_weight_kg']).toString();

      _medQtyCtrl.text = _num(r['medicine_qty']) == 0
          ? ''
          : _num(r['medicine_qty']).toString();
      _medPriceCtrl.text = _num(r['medicine_unit_price']) == 0
          ? ''
          : _num(r['medicine_unit_price']).toString();
      _vacQtyCtrl.text = _num(r['vaccine_qty']) == 0
          ? ''
          : _num(r['vaccine_qty']).toString();
      _vacPriceCtrl.text = _num(r['vaccine_unit_price']) == 0
          ? ''
          : _num(r['vaccine_unit_price']).toString();
      _othersCtrl.text = _num(r['others_cost']) == 0
          ? ''
          : _num(r['others_cost']).toString();

      _labourCtrl.text = _num(r['labour_cost']) == 0
          ? ''
          : _num(r['labour_cost']).toString();
      _electricityCtrl.text = _num(r['electricity_cost']) == 0
          ? ''
          : _num(r['electricity_cost']).toString();
      _transportCtrl.text = _num(r['transport_cost']) == 0
          ? ''
          : _num(r['transport_cost']).toString();

      _marketPriceCtrl.text = _num(r['market_price_per_kg']) == 0
          ? ''
          : _num(r['market_price_per_kg']).toString();
      _eggPriceCtrl.text = _num(r['egg_price_per_piece']) == 0
          ? ''
          : _num(r['egg_price_per_piece']).toString();
      _remarksCtrl.text = (r['remarks'] ?? '').toString();
    });

    if (announce) {
      _snack(
        'Existing ${_session.label.toLowerCase()} entry loaded — saving updates it.',
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    _syncFormWithExistingRow(announce: true);
  }

  void _pickSession(RecordSession s) {
    if (s == _session) return;
    setState(() => _session = s);
    _syncFormWithExistingRow(announce: true);
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? colors.error : colors.brand,
      ),
    );
  }

  void _resetForm() {
    for (final c in _allControllers) {
      c.clear();
    }
    _sampleSizeCtrl.text = '10';
    setState(() {
      _editingRecordId = null;
      _editingSavedTotal = 0;
      _selectedDate = DateTime.now();
      _session = _defaultSession();
    });
    _syncFormWithExistingRow();
    if (_selectedBatch != null) {
      _prefillFromCloud(_selectedBatch!['id'].toString());
    }
  }

  /// Removes the form's values but keeps batch / date / session.
  void _clearValues() {
    for (final c in _allControllers) {
      c.clear();
    }
    _sampleSizeCtrl.text = '10';
    setState(() {
      _editingRecordId = null;
      _editingSavedTotal = 0;
    });
  }

  // --------------------------------------------------------------- saving ---
  Map<String, dynamic> _buildPayload(String userId) {
    final feedKg = _parse(_feedKgCtrl);
    final feedPrice = _parse(_feedPriceCtrl);
    final medQty = _parse(_medQtyCtrl);
    final medPrice = _parse(_medPriceCtrl);
    final vacQty = _parse(_vacQtyCtrl);
    final vacPrice = _parse(_vacPriceCtrl);

    final payload = <String, dynamic>{
      'user_id': userId,
      'batch_id': _selectedBatch!['id'],
      'record_date': _dateFmt.format(_selectedDate),
      'session': _session.dbValue,
      'feed_kg': feedKg,
      'water_litre': _parse(_waterCtrl),
      'eggs_collected': eggsTotal,
      'mortality': _parseInt(_mortalityCtrl),
      'remarks': _remarksCtrl.text.trim(),
    };

    if (_schemaReady) {
      payload.addAll({
        'feed_unit_price': feedPrice,
        'feed_cost': feedKg * feedPrice,
        'medicine_qty': medQty,
        'medicine_unit_price': medPrice,
        'medicine_cost': medQty * medPrice,
        'vaccine_qty': vacQty,
        'vaccine_unit_price': vacPrice,
        'vaccine_cost': vacQty * vacPrice,
        'others_cost': othersApplied,
        'labour_cost': labourCost,
        'electricity_cost': electricityCost,
        'transport_cost': transportCost,
        'applied_cost': appliedCost,
        'other_expense_cost': otherExpenseCost,
        'total_cost': sessionTotal,
        'sample_size': _parseInt(_sampleSizeCtrl),
        'avg_weight_kg': avgWeightKg,
        'market_price_per_kg': marketPricePerKg,
        'egg_price_per_piece': eggPricePerPiece,
        'eggs_good': eggsGood,
        'eggs_damaged': eggsDamaged,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    return payload;
  }

  Future<void> _save() async {
    if (_selectedBatch == null) {
      _snack('Select a batch first', isError: true);
      return;
    }
    if (sessionTotal <= 0 && eggsTotal == 0 && _parseInt(_mortalityCtrl) == 0) {
      _snack(
        'Nothing to save — enter applied cost, eggs or mortality',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final payload = _buildPayload(user.id);
      String? existingId =
          _editingRecordId ?? _existingSessionRow?['id']?.toString();

      if (existingId != null) {
        await _supabase
            .from('daily_records')
            .update(payload)
            .eq('id', existingId);
      } else {
        await _supabase.from('daily_records').insert(payload);
      }

      final label = '${_session.label} · ${_dateFmt.format(_selectedDate)}';
      _snack(existingId != null ? 'Updated $label' : 'Saved $label');

      final batchId = _selectedBatch!['id'].toString();
      _clearValues();
      await _loadBatchContext(batchId);
    } catch (e) {
      _snack('Save error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> r) async {
    final colors = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry'),
        content: Text(
          'Remove the ${RecordSessionX.fromDb(r['session']).label.toLowerCase()} '
          'entry of ${r['record_date']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || _selectedBatch == null) return;

    try {
      await _supabase
          .from('daily_records')
          .delete()
          .eq('id', r['id'].toString());
      _snack('Entry deleted');
      await _loadBatchContext(_selectedBatch!['id'].toString());
    } catch (e) {
      _snack('Delete error: $e', isError: true);
    }
  }

  // ------------------------------------------------------------ navigation ---
  Future<void> _openLayerPerformance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LayerPerformanceScreen(
          initialBatchId: _selectedBatch?['id']?.toString(),
        ),
      ),
    );
    if (_selectedBatch != null) {
      await _loadBatchContext(_selectedBatch!['id'].toString());
    }
  }

  Future<void> _openAverageWeight() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AverageWeightScreen(
          initialBatchId: _selectedBatch?['id']?.toString(),
        ),
      ),
    );
    if (_selectedBatch != null) {
      await _loadBatchContext(_selectedBatch!['id'].toString(), prefill: true);
    }
  }

  Future<void> _openMarketPrice() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MarketPriceScreen()),
    );
    if (_selectedBatch != null) {
      await _prefillFromCloud(_selectedBatch!['id'].toString());
    }
  }

  // ------------------------------------------------------------------- UI ---
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showBody =
        !_isLoading && _batches.isNotEmpty && _selectedBatch != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Records'),
        actions: [
          IconButton(
            tooltip: 'New entry',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: _resetForm,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadBatches,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !showBody
          ? _emptyBatches(colors)
          : _content(colors),
      bottomNavigationBar: showBody ? _saveBar(context, colors) : null,
    );
  }

  Widget _emptyBatches(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: colors.warning),
            const SizedBox(height: 12),
            const Text(
              'No batch found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add a batch first — daily costing hangs off a batch.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go back and add a batch'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _header(colors),
        if (!_schemaReady) ...[
          const SizedBox(height: 12),
          _warningBanner(colors),
        ],
        const SizedBox(height: 16),
        _dayStrip(colors),
        const SizedBox(height: 16),
        _section(
          colors,
          title: 'Daily Operations',
          icon: Icons.water_drop_outlined,
          color: colors.info,
          children: [
            _lineItem(
              colors: colors,
              title: 'Feed applied',
              icon: Icons.grass,
              qty: _feedKgCtrl,
              price: _feedPriceCtrl,
              qtyLabel: 'Quantity (kg)',
              priceLabel: 'Unit price / kg',
              total: feedApplied,
              tint: colors.brand,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _waterCtrl,
                    'Water (litre)',
                    icon: Icons.water_drop,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    _mortalityCtrl,
                    'Mortality (birds)',
                    integer: true,
                    icon: Icons.remove_circle_outline,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (isLayerBatch) ...[
          const SizedBox(height: 14),
          _section(
            colors,
            title: 'Egg Collection',
            icon: Icons.egg_outlined,
            color: colors.warning,
            trailing: _navButton(
              colors,
              label: 'Layer performance',
              onTap: _openLayerPerformance,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _eggsGoodCtrl,
                      'Good eggs',
                      integer: true,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _eggsDamagedCtrl,
                      'Damaged',
                      integer: true,
                      icon: Icons.broken_image_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _readout(
                colors,
                label: 'Total eggs this session',
                note: 'good + damaged',
                value: '$eggsTotal',
                color: colors.warning,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openLayerPerformance,
                  icon: const Icon(Icons.egg_alt_outlined, size: 18),
                  label: const Text('Open Layer Performance (HDP, trend)'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ডিম এখানেই লেখা হয়। Layer Performance স্ক্রিনটি শুধু বিশ্লেষণের জন্য — '
                'ওখানে আবার ডিম লিখলে দুইবার গণনা হবে।',
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _section(
          colors,
          title: 'Bird Weight Sample',
          icon: Icons.scale,
          color: colors.purple,
          children: [
            Row(
              children: [
                Expanded(
                  child: _field(
                    _sampleSizeCtrl,
                    'Sample size',
                    integer: true,
                    icon: Icons.groups_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    _avgWeightCtrl,
                    'Average weight (kg)',
                    icon: Icons.monitor_weight_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (avgWeightKg > 0)
              Text(
                'Average: ${(avgWeightKg * 1000).toStringAsFixed(0)} g per bird',
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openAverageWeight,
                icon: const Icon(Icons.show_chart, size: 18),
                label: const Text('Open Average Weight & Growth'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _section(
          colors,
          title: 'Market Price',
          icon: Icons.trending_up,
          color: colors.info,
          children: [
            _field(
              _marketPriceCtrl,
              'Live bird price / kg',
              icon: Icons.sell_outlined,
              hint: 'selling rate per kg',
              suffix: IconButton(
                tooltip: 'Market price screen',
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: _openMarketPrice,
              ),
            ),
            if (isLayerBatch) ...[
              const SizedBox(height: 10),
              _field(
                _eggPriceCtrl,
                'Egg price / piece',
                icon: Icons.egg_outlined,
                hint: 'selling rate per egg',
              ),
            ],
            const SizedBox(height: 10),
            _readout(
              colors,
              label: 'Estimated flock value',
              note:
                  '$activeBirds birds × ${_money0(avgWeightKg)} kg × '
                  '$_currency${_money0(marketPricePerKg)}',
              value: '$_currency ${_money0(estimatedFlockValue)}',
              color: colors.info,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _section(
          colors,
          title: 'Applied Cost',
          icon: Icons.assignment_turned_in_outlined,
          color: colors.brand,
          children: [
            _derivedRow(
              colors,
              label: 'Feed (from Daily Operations)',
              detail:
                  '${_money0(_parse(_feedKgCtrl))} kg × '
                  '$_currency${_money0(_parse(_feedPriceCtrl))}',
              value: feedApplied,
              tint: colors.brand,
            ),
            const SizedBox(height: 10),
            _lineItem(
              colors: colors,
              title: 'Medicine',
              icon: Icons.medication_outlined,
              qty: _medQtyCtrl,
              price: _medPriceCtrl,
              qtyLabel: 'Quantity',
              priceLabel: 'Unit price',
              total: medicineApplied,
              tint: colors.error,
            ),
            const SizedBox(height: 10),
            _lineItem(
              colors: colors,
              title: 'Vaccine',
              icon: Icons.vaccines_outlined,
              qty: _vacQtyCtrl,
              price: _vacPriceCtrl,
              qtyLabel: 'Quantity',
              priceLabel: 'Unit price',
              total: vaccineApplied,
              tint: colors.purple,
            ),
            const SizedBox(height: 10),
            _field(
              _othersCtrl,
              'Others (direct amount)',
              icon: Icons.more_horiz,
            ),
            const SizedBox(height: 12),
            _readout(
              colors,
              label: 'Applied this session',
              note: 'feed + medicine + vaccine + others',
              value: '$_currency ${_money0(appliedCost)}',
              color: colors.brand,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _section(
          colors,
          title: 'Other Expenses',
          icon: Icons.receipt_long,
          color: colors.warning,
          children: [
            Row(
              children: [
                Expanded(
                  child: _field(
                    _labourCtrl,
                    'Labour',
                    icon: Icons.engineering_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    _electricityCtrl,
                    'Electricity',
                    icon: Icons.bolt_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _field(
              _transportCtrl,
              'Transport',
              icon: Icons.local_shipping_outlined,
            ),
            const SizedBox(height: 12),
            _readout(
              colors,
              label: 'Support cost this session',
              note: 'labour + electricity + transport',
              value: '$_currency ${_money0(otherExpenseCost)}',
              color: colors.warning,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _summary(colors),
        const SizedBox(height: 14),
        _remarksField(),
        const SizedBox(height: 22),
        _history(colors),
      ],
    );
  }

  // ----------------------------------------------------------- fragments ---
  Widget _header(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.brand, colors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: colors.onAccentMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'ACTIVE BATCH',
                style: TextStyle(
                  color: colors.onAccentMuted,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.onAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isLayerBatch ? 'Egg / Layer' : 'Meat / Bird',
                  style: TextStyle(
                    color: colors.onAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: colors.card,
              icon: Icon(Icons.expand_more, color: colors.onAccent),
              value: _selectedBatch!['id'].toString(),
              selectedItemBuilder: (_) => _batches
                  .map(
                    (b) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        (b['name'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onAccent,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              items: _batches
                  .map(
                    (b) => DropdownMenuItem<String>(
                      value: b['id'].toString(),
                      child: Text(
                        '${b['name']}  ·  ${b['production_category'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) async {
                if (val == null) return;
                final picked = _batches.firstWhere(
                  (b) => b['id'].toString() == val,
                );
                setState(() {
                  _selectedBatch = picked;
                  _editingRecordId = null;
                  _editingSavedTotal = 0;
                });
                _clearValues();
                await _loadBatchContext(val, prefill: true);
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _headerChip(
                colors,
                Icons.cake_outlined,
                'Age: $batchAgeDays day${batchAgeDays == 1 ? '' : 's'}',
              ),
              _headerChip(colors, Icons.pets_outlined, 'Live: $activeBirds'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.onAccent.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: colors.onAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _displayFmt.format(_selectedDate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.edit, size: 13, color: colors.onAccentMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip(AppColors colors, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.onAccent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.onAccent),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: colors.onAccent, fontSize: 12)),
        ],
      ),
    );
  }

  /// Session selector + what is already booked for the day.
  Widget _dayStrip(AppColors colors) {
    final saved = _rowsOfSelectedDay
        .where((r) => r['id']?.toString() != _editingRecordId)
        .toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 15, color: colors.inkAlt),
              const SizedBox(width: 6),
              Text(
                'Entry session',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
              const Spacer(),
              if (_editingRecordId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warningSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'editing',
                    style: TextStyle(fontSize: 10, color: colors.warning),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: RecordSession.values.map((s) {
              final active = s == _session;
              final hasData = saved.any(
                (r) => RecordSessionX.fromDb(r['session']) == s,
              );
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: s == RecordSession.evening ? 0 : 8,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _pickSession(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? colors.brand : colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? colors.brand : colors.line,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            s.icon,
                            size: 15,
                            color: active ? colors.onBrand : colors.inkAlt,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: active ? colors.onBrand : colors.inkAlt,
                            ),
                          ),
                          if (hasData)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'saved',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: active ? colors.onBrand : colors.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (saved.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Already booked today: '
              '${saved.map((r) {
                final rs = RecordSessionX.fromDb(r['session']);
                return '${rs.label} ${_currency}${_money0(_rowTotal(r))}';
              }).join('  ·  ')}',
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _warningBanner(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.noticeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.noticeBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: colors.noticeIcon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _schemaWarning ?? 'Cost columns missing in the database.',
              style: TextStyle(fontSize: 12, color: colors.noticeText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    AppColors colors, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.ink,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? icon,
    bool integer = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        prefixIcon: icon == null ? null : Icon(icon, size: 18),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _lineItem({
    required AppColors colors,
    required String title,
    required IconData icon,
    required TextEditingController qty,
    required TextEditingController price,
    required String qtyLabel,
    required String priceLabel,
    required double total,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: tint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: colors.ink,
                  ),
                ),
              ),
              Text(
                '$_currency ${_money0(total)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: tint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _field(qty, qtyLabel, hint: '0')),
              const SizedBox(width: 8),
              Expanded(child: _field(price, priceLabel, hint: '0')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${qty.text.trim().isEmpty ? '0' : qty.text.trim()} × '
            '${price.text.trim().isEmpty ? '0' : price.text.trim()} '
            '= $_currency ${_money0(total)}',
            style: TextStyle(fontSize: 11, color: colors.muted),
          ),
        ],
      ),
    );
  }

  Widget _derivedRow(
    AppColors colors, {
    required String label,
    required String detail,
    required double value,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 14, color: tint),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
          ),
          Text(
            '$_currency ${_money0(value)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: tint),
          ),
        ],
      ),
    );
  }

  Widget _readout(
    AppColors colors, {
    required String label,
    required String note,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(note, style: TextStyle(fontSize: 11, color: colors.muted)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(
    AppColors colors, {
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.info,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 15, color: colors.info),
          ],
        ),
      ),
    );
  }

  Widget _summary(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_outlined, size: 16, color: colors.ink),
              const SizedBox(width: 6),
              Text(
                'Cost Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow(colors, '${_session.label} session', sessionTotal),
          if (daySavedTotal > 0) ...[
            const SizedBox(height: 6),
            _summaryRow(colors, 'Other sessions today', daySavedTotal),
          ],
          const Divider(height: 20),
          _summaryRow(colors, 'Daily total', dayTotal, bold: true),
          const SizedBox(height: 10),
          _summaryRow(
            colors,
            'Batch cumulative cost',
            batchCumulativeAfterSave,
          ),
          if (_batchExpenses > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Includes $_currency ${_money0(_batchExpenses)} booked on the Expenses screen.',
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
          ],
          if (isLayerBatch && eggRevenueToday > 0) ...[
            const SizedBox(height: 8),
            _infoPill(
              colors,
              'Egg value today',
              '$_currency ${_money0(eggRevenueToday)}',
              colors.warning,
            ),
          ],
          if (marketPricePerKg > 0 && avgWeightKg > 0) ...[
            const SizedBox(height: 8),
            _infoPill(
              colors,
              'Flock value at market rate',
              '$_currency ${_money0(estimatedFlockValue)}',
              colors.info,
            ),
          ],
          const SizedBox(height: 6),
          _infoPill(
            colors,
            'Cost per live bird',
            '$_currency ${_money0(costPerBird)}',
            colors.inkAlt,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    AppColors colors,
    String label,
    double value, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: colors.ink,
            ),
          ),
        ),
        Text(
          '$_currency ${_money0(value)}',
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: bold ? colors.brand : colors.ink,
          ),
        ),
      ],
    );
  }

  Widget _infoPill(AppColors colors, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.inkAlt),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _remarksField() {
    return TextField(
      controller: _remarksCtrl,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'Remarks (optional)',
        hintText: 'Vaccine name, vet advice, notes…',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _history(AppColors colors) {
    // Group by date, newest first.
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in _records) {
      grouped.putIfAbsent(_dateKeyOf(r['record_date']), () => []).add(r);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 16, color: colors.inkAlt),
            const SizedBox(width: 6),
            Text(
              'Recent Records',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.ink,
              ),
            ),
            const Spacer(),
            Text(
              '${_records.length} entr${_records.length == 1 ? 'y' : 'ies'}',
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (dates.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 32, color: colors.hint),
                const SizedBox(height: 8),
                Text(
                  'No records yet for this batch',
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ],
            ),
          )
        else
          ...dates.take(15).map((d) => _dayCard(colors, d, grouped[d]!)),
      ],
    );
  }

  Widget _dayCard(
    AppColors colors,
    String dayKey,
    List<Map<String, dynamic>> rows,
  ) {
    rows.sort((a, b) {
      final ia = RecordSessionX.fromDb(a['session']).index;
      final ib = RecordSessionX.fromDb(b['session']).index;
      return ia.compareTo(ib);
    });
    final dayTotalValue = rows.fold<double>(0, (s, r) => s + _rowTotal(r));
    final eggs = rows.fold<int>(
      0,
      (s, r) => s + _int(r['eggs_good']) + _int(r['eggs_damaged']),
    );
    final eggsLegacy = eggs > 0
        ? eggs
        : rows.fold<int>(0, (s, r) => s + _int(r['eggs_collected']));
    final mort = rows.fold<int>(0, (s, r) => s + _int(r['mortality']));
    final d = DateTime.tryParse(dayKey);
    final label = d == null ? dayKey : _displayFmt.format(d);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (rows.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brandSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${rows.length} sessions',
                        style: TextStyle(fontSize: 9, color: colors.brand),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '$_currency ${_money0(dayTotalValue)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.brand,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Row(
                children: [
                  if (isLayerBatch)
                    Text(
                      'Eggs $eggsLegacy   ',
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                  Text(
                    'Mortality $mort',
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...rows.map((r) {
              final rs = RecordSessionX.fromDb(r['session']);
              final active =
                  _editingRecordId != null &&
                  _editingRecordId == r['id']?.toString();
              return InkWell(
                onTap: () => _loadRecordIntoForm(r, announce: true),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  color: active ? colors.brandSoft : null,
                  child: Row(
                    children: [
                      Icon(
                        rs.icon,
                        size: 14,
                        color: active ? colors.brand : colors.inkAlt,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rs.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              [
                                if (_num(r['feed_kg']) > 0)
                                  'Feed ${_money0(_num(r['feed_kg']))}kg',
                                if (_num(r['water_litre']) > 0)
                                  'Water ${_money0(_num(r['water_litre']))}L',
                                if (_int(r['mortality']) > 0)
                                  'Mort ${_int(r['mortality'])}',
                                if (isLayerBatch &&
                                    (_int(r['eggs_good']) +
                                            _int(r['eggs_damaged'])) >
                                        0)
                                  'Eggs ${_int(r['eggs_good'])}/${_int(r['eggs_damaged'])}',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$_currency ${_money0(_rowTotal(r))}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 17,
                          color: colors.error,
                        ),
                        onPressed: () => _deleteRecord(r),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _saveBar(BuildContext context, AppColors colors) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.line)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Day total',
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
              Text(
                '$_currency ${_money0(dayTotal)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onBrand,
                        ),
                      )
                    : Icon(
                        _editingRecordId != null
                            ? Icons.save
                            : Icons.cloud_upload,
                      ),
                label: Text(
                  _isSaving
                      ? 'Saving…'
                      : _editingRecordId != null
                      ? 'Update ${_session.shortLabel}'
                      : 'Save ${_session.shortLabel}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
