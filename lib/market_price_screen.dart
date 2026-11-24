import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';

class MarketPriceScreen extends StatefulWidget {
  const MarketPriceScreen({super.key});

  @override
  State<MarketPriceScreen> createState() => _MarketPriceScreenState();
}

// Backward compatibility alias
class MarketPriceScreenV2 extends StatelessWidget {
  const MarketPriceScreenV2({super.key});

  @override
  Widget build(BuildContext context) => const MarketPriceScreen();
}

class _MarketPriceScreenState extends State<MarketPriceScreen> {
  final supabase = Supabase.instance.client;

  // ─── Hardcoded PIN for rate update (change this as needed) ───
  static const String _updatePin = '2468';

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allPrices = [];
  Map<String, Map<String, dynamic>> _latestByCategory = {};
  Map<String, double?> _priceChanges = {};
  Map<String, double?> _priceChangePercent = {};

  // Category definitions matching the rest of the app
  static const Map<String, String> _birdCategories = {
    'broiler': 'Broiler Chicken (Live)',
    'sonali': 'Sonali Chicken (Live)',
    'desi': 'Desi Chicken (Live)',
    'layer': 'Layer Chicken (Live)',
  };

  static const Map<String, String> _eggCategories = {
    'table_egg': 'Table Egg',
    'hatching_egg': 'Hatching Egg',
  };

  static const Map<String, IconData> _categoryIcons = {
    'broiler': Icons.egg_alt_outlined,
    'sonali': Icons.pets_outlined,
    'desi': Icons.grass_outlined,
    'layer': Icons.female_outlined,
    'table_egg': Icons.egg_outlined,
    'hatching_egg': Icons.egg_outlined,
  };

  @override
  void initState() {
    super.initState();
    _fetchMarketPrices();
  }

