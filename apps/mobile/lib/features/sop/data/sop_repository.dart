import 'dart:developer' as developer;

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/push_dispatcher.dart';

class SopDocumentDraft {
  SopDocumentDraft({
    required this.title,
    this.summary,
    this.category,
    this.tags = const [],
    this.status = 'draft',
    this.body,
  });

  final String title;
  final String? summary;
  final String? category;
  final List<String> tags;
  final String status;
  final String? body;
}

abstract class SopRepositoryBase {
  Future<List<SopDocument>> fetchDocuments();
  Future<List<SopVersion>> fetchVersions(String sopId);
  Future<List<SopApproval>> fetchApprovals(String sopId);
  Future<List<SopAcknowledgement>> fetchAcknowledgements(String sopId);

  Future<SopDocument> createDocument(SopDocumentDraft draft);
  Future<SopDocument> updateDocument({
    required SopDocument document,
    String? title,
    String? summary,
    String? category,
    List<String>? tags,
    String? status,
  });
  Future<void> updateDraft({
    required SopDocument document,
    required String body,
  });
  Future<SopVersion> addVersion({
    required SopDocument document,
    required String body,
    String? version,
  });

  Future<SopApproval> requestApproval({
    required SopDocument document,
    String? versionId,
    String? notes,
  });
  Future<SopApproval> updateApprovalStatus({
    required SopApproval approval,
    required String status,
    String? notes,
  });

  Future<void> acknowledge({
    required SopDocument document,
    String? versionId,
  });
}

class SupabaseSopRepository implements SopRepositoryBase {
  SupabaseSopRepository(this._client) : _push = PushDispatcher(_client);

  final SupabaseClient _client;
  final PushDispatcher _push;

