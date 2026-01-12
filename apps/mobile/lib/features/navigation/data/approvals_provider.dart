import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dashboard/data/dashboard_provider.dart';
import '../../dashboard/data/active_role_provider.dart';

class ApprovalItem {
  const ApprovalItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.requestedBy,
    required this.requestedAt,
    required this.status,
    this.notes,
  });

  final String id;
  final String title;
  final String description;
  final String type; // e.g., form, document, sop
  final String? requestedBy;
  final DateTime requestedAt;
  final String status; // pending/approved/rejected/revision
  final String? notes;

  ApprovalItem copyWith({
    String? status,
    String? notes,
    String? approvedBy,
  }) {
    return ApprovalItem(
      id: id,
      title: title,
      description: description,
      type: type,
      requestedBy: requestedBy,
      requestedAt: requestedAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

abstract class ApprovalsRepositoryBase {
  Future<List<ApprovalItem>> fetchApprovals({required UserRole role});
  Future<ApprovalItem> updateStatus({
    required String id,
    required String status,
    String? notes,
  });
}

class SupabaseApprovalsRepository implements ApprovalsRepositoryBase {
  SupabaseApprovalsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ApprovalItem>> fetchApprovals({required UserRole role}) async {
    final isGlobal = role == UserRole.techSupport;
    final orgId = isGlobal ? null : await _getOrgId();
    if (!isGlobal && orgId == null) return const [];
    try {
      dynamic query = _client.from('sop_approvals').select(
            '''
            id, org_id, sop_id, status, requested_by, requested_at, notes, metadata,
            sop:sop_documents (title, summary, category, metadata),
            requester:profiles!requested_by (full_name, email)
            ''',
          );
      if (!isGlobal && orgId != null) {
        query = query.eq('org_id', orgId);
      }
      query = query.order('requested_at', ascending: false);
      final res = await query;
      return (res as List<dynamic>)
          .map((row) => _mapApproval(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e, st) {
      developer.log('fetchApprovals failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<ApprovalItem> updateStatus({
    required String id,
    required String status,
    String? notes,
  }) async {
    try {
      final res = await _client
          .from('sop_approvals')
          .update({
            'status': status,
            if (notes != null) 'notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return _mapApproval(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      developer.log('updateStatus failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<String?> _getOrgId() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final res = await _client
          .from('org_members')
          .select('org_id')
          .eq('user_id', user.id)
          .limit(1)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    return null;
  }

  ApprovalItem _mapApproval(Map<String, dynamic> row) {
    final sop = row['sop'] as Map<String, dynamic>?;
    final requester = row['requester'];
    final metadata = (row['metadata'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value),
        ) ??
        const <String, dynamic>{};
    final sopMetadata = (sop?['metadata'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value),
        ) ??
        const <String, dynamic>{};
    final requestedByName = requester is Map<String, dynamic>
        ? requester['full_name']?.toString() ??
            requester['email']?.toString()
        : null;
    final type = sop?['category']?.toString() ??
        sopMetadata['category']?.toString() ??
        'sop';
    final description = sop?['summary']?.toString() ??
        sopMetadata['summary']?.toString() ??
        metadata['description']?.toString() ??
        '';
    return ApprovalItem(
      id: row['id']?.toString() ?? '',
      title: sop?['title']?.toString() ??
          metadata['title']?.toString() ??
          'Approval item',
      description: description,
      type: type.isEmpty ? 'sop' : type,
      requestedBy: requestedByName ?? row['requested_by']?.toString(),
      requestedAt: DateTime.tryParse(row['requested_at']?.toString() ?? '') ??
          DateTime.now(),
      status: row['status']?.toString() ?? 'pending',
      notes: row['notes']?.toString(),
    );
  }
}

final approvalsRepositoryProvider = Provider<ApprovalsRepositoryBase>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SupabaseApprovalsRepository(client);
});

final approvalsProvider =
    FutureProvider.autoDispose<List<ApprovalItem>>((ref) async {
  final repo = ref.read(approvalsRepositoryProvider);
  final role = ref.watch(activeRoleProvider);
  return repo.fetchApprovals(role: role);
});
