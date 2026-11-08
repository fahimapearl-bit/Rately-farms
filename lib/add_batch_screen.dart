import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';

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
  final layerBreeds = [
    'Hy-Line Brown',
    'ISA Brown',
    'Lohmann',
    'White Leghorn',
  ];
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
    initialBirdsController.addListener(_refreshPreview);
    chickPriceController.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
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
      helpText: 'Select batch start date',
    );
    if (picked != null) setState(() => startDate = picked);
  }

  String? _requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _positiveInteger(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0)
      return 'Enter a valid count greater than 0';
    return null;
  }

  String? _nonNegativePrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final price = double.tryParse(value.trim());
    if (price == null || price < 0) return 'Enter a valid non-negative price';
    return null;
  }

  Future<void> saveBatchToSupabase() async {
    if (!_formKey.currentState!.validate()) return;

    final initialBirds = int.tryParse(initialBirdsController.text.trim());
    if (initialBirds == null || initialBirds <= 0) return;

    final finalCategory = productionCategory == 'Other'
        ? customCategoryController.text.trim()
        : (productionCategory ?? 'General');
    final chickPrice = double.tryParse(chickPriceController.text.trim()) ?? 0.0;

    setState(() => _isSaving = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null)
        throw Exception('User is not logged in. Please log in first.');

      // Keep the UI wording and database constraint consistent.
      final dbProductionType = productionType == 'Meat Production'
          ? 'Bird Production'
          : 'Egg Production';

      await client.from('batches').insert({
        'user_id': user.id,
        'name': nameController.text.trim(),
        'production_type': dbProductionType,
        'production_category': finalCategory,
        'breed': breed ?? finalCategory,
        'initial_birds': initialBirds,
        'additional_birds': 0,
        'chick_price': chickPrice,
        'source': sourceController.text.trim().isEmpty
            ? 'Hatchery'
            : sourceController.text.trim(),
        'shed': shedController.text.trim(),
        'notes': notesController.text.trim(),
        'start_date': startDate.toIso8601String().split('T').first,
        'status': 'Active',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Batch saved successfully'),
          backgroundColor: context.colors.brand,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving batch: $e'),
            backgroundColor: context.colors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
    String? prefixText,
  }) {
    final colors = context.colors;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 20, color: colors.brand),
      filled: true,
      fillColor: colors.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.brand, width: 1.5),
      ),
    );
  }

  Widget _sectionCard({
    required int number,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colors = context.colors;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colors.brand, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$number. $title',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(int birdsCount, double totalChickCost) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.brand, Color.lerp(colors.brand, Colors.teal, 0.45)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.agriculture_outlined,
                color: Colors.white,
                size: 21,
              ),
              const SizedBox(width: 8),
              Text(
                'New batch overview',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            nameController.text.trim().isEmpty
                ? 'Ready to create a batch'
                : nameController.text.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${productionType ?? 'Production'} • ${productionCategory ?? 'Category'}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _summaryMetric('Initial birds', '$birdsCount pcs'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryMetric(
                  'Estimated cost',
                  '৳${totalChickCost.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField() {
    final formatted =
        '${startDate.day.toString().padLeft(2, '0')}/'
        '${startDate.month.toString().padLeft(2, '0')}/${startDate.year}';

    return InkWell(
      onTap: pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(
          'Batch start date',
          icon: Icons.calendar_today_outlined,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatted,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Change',
              style: TextStyle(
                color: context.colors.brand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final birdsCount = int.tryParse(initialBirdsController.text.trim()) ?? 0;
    final pricePerBird =
        double.tryParse(chickPriceController.text.trim()) ?? 0.0;
    final totalChickCost = birdsCount * pricePerBird;

    return Scaffold(
      backgroundColor: colors.soft,
      appBar: AppBar(
        backgroundColor: colors.card,
        foregroundColor: colors.ink,
        title: const Text(
          'Create New Batch',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryCard(birdsCount, totalChickCost),
                _sectionCard(
                  number: 1,
                  title: 'Batch identity',
                  subtitle:
                      'Give your flock a name and choose its production type.',
                  icon: Icons.badge_outlined,
                  children: [
                    TextFormField(
                      controller: nameController,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration(
                        'Batch name *',
                        hint: 'e.g. Broiler-2026-01',
                        icon: Icons.edit_note_outlined,
                      ),
                      validator: (value) => _requiredText(value, 'Batch name'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: productionType,
                            isExpanded: true,
                            decoration: _inputDecoration(
                              'Production type *',
                              icon: Icons.category_outlined,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Meat Production',
                                child: Text('Meat'),
                              ),
                              DropdownMenuItem(
                                value: 'Egg Production',
                                child: Text('Eggs'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                productionType = value;
                                productionCategory =
                                    currentCategories.isNotEmpty
                                    ? currentCategories.first
                                    : null;
                                breed = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value:
                                currentCategories.contains(productionCategory)
                                ? productionCategory
                                : null,
                            isExpanded: true,
                            decoration: _inputDecoration(
                              'Category *',
                              icon: Icons.tune_outlined,
                            ),
                            items: currentCategories
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                productionCategory = value;
                                breed = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (productionCategory == 'Other') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customCategoryController,
                        decoration: _inputDecoration(
                          'Specify category *',
                          hint: 'e.g. Quail, Turkey',
                          icon: Icons.more_horiz,
                        ),
                        validator: (value) => productionCategory == 'Other'
                            ? _requiredText(value, 'Category name')
                            : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: breedList.contains(breed) ? breed : null,
                      isExpanded: true,
                      decoration: _inputDecoration(
                        'Breed / strain (optional)',
                        icon: Icons.pets_outlined,
                      ),
                      items: breedList
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => breed = value),
                    ),
                  ],
                ),
                _sectionCard(
                  number: 2,
                  title: 'Flock & cost',
                  subtitle: 'Record the starting flock and purchase cost.',
                  icon: Icons.egg_alt_outlined,
                  children: [
                    _dateField(),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: initialBirdsController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              'Initial birds *',
                              hint: '500',
                              icon: Icons.numbers_outlined,
                            ),
                            validator: _positiveInteger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: chickPriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              'Price / bird',
                              hint: '50.00',
                              icon: Icons.payments_outlined,
                              prefixText: '৳ ',
                            ),
                            validator: _nonNegativePrice,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.noticeBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.noticeBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: colors.noticeIcon,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Additional birds will start from 0. You can add birds later from the active batch.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: colors.noticeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _sectionCard(
                  number: 3,
                  title: 'Housing & notes',
                  subtitle: 'Add optional location and purchase details.',
                  icon: Icons.warehouse_outlined,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: shedController,
                            decoration: _inputDecoration(
                              'Shed / house',
                              hint: 'Shed-1',
                              icon: Icons.roofing_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: sourceController,
                            decoration: _inputDecoration(
                              'Source',
                              hint: 'Hatchery',
                              icon: Icons.local_shipping_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        'Notes / remarks (optional)',
                        hint: 'Vaccine, supplier, or other remarks...',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: colors.card,
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                offset: const Offset(0, -2),
                blurRadius: 10,
              ),
            ],
          ),
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.onBrand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSaving ? null : saveBatchToSupabase,
              icon: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onBrand,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isSaving ? 'Saving batch...' : 'Create batch',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
