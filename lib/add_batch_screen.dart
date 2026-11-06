import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddBatchPageNew extends StatefulWidget {
  final String? initialBatchId;
  final int initialMode; // 0 = New Batch, 1 = Add Birds

  const AddBatchPageNew({
    super.key,
    this.initialBatchId,
    this.initialMode = 0,
  });

  @override
  State<AddBatchPageNew> createState() => _AddBatchPageNewState();
}

class _AddBatchPageNewState extends State<AddBatchPageNew> {
  late int _mode; // 0: New Batch, 1: Add Birds
  final _newBatchFormKey = GlobalKey<FormState>();
  final _addBirdsFormKey = GlobalKey<FormState>();

  // --- 1. New Batch Form Controllers ---
  final nameController = TextEditingController();
  final shedController = TextEditingController();
  final initialBirdsController = TextEditingController();
  final chickPriceController = TextEditingController();
  final sourceController = TextEditingController(text: 'Hatchery');
  final notesController = TextEditingController();
  final customCategoryController = TextEditingController();

  String? productionType = 'Meat Production';
  String? productionCategory = 'Broiler';
  String? breed;
  DateTime startDate = DateTime.now();

  // --- 2. Add Birds Form Controllers ---
  final additionalBirdsController = TextEditingController();
  final additionalChickPriceController = TextEditingController();
  final additionalSourceController = TextEditingController(text: 'Hatchery');
  final additionalNotesController = TextEditingController();
  DateTime additionDate = DateTime.now();
  bool _recordAsExpense = true;

  // Active Batches for Add Birds
  List<Map<String, dynamic>> _activeBatches = [];
  Map<String, dynamic>? _selectedBatch;
  bool _loadingBatches = false;
  bool _isSaving = false;

  final meatCategories = ['Broiler', 'Sonali', 'Deshi', 'Other'];
  final eggCategories = ['Layer', 'Sonali', 'Deshi', 'Other'];

  final broilerBreeds = ['Ross 308', 'Cobb 500', 'Hubbard', 'Vencob'];
  final layerBreeds = ['Hy-Line Brown', 'ISA Brown', 'Lohmann', 'White Leghorn'];
  final generalBreeds = ['Sonali Classic', 'Deshi Cross', 'Fayoumi', 'RIR'];

  List<String> get currentCategories {
    if (productionType == 'Meat Production') return meatCategories;
    if (productionType == 'Egg Production') return eggCategories;
    return [];
  }

  List<String> get breedList {
    if (productionCategory == 'Broiler') return broilerBreeds;
    if (productionCategory == 'Layer') return layerBreeds;
    return generalBreeds;
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;

    // Listeners for live Bento KPI updates
    initialBirdsController.addListener(() => setState(() {}));
    chickPriceController.addListener(() => setState(() {}));
    additionalBirdsController.addListener(() => setState(() {}));
    additionalChickPriceController.addListener(() => setState(() {}));

    _loadActiveBatches();
  }

