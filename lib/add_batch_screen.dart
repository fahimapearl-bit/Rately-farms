import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'models.dart' as cloud_models;
import 'supabase_repository.dart';

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

  String? productionType;
  String? productionCategory;
  String? breed;
  DateTime startDate = DateTime.now();

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

  Future<void> saveBatch() async {
    if (_formKey.currentState!.validate()) {
      final initialBirds = int.tryParse(initialBirdsController.text.trim());
      if (initialBirds == null || initialBirds <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Initial Birds-এ 0-এর বেশি সংখ্যা দিন')),
        );
        return;
      }

      final finalCategory = (productionCategory == 'Other')
          ? customCategoryController.text.trim()
          : (productionCategory ?? 'General');

      try {
        final cloud = SupabaseRepository();
        final cloudBatch = await cloud.createBatch(cloud_models.Batch(
          id: '',
          userId: cloud.userId,
          name: nameController.text.trim(),
          productionType: productionType ?? 'Meat Production',
          productionCategory: finalCategory,
          breed: breed ?? finalCategory,
          startDate: startDate,
          initialBirds: initialBirds,
        ));

        final batch = Batch(
          id: cloudBatch.id,
          name: nameController.text.trim(),
          category: finalCategory,
          breed: breed ?? finalCategory,
          shed: shedController.text.trim(),
          startDate: startDate,
          initialBirds: initialBirds,
          status: 'Active',
        );

        batches.add(batch);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          'batches',
          batches.map((e) => jsonEncode(e.toJson())).toList(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('নতুন Batch সফলভাবে তৈরি হয়েছে!')),
        );
        Navigator.pop(context);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch save হয়নি: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
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
                  hintText: 'B-2026-01',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Batch Name দিন' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: productionType,
                decoration: const InputDecoration(
                  labelText: 'Production Type *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Meat Production',
                    child: Text('Meat Production'),
                  ),
                  DropdownMenuItem(
                    value: 'Egg Production',
                    child: Text('Egg Production'),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    productionType = v;
                    productionCategory = null;
                    breed = null;
                  });
                },
                validator: (v) => v == null ? 'Production Type নির্বাচন করুন' : null,
              ),
              const SizedBox(height: 16),

              if (productionType != null) ...[
                DropdownButtonFormField<String>(
                  value: productionCategory,
                  decoration: const InputDecoration(
                    labelText: 'Production Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: currentCategories
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      productionCategory = v;
                      breed = null;
                    });
                  },
                  validator: (v) => v == null ? 'Category নির্বাচন করুন' : null,
                ),
                const SizedBox(height: 16),
                if (productionCategory == 'Other') ...[
                  TextFormField(
                    controller: customCategoryController,
                    decoration: const InputDecoration(
                      labelText: 'ক্যাটাগরির নাম লিখুন *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'ক্যাটাগরি লিখুন' : null,
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              if (productionCategory != null && productionCategory != 'Other') ...[
                DropdownButtonFormField<String>(
                  value: breed,
                  decoration: const InputDecoration(
                    labelText: 'Breed / জাত (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: breedList
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => breed = v),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: initialBirdsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial Birds (মোট বাচ্চা) *',
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
                  labelText: 'Shed / House (optional)',
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
                maxLines: 3,
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
                  onPressed: saveBatch,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Batch', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
