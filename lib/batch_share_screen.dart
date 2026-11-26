import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';
import 'batch_sharing.dart';

/// Owner-only screen: assign other accounts to ONE batch and control what
/// each account can do. Direct account → batch assignment, no hierarchy.
class BatchShareScreen extends StatefulWidget {
  const BatchShareScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  final String batchId;
  final String batchName;

  @override
  State<BatchShareScreen> createState() => _BatchShareScreenState();
}

class _BatchShareScreenState extends State<BatchShareScreen> {
  final client = Supabase.instance.client;
  final service = BatchSharingService(Supabase.instance.client);
  final emailCtrl = TextEditingController();

  List<BatchMemberInfo> members = [];
  bool loading = true;

  // Toggles for the account being added / edited.
  bool canEditRecords = false;
  bool canAddExpenses = false;
  bool canEditSales = false;
  String? editingUserId; // null = adding a new account

  @override
  void initState() {
    super.initState();
    loadMembers();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  Future<void> loadMembers() async {
    setState(() => loading = true);
    try {
      final list = await service.listMembers(widget.batchId);
      if (!mounted) return;
      setState(() {
        members = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _snack('Failed to load members: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? colors.error : colors.brand,
      ),
    );
  }

  Future<void> addMember() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack('Enter the account email', error: true);
      return;
    }
    try {
      final account = await service.lookupByEmail(email);
      if (!mounted) return;
      if (account == null) {
        _snack('No account found for $email', error: true);
        return;
      }
      final userId = account['id'].toString();
      if (userId == client.auth.currentUser!.id) {
        _snack('You already own this batch', error: true);
        return;
      }
      await service.addMember(
        batchId: widget.batchId,
        userId: userId,
        canEditRecords: canEditRecords,
        canAddExpenses: canAddExpenses,
        canEditSales: canEditSales,
      );
      emailCtrl.clear();
      setState(() {
        canEditRecords = false;
        canAddExpenses = false;
        canEditSales = false;
      });
      _snack('Assigned to ${account['full_name'] ?? email}');
      await loadMembers();
    } catch (e) {
      _snack('Assign failed: $e', error: true);
    }
  }

  Future<void> saveMember(BatchMemberInfo m) async {
    try {
      await service.updateMember(
        batchId: widget.batchId,
        userId: m.userId,
        canEditRecords: canEditRecords,
        canAddExpenses: canAddExpenses,
        canEditSales: canEditSales,
      );
      if (!mounted) return;
      setState(() => editingUserId = null);
      _snack('Permissions updated');
      await loadMembers();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  Future<void> removeMember(BatchMemberInfo m) async {
    try {
      await service.removeMember(
        batchId: widget.batchId,
        userId: m.userId,
      );
      _snack('Access removed');
      await loadMembers();
    } catch (e) {
      _snack('Remove failed: $e', error: true);
    }
  }

  void startEdit(BatchMemberInfo m) {
    setState(() {
      editingUserId = m.userId;
      canEditRecords = m.canEditRecords;
      canAddExpenses = m.canAddExpenses;
      canEditSales = m.canEditSales;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text('Assign — ${widget.batchName}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Assign an account to this batch',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Account email',
                    hintText: 'person@example.com',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.person_search, color: colors.brand),
                      onPressed: addMember,
                    ),
                  ),
                  onSubmitted: (_) => addMember(),
                ),
                CheckboxListTile(
                  dense: true,
                  title: const Text('Can edit daily records & weights'),
                  value: canEditRecords,
                  onChanged: (v) => setState(() => canEditRecords = v ?? false),
                ),
                CheckboxListTile(
                  dense: true,
                  title: const Text('Can add expenses'),
                  value: canAddExpenses,
                  onChanged: (v) => setState(() => canAddExpenses = v ?? false),
                ),
                CheckboxListTile(
                  dense: true,
                  title: const Text('Can edit sales'),
                  value: canEditSales,
                  onChanged: (v) => setState(() => canEditSales = v ?? false),
                ),
                const Divider(height: 32),
                Text('Assigned accounts (${members.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  const Text('No accounts assigned yet.'),
                for (final m in members)
                  Card(
                    child: editingUserId == m.userId
                        ? _editTile(colors, m)
                        : ListTile(
                            title: Text(m.fullName ?? m.userId.substring(0, 8)),
                            subtitle: Text(m.mobileNumber ?? m.permissionLabel),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(label: Text(m.permissionLabel)),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => startEdit(m),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: colors.error),
                                  onPressed: () => removeMember(m),
                                ),
                              ],
                            ),
                          ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Note: assigned accounts can never delete records or close / '
                  'delete this batch — only you (the owner) can. This is '
                  'enforced in the database, not just hidden in the app.',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _editTile(dynamic colors, BatchMemberInfo m) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.fullName ?? m.userId.substring(0, 8),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              dense: true,
              title: const Text('Can edit daily records & weights'),
              value: canEditRecords,
              onChanged: (v) => setState(() => canEditRecords = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('Can add expenses'),
              value: canAddExpenses,
              onChanged: (v) => setState(() => canAddExpenses = v ?? false),
            ),
            CheckboxListTile(
              dense: true,
              title: const Text('Can edit sales'),
              value: canEditSales,
              onChanged: (v) => setState(() => canEditSales = v ?? false),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => editingUserId = null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => saveMember(m),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );
}