  @override
  void dispose() {
    nameController.dispose();
    shedController.dispose();
    initialBirdsController.dispose();
    chickPriceController.dispose();
    sourceController.dispose();
    notesController.dispose();
    customCategoryController.dispose();

    additionalBirdsController.dispose();
    additionalChickPriceController.dispose();
    additionalSourceController.dispose();
    additionalNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveBatches() async {
    setState(() => _loadingBatches = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final data = await client
          .from('batches')
          .select('id, name, production_type, production_category, breed, initial_birds, additional_birds, chick_price, status, start_date, shed')
          .eq('user_id', user.id)
          .eq('status', 'Active')
          .order('start_date', ascending: false);

      if (!mounted) return;
      setState(() {
        _activeBatches = List<Map<String, dynamic>>.from(data);
        if (_activeBatches.isNotEmpty) {
          if (widget.initialBatchId != null) {
            _selectedBatch = _activeBatches.firstWhere(
              (b) => b['id'].toString() == widget.initialBatchId,
              orElse: () => _activeBatches.first,
            );
          } else {
            _selectedBatch = _activeBatches.first;
          }

          if (additionalChickPriceController.text.isEmpty && _selectedBatch != null) {
            final cp = (_selectedBatch!['chick_price'] as num?)?.toDouble() ?? 0.0;
            if (cp > 0) {
              additionalChickPriceController.text = cp.toStringAsFixed(2);
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading active batches: $e');
    } finally {
      if (mounted) setState(() => _loadingBatches = false);
    }
  }

  void _onBatchChanged(Map<String, dynamic>? batch) {
    setState(() {
      _selectedBatch = batch;
      if (batch != null) {
        final cp = (batch['chick_price'] as num?)?.toDouble() ?? 0.0;
        if (cp > 0 && additionalChickPriceController.text.isEmpty) {
          additionalChickPriceController.text = cp.toStringAsFixed(2);
        }
      }
    });
  }

  Future<void> _pickDate({required bool isNewBatch}) async {
    final initial = isNewBatch ? startDate : additionDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isNewBatch) {
          startDate = picked;
        } else {
          additionDate = picked;
        }
      });
    }
  }

  Future<void> _saveNewBatch() async {
    if (!_newBatchFormKey.currentState!.validate()) return;

    final initialBirds = int.tryParse(initialBirdsController.text.trim());
    if (initialBirds == null || initialBirds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initial birds count must be greater than 0'), backgroundColor: Colors.red),
      );
      return;
    }

    final chickPrice = double.tryParse(chickPriceController.text.trim()) ?? 0.0;
    final finalCategory = (productionCategory == 'Other' && customCategoryController.text.trim().isNotEmpty)
        ? customCategoryController.text.trim()
        : (productionCategory ?? 'Broiler');

    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User is not logged in. Please log in first.');

      await client.from('batches').insert({
        'user_id': user.id,
        'name': nameController.text.trim(),
        'production_type': productionType ?? 'Meat Production',
        'production_category': finalCategory,
        'breed': breed ?? finalCategory,
        'initial_birds': initialBirds,
        'additional_birds': 0,
        'chick_price': chickPrice,
        'source': sourceController.text.trim().isEmpty ? 'Hatchery' : sourceController.text.trim(),
        'shed': shedController.text.trim(),
        'notes': notesController.text.trim(),
        'start_date': startDate.toIso8601String().split('T').first,
        'status': 'Active',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New Batch created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving batch: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAdditionalBirds() async {
    if (!_addBirdsFormKey.currentState!.validate()) return;
    if (_selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an active batch first'), backgroundColor: Colors.orange),
      );
      return;
    }

    final additionalCount = int.tryParse(additionalBirdsController.text.trim());
    if (additionalCount == null || additionalCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Additional birds count must be greater than 0'), backgroundColor: Colors.red),
      );
      return;
    }

    final chickPrice = double.tryParse(additionalChickPriceController.text.trim()) ?? 0.0;
    final totalAddedCost = additionalCount * chickPrice;

    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final batchId = _selectedBatch!['id'];
      final currentAdditional = ((_selectedBatch!['additional_birds'] ?? 0) as num).toInt();
      final newAdditionalTotal = currentAdditional + additionalCount;

      final dateStr = additionDate.toIso8601String().split('T').first;
      final sourceStr = additionalSourceController.text.trim().isNotEmpty
          ? ' from ${additionalSourceController.text.trim()}'
          : '';
      final priceStr = chickPrice > 0 ? ' @ TK ${chickPrice.toStringAsFixed(2)}/pc' : '';
      final userNote = additionalNotesController.text.trim().isNotEmpty
          ? ' (${additionalNotesController.text.trim()})'
          : '';
      final additionLog = '[+$additionalCount birds on $dateStr$priceStr$sourceStr$userNote]';

      final existingNotes = (_selectedBatch!['notes'] ?? '').toString().trim();
      final updatedNotes = existingNotes.isEmpty ? additionLog : '$existingNotes\n$additionLog';

      // 1. Update batch with new additional_birds count and notes
      await client.from('batches').update({
        'additional_birds': newAdditionalTotal,
        'notes': updatedNotes,
      }).eq('id', batchId).eq('user_id', user.id);

      // 2. Optionally record in expenses if enabled and price > 0
      if (_recordAsExpense && totalAddedCost > 0) {
        await client.from('expenses').insert({
          'user_id': user.id,
          'batch_id': batchId,
          'expense_date': dateStr,
          'expense_type': 'Other',
          'amount': totalAddedCost,
          'description': 'Additional Chick Purchase ($additionalCount birds$priceStr)',
          'remarks': 'Auto-logged from Add Batch screen$sourceStr',
        });
      }

      if (mounted) {
        final bName = _selectedBatch!['name'] ?? 'Batch';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $additionalCount birds to "$bName"!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding birds: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDeco(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _bentoTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.shade800),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.shade900),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color.shade900),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: color.shade700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Bento KPI Grid for New Batch
  Widget _buildNewBatchBentoGrid({
    required int birdsCount,
    required double pricePerPc,
    required double totalChickCost,
    required String type,
    required String category,
    required String breedName,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.dashboard_customize_outlined, size: 18, color: Colors.blue.shade800),
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Batch KPI Preview',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'REAL-TIME',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _bentoTile(
                  title: 'Initial Flock',
                  value: birdsCount > 0 ? '$birdsCount Birds' : '--',
                  subtitle: 'Start birds count',
                  icon: Icons.egg_outlined,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bentoTile(
                  title: 'Chick Rate',
                  value: pricePerPc > 0 ? 'TK ${pricePerPc.toStringAsFixed(2)}' : '--',
                  subtitle: 'Price per piece',
                  icon: Icons.payments_outlined,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.teal.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Est. Flock Placement Investment',
                        style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'TK ${totalChickCost.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.category_outlined, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$type • $category • $breedName',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bento KPI Grid for Add Birds
  Widget _buildAddBirdsBentoGrid({
    required int initialBirds,
    required int existingAdditional,
    required int addedCount,
    required double chickRate,
    required double addedCost,
  }) {
    final prevTotal = initialBirds + existingAdditional;
    final newTotal = prevTotal + addedCount;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.group_add_outlined, size: 18, color: Colors.amber.shade900),
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Addition KPI Grid',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  'REAL-TIME',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _bentoTile(
                  title: 'Previous Flock',
                  value: '$prevTotal Birds',
                  subtitle: existingAdditional > 0
                      ? '($initialBirds + $existingAdditional addl)'
                      : 'Initial count',
                  icon: Icons.pets_outlined,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bentoTile(
                  title: 'Incoming Lot',
                  value: addedCount > 0 ? '+$addedCount Birds' : '--',
                  subtitle: chickRate > 0 ? '@ TK ${chickRate.toStringAsFixed(2)}/pc' : 'Rate pending',
                  icon: Icons.add_circle_outline,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.indigo.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.groups_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Total Combined Batch Flock',
                        style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$newTotal Birds',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (addedCost > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 18, color: Colors.teal.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Additional Lot Cost:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.teal.shade900),
                      ),
                    ],
                  ),
                  Text(
                    'TK ${addedCost.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _mode == index;
    return GestureDetector(
      onTap: () {
        setState(() => _mode = index);
        if (index == 1 && _activeBatches.isEmpty) {
          _loadActiveBatches();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewBatchView() {
    final birdsCount = int.tryParse(initialBirdsController.text.trim()) ?? 0;
    final pricePerPc = double.tryParse(chickPriceController.text.trim()) ?? 0.0;
    final totalChickCost = birdsCount * pricePerPc;
    final finalCategory = (productionCategory == 'Other' && customCategoryController.text.trim().isNotEmpty)
        ? customCategoryController.text.trim()
        : (productionCategory ?? 'Broiler');

    return Form(
      key: _newBatchFormKey,
      child: Column(
        children: [
          // 1. Batch Identification
          _buildSectionCard(
            title: 'Batch Identification',
            icon: Icons.badge_outlined,
            children: [
              TextFormField(
                controller: nameController,
                decoration: _inputDeco('Batch Name *', hint: 'e.g. Broiler-2026-01', icon: Icons.edit_note),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter batch name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: productionType,
                decoration: _inputDeco('Production Type *', icon: Icons.category_outlined),
                items: const [
                  DropdownMenuItem(value: 'Meat Production', child: Text('Meat Production')),
                  DropdownMenuItem(value: 'Egg Production', child: Text('Egg Production')),
                ],
                onChanged: (val) {
                  setState(() {
                    productionType = val;
                    productionCategory = currentCategories.isNotEmpty ? currentCategories.first : null;
                    breed = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: currentCategories.contains(productionCategory) ? productionCategory : null,
                decoration: _inputDeco('Production Category *', icon: Icons.tune),
                items: currentCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  setState(() {
                    productionCategory = val;
                    breed = null;
                  });
                },
              ),
              if (productionCategory == 'Other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: customCategoryController,
                  decoration: _inputDeco('Specify Category *', hint: 'e.g. Turkey / Quail', icon: Icons.create),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter category name' : null,
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: breedList.contains(breed) ? breed : null,
                decoration: _inputDeco('Breed / Strain (optional)', icon: Icons.pets_outlined),
                items: breedList.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (val) => setState(() => breed = val),
              ),
            ],
          ),

          // 2. Flock Size & Purchase Cost (With Live Bento KPI Preview)
          _buildSectionCard(
            title: 'Flock Size & Purchase Cost',
            icon: Icons.egg_outlined,
            children: [
              InkWell(
                onTap: () => _pickDate(isNewBatch: true),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text('Start Date: ${startDate.toIso8601String().split('T').first}'),
                        ],
                      ),
                      const Text('Change', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: initialBirdsController,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('Initial Birds (Count) *', hint: '500', icon: Icons.numbers),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter bird count' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: chickPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDeco('Chick Price per pc (TK)', hint: '50.00', icon: Icons.payments_outlined),
              ),
              const SizedBox(height: 14),

              // --- Live Bento KPI Grid ---
              _buildNewBatchBentoGrid(
                birdsCount: birdsCount,
                pricePerPc: pricePerPc,
                totalChickCost: totalChickCost,
                type: productionType ?? 'Meat',
                category: finalCategory,
                breedName: breed ?? 'Standard',
              ),
            ],
          ),

          // 3. Housing & Placement Details
          _buildSectionCard(
            title: 'Housing & Placement Details',
            icon: Icons.warehouse_outlined,
            children: [
              TextFormField(
                controller: shedController,
                decoration: _inputDeco('Shed / Pen No. (optional)', hint: 'e.g. Shed-1', icon: Icons.meeting_room_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sourceController,
                decoration: _inputDeco('Chick Source', hint: 'Hatchery name', icon: Icons.local_shipping_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                maxLines: 2,
                decoration: _inputDeco('Notes / Remarks (optional)', hint: 'Vaccine, batch remarks...', icon: Icons.notes),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddBirdsView() {
    if (_loadingBatches) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeBatches.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.amber.shade300),
        ),
        color: Colors.amber.shade50,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 40, color: Colors.amber.shade900),
              const SizedBox(height: 12),
              Text(
                'No Active Batches Found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber.shade900),
              ),
              const SizedBox(height: 6),
              const Text(
                'To add additional birds, you need at least one active batch. Please create a new batch first.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => _mode = 0),
                icon: const Icon(Icons.add),
                label: const Text('Create New Batch'),
              ),
            ],
          ),
        ),
      );
    }

    final initialCount = ((_selectedBatch?['initial_birds'] ?? 0) as num).toInt();
    final existingAdditional = ((_selectedBatch?['additional_birds'] ?? 0) as num).toInt();
    final addedCount = int.tryParse(additionalBirdsController.text.trim()) ?? 0;
    final chickRate = double.tryParse(additionalChickPriceController.text.trim()) ?? 0.0;
    final addedCost = addedCount * chickRate;

    return Form(
      key: _addBirdsFormKey,
      child: Column(
        children: [
          // 1. Select Target Active Batch
          _buildSectionCard(
            title: 'Select Active Batch',
            icon: Icons.check_circle_outline,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedBatch?['id']?.toString(),
                decoration: _inputDeco('Target Batch *', icon: Icons.folder_open),
                items: _activeBatches.map((b) {
                  final name = b['name'] ?? 'Unnamed';
                  final cat = b['production_category'] ?? '';
                  final init = b['initial_birds'] ?? 0;
                  return DropdownMenuItem<String>(
                    value: b['id'].toString(),
                    child: Text('$name ($cat • $init birds)', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (id) {
                  final match = _activeBatches.firstWhere((b) => b['id'].toString() == id);
                  _onBatchChanged(match);
                },
              ),
              if (_selectedBatch != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Batch: ${_selectedBatch!['name']} | Breed: ${_selectedBatch!['breed'] ?? 'Standard'} | Started: ${_selectedBatch!['start_date']}',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // 2. Additional Birds Details
          _buildSectionCard(
            title: 'Additional Birds Details',
            icon: Icons.add_circle_outline,
            children: [
              InkWell(
                onTap: () => _pickDate(isNewBatch: false),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text('Addition Date: ${additionDate.toIso8601String().split('T').first}'),
                        ],
                      ),
                      const Text('Change', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: additionalBirdsController,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('Additional Birds (Count) *', hint: 'e.g. 100', icon: Icons.exposure_plus_1),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter number of birds';
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: additionalChickPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDeco('Chick Price per pc (TK)', hint: 'e.g. 52.00', icon: Icons.payments_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: additionalSourceController,
                decoration: _inputDeco('Hatchery / Source', hint: 'e.g. Kazi Hatchery', icon: Icons.local_shipping_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: additionalNotesController,
                decoration: _inputDeco('Reason / Remarks (optional)', hint: 'e.g. Added 2nd lot of chicks', icon: Icons.notes),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _recordAsExpense,
                activeColor: Theme.of(context).colorScheme.primary,
                title: const Text('Record cost in Expenses (ব্যয় হিসেবে সেভ করুন)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Automatically adds an entry in Expenses under "Other"', style: TextStyle(fontSize: 11)),
                onChanged: (val) => setState(() => _recordAsExpense = val ?? true),
              ),
              const SizedBox(height: 10),

              // --- Live Addition Bento KPI Grid ---
              _buildAddBirdsBentoGrid(
                initialBirds: initialCount,
                existingAdditional: existingAdditional,
                addedCount: addedCount,
                chickRate: chickRate,
                addedCost: addedCost,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == 0 ? 'Create Batch' : 'Add Birds to Batch'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Segmented Mode Selector
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(child: _buildTabButton(0, 'New Batch', Icons.egg_outlined)),
                    const SizedBox(width: 4),
                    Expanded(child: _buildTabButton(1, 'Add Birds', Icons.group_add_outlined)),
                  ],
                ),
              ),

              // Form view depending on selected mode
              _mode == 0 ? _buildNewBatchView() : _buildAddBirdsView(),

              const SizedBox(height: 80), // Padding for bottom bar
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                offset: const Offset(0, -2),
                blurRadius: 6,
              ),
            ],
          ),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                      if (_mode == 0) {
                        _saveNewBatch();
                      } else {
                        _saveAdditionalBirds();
                      }
                    },
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_mode == 0 ? Icons.cloud_upload_outlined : Icons.add_circle_outline),
              label: Text(
                _isSaving
                    ? (_mode == 0 ? 'Saving Batch...' : 'Adding Birds...')
                    : (_mode == 0 ? 'Save Batch' : 'Confirm & Add Birds'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
