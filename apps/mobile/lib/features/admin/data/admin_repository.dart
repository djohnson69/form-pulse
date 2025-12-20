import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';

class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<AdminStats> fetchStats({String? orgId}) async {
    // Fetch base lists and derive counts client-side to avoid head/count API differences.
    var formsQuery = _client.from('forms').select('id, category');
    var submissionsQuery = _client.from('submissions').select('id');
    var attachmentsQuery = _client.from('attachments').select('id');
    var projectsQuery = _client.from('projects').select('id');
    var tasksQuery = _client.from('tasks').select('id');
    var assetsQuery = _client.from('equipment').select('id');
    var inspectionsQuery = _client.from('asset_inspections').select('id');
    var incidentsQuery = _client.from('incident_reports').select('id');
    var documentsQuery = _client.from('documents').select('id');
    var trainingQuery = _client.from('training_records').select('id');
    var notificationsQuery = _client.from('notifications').select('id');
    var webhooksQuery = _client.from('webhook_endpoints').select('id');
    var exportJobsQuery = _client.from('export_jobs').select('id');
    var aiJobsQuery = _client.from('ai_jobs').select('id');

    if (orgId != null && orgId.isNotEmpty) {
      formsQuery = formsQuery.eq('org_id', orgId);
      submissionsQuery = submissionsQuery.eq('org_id', orgId);
      attachmentsQuery = attachmentsQuery.eq('org_id', orgId);
      projectsQuery = projectsQuery.eq('org_id', orgId);
      tasksQuery = tasksQuery.eq('org_id', orgId);
      assetsQuery = assetsQuery.eq('org_id', orgId);
      inspectionsQuery = inspectionsQuery.eq('org_id', orgId);
      incidentsQuery = incidentsQuery.eq('org_id', orgId);
      documentsQuery = documentsQuery.eq('org_id', orgId);
      trainingQuery = trainingQuery.eq('org_id', orgId);
      notificationsQuery = notificationsQuery.eq('org_id', orgId);
      webhooksQuery = webhooksQuery.eq('org_id', orgId);
      exportJobsQuery = exportJobsQuery.eq('org_id', orgId);
      aiJobsQuery = aiJobsQuery.eq('org_id', orgId);
    }

    final results = await Future.wait([
      formsQuery,
      submissionsQuery,
      attachmentsQuery,
      projectsQuery,
      tasksQuery,
      assetsQuery,
      inspectionsQuery,
      incidentsQuery,
      documentsQuery,
      trainingQuery,
      notificationsQuery,
      webhooksQuery,
      exportJobsQuery,
      aiJobsQuery,
    ]);

    final forms = results[0] as List;
    final submissions = results[1] as List;
    final attachments = results[2] as List;
    final projects = results[3] as List;
    final tasks = results[4] as List;
    final assets = results[5] as List;
    final inspections = results[6] as List;
    final incidents = results[7] as List;
    final documents = results[8] as List;
    final training = results[9] as List;
    final notifications = results[10] as List;
    final webhooks = results[11] as List;
    final exportJobs = results[12] as List;
    final aiJobs = results[13] as List;

    final byCategory = <String, int>{};
    for (final row in forms) {
      final cat = (row['category'] ?? 'Uncategorized').toString();
      byCategory[cat] = (byCategory[cat] ?? 0) + 1;
    }