  Future<void> _fetchMarketPrices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await supabase
          .from('market_prices')
          .select()
          .order('price_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(60);

      final List<Map<String, dynamic>> data =
          List<Map<String, dynamic>>.from(response);

      final Map<String, Map<String, dynamic>> latestMap = {};
      final Map<String, double?> changeMap = {};
      final Map<String, double?> percentMap = {};

      // Group by category → find latest + previous price for trend
      for (final row in data) {
        final category = (row['category'] ?? '').toString();
        if (category.isEmpty) continue;

        if (!latestMap.containsKey(category)) {
          latestMap[category] = row;
        } else if (!changeMap.containsKey(category)) {
          final currentPrice = _toDouble(latestMap[category]!['price_per_unit']);
          final prevPrice = _toDouble(row['price_per_unit']);
          final diff = currentPrice - prevPrice;
          changeMap[category] = diff;

          if (prevPrice > 0) {
            percentMap[category] = (diff / prevPrice) * 100;
          } else {
            percentMap[category] = null;
          }
        }
      }

      if (mounted) {
        setState(() {
          _allPrices = data;
          _latestByCategory = latestMap;
          _priceChanges = changeMap;
          _priceChangePercent = percentMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  // ────────────────────────────────────────────────
  // PIN Dialog → then open Update Form
  // ────────────────────────────────────────────────
  Future<void> _requestPinAndUpdate() async {
    final pinController = TextEditingController();
    final colors = context.colors;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: colors.warning, size: 22),
              const SizedBox(width: 8),
              const Text('Enter PIN', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Only authorized users can update market rates.',
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '4-digit PIN',
                  counterText: '',
                  prefixIcon: Icon(Icons.pin_outlined, color: colors.warning),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.warning, width: 1.5),
                  ),
                ),
                onSubmitted: (_) {
                  if (pinController.text == _updatePin) {
                    Navigator.pop(ctx, true);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: colors.warning),
              onPressed: () {
                if (pinController.text == _updatePin) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Incorrect PIN'),
                      backgroundColor: colors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    pinController.dispose();

    if (ok == true && mounted) {
      await _showUpdateForm();
    }
  }

  // ────────────────────────────────────────────────
  // Update Form (Bottom Sheet)
  // ────────────────────────────────────────────────
  Future<void> _showUpdateForm() async {
    final colors = context.colors;

    // Controllers for each category
    final Map<String, TextEditingController> priceCtrls = {};
    final Map<String, String> units = {};

    for (final key in [..._birdCategories.keys, ..._eggCategories.keys]) {
      final existing = _latestByCategory[key];
      final currentPrice = existing != null
          ? _toDouble(existing['price_per_unit']).toStringAsFixed(
              (existing['unit'] == 'piece') ? 2 : 0)
          : '';
      priceCtrls[key] = TextEditingController(text: currentPrice);
      units[key] = existing?['unit']?.toString() ??
          (key.contains('egg') ? 'piece' : 'kg');
    }

    final locationCtrl = TextEditingController(
        text: _latestByCategory.values.isNotEmpty
            ? (_latestByCategory.values.first['market_location'] ?? 'National')
            : 'National');
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Text(
                      'Update Market Rates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.inkAlt,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter today\'s benchmark prices',
                      style: TextStyle(fontSize: 13, color: colors.muted),
                    ),
                    const SizedBox(height: 20),

                    // Date + Location
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Price Date',
                                prefixIcon: Icon(Icons.calendar_today_outlined,
                                    size: 18, color: colors.warning),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                              child: Text(
                                DateFormat('dd MMM yyyy').format(selectedDate),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: locationCtrl,
                            decoration: InputDecoration(
                              labelText: 'Location',
                              prefixIcon: Icon(Icons.location_on_outlined,
                                  size: 18, color: colors.warning),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Birds Section
                    Text(
                      'BIRDS PRICE (per kg)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.inkAlt,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._birdCategories.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: priceCtrls[e.key],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: e.value,
                            prefixText: '৳ ',
                            suffixText: ' / kg',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 8),
                    Text(
                      'EGG PRICE (per piece)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.inkAlt,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._eggCategories.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: priceCtrls[e.key],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: e.value,
                            prefixText: '৳ ',
                            suffixText: ' / piece',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.warning,
                          foregroundColor: colors.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                try {
                                  final location = locationCtrl.text.trim().isEmpty
                                      ? 'National'
                                      : locationCtrl.text.trim();
                                  final notes = notesCtrl.text.trim();
                                  final dateStr = selectedDate
                                      .toIso8601String()
                                      .split('T')
                                      .first;

                                  final List<Map<String, dynamic>> rows = [];

                                  for (final entry in {
                                    ..._birdCategories,
                                    ..._eggCategories
                                  }.entries) {
                                    final priceText =
                                        priceCtrls[entry.key]!.text.trim();
                                    if (priceText.isEmpty) continue;

                                    final price = double.tryParse(priceText);
                                    if (price == null || price < 0) continue;

                                    final isEgg = entry.key.contains('egg');
                                    rows.add({
                                      'category': entry.key,
                                      'item_name': entry.value,
                                      'price_per_unit': price,
                                      'unit': isEgg ? 'piece' : 'kg',
                                      'market_location': location,
                                      'price_date': dateStr,
                                      'notes': notes.isEmpty ? null : notes,
                                    });
                                  }

                                  if (rows.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Enter at least one price'),
                                        backgroundColor: colors.error,
                                      ),
                                    );
                                    setModalState(() => isSaving = false);
                                    return;
                                  }

                                  await supabase.from('market_prices').insert(rows);

                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '${rows.length} rate(s) updated successfully'),
                                        backgroundColor: colors.brand,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    _fetchMarketPrices();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to save: $e'),
                                        backgroundColor: colors.error,
                                      ),
                                    );
                                  }
                                } finally {
                                  setModalState(() => isSaving = false);
                                }
                              },
                        icon: isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.card,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          isSaving ? 'Saving...' : 'Save Rates',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Dispose controllers
    for (final c in priceCtrls.values) {
      c.dispose();
    }
    locationCtrl.dispose();
    notesCtrl.dispose();
  }

  // ────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surfaceAlt,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market Rate Bulletin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Official Daily Benchmark Rates',
              style: TextStyle(fontSize: 12, color: colors.onAccentMuted),
            ),
          ],
        ),
        backgroundColor: colors.warning,
        foregroundColor: colors.card,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Rates',
            onPressed: _isLoading ? null : _fetchMarketPrices,
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_outlined),
            tooltip: 'Update Rates (PIN required)',
            onPressed: _requestPinAndUpdate,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colors = context.colors;

    if (_isLoading && _allPrices.isEmpty) {
      return Center(child: CircularProgressIndicator(color: colors.warning));
    }

    if (_errorMessage != null && _allPrices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              const SizedBox(height: 12),
              Text(
                'Failed to load rates\n$_errorMessage',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchMarketPrices,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.warning,
                  foregroundColor: colors.card,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: colors.warning,
      onRefresh: _fetchMarketPrices,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.warningSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.warningBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign_outlined, color: colors.warning, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rates are published based on wholesale market trends. Tap the edit icon to update (PIN required).',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── BIRDS SECTION ──
          _sectionHeader('BIRDS PRICE', Icons.pets_outlined),
          const SizedBox(height: 10),
          ..._birdCategories.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCategoryCard(
                categoryKey: e.key,
                defaultTitle: e.value,
                icon: _categoryIcons[e.key] ?? Icons.egg_alt_outlined,
                accentColor: colors.warning,
              ),
            );
          }),

          const SizedBox(height: 16),

          // ── EGGS SECTION ──
          _sectionHeader('EGG PRICE', Icons.egg_outlined),
          const SizedBox(height: 10),
          ..._eggCategories.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCategoryCard(
                categoryKey: e.key,
                defaultTitle: e.value,
                icon: _categoryIcons[e.key] ?? Icons.egg_outlined,
                accentColor: colors.accent,
              ),
            );
          }),

          const SizedBox(height: 24),

          // ── HISTORY ──
          _sectionHeader('RECENT BROADCASTS', Icons.history),
          const SizedBox(height: 10),

          if (_allPrices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No broadcast history available.',
                  style: TextStyle(color: colors.muted),
                ),
              ),
            )
          else
            ..._allPrices.map((row) => _buildHistoryCard(row)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.inkAlt),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colors.inkAlt,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required String categoryKey,
    required String defaultTitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final colors = context.colors;
    final row = _latestByCategory[categoryKey];
    final hasData = row != null;
    final price = hasData ? _toDouble(row['price_per_unit']) : 0.0;
    final unit = hasData ? (row['unit'] ?? 'kg') : (categoryKey.contains('egg') ? 'piece' : 'kg');
    final itemName = hasData ? (row['item_name'] ?? defaultTitle) : defaultTitle;
    final location = hasData ? (row['market_location'] ?? 'National') : 'National';
    final dateStr = hasData ? _formatDate(row['price_date']) : 'Pending';
    final change = _priceChanges[categoryKey];
    final percent = _priceChangePercent[categoryKey];

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colors.inkAlt,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: colors.muted),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        location,
                        style: TextStyle(fontSize: 11, color: colors.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_outlined, size: 11, color: colors.muted),
                    const SizedBox(width: 3),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasData
                    ? '৳ ${price.toStringAsFixed(unit == 'piece' ? 2 : 0)}'
                    : '---',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: accentColor,
                ),
              ),
              Text(
                'per $unit',
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
              if (change != null) ...[
                const SizedBox(height: 3),
                _buildTrendBadge(change, percent),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBadge(double diff, double? percent) {
    final colors = context.colors;

    if (diff > 0) {
      final percentText = percent != null
          ? ' (↑ ${percent.toStringAsFixed(1)}%)'
          : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.successSoft,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.brandSoft),
        ),
        child: Text(
          '▲ +৳${diff.toStringAsFixed(1)}$percentText',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colors.brand,
          ),
        ),
      );
    } else if (diff < 0) {
      final percentText = percent != null
          ? ' (↓ ${percent.abs().toStringAsFixed(1)}%)'
          : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.errorSoft,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.errorBorder),
        ),
        child: Text(
          '▼ -৳${diff.abs().toStringAsFixed(1)}$percentText',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colors.error,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '― Stable',
          style: TextStyle(fontSize: 10, color: colors.inkAlt),
        ),
      );
    }
  }

  Widget _buildHistoryCard(Map<String, dynamic> row) {
    final colors = context.colors;
    final price = _toDouble(row['price_per_unit']);
    final unit = row['unit'] ?? 'kg';
    final itemName = row['item_name'] ?? 'Market Rate';
    final location = row['market_location'] ?? 'National';
    final dateStr = _formatDate(row['price_date']);
    final notes = (row['notes'] ?? '').toString().trim();
    final category = (row['category'] ?? '').toString();

    final isEgg = category.contains('egg');
    final accent = isEgg ? colors.accent : colors.warning;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '৳ ${price.toStringAsFixed(unit == 'piece' ? 2 : 0)} / $unit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: colors.hint)),
                const SizedBox(width: 8),
                Text(
                  location,
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Note: $notes',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: colors.inkAlt,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
