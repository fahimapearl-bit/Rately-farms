import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseScreenNew extends StatefulWidget {
  const ExpenseScreenNew({super.key});
  @override
  State<ExpenseScreenNew> createState() => _ExpenseScreenNewState();
}

class _ExpenseScreenNewState extends State<ExpenseScreenNew> {
  final client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  final _remarks = TextEditingController();

  static const types = [
    'Feed', 'Medicine', 'Vaccine', 'Litter', 'Labour',
    'Electricity', 'Transport', 'Equipment', 'Other'
  ];

  List<Map<String, dynamic>> batches = [];
  List<Map<String, dynamic>> expenses = [];
  String? batchId;
  String type = 'Feed';
  DateTime date = DateTime.now();
  bool loading = true, saving = false;

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
    _loadBatches();
  }

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    _remarks.dispose();
    super.dispose();
  }

  void _msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t), backgroundColor: error ? Colors.red : Colors.green));
  }

  Future<void> _loadBatches() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await client
          .from('batches')
          .select('id, name, production_type, production_category, initial_birds, chick_price, status')
          .eq('user_id', user.id)
          .order('start_date', ascending: false);
      batches = List<Map<String, dynamic>>.from(rows)
          .where((b) => (b['status'] ?? 'Active') == 'Active')
          .toList();
      if (batches.isNotEmpty) batchId = batches.first['id'];
      await _loadExpenses();
    } catch (e) {
      _msg('Failed to load batches: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadExpenses() async {
    if (batchId == null) return;
    final rows = await client
        .from('expenses')
        .select()
        .eq('batch_id', batchId!)
        .order('expense_date', ascending: false);
    if (mounted) setState(() => expenses = List<Map<String, dynamic>>.from(rows));
  }

  Map<String, dynamic>? get batch =>
      batches.where((b) => b['id'] == batchId).firstOrNull;

  double get chickCost {
    final b = batch;
    if (b == null) return 0;
    return ((b['initial_birds'] ?? 0) as num).toDouble() *
        ((b['chick_price'] ?? 0) as num).toDouble();
  }

  double get otherTotal =>
      expenses.fold(0.0, (s, e) => s + ((e['amount'] ?? 0) as num).toDouble());

  Map<String, double> get byType {
    final m = <String, double>{};
    for (final e in expenses) {
      final t = (e['expense_type'] ?? 'Other').toString();
      m[t] = (m[t] ?? 0) + ((e['amount'] ?? 0) as num).toDouble();
    }
    return m;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || batchId == null) return;
    setState(() => saving = true);
    try {
      await client.from('expenses').insert({
        'user_id': client.auth.currentUser!.id,
        'batch_id': batchId,
        'expense_date': date.toIso8601String().split('T').first,
        'expense_type': type,
        'description': _desc.text.trim(),
        'amount': double.parse(_amount.text.trim()),
        'remarks': _remarks.text.trim(),
      });
      _desc.clear();
      _amount.clear();
      _remarks.clear();
      _msg('Expense saved');
      await _loadExpenses();
    } catch (e) {
      _msg('Save failed: $e', error: true);
    }
    if (mounted) setState(() => saving = false);
  }

  Future<bool> _delete(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('${e['expense_type']} - ${e['amount']} tk'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await client.from('expenses').delete().eq('id', e['id']);
      setState(() => expenses.remove(e));
      _msg('Deleted');
      return true;
    } catch (err) {
      _msg('Delete failed: $err', error: true);
      return false;
    }
  }

  String _label(Map<String, dynamic> b) {
    final t = (b['production_type'] ?? '').toString().replaceAll(' Production', '');
    final c = (b['production_category'] ?? '').toString();
    return '${b['name']} ($t - $c)';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (batches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expenses')),
        body: const Center(child: Text('No active batch found. Add a batch first.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: RefreshIndicator(
        onRefresh: _loadExpenses,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Form(
              key: _formKey,
              child: Column(children: [
                DropdownButtonFormField<String>(
                  value: batchId,
                  isExpanded: true,
                  decoration: _dec('Batch', icon: Icons.inventory_2),
                  items: batches
                      .map((b) => DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text(_label(b), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => batchId = v);
                    _loadExpenses();
                  },
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: type,
                      isExpanded: true,
                      decoration: _dec('Expense type', icon: Icons.category),
                      items: types
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => type = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dec('Amount (tk)', icon: Icons.payments),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) return 'Enter amount';
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _desc,
                  decoration: _dec('Description (e.g. 10 bags starter feed)',
                      icon: Icons.notes),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _remarks,
                  decoration: _dec('Remarks (optional)', icon: Icons.comment),
                ),
                const SizedBox(height: 10),
                Row(children: [
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
                          lastDate: DateTime.now());
                      if (d != null) setState(() => date = d);
                    },
                    child: const Text('Change'),
                  ),
                ]),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: const Text('Save Expense'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _row('Chick cost (from batch)', chickCost),
                  _row('Other expenses', otherTotal),
                  const Divider(),
                  _row('Total expense', chickCost + otherTotal, bold: true),
                  if (byType.isNotEmpty) const Divider(),
                  ...byType.entries.map((e) => _row('  ${e.key}', e.value)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Recent expenses (swipe left to delete)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No expenses yet')),
              ),
            ...expenses.map((e) => Dismissible(
                  key: ValueKey(e['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _delete(e),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long),
                    title: Text('${e['expense_type']}  •  ${e['amount']} tk'),
                    subtitle: Text(
                        '${e['expense_date']}  ${(e['description'] ?? '').toString()}'),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, double v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(l)),
          Text('${v.toStringAsFixed(2)} tk',
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );
}
