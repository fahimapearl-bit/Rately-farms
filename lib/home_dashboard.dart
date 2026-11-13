import "average_weight_screen.dart";
import 'ai_advisor_screen.dart';
import 'package:flutter/material.dart';
import 'supabase_config.dart';
import 'add_batch_screen.dart';
import 'batch_list_screen.dart';
import 'daily_record_screen.dart';
import 'sales_screen.dart';
import 'expense_screen.dart';
import 'cloud_lists_screen.dart';
import 'cloud_summary_screens.dart';
import 'management_screens.dart';
import 'market_price_screen.dart';
import 'layer_performance_screen.dart';
import 'layer_snapshot_card.dart';

import 'app_colors.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  void _confirmLogout(BuildContext context) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: colors.error),
            SizedBox(width: 8),
            Text("Logout Confirmation"),
          ],
        ),
        content: const Text("Are you sure you want to log out from Rately Farms?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () {
              Navigator.pop(ctx);
              SupabaseConfig.client.auth.signOut();
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = SupabaseConfig.client.auth.currentUser;
    final farmName = user?.userMetadata?['farm_name']?.toString() ?? 'Rately Farms';
    final userName = user?.userMetadata?['name']?.toString() ?? 'Farmer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rately Farms', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Farm Welcome Header Card
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                      child: Icon(Icons.agriculture, color: Theme.of(context).colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farmName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Logged in as $userName",
                            style: TextStyle(fontSize: 12, color: colors.inkAlt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            LayerSnapshotCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LayerPerformanceScreen()),
              ),
            ),
            const SizedBox(height: 14),
            // AI Advisor Highlights Card
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiAdvisorScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accent, colors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.onAccent.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.psychology, color: colors.card, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AI & Batch Advisor",
                            style: TextStyle(
                              color: colors.card,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Live Break-Even, Valuation & Health Advice",
                            style: TextStyle(
                              color: colors.onAccentMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: colors.onAccentMuted, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Section 1: Batches
            _buildSectionHeader(context, "Batches", Icons.inventory_2, colors.accent),
            _buildGrid([
              _DashboardItem(
                title: "Add Batch",
                subtitle: "Create new batch",
                icon: Icons.add_business,
                color: colors.accent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddBatchPageNew()),
                ),
              ),
              _DashboardItem(
                title: "Batch List",
                subtitle: "Active & closed",
                icon: Icons.format_list_bulleted,
                color: colors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BatchListScreenNew()),
                ),
              ),
            ]),
            const SizedBox(height: 18),

            // Section 2: Daily Operations
            _buildSectionHeader(context, "Daily Records", Icons.edit_calendar, colors.info),
            _buildGrid([
              _DashboardItem(
                title: "Daily Record",
                subtitle: "Feed, water, eggs",
                icon: Icons.edit_note,
                color: colors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailyRecordPageNew()),
                ),
              ),
              _DashboardItem(
                title: "Records List",
                subtitle: "Daily entry history",
                icon: Icons.history,
                color: colors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CloudDailyRecordsScreen()),
                ),
              ),
              _DashboardItem(
                title: "Average Weight",
                subtitle: "Weight monitoring",
                icon: Icons.scale,
                color: colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AverageWeightScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 18),

            // Section 3: Finance
            _buildSectionHeader(context, "Finance", Icons.account_balance, colors.brand),
            _buildGrid([
              _DashboardItem(
                title: "Sales",
                subtitle: "Birds, eggs & litter",
                icon: Icons.point_of_sale,
                color: colors.brand,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SalesScreenV2()),
                ),
              ),
              _DashboardItem(
                title: "Expenses",
                subtitle: "Feed, medicine & more",
                icon: Icons.receipt_long,
                color: colors.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpenseScreenNew()),
                ),
              ),
              _DashboardItem(
                title: "Market Price",
                subtitle: "Daily market rates",
                icon: Icons.trending_up,
                color: colors.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MarketPriceScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 18),

            // Section 4: Reports & Analytics
            _buildSectionHeader(context, "Reports & Analytics", Icons.bar_chart, colors.purple),
            _buildGrid([
              _DashboardItem(
                title: "Date Range Summary",
                subtitle: "Periodic farm report",
                icon: Icons.date_range,
                color: colors.inkAlt,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CloudDateRangeSummaryPage()),
                ),
              ),
              _DashboardItem(
                title: "Batch Summary",
                subtitle: "Batch P&L & stats",
                icon: Icons.analytics,
                color: colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CloudBatchSummaryPage()),
                ),
              ),
              _DashboardItem(
                title: 'Layer Performance',
                subtitle: 'HDP and egg stats',
                icon: Icons.egg_outlined,
                color: colors.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LayerPerformanceScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.ink,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<_DashboardItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.28,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildCard(context, items[index]),
    );
  }

  Widget _buildCard(BuildContext context, _DashboardItem item) {
    final colors = context.colors;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: item.color.withOpacity(0.22), width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: item.color.withOpacity(0.18),
                child: Icon(item.icon, color: item.color, size: 21),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                textAlign: TextAlign.center,
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
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
