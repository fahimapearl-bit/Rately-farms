import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';
import 'batch_sharing.dart';
import 'batch_share_screen.dart';

class AddBirdsResult {
  final int quantity;
  final double pricePerBird;
  final String source;
  const AddBirdsResult(this.quantity, this.pricePerBird, this.source);
}

class BatchListScreenNew extends StatefulWidget {
  const BatchListScreenNew({super.key});

  @override
  State<BatchListScreenNew> createState() => _BatchListScreenNewState();
}

class _BatchListScreenNewState extends State<BatchListScreenNew> {
  final client = Supabase.instance.client;
  List<Map<String, dynamic>> batches = [];
  // batchId -> 'owner' | 'edit' | 'expenses' | 'sales' | 'view'
  Map<String, String> permissions = {};
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

      // Owned batches + batches assigned to this account (RLS-scoped).
      final access = await loadAccessibleBatches(client);

      if (!mounted) return;
      setState(() {
        batches = access.batches;
        permissions = access.permissions;
      });
    } catch (e) {
      if (mounted) {
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load batches: $e'), backgroundColor: colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addBirdsToBatch(Map<String, dynamic> batch, AddBirdsResult result) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final batchId = batch['id'].toString();

      // add_number: next in the add1, add2, add3... sequence.
      final last = await client
          .from('bird_additions')
          .select('add_number')
          .eq('batch_id', batchId)
          .order('add_number', ascending: false)
          .limit(1);
      final nextAdd = last.isEmpty
          ? 1
          : _int(last.first['add_number']) + 1;

      await client.from('bird_additions').insert({
        'user_id': user.id,
        'batch_id': batchId,
        'add_number': nextAdd,
        'add_date': DateTime.now().toIso8601String().split('T').first,
        'quantity': result.quantity,
        'price_per_bird': result.pricePerBird,
        'source': result.source,
      });

      // batches.additional_birds is re-synced by the DB trigger sync_batch_additional_birds().
      await loadBatches();

      if (mounted) {
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${result.quantity} birds (add$nextAdd) to "${batch['name']}"',
            ),
            backgroundColor: colors.brand,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add birds: $e'),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  Future<void> showAddBirdsDialog(Map<String, dynamic> batch) async {
    final colors = context.colors;
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final sourceCtrl = TextEditingController(text: 'Hatchery');
    final formKey = GlobalKey<FormState>();
    final alreadyAdded = _int(batch['additional_birds']);

    final result = await showDialog<AddBirdsResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Birds — ${batch['name']}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Added so far: $alreadyAdded pcs',
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of birds *',
                  hintText: '100',
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a count greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price / bird',
                  hintText: '50.00',
                  prefixText: '৳ ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final p = double.tryParse(v.trim());
                  if (p == null || p < 0) return 'Enter a valid price';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sourceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  hintText: 'Hatchery',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.brand),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                AddBirdsResult(
                  int.parse(qtyCtrl.text.trim()),
                  double.tryParse(priceCtrl.text.trim()) ?? 0,
                  sourceCtrl.text.trim().isEmpty
                      ? 'Hatchery'
                      : sourceCtrl.text.trim(),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      await addBirdsToBatch(batch, result);
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
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'Closed' ? 'Batch closed ($closeType)' : 'Batch re-opened'),
            backgroundColor: colors.brand,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final colors = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: colors.error),
        );
      }
    }
  }

  Future<void> confirmCloseBatch(Map<String, dynamic> batch) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Batch?'),
        content: Text('Do you want to manually close batch "${batch['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: colors.warning),
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
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Batch?'),
        content: Text('Deleting "${batch['name']}" will remove all its records! Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: colors.error),
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
          final colors = context.colors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: colors.error),
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
    final colors = context.colors;

    if (status == 'Active') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.successSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.brand),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: colors.brand),
            const SizedBox(width: 4),
            Text('Active', style: TextStyle(color: colors.brand, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      );
    } else {
      final isAuto = closeType.toLowerCase() == 'auto';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isAuto ? colors.surfaceAlt : colors.warningSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAuto ? colors.hint : colors.warning),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isAuto ? Icons.auto_mode : Icons.lock_clock, size: 14, color: isAuto ? colors.inkAlt : colors.warning),
            const SizedBox(width: 4),
            Text(
              isAuto ? 'Auto Closed' : 'Manual Closed',
              style: TextStyle(color: isAuto ? colors.ink : colors.warning, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final batch = filteredBatches[index];
                          final isActive = (batch['status'] ?? 'Active') == 'Active';
                          final isOwner = permissions[batch['id'].toString()] == 'owner';

                          return Card(
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          batch['name'] ?? 'Unnamed Batch',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      _buildStatusChip(batch),
                                      if (isOwner) ...[
                                        const SizedBox(width: 4),
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert, color: colors.muted),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Batch options',
                                          onSelected: (val) {
                                            if (val == 'close') confirmCloseBatch(batch);
                                            if (val == 'reopen') updateBatchStatus(batch['id'].toString(), 'Active');
                                            if (val == 'delete') deleteBatch(batch);
                                          },
                                          itemBuilder: (context) => [
                                            if (isActive)
                                              PopupMenuItem(
                                                value: 'close',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.check_box_outlined, size: 20, color: colors.warning),
                                                    const SizedBox(width: 10),
                                                    const Text('Close Batch'),
                                                  ],
                                                ),
                                              )
                                            else
                                              PopupMenuItem(
                                                value: 'reopen',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.replay, size: 20, color: colors.brand),
                                                    const SizedBox(width: 10),
                                                    const Text('Re-open Batch'),
                                                  ],
                                                ),
                                              ),
                                            const PopupMenuDivider(),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline, size: 20, color: colors.error),
                                                  const SizedBox(width: 10),
                                                  Text('Delete Batch', style: TextStyle(color: colors.error)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Type: ${batch['production_type'] ?? '-'} (${batch['production_category'] ?? '-'})'),
                                  Text('Breed: ${batch['breed'] ?? '-'} | Birds: ${batch['initial_birds'] ?? 0}'
                                      '${_int(batch['additional_birds']) > 0 ? ' + ${_int(batch['additional_birds'])} added' : ''}'),
                                  Text('Started: ${batch['start_date'] ?? '-'}'),
                                  if (!isActive && batch['closed_date'] != null)
                                    Text('Closed: ${batch['closed_date']}', style: TextStyle(color: colors.muted)),
                                  if (isOwner) ...[
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: Icon(Icons.group_add, size: 16, color: colors.brand),
                                          label: Text('Assign', style: TextStyle(color: colors.brand)),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: colors.brand),
                                          ),
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => BatchShareScreen(
                                                  batchId: batch['id'].toString(),
                                                  batchName: (batch['name'] ?? 'Batch').toString(),
                                                ),
                                              ),
                                            );
                                            loadBatches();
                                          },
                                        ),
                                        if (isActive) ...[
                                          const SizedBox(width: 10),
                                          FilledButton.icon(
                                            icon: const Icon(Icons.add_circle_outline, size: 16),
                                            label: const Text('Add Birds'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: colors.brand,
                                              foregroundColor: colors.onBrand,
                                            ),
                                            onPressed: () => showAddBirdsDialog(batch),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
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
