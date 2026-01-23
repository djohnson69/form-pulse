import 'dart:developer' as developer;

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/error_logger.dart';
import 'admin_models.dart';

class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;
  static const int _aiUsageWindowDays = 30;

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
    var newsPostsQuery = _client.from('news_posts').select('id');
    var notificationRulesQuery =
        _client.from('notification_rules').select('id');
    var notebookPagesQuery = _client.from('notebook_pages').select('id');
    var notebookReportsQuery = _client.from('notebook_reports').select('id');
    var signatureRequestsQuery =
        _client.from('signature_requests').select('id');
    var projectPhotosQuery = _client.from('project_photos').select('id');
    var paymentRequestsQuery =
        _client.from('payment_requests').select('id');
    var reviewsQuery = _client.from('reviews').select('id');
    var portfolioItemsQuery =
        _client.from('portfolio_items').select('id');
    var guestInvitesQuery = _client.from('guest_invites').select('id');
    var clientsQuery = _client.from('clients').select('id');
    var vendorsQuery = _client.from('vendors').select('id');
    var messageThreadsQuery = _client.from('message_threads').select('id');

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
      newsPostsQuery = newsPostsQuery.eq('org_id', orgId);
      notificationRulesQuery = notificationRulesQuery.eq('org_id', orgId);
      notebookPagesQuery = notebookPagesQuery.eq('org_id', orgId);
      notebookReportsQuery = notebookReportsQuery.eq('org_id', orgId);
      signatureRequestsQuery = signatureRequestsQuery.eq('org_id', orgId);
      projectPhotosQuery = projectPhotosQuery.eq('org_id', orgId);
      paymentRequestsQuery = paymentRequestsQuery.eq('org_id', orgId);
      reviewsQuery = reviewsQuery.eq('org_id', orgId);
      portfolioItemsQuery = portfolioItemsQuery.eq('org_id', orgId);
      guestInvitesQuery = guestInvitesQuery.eq('org_id', orgId);
      clientsQuery = clientsQuery.eq('org_id', orgId);
      vendorsQuery = vendorsQuery.eq('org_id', orgId);
      messageThreadsQuery = messageThreadsQuery.eq('org_id', orgId);
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
      newsPostsQuery,
      notificationRulesQuery,
      notebookPagesQuery,
      notebookReportsQuery,
      signatureRequestsQuery,
      projectPhotosQuery,
      paymentRequestsQuery,
      reviewsQuery,
      portfolioItemsQuery,
      guestInvitesQuery,
      clientsQuery,
      vendorsQuery,
      messageThreadsQuery,
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
    final newsPosts = results[14] as List;
    final notificationRules = results[15] as List;
    final notebookPages = results[16] as List;
    final notebookReports = results[17] as List;
    final signatureRequests = results[18] as List;
    final projectPhotos = results[19] as List;
    final paymentRequests = results[20] as List;
    final reviews = results[21] as List;
    final portfolioItems = results[22] as List;
    final guestInvites = results[23] as List;
    final clients = results[24] as List;
    final vendors = results[25] as List;
    final messageThreads = results[26] as List;

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
      newsPosts: newsPosts.length,
      notificationRules: notificationRules.length,
      notebookPages: notebookPages.length,
      notebookReports: notebookReports.length,
      signatureRequests: signatureRequests.length,
      projectPhotos: projectPhotos.length,
      paymentRequests: paymentRequests.length,
      reviews: reviews.length,
      portfolioItems: portfolioItems.length,
      guestInvites: guestInvites.length,
      clients: clients.length,
      vendors: vendors.length,
      messageThreads: messageThreads.length,
      formsByCategory: byCategory,
    );
  }

  Future<AdminAiUsageSummary> fetchAiUsageSummary({String? orgId}) async {
    final cutoff = DateTime.now().subtract(
      const Duration(days: _aiUsageWindowDays),
    );
    var query = _client
        .from('ai_jobs')
        .select('id,type,created_by,created_at')
        .gte('created_at', cutoff.toIso8601String());

    if (orgId != null && orgId.isNotEmpty) {
      query = query.eq('org_id', orgId);
    }

    final rows = await query;
    final byType = <String, int>{};
    final byUser = <String, int>{};

    for (final row in rows) {
      final type = row['type']?.toString().trim();
      if (type != null && type.isNotEmpty) {
        byType[type] = (byType[type] ?? 0) + 1;
      }
      final userId = row['created_by']?.toString().trim();
      if (userId != null && userId.isNotEmpty) {
        byUser[userId] = (byUser[userId] ?? 0) + 1;
      }
    }

    final sortedUsers = byUser.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topUserEntries = sortedUsers.take(6).toList();
    final topUserIds = topUserEntries.map((e) => e.key).toList();

    final profilesById = <String, Map<String, dynamic>>{};
    if (topUserIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id,email,first_name,last_name')
          .inFilter('id', topUserIds);
      for (final row in profiles) {
        final id = row['id']?.toString();
        if (id != null) {
          profilesById[id] = Map<String, dynamic>.from(row as Map);
        }
      }
    }

    final topUsers = topUserEntries.map((entry) {
      final profile = profilesById[entry.key];
      final firstName = profile?['first_name']?.toString() ?? '';
      final lastName = profile?['last_name']?.toString() ?? '';
      final email = profile?['email']?.toString() ?? 'unknown';
      final displayName =
          ('$firstName $lastName'.trim().isEmpty ? email : '$firstName $lastName')
              .trim();

      return AdminAiUserUsage(
        userId: entry.key,
        displayName: displayName,
        email: email,
        jobs: entry.value,
      );
    }).toList();

    return AdminAiUsageSummary(
      totalJobs: rows.length,
      byType: byType,
      topUsers: topUsers,
      windowLabel: 'Last $_aiUsageWindowDays days',
    );
  }

  Future<UserRole?> _resolveCurrentUserRole(String userId) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final rawRole = profile?['role']?.toString();
      if (rawRole != null && rawRole.isNotEmpty) {
        return UserRole.fromRaw(rawRole);
      }
    } catch (e, st) {
      developer.log(
        'AdminRepository: profiles role lookup failed, trying org_members',
        error: e,
        stackTrace: st,
      );
    }
    try {
      final member = await _client
          .from('org_members')
          .select('role')
          .eq('user_id', userId)
          .maybeSingle();
      final rawRole = member?['role']?.toString();
      if (rawRole != null && rawRole.isNotEmpty) {
        return UserRole.fromRaw(rawRole);
      }
    } catch (e, st) {
      ErrorLogger.warn(
        'Could not resolve user role from profiles or org_members',
        context: 'AdminRepository._resolveCurrentUserRole',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  Future<List<AdminOrgSummary>> fetchOrganizations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final role = await _resolveCurrentUserRole(userId);
    final canViewAllOrgs = role?.canViewAcrossOrgs ?? false;
    late final List<dynamic> orgRows;
    late final List<dynamic> members;

    if (canViewAllOrgs) {
      orgRows = await _client.from('orgs').select('id,name,created_at');
      members = await _client.from('org_members').select('org_id, role');
    } else {
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

      orgRows = await _client
          .from('orgs')
          .select('id,name,created_at')
          .inFilter('id', orgIds);
      members = await _client
          .from('org_members')
          .select('org_id, role')
          .inFilter('org_id', orgIds);
    }

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

  /// Fetch full organization details by ID
  Future<AdminOrgDetail?> fetchOrganizationDetail(String orgId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final role = await _resolveCurrentUserRole(userId);
    final canViewAllOrgs = role?.canViewAcrossOrgs ?? false;
    if (!canViewAllOrgs) return null;

    final res = await _client
        .from('orgs')
        .select()
        .eq('id', orgId)
        .maybeSingle();

    if (res == null) return null;

    // Get member count
    final members = await _client
        .from('org_members')
        .select('id')
        .eq('org_id', orgId);
    final memberCount = (members as List).length;

    return AdminOrgDetail(
      id: res['id'] as String,
      name: res['name'] as String? ?? '',
      displayName: res['display_name'] as String?,
      industry: res['industry'] as String?,
      companySize: res['company_size'] as String?,
      website: res['website'] as String?,
      phone: res['phone'] as String?,
      addressLine1: res['address_line1'] as String?,
      addressLine2: res['address_line2'] as String?,
      city: res['city'] as String?,
      state: res['state'] as String?,
      postalCode: res['postal_code'] as String?,
      country: res['country'] as String?,
      taxId: res['tax_id'] as String?,
      isActive: res['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(res['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(res['updated_at']?.toString() ?? '') ?? DateTime.now(),
      memberCount: memberCount,
    );
  }

  /// Create a new organization (platform roles only)
  Future<AdminOrgDetail> createOrganization({
    required String name,
    String? displayName,
    String? industry,
    String? companySize,
    String? website,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? taxId,
  }) async {
    final res = await _client.functions.invoke(
      'org-manage',
      body: {
        'action': 'create',
        'name': name,
        if (displayName != null) 'displayName': displayName,
        if (industry != null) 'industry': industry,
        if (companySize != null) 'companySize': companySize,
        if (website != null) 'website': website,
        if (phone != null) 'phone': phone,
        if (addressLine1 != null) 'addressLine1': addressLine1,
        if (addressLine2 != null) 'addressLine2': addressLine2,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (postalCode != null) 'postalCode': postalCode,
        if (country != null) 'country': country,
        if (taxId != null) 'taxId': taxId,
      },
    );

    final data = res.data as Map<String, dynamic>?;
    if (data == null || data['ok'] != true) {
      throw Exception(data?['error']?.toString() ?? 'Failed to create organization');
    }

    return AdminOrgDetail.fromEdgeResponse(data['org'] as Map<String, dynamic>);
  }

  /// Update an existing organization (platform roles only)
  Future<AdminOrgDetail> updateOrganization({
    required String orgId,
    String? name,
    String? displayName,
    String? industry,
    String? companySize,
    String? website,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? taxId,
    bool? isActive,
  }) async {
    final res = await _client.functions.invoke(
      'org-manage',
      body: {
        'action': 'update',
        'orgId': orgId,
        if (name != null) 'name': name,
        if (displayName != null) 'displayName': displayName,
        if (industry != null) 'industry': industry,
        if (companySize != null) 'companySize': companySize,
        if (website != null) 'website': website,
        if (phone != null) 'phone': phone,
        if (addressLine1 != null) 'addressLine1': addressLine1,
        if (addressLine2 != null) 'addressLine2': addressLine2,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (postalCode != null) 'postalCode': postalCode,
        if (country != null) 'country': country,
        if (taxId != null) 'taxId': taxId,
        if (isActive != null) 'isActive': isActive,
      },
    );

    final data = res.data as Map<String, dynamic>?;
    if (data == null || data['ok'] != true) {
      throw Exception(data?['error']?.toString() ?? 'Failed to update organization');
    }

    return AdminOrgDetail.fromEdgeResponse(data['org'] as Map<String, dynamic>);
  }

  /// Soft-delete (deactivate) an organization (platform roles only)
  Future<void> deleteOrganization(String orgId) async {
    final res = await _client.functions.invoke(
      'org-manage',
      body: {
        'action': 'delete',
        'orgId': orgId,
      },
    );

    final data = res.data as Map<String, dynamic>?;
    if (data == null || data['ok'] != true) {
      throw Exception(data?['error']?.toString() ?? 'Failed to delete organization');
    }
  }

  Future<List<AdminUserSummary>> fetchUsers({
    String? orgId,
    String? search,
    UserRole? role,
  }) async {
    var query = _client.from('profiles').select();

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

    final res = await query.limit(250);
    final users = res.map<AdminUserSummary>((row) {
      final roleName = row['role']?.toString();
      return AdminUserSummary(
        id: row['id'].toString(),
        orgId: row['org_id']?.toString() ?? '',
        email: row['email']?.toString() ?? 'unknown',
        firstName: row['first_name']?.toString() ?? '',
        lastName: row['last_name']?.toString() ?? '',
        role: UserRole.fromRaw(roleName),
        isActive: row['is_active'] as bool? ?? true,
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();

    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return users;
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

  Future<void> updateUserActive({
    required String userId,
    required bool isActive,
  }) async {
    try {
      await _client.from('profiles').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } on PostgrestException catch (e) {
      if (e.message.contains('is_active') || e.code == '42703') {
        return;
      }
      rethrow;
    }
  }

  // ============================================
  // INVITATION MANAGEMENT
  // ============================================

  /// Fetch pending invitations for an organization
  Future<List<PendingInvitation>> fetchPendingInvitations({String? orgId}) async {
    try {
      var query = _client
          .from('user_invitations')
          .select()
          .eq('status', 'pending');

      if (orgId != null) {
        query = query.eq('org_id', orgId);
      }

      final res = await query.order('invited_at', ascending: false);
      return (res as List)
          .map((row) => PendingInvitation.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      // Table might not exist yet
      if (e.code == '42P01') return [];
      rethrow;
    }
  }

  /// Resend an invitation email
  Future<void> resendInvitation(String invitationId) async {
    // Get invitation details
    final invitation = await _client
        .from('user_invitations')
        .select()
        .eq('id', invitationId)
        .single();

    // Call org-invite function to resend
    await _client.functions.invoke('org-invite', body: {
      'email': invitation['email'],
      'role': invitation['role'],
      'firstName': invitation['first_name'],
      'lastName': invitation['last_name'],
      'resend': true,
    });

    // Update expires_at to extend the invitation
    await _client.from('user_invitations').update({
      'expires_at': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
    }).eq('id', invitationId);
  }

  /// Revoke a pending invitation
  Future<void> revokeInvitation(String invitationId) async {
    await _client.from('user_invitations').update({
      'status': 'revoked',
    }).eq('id', invitationId);
  }

  /// Record a new invitation (called by org-invite function)
  Future<void> recordInvitation({
    required String orgId,
    required String email,
    required String role,
    String? firstName,
    String? lastName,
    required String invitedBy,
  }) async {
    await _client.from('user_invitations').upsert({
      'org_id': orgId,
      'email': email,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'invited_by': invitedBy,
      'status': 'pending',
      'invited_at': DateTime.now().toUtc().toIso8601String(),
      'expires_at': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
    }, onConflict: 'org_id,email');
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
      'id,form_id,status,submitted_at,submitted_by,attachments,metadata,forms(title)',
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
    final submitterIds = <String>{};
    for (final row in res) {
      final userId = row['submitted_by']?.toString();
      if (userId != null && userId.isNotEmpty) {
        submitterIds.add(userId);
      }
    }

    final profilesById = <String, Map<String, dynamic>>{};
    if (submitterIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, role, first_name, last_name, email')
          .inFilter('id', submitterIds.toList());
      for (final row in profiles) {
        final id = row['id']?.toString();
        if (id != null) {
          profilesById[id] = Map<String, dynamic>.from(row as Map);
        }
      }
    }

    return res.map<AdminSubmissionSummary>((row) {
      final attachments = row['attachments'];
      final attCount = attachments is List ? attachments.length : 0;
      final submitterId = row['submitted_by']?.toString();
      final profile = submitterId != null ? profilesById[submitterId] : null;
      final roleName = profile?['role']?.toString();
      final role = roleName == null ? null : UserRole.fromRaw(roleName);
      final firstName = profile?['first_name']?.toString() ?? '';
      final lastName = profile?['last_name']?.toString() ?? '';
      final email = profile?['email']?.toString() ?? '';
      final displayName = ('$firstName $lastName').trim();

      return AdminSubmissionSummary(
        id: row['id'].toString(),
        formId: row['form_id']?.toString() ?? '',
        formTitle: row['forms']?['title']?.toString(),
        status: row['status']?.toString() ?? 'submitted',
        submittedAt:
            DateTime.tryParse(row['submitted_at']?.toString() ?? '') ??
                DateTime.now(),
        submittedBy: submitterId,
        submittedByName: displayName.isNotEmpty ? displayName : email,
        submittedByRole: role,
        attachmentsCount: attCount,
        metadata: row['metadata'] as Map<String, dynamic>?,
      );
    }).toList();
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
