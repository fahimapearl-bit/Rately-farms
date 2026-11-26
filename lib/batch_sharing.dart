import 'package:supabase_flutter/supabase_flutter.dart';

/// Account-to-account batch sharing.
///
/// A batch always belongs to its creator (`batches.user_id` = owner). The
/// owner can assign OTHER accounts to individual batches with per-user
/// permission flags stored in `batch_members`. There is no owner/manager/
/// worker hierarchy — every assignment is direct account → batch.
///
/// Permission model (mirrors `batch_members` flags and the RLS policies):
///   * owner            — full control; only the owner can delete records,
///                        close/re-open a batch, delete a batch, or assign
///                        accounts. Enforced by RLS, not just hidden buttons.
///   * can_edit_records — add/edit daily records + weekly weights.
///   * can_add_expenses — add/edit expenses.
///   * can_edit_sales   — add/edit sales.
///   * can_view         — read-only.
class BatchAccess {
  BatchAccess({
    required this.batches,
    required this.permissions,
  });

  /// Merged owned + shared batch rows (ordered by start_date desc).
  final List<Map<String, dynamic>> batches;

  /// batchId -> 'owner' | 'edit' | 'expenses' | 'sales' | 'view'
  final Map<String, String> permissions;

  static String permissionOf(Map<String, dynamic> member) {
    if (member['can_edit_records'] == true) return 'edit';
    if (member['can_add_expenses'] == true) return 'expenses';
    if (member['can_edit_sales'] == true) return 'sales';
    return 'view';
  }

  bool get canDeleteSomething =>
      permissions.values.any((p) => p == 'owner');
}

/// Loads every batch the signed-in account can access:
/// batches they own plus batches assigned to them via batch_members.
Future<BatchAccess> loadAccessibleBatches(SupabaseClient client) async {
  final user = client.auth.currentUser;
  if (user == null) throw Exception('User not logged in');

  final results = await Future.wait([
    client
        .from('batches')
        .select()
        .eq('user_id', user.id)
        .order('start_date', ascending: false),
    client
        .from('batch_members')
        .select('batch_id, can_view, can_edit_records, can_add_expenses, '
            'can_edit_sales, batches(*)')
        .eq('user_id', user.id),
  ]);

  final ownedRows = List<Map<String, dynamic>>.from(results[0] as List);
  final memberRows = List<Map<String, dynamic>>.from(results[1] as List);

  final merged = <String, Map<String, dynamic>>{};
  final perms = <String, String>{};

  for (final row in ownedRows) {
    final id = row['id'].toString();
    merged[id] = row;
    perms[id] = 'owner';
  }
  for (final m in memberRows) {
    final batch = Map<String, dynamic>.from(m['batches'] as Map);
    final id = batch['id'].toString();
    if (!merged.containsKey(id)) {
      merged[id] = batch;
      perms[id] = BatchAccess.permissionOf(m);
    }
  }

  final list = merged.values.toList()
    ..sort((a, b) => (b['start_date'] ?? '').toString()
        .compareTo((a['start_date'] ?? '').toString()));
  return BatchAccess(batches: list, permissions: perms);
}

class BatchMemberInfo {
  final String userId;
  final bool canView;
  final bool canEditRecords;
  final bool canAddExpenses;
  final bool canEditSales;
  final String? fullName;
  final String? mobileNumber;

  BatchMemberInfo({
    required this.userId,
    required this.canView,
    required this.canEditRecords,
    required this.canAddExpenses,
    required this.canEditSales,
    this.fullName,
    this.mobileNumber,
  });

  String get permissionLabel {
    if (canEditRecords && canAddExpenses) return 'Records + Expenses';
    if (canEditRecords) return 'Edit records';
    if (canAddExpenses) return 'Expenses only';
    if (canEditSales) return 'Sales only';
    return 'View only';
  }
}

/// Owner-side management of a batch's assignments.
class BatchSharingService {
  BatchSharingService(this._client);
  final SupabaseClient _client;

  Future<List<BatchMemberInfo>> listMembers(String batchId) async {
    final rows = await _client
        .rpc('list_batch_members', params: {'p_batch_id': batchId});
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .map((r) => BatchMemberInfo(
              userId: r['user_id'].toString(),
              canView: r['can_view'] == true,
              canEditRecords: r['can_edit_records'] == true,
              canAddExpenses: r['can_add_expenses'] == true,
              canEditSales: r['can_edit_sales'] == true,
              fullName: r['full_name']?.toString(),
              mobileNumber: r['mobile_number']?.toString(),
            ))
        .toList();
  }

  /// Looks up an account by email using the security-definer RPC.
  /// Never touches auth.users directly from the client.
  Future<Map<String, dynamic>?> lookupByEmail(String email) async {
    final rows = await _client.rpc(
      'lookup_batch_collaborator',
      params: {'p_email': email.trim()},
    );
    final list = (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    return list.isEmpty ? null : list.first;
  }

  Future<void> addMember({
    required String batchId,
    required String userId,
    required bool canEditRecords,
    required bool canAddExpenses,
    required bool canEditSales,
  }) async {
    await _client.from('batch_members').upsert({
      'batch_id': batchId,
      'user_id': userId,
      'can_view': true,
      'can_edit_records': canEditRecords,
      'can_add_expenses': canAddExpenses,
      'can_edit_sales': canEditSales,
      'invited_by': _client.auth.currentUser!.id,
    });
  }

  Future<void> updateMember({
    required String batchId,
    required String userId,
    required bool canEditRecords,
    required bool canAddExpenses,
    required bool canEditSales,
  }) async {
    await _client
        .from('batch_members')
        .update({
          'can_edit_records': canEditRecords,
          'can_add_expenses': canAddExpenses,
          'can_edit_sales': canEditSales,
        })
        .eq('batch_id', batchId)
        .eq('user_id', userId);
  }

  Future<void> removeMember({
    required String batchId,
    required String userId,
  }) async {
    await _client
        .from('batch_members')
        .delete()
        .eq('batch_id', batchId)
        .eq('user_id', userId);
  }
}
