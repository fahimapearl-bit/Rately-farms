import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allPrices = [];
  Map<String, Map<String, dynamic>> _latestByCategory = {};
  Map<String, double?> _priceChanges = {};

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
          .limit(40);

      final List<Map<String, dynamic>> data =
          List<Map<String, dynamic>>.from(response);

      final Map<String, Map<String, dynamic>> latestMap = {};
      final Map<String, double?> changeMap = {};

      // Group records by category to find latest and calculate trend
      for (final row in data) {
        final category = (row['category'] ?? '').toString();
        if (category.isEmpty) continue;

        if (!latestMap.containsKey(category)) {
          latestMap[category] = row;
        } else if (!changeMap.containsKey(category)) {
          // Compare with previous price
          final currentPrice = _toDouble(latestMap[category]!['price_per_unit']);
          final prevPrice = _toDouble(row['price_per_unit']);
          changeMap[category] = currentPrice - prevPrice;
        }
      }

      if (mounted) {
        setState(() {
          _allPrices = data;
          _latestByCategory = latestMap;
          _priceChanges = changeMap;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market Rate Bulletin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Official Daily Benchmark Rates',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Rates',
            onPressed: _isLoading ? null : _fetchMarketPrices,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _allPrices.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
    }

    if (_errorMessage != null && _allPrices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Failed to load rates\n$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchMarketPrices,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.deepOrange,
      onRefresh: _fetchMarketPrices,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign_outlined, color: Colors.amber.shade900, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rates are published by Central Admin based on wholesale market trends.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bento Section: Live Snapshot
          const Text(
            'TODAY\'S BENCHMARK RATES',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          _buildCategoryCard(
            categoryKey: 'broiler',
            defaultTitle: 'Broiler Chicken (Live)',
            icon: Icons.egg_alt_outlined,
            accentColor: Colors.deepOrange,
          ),
          const SizedBox(height: 10),

          _buildCategoryCard(
            categoryKey: 'sonali',
            defaultTitle: 'Sonali Chicken (Live)',
            icon: Icons.pets_outlined,
            accentColor: Colors.amber.shade800,
          ),
          const SizedBox(height: 10),

          _buildCategoryCard(
            categoryKey: 'desi',
            defaultTitle: 'Desi Chicken (Live)',
            icon: Icons.grass_outlined,
            accentColor: Colors.teal.shade700,
          ),
          const SizedBox(height: 10),

          _buildCategoryCard(
            categoryKey: 'table_egg',
            defaultTitle: 'Red Table Egg',
            icon: Icons.egg_outlined,
            accentColor: Colors.brown.shade600,
          ),

          const SizedBox(height: 24),

          // Section 2: Recent Broadcast History
          const Text(
            'RECENT BROADCAST BULLETINS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          if (_allPrices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No broadcast history available.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._allPrices.map((row) => _buildHistoryCard(row)),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String categoryKey,
    required String defaultTitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final row = _latestByCategory[categoryKey];
    final hasData = row != null;
    final price = hasData ? _toDouble(row['price_per_unit']) : 0.0;
    final unit = hasData ? (row['unit'] ?? 'kg') : 'kg';
    final itemName = hasData ? (row['item_name'] ?? defaultTitle) : defaultTitle;
    final location = hasData ? (row['market_location'] ?? 'National') : 'National';
    final dateStr = hasData ? _formatDate(row['price_date']) : 'Pending';
    final change = _priceChanges[categoryKey];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              color: accentColor.withOpacity(0.12),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 3),
                    Text(
                      location,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey.shade600),
                    const SizedBox(width: 3),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                hasData ? '৳ ${price.toStringAsFixed(unit == 'piece' ? 2 : 0)}' : '---',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: accentColor,
                ),
              ),
              Text(
                'per $unit',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              if (change != null) ...[
                const SizedBox(height: 2),
                _buildTrendBadge(change),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBadge(double diff) {
    if (diff > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Text(
          '▲ +৳${diff.toStringAsFixed(1)}',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700),
        ),
      );
    } else if (diff < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Text(
          '▼ -৳${diff.abs().toStringAsFixed(1)}',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '― Stable',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
        ),
      );
    }
  }

  Widget _buildHistoryCard(Map<String, dynamic> row) {
    final price = _toDouble(row['price_per_unit']);
    final unit = row['unit'] ?? 'kg';
    final itemName = row['item_name'] ?? 'Market Rate';
    final location = row['market_location'] ?? 'National';
    final dateStr = _formatDate(row['price_date']);
    final notes = (row['notes'] ?? '').toString().trim();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
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
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Text(
                  '৳ ${price.toStringAsFixed(unit == 'piece' ? 2 : 0)} / $unit',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrange),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: Colors.grey.shade400)),
                const SizedBox(width: 8),
                Text(
                  location,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Note: $notes',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
