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

  // --- সরাসরি Supabase-এ সেভ করার কোড ---
  Future<void> saveBatchToSupabase() async {
    if (!_formKey.currentState!.validate()) return;

    final initialBirds = int.tryParse(initialBirdsController.text.trim());
    if (initialBirds == null || initialBirds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initial Birds-এ ০ এর বেশি সংখ্যা দিন')),
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
        throw Exception('ইউজার লগইন করা নেই। অনুগ্রহ করে লগইন করুন।');
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
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ব্যাচ সফলভাবে Supabase Cloud-এ সেভ হয়েছে!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ত্রুটি: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Batch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Batch Name *',
                  hintText: 'Broiler-2026-01',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'ব্যাচের নাম দিন' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: productionType,
                decoration: const InputDecoration(
                  labelText: 'Production Type *',
                  border: OutlineInputBorder(),
                ),
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
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: currentCategories.contains(productionCategory) ? productionCategory : null,
                decoration: const InputDecoration(
                  labelText: 'Production Category *',
                  border: OutlineInputBorder(),
                ),
                items: currentCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  setState(() {
                    productionCategory = val;
                    breed = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              if (productionCategory == 'Other') ...[
                TextFormField(
                  controller: customCategoryController,
                  decoration: const InputDecoration(
                    labelText: 'Specify Category Name *',
                    hintText: 'যেমন: কোয়েল, টার্কি ইত্যাদি',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'ক্যাটেগরির নাম লিখুন' : null,
                ),
                const SizedBox(height: 16),
              ],

              DropdownButtonFormField<String>(
                value: breedList.contains(breed) ? breed : null,
                decoration: const InputDecoration(
                  labelText: 'Breed / জাত (optional)',
                  border: OutlineInputBorder(),
                ),
                items: breedList.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (val) => setState(() => breed = val),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: initialBirdsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial Birds (মোট বাচ্চার সংখ্যা) *',
                  hintText: '500',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'সংখ্যা দিন' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: chickPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'বাচ্চার দর / দাম per pc (টাকা)',
                  hintText: '50.00',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: sourceController,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  hintText: 'Hatchery',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: shedController,
                decoration: const InputDecoration(
                  labelText: 'Shed / শেড নম্বর (optional)',
                  hintText: 'Shed-1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Start Date: ${startDate.toLocal()}'.split(' ')[0],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Change Date'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes / মন্তব্য (optional)',
                  hintText: 'টিকা বা বিশেষ কোনো তথ্য...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : saveBatchToSupabase,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _isSaving ? 'সংরক্ষণ হচ্ছে...' : 'Save Batch',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