  @override
  Future<List<SopDocument>> fetchDocuments() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('sop_documents')
        .select()
        .eq('org_id', orgId)
        .order('updated_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => SopDocument.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<List<SopVersion>> fetchVersions(String sopId) async {
    final rows = await _client
        .from('sop_versions')
        .select()
        .eq('sop_id', sopId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => SopVersion.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<List<SopApproval>> fetchApprovals(String sopId) async {
    final rows = await _client
        .from('sop_approvals')
        .select()
        .eq('sop_id', sopId)
        .order('requested_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => SopApproval.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<List<SopAcknowledgement>> fetchAcknowledgements(String sopId) async {
    final rows = await _client
        .from('sop_acknowledgements')
        .select()
        .eq('sop_id', sopId)
        .order('acknowledged_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => SopAcknowledgement.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<SopDocument> createDocument(SopDocumentDraft draft) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final payload = {
      'org_id': orgId,
      'title': draft.title,
      'summary': draft.summary,
      'category': draft.category,
      'tags': draft.tags,
      'status': draft.status,
      'current_version': 'v1',
      'created_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final res = await _client.from('sop_documents').insert(payload).select().single();
    final doc = SopDocument.fromJson(Map<String, dynamic>.from(res as Map));
    final version = await addVersion(
      document: doc,
      body: draft.body ?? '',
      version: 'v1',
    );
    final updated = await _client
        .from('sop_documents')
        .update({
          'current_version_id': version.id,
          'current_version': version.version,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', doc.id)
        .select()
        .single();
    final created = SopDocument.fromJson(Map<String, dynamic>.from(updated as Map));
    await _safeAudit(
      orgId: created.orgId,
      resourceId: created.id,
      action: 'sop_created',
      payload: {
        'title': created.title,
        'version': version.version,
        'status': created.status,
      },
    );
    if (created.status == 'published') {
      await _safeNotifyOrgMembers(
        orgId: created.orgId,
        title: 'New SOP published',
        body: '${created.title} (${version.version}) is now available.',
        type: 'sop',
      );
    }
    return created;
  }

  @override
  Future<SopDocument> updateDocument({
    required SopDocument document,
    String? title,
    String? summary,
    String? category,
    List<String>? tags,
    String? status,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) payload['title'] = title;
    if (summary != null) payload['summary'] = summary;
    if (category != null) payload['category'] = category;
    if (tags != null) payload['tags'] = tags;
    if (status != null) payload['status'] = status;
    final res = await _client
        .from('sop_documents')
        .update(payload)
        .eq('id', document.id)
        .select()
        .single();
    final updated = SopDocument.fromJson(Map<String, dynamic>.from(res as Map));
    final changed = title != null ||
        summary != null ||
        category != null ||
        tags != null ||
        status != null;
    if (changed) {
      await _safeAudit(
        orgId: updated.orgId,
        resourceId: updated.id,
        action: 'sop_updated',
        payload: {
          if (title != null) 'title': title,
          if (summary != null) 'summary': summary,
          if (category != null) 'category': category,
          if (tags != null) 'tags': tags,
          if (status != null) 'status': status,
        },
      );
    }
    if (status != null && status != document.status) {
      await _safeNotifyOrgMembers(
        orgId: updated.orgId,
        title: 'SOP status updated',
        body: '${updated.title} is now ${updated.status}.',
        type: 'sop',
      );
    }
    return updated;
  }

  @override
  Future<void> updateDraft({
    required SopDocument document,
    required String body,
  }) async {
    try {
      final res = await _client
          .from('sop_documents')
          .select('metadata')
          .eq('id', document.id)
          .maybeSingle();
      final metadata =
          Map<String, dynamic>.from(res?['metadata'] as Map? ?? const {});
      metadata['draft_body'] = body;
      metadata['draft_updated_at'] = DateTime.now().toIso8601String();
      metadata['draft_updated_by'] = _client.auth.currentUser?.id;
      await _client.from('sop_documents').update({
        'metadata': metadata,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', document.id);
    } catch (e, st) {
      developer.log('Supabase updateDraft failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<SopVersion> addVersion({
    required SopDocument document,
    required String body,
    String? version,
  }) async {
    final label = version ?? _nextVersion(document.currentVersion);
    final payload = {
      'org_id': document.orgId,
      'sop_id': document.id,
      'version': label,
      'body': body,
      'attachments': const [],
      'created_by': _client.auth.currentUser?.id,
    };
    final res = await _client.from('sop_versions').insert(payload).select().single();
    final created = SopVersion.fromJson(Map<String, dynamic>.from(res as Map));
    await _client.from('sop_documents').update({
      'current_version_id': created.id,
      'current_version': created.version,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', document.id);
    await _updateSearchMetadata(document.id, body);
    await _safeAudit(
      orgId: document.orgId,
      resourceId: document.id,
      action: 'sop_version_added',
      payload: {
        'version': created.version,
      },
    );
    await _safeNotifyOrgMembers(
      orgId: document.orgId,
      title: 'SOP updated',
      body: '${document.title} updated to ${created.version}.',
      type: 'sop',
    );
    return created;
  }

  @override
  Future<SopApproval> requestApproval({
    required SopDocument document,
    String? versionId,
    String? notes,
  }) async {
    final payload = {
      'org_id': document.orgId,
      'sop_id': document.id,
      'version_id': versionId,
      'status': 'pending',
      'requested_by': _client.auth.currentUser?.id,
      'notes': notes,
    };
    final res = await _client.from('sop_approvals').insert(payload).select().single();
    await _client.from('sop_documents').update({
      'status': 'pending_approval',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', document.id);
    await _safeAudit(
      orgId: document.orgId,
      resourceId: document.id,
      action: 'sop_approval_requested',
      payload: {
        'versionId': versionId,
        if (notes != null) 'notes': notes,
      },
    );
    await _safeNotifyOrgMembers(
      orgId: document.orgId,
      title: 'SOP approval requested',
      body: '${document.title} is awaiting approval.',
      type: 'sop',
    );
    return SopApproval.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<SopApproval> updateApprovalStatus({
    required SopApproval approval,
    required String status,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
      'approved_by': _client.auth.currentUser?.id,
      'approved_at': DateTime.now().toIso8601String(),
      if (notes != null) 'notes': notes,
    };
    final res = await _client
        .from('sop_approvals')
        .update(payload)
        .eq('id', approval.id)
        .select()
        .single();
    if (status == 'approved') {
      await _client.from('sop_documents').update({
        'status': 'published',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', approval.sopId);
    }
    await _safeAudit(
      orgId: approval.orgId,
      resourceId: approval.sopId,
      action: 'sop_approval_${status.toLowerCase()}',
      payload: {
        'approvalId': approval.id,
        if (notes != null) 'notes': notes,
      },
    );
    await _safeNotifyOrgMembers(
      orgId: approval.orgId,
      title: 'SOP ${status.toLowerCase()}',
      body: 'SOP approval marked ${status.toLowerCase()}.',
      type: 'sop',
    );
    return SopApproval.fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<void> acknowledge({
    required SopDocument document,
    String? versionId,
  }) async {
    final payload = {
      'org_id': document.orgId,
      'sop_id': document.id,
      'version_id': versionId,
      'user_id': _client.auth.currentUser?.id,
      'acknowledged_at': DateTime.now().toIso8601String(),
    };
    try {
      await _client.from('sop_acknowledgements').insert(payload);
      await _safeAudit(
        orgId: document.orgId,
        resourceId: document.id,
        action: 'sop_acknowledged',
        payload: {
          if (versionId != null) 'versionId': versionId,
        },
      );
    } catch (e, st) {
      developer.log('Supabase acknowledge SOP failed', error: e, stackTrace: st);
    }
  }

  String _nextVersion(String? current) {
    final raw = current ?? 'v0';
    final numeric = int.tryParse(raw.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
    return 'v${numeric + 1}';
  }

  Future<void> _updateSearchMetadata(String sopId, String body) async {
    try {
      final metadata = await _loadMetadata(sopId);
      metadata['latest_body'] = body;
      metadata.remove('draft_body');
      metadata.remove('draft_updated_at');
      metadata.remove('draft_updated_by');
      await _client.from('sop_documents').update({
        'metadata': metadata,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sopId);
    } catch (e, st) {
      developer.log('SOP metadata update failed', error: e, stackTrace: st);
    }
  }

  Future<Map<String, dynamic>> _loadMetadata(String sopId) async {
    final res = await _client
        .from('sop_documents')
        .select('metadata')
        .eq('id', sopId)
        .maybeSingle();
    return Map<String, dynamic>.from(res?['metadata'] as Map? ?? const {});
  }

  Future<void> _safeNotifyOrgMembers({
    required String orgId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final rows = await _client
          .from('org_members')
          .select('user_id')
          .eq('org_id', orgId);
      final targets = (rows as List<dynamic>)
          .map((row) => (row as Map)['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      if (targets.isEmpty) return;
      final payload = targets
          .map(
            (userId) => {
              'org_id': orgId,
              'user_id': userId,
              'title': title,
              'body': body,
              'type': type,
              'is_read': false,
            },
          )
          .toList();
      await _client.from('notifications').insert(payload);
      await _push.sendToUsers(
        userIds: targets,
        orgId: orgId,
        title: title,
        body: body,
        data: {'type': type},
      );
    } catch (e, st) {
      developer.log('SOP notification failed', error: e, stackTrace: st);
    }
  }

  Future<void> _safeAudit({
    required String orgId,
    required String resourceId,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _client.from('audit_log').insert({
        'org_id': orgId,
        'actor_id': _client.auth.currentUser?.id,
        'resource_type': 'sop',
        'resource_id': resourceId,
        'action': action,
        'payload': payload ?? const {},
      });
    } catch (e, st) {
      developer.log('SOP audit log failed', error: e, stackTrace: st);
    }
  }

  Future<String?> _getOrgId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _client
          .from('org_members')
          .select('org_id')
          .eq('user_id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (e, st) {
      developer.log('SopRepository org_members lookup failed',
          error: e, stackTrace: st, name: 'SopRepository._getOrgId');
    }
    try {
      final res = await _client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (e, st) {
      developer.log('SopRepository profiles lookup failed',
          error: e, stackTrace: st, name: 'SopRepository._getOrgId');
    }
    return null;
  }
}