    return AdminStats(
      forms: forms.length,
      submissions: submissions.length,
      attachments: attachments.length,
      projects: projects.length,
      tasks: tasks.length,
      assets: assets.length,
      inspections: inspections.length,
      incidents: incidents.length,
      documents: documents.length,
      trainingRecords: training.length,
      notifications: notifications.length,
      webhooks: webhooks.length,
      exportJobs: exportJobs.length,
      aiJobs: aiJobs.length,
      formsByCategory: byCategory,
    );
  }

  Future<List<AdminOrgSummary>> fetchOrganizations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final memberships = await _client
        .from('org_members')
        .select('org_id, role')
        .eq('user_id', userId);

    final orgIds = memberships
        .map((row) => row['org_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (orgIds.isEmpty) return [];

    final orgRows = await _client
        .from('orgs')
        .select('id,name,created_at')
        .inFilter('id', orgIds);
    final members = await _client
        .from('org_members')
        .select('org_id, role')
        .inFilter('org_id', orgIds);

    final roleCountsByOrg = <String, Map<String, int>>{};
    final memberCounts = <String, int>{};
    for (final row in members) {
      final orgId = row['org_id']?.toString();
      if (orgId == null) continue;
      memberCounts[orgId] = (memberCounts[orgId] ?? 0) + 1;
      final role = row['role']?.toString() ?? 'member';
      final bucket = roleCountsByOrg.putIfAbsent(orgId, () => <String, int>{});
      bucket[role] = (bucket[role] ?? 0) + 1;
    }

    return orgRows
        .map<AdminOrgSummary>(
          (row) => AdminOrgSummary(
            id: row['id'].toString(),
            name: row['name']?.toString() ?? 'Untitled org',
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
            memberCount: memberCounts[row['id'].toString()] ?? 0,
            roleCounts: roleCountsByOrg[row['id'].toString()] ?? const {},
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<AdminUserSummary>> fetchUsers({
    String? orgId,
    String? search,
    UserRole? role,
  }) async {
    var query = _client.from('profiles').select(
          'id,org_id,email,first_name,last_name,role,created_at,updated_at',
        );

    if (orgId != null && orgId.isNotEmpty) {
      query = query.eq('org_id', orgId);
    }
    if (role != null) {
      query = query.eq('role', role.name);
    }
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      query = query.or(
        'email.ilike.%$term%,first_name.ilike.%$term%,last_name.ilike.%$term%',
      );
    }

    final res = await query.order('created_at', ascending: false).limit(250);
    return res.map<AdminUserSummary>((row) {
      final roleName = row['role']?.toString();
      return AdminUserSummary(
        id: row['id'].toString(),
        orgId: row['org_id']?.toString() ?? '',
        email: row['email']?.toString() ?? 'unknown',
        firstName: row['first_name']?.toString() ?? '',
        lastName: row['last_name']?.toString() ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == roleName,
          orElse: () => UserRole.viewer,
        ),
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  Future<void> updateUserRole({
    required String userId,
    required UserRole role,
  }) async {
    await _client.from('profiles').update({
      'role': role.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  Future<List<AdminFormSummary>> fetchForms({
    String? orgId,
    String? search,
    String? category,
    bool? published,
  }) async {
    var query = _client.from('forms').select(
          'id,org_id,title,category,tags,is_published,version,updated_at',
        )..order('updated_at', ascending: false);

    if (orgId != null && orgId.isNotEmpty) {
      query = query.eq('org_id', orgId);
    }

    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('title', '%${search.trim()}%');
    }
    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (published != null) {
      query = query.eq('is_published', published);
    }

    final res = await query.limit(200);
    return res
        .map<AdminFormSummary>(
          (row) => AdminFormSummary(
            id: row['id'].toString(),
            title: row['title'] as String? ?? 'Untitled',
            category: row['category'] as String?,
            tags: (row['tags'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
            version: row['version'] as String?,
            isPublished: row['is_published'] as bool? ?? false,
            updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  Future<void> togglePublish({
    required String formId,
    required bool isPublished,
  }) async {
    await _client.from('forms').update({
      'is_published': isPublished,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', formId);
  }

  Future<List<AdminSubmissionSummary>> fetchRecentSubmissions({
    String? orgId,
    int limit = 25,
    String? status,
  }) async {
    var query = _client.from('submissions').select(
      'id,form_id,status,submitted_at,submitted_by,attachments,metadata',
    )
      ..order('submitted_at', ascending: false)
      ..limit(limit);

    if (orgId != null && orgId.isNotEmpty) {
      query = query.eq('org_id', orgId);
    }

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final res = await query;
    return res
        .map<AdminSubmissionSummary>((row) {
          final attachments = row['attachments'];
          final attCount = attachments is List ? attachments.length : 0;
          return AdminSubmissionSummary(
            id: row['id'].toString(),
            formId: row['form_id']?.toString() ?? '',
            status: row['status']?.toString() ?? 'submitted',
            submittedAt:
                DateTime.tryParse(row['submitted_at']?.toString() ?? '') ??
                    DateTime.now(),
            submittedBy: row['submitted_by']?.toString(),
            attachmentsCount: attCount,
            metadata: row['metadata'] as Map<String, dynamic>?,
          );
        })
        .toList();
  }

  Future<FormSubmission> fetchSubmissionDetail(String submissionId) async {
    final row = await _client
        .from('submissions')
        .select(
          'id,form_id,submitted_by,submitted_by_name,submitted_at,status,data,attachments,location,metadata,forms(title)',
        )
        .eq('id', submissionId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Submission not found');
    }

    final formId = row['form_id']?.toString() ?? '';
    final formTitle = row['forms']?['title']?.toString() ?? formId;
    final statusValue = row['status']?.toString() ?? 'submitted';

    return FormSubmission(
      id: row['id'].toString(),
      formId: formId,
      formTitle: formTitle,
      submittedBy: row['submitted_by']?.toString() ?? '',
      submittedByName: row['submitted_by_name']?.toString(),
      submittedAt:
          DateTime.tryParse(row['submitted_at']?.toString() ?? '') ??
              DateTime.now(),
      status: SubmissionStatus.values.firstWhere(
        (e) => e.name == statusValue,
        orElse: () => SubmissionStatus.submitted,
      ),
      data: Map<String, dynamic>.from(
        row['data'] as Map? ?? <String, dynamic>{},
      ),
      attachments: (row['attachments'] as List?)
          ?.map(
            (a) => MediaAttachment.fromJson(
              Map<String, dynamic>.from(a as Map),
            ),
          )
          .toList(),
      location: row['location'] != null
          ? LocationData.fromJson(
              Map<String, dynamic>.from(row['location'] as Map),
            )
          : null,
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Future<List<AdminAuditEvent>> fetchAuditLog({
    String? orgId,
    int limit = 50,
  }) async {
    var query = _client.from('audit_log').select(
      'id,org_id,actor_id,resource_type,resource_id,action,payload,created_at',
    )
      ..order('created_at', ascending: false)
      ..limit(limit);

    if (orgId != null && orgId.isNotEmpty) {
      query = query.eq('org_id', orgId);
    }

    final res = await query;
    return res.map<AdminAuditEvent>((row) {
      return AdminAuditEvent(
        id: row['id'] as int? ?? 0,
        orgId: row['org_id']?.toString(),
        actorId: row['actor_id']?.toString(),
        resourceType: row['resource_type']?.toString() ?? '',
        resourceId: row['resource_id']?.toString(),
        action: row['action']?.toString() ?? '',
        payload: row['payload'] as Map<String, dynamic>?,
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }
}
