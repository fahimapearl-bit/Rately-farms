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

  static const _ink = Color(0xFF102A1F);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E9E6);
  static const _soft = Color(0xFFF4F7F5);
  static const _brand = Color(0xFF1B5E20);
  static const _brandSoft = Color(0xFFE8F2E9);

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
    initialBirdsController.addListener(_refresh);
    chickPriceController.addListener(_refresh);
    nameController.addListener(_refresh);
  }

  void _refresh() {
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: _brand),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => startDate = picked);
  }

  String? _requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _positiveInteger(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) return 'Enter a valid count greater than 0';
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
      if (user == null) throw Exception('User is not logged in. Please log in first.');

      final dbProductionType =
          productionType == 'Meat Production' ? 'Bird Production' : 'Egg Production';

      await client.from('batches').insert({
        'user_id': user.id,
        'name': nameController.text.trim(),
        'production_type': dbProductionType,
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch saved successfully'),
          backgroundColor: _brand,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving batch: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _field(
    String label, {
    String? hint,
    IconData? icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 20, color: _brand.withOpacity(0.85)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _muted,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _brand,
      ),
      hintStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.grey.shade400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brand, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }

  Widget _section({
    required String step,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _brandSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                    color: _brand,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: _muted,
                      ),
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
    );
  }

  Widget _headerCard(int birdsCount, double totalCost) {
    final batchName = nameController.text.trim();
    final typeLabel = productionType == 'Meat Production' ? 'Meat' : 'Eggs';
    final category = productionCategory ?? '—';
    final price = double.tryParse(chickPriceController.text.trim()) ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.layers_outlined, color: _brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New batch',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      batchName.isEmpty ? 'Untitled batch' : batchName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(typeLabel),
              _chip(category),
              if (breed != null) _chip(breed!),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _metric('Birds', birdsCount > 0 ? '$birdsCount' : '—'),
                ),
                Container(width: 1, height: 28, color: _line),
                Expanded(
                  child: _metric(
                    'Per bird',
                    price > 0 ? 'TK ${price.toStringAsFixed(0)}' : '—',
                  ),
                ),
                Container(width: 1, height: 28, color: _line),
                Expanded(
                  child: _metric(
                    'Total',
                    totalCost > 0 ? 'TK ${totalCost.toStringAsFixed(0)}' : '—',
                    emphasize: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _brandSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _brand,
        ),
      ),
    );
  }

  Widget _metric(String label, String value, {bool emphasize = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _muted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 15 : 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: emphasize ? _brand : _ink,
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    final formatted =
        '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year}';

    return InkWell(
      onTap: pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _field('Batch start date', icon: Icons.calendar_today_outlined),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatted,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: _ink,
              ),
            ),
            const Text(
              'Change',
              style: TextStyle(
                color: _brand,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3E2B0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Color(0xFF8A6A1A)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Additional birds start at 0. You can add more birds later from an active batch.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFF6E5718),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birdsCount = int.tryParse(initialBirdsController.text.trim()) ?? 0;
    final pricePerBird = double.tryParse(chickPriceController.text.trim()) ?? 0.0;
    final totalChickCost = birdsCount * pricePerBird;

    return Scaffold(
      backgroundColor: _soft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Create batch',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _line),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(birdsCount, totalChickCost),
                _section(
                  step: '1',
                  title: 'Identity',
                  subtitle: 'Name the batch and choose production type.',
                  children: [
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _field(
                        'Batch name *',
                        hint: 'e.g. Broiler-2026-01',
                        icon: Icons.edit_outlined,
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
                            decoration: _field(
                              'Production *',
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
                                productionCategory = currentCategories.isNotEmpty
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
                            value: currentCategories.contains(productionCategory)
                                ? productionCategory
                                : null,
                            isExpanded: true,
                            decoration: _field(
                              'Category *',
                              icon: Icons.tune_outlined,
                            ),
                            items: currentCategories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
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
                        decoration: _field(
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
                      decoration: _field(
                        'Breed / strain',
                        hint: 'Optional',
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
                _section(
                  step: '2',
                  title: 'Flock & cost',
                  subtitle: 'Starting birds and purchase price.',
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
                            decoration: _field(
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
                            decoration: _field(
                              'Price / bird',
                              hint: '50.00',
                              icon: Icons.payments_outlined,
                              prefixText: 'TK ',
                            ),
                            validator: _nonNegativePrice,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _notice(),
                  ],
                ),
                _section(
                  step: '3',
                  title: 'Housing & notes',
                  subtitle: 'Optional location and remarks.',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: shedController,
                            decoration: _field(
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
                            decoration: _field(
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
                      decoration: _field(
                        'Notes',
                        hint: 'Vaccine, supplier, or other remarks',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 72),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: _line)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _isSaving ? null : saveBatchToSupabase,
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                disabledBackgroundColor: _brand.withOpacity(0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create batch',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
