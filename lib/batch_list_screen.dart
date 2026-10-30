import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BatchListScreenNew extends StatefulWidget {
  const BatchListScreenNew({super.key});

  @override
  State<BatchListScreenNew> createState() => _BatchListScreenNewState();
}

class _BatchListScreenNewState extends State<BatchListScreenNew> {
  final client = Supabase.instance.client;
  List<Map<String, dynamic>> batches = [];
  bool loading = true;
  String selectedFilter = 'All'; // 'All', 'Active', 'Closed'

  @override
  void initState() {
    super.initState();
    loadBatches();
  }

  Future<void> loadBatches() async {
    setState(() => loading = true);
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final data = await client
          .from('batches')
          .select()
          .eq('user_id', user.id)
          .order('start_date', ascending: false);

      if (!mounted) return;
      setState(() {
        batches = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load batches: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateBatchStatus(String batchId, String newStatus, {String? closeType}) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'close_type': newStatus == 'Closed' ? (closeType ?? 'Manual') : null,
        'closed_date': newStatus == 'Closed' ? DateTime.now().toIso8601String().split('T').first : null,
      };

      await client.from('batches').update(updateData).eq('id', batchId);
      await loadBatches();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'Closed' ? 'Batch closed ($closeType)' : 'Batch re-opened'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> confirmCloseBatch(Map<String, dynamic> batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Batch?'),
        content: Text('Do you want to manually close batch "${batch['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            child: const Text('Confirm Close'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await updateBatchStatus(batch['id'].toString(), 'Closed', closeType: 'Manual');
    }
  }

  Future<void> deleteBatch(Map<String, dynamic> batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Batch?'),
        content: Text('Deleting "${batch['name']}" will remove all its records! Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await client.from('batches').delete().eq('id', batch['id']);
        setState(() => batches.removeWhere((b) => b['id'] == batch['id']));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> get filteredBatches {
    if (selectedFilter == 'Active') {
      return batches.where((b) => (b['status'] ?? 'Active') == 'Active').toList();
    } else if (selectedFilter == 'Closed') {
      return batches.where((b) => (b['status'] ?? 'Active') == 'Closed').toList();
    }
    return batches;
  }

  Widget _buildStatusChip(Map<String, dynamic> batch) {
    final status = (batch['status'] ?? 'Active').toString();
    final closeType = (batch['close_type'] ?? '').toString();

    if (status == 'Active') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text('Active', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      );
    } else {
      final isAuto = closeType.toLowerCase() == 'auto';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isAuto ? Colors.grey.shade100 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAuto ? Colors.grey.shade400 : Colors.orange.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isAuto ? Icons.auto_mode : Icons.lock_clock, size: 14, color: isAuto ? Colors.grey.shade700 : Colors.orange.shade800),
            const SizedBox(width: 4),
            Text(
              isAuto ? 'Auto Closed' : 'Manual Closed',
              style: TextStyle(color: isAuto ? Colors.grey.shade800 : Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch List'),
        actions: [
          IconButton(onPressed: loadBatches, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'All', label: Text('All')),
                ButtonSegment(value: 'Active', label: Text('Active')),
                ButtonSegment(value: 'Closed', label: Text('Closed')),
              ],
              selected: {selectedFilter},
              onSelectionChanged: (newVal) {
                setState(() => selectedFilter = newVal.first);
              },
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filteredBatches.isEmpty
                    ? Center(child: Text('No $selectedFilter batches found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredBatches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final batch = filteredBatches[index];
                          final isActive = (batch['status'] ?? 'Active') == 'Active';

                          return Card(
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          batch['name'] ?? 'Unnamed Batch',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      _buildStatusChip(batch),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Type: ${batch['production_type'] ?? '-'} (${batch['production_category'] ?? '-'})'),
                                  Text('Breed: ${batch['breed'] ?? '-'} | Birds: ${batch['initial_birds'] ?? 0}'),
                                  Text('Started: ${batch['start_date'] ?? '-'}'),
                                  if (!isActive && batch['closed_date'] != null)
                                    Text('Closed: ${batch['closed_date']}', style: const TextStyle(color: Colors.grey)),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (isActive)
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.check_box_outlined, size: 16, color: Colors.orange),
                                          label: const Text('Close Batch', style: TextStyle(color: Colors.orange)),
                                          onPressed: () => confirmCloseBatch(batch),
                                        )
                                      else
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.replay, size: 16, color: Colors.green),
                                          label: const Text('Re-open', style: TextStyle(color: Colors.green)),
                                          onPressed: () => updateBatchStatus(batch['id'].toString(), 'Active'),
                                        ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => deleteBatch(batch),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
