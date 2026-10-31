import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddBatchPageNew extends StatefulWidget {
  const AddBatchPageNew({super.key});

  @override
  State<AddBatchPageNew> createState() => _AddBatchPageNewState();
}

class _AddBatchPageNewState extends State<AddBatchPageNew> {
  final _formKey = GlobalKey<FormState>();

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
    // লাইভ মিনি-বেন্টো কার্ড আপডেটের জন্য লিসেনার
    initialBirdsController.addListener(() => setState(() {}));
    chickPriceController.addListener(() => setState(() {}));
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
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => startDate = picked);
  }

  Future<void> saveBatchToSupabase() async {
    if (!_formKey.currentState!.validate()) return;

    final initialBirds = int.tryParse(initialBirdsController.text.trim());
    if (initialBirds == null || initialBirds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Initial Birds count greater than 0')),
      );
      return;
    }

    final finalCategory = (productionCategory == 'Other')
        ? customCategoryController.text.trim()
        : (productionCategory ?? 'General');

    final chickPrice = double.tryParse(chickPriceController.text.trim()) ?? 0.0;

    setState(() => _isSaving = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception('User is not logged in. Please log in first.');
      }

      await client.from('batches').insert({
        'user_id': user.id,
        'name': nameController.text.trim(),
        'production_type': productionType ?? 'Meat Production',
        'production_category': finalCategory,
        'breed': breed ?? finalCategory,
        'initial_birds': initialBirds,
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
            content: Text('Batch saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving batch: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
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

  @override
  Widget build(BuildContext context) {
    final birdsCount = int.tryParse(initialBirdsController.text.trim()) ?? 0;
    final pricePerPc = double.tryParse(chickPriceController.text.trim()) ?? 0.0;
    final totalChickCost = birdsCount * pricePerPc;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Batch'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ১. Batch Identity Card
                _buildSectionCard(
                  title: 'Batch Identity & Type',
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
                        decoration: _inputDeco('Specify Category Name *', hint: 'e.g. Quail, Turkey'),
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

                // ২. Flock & Cost Card (With Live Mini Bento Preview)
                _buildSectionCard(
                  title: 'Flock Size & Purchase Cost',
                  icon: Icons.egg_outlined,
                  children: [
                    InkWell(
                      onTap: pickDate,
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
                                const Icon(Icons.calendar_today, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Text(
                                  'Start Date: ${startDate.toLocal()}'.split(' ')[0],
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
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
                      decoration: _inputDeco('Chick Price per pc (BDT)', hint: '50.00', icon: Icons.payments_outlined),
                    ),
                    const SizedBox(height: 14),

                    // --- Live Mini-Bento KPI Grid (2 Tiles) ---
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Initial Flock', style: TextStyle(fontSize: 11, color: Colors.blue.shade900)),
                                const SizedBox(height: 4),
                                Text(
                                  '$birdsCount pcs',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.teal.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Est. Chick Cost', style: TextStyle(fontSize: 11, color: Colors.teal.shade900)),
                                const SizedBox(height: 4),
                                Text(
                                  '৳${totalChickCost.toStringAsFixed(1)}',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ৩. Shed & Logistics Card
                _buildSectionCard(
                  title: 'Housing & Logistics',
                  icon: Icons.warehouse_outlined,
                  children: [
                    TextFormField(
                      controller: shedController,
                      decoration: _inputDeco('Shed / House No (optional)', hint: 'Shed-1', icon: Icons.roofing),
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
          ),
        ),
      ),
      // ফিক্সড ও সেফ এরিয়া সহ সেভ বাটন (কখনও হোম কী-এর নিচে ঢুকবে না)
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
              onPressed: _isSaving ? null : saveBatchToSupabase,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _isSaving ? 'Saving Batch...' : 'Save Batch',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
