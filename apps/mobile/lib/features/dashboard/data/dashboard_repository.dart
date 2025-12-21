import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/api_client.dart';
import '../../../core/utils/storage_utils.dart';

class DashboardData {
  DashboardData({
    required this.forms,
    required this.submissions,
    required this.notifications,
  });

  final List<FormDefinition> forms;
  final List<FormSubmission> submissions;
  final List<AppNotification> notifications;

  int get activeForms => forms.length;
  int get completedSubmissions => submissions.length;
  int get unreadNotifications => notifications.where((n) => !n.isRead).length;
}

class SubmissionFilters {
  SubmissionFilters({
    this.status,
    this.formId,
    this.startDate,
    this.endDate,
  });

  final SubmissionStatus? status;
  final String? formId;
  final DateTime? startDate;
  final DateTime? endDate;
}

/// Repository interface for dashboard data sources.
abstract class DashboardRepositoryBase {
  Future<DashboardData> loadDashboard();
  Future<List<FormSubmission>> fetchSubmissions({
    SubmissionFilters? filters,
    int limit = 200,
  });
  Future<FormSubmission> createSubmission({
    required String formId,
    required Map<String, dynamic> data,
    required String submittedBy,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? location,
    Map<String, dynamic>? metadata,
  });
  Future<FormSubmission> updateSubmissionStatus({
    required String submissionId,
    required SubmissionStatus status,
    String? note,
  });
  Future<void> markNotificationRead(String id);
  Future<FormDefinition> createForm(FormDefinition form);
}

/// Repository that communicates with the backend API.
class DashboardRepository implements DashboardRepositoryBase {
  DashboardRepository(this._client);

  final ApiClient _client;

  @override
  Future<DashboardData> loadDashboard() async {
    try {
      final responses = await Future.wait([
        _client.raw.get(ApiConstants.forms),
        _client.raw.get(ApiConstants.submissions),
        _client.raw.get(ApiConstants.notifications),
      ]);

      final forms =
          (responses[0].data['forms'] as List?)
              ?.map((e) => FormDefinition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <FormDefinition>[];

      final submissions =
          (responses[1].data['submissions'] as List?)
              ?.map((e) => FormSubmission.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <FormSubmission>[];

      final notifications =
          (responses[2].data['notifications'] as List?)
              ?.map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AppNotification>[];

      return DashboardData(
        forms: forms,
        submissions: submissions,
        notifications: notifications,
      );
    } on DioException catch (e, st) {
      developer.log(
        'Dashboard fetch failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } catch (e, st) {
      developer.log(
        'Unexpected dashboard error',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<FormSubmission>> fetchSubmissions({
    SubmissionFilters? filters,
    int limit = 200,
  }) async {
    final data = await loadDashboard();
    if (filters == null) return data.submissions;
    return _applySubmissionFilters(data.submissions, filters);
  }

  @override
  Future<FormSubmission> createSubmission({
    required String formId,
    required Map<String, dynamic> data,
    required String submittedBy,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? location,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = {
      'formId': formId,
      'data': data,
      'submittedBy': submittedBy,
      'submittedAt': DateTime.now().toIso8601String(),
      'status': SubmissionStatus.submitted.name,
      if (attachments != null) 'attachments': attachments,
      if (location != null) 'location': location,
      if (metadata != null) 'metadata': metadata,
    };
    try {
      final res = await _client.raw.post(
        ApiConstants.submissions,
        data: payload,
      );
      final body = res.data;

      if (body is Map<String, dynamic> && body.containsKey('id')) {
        return FormSubmission.fromJson(body);
      }
      throw Exception('Submission response missing id');
    } on DioException catch (e, st) {
      developer.log(
        'Submission POST failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<FormSubmission> updateSubmissionStatus({
    required String submissionId,
    required SubmissionStatus status,
    String? note,
  }) async {
    final payload = {
      'status': status.name,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    try {
      final res = await _client.raw.patch(
        '${ApiConstants.submissions}/$submissionId',
        data: payload,
      );
      final body = res.data;
      if (body is Map<String, dynamic>) {
        return FormSubmission.fromJson(body);
      }
      throw Exception('Update submission response missing body');
    } on DioException catch (e, st) {
      developer.log(
        'Update submission failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> markNotificationRead(String id) async {
    // Attempt PATCH then fallback to POST if backend uses different verb.
    try {
      await _client.raw.patch(
        '${ApiConstants.notifications}/$id',
        data: {'isRead': true, 'readAt': DateTime.now().toIso8601String()},
      );
    } on DioException catch (_) {
      await _client.raw.post('${ApiConstants.notifications}/$id/read');
    }
  }

  @override
  Future<FormDefinition> createForm(FormDefinition form) async {
    try {
      final res = await _client.raw.post(
        ApiConstants.forms,
        data: form.toJson(),
      );
      final body = res.data;
      if (body is Map<String, dynamic> && body.containsKey('id')) {
        return FormDefinition.fromJson(body);
      }
      throw Exception('Create form response missing id');
    } on DioException catch (e, st) {
      developer.log(
        'Create form failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}

/// Supabase-backed repository.
class SupabaseDashboardRepository implements DashboardRepositoryBase {
  SupabaseDashboardRepository(this._client);

  final SupabaseClient _client;
  static const _bucketName =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

  @override
  Future<DashboardData> loadDashboard() async {
    try {
      developer.log('Loading dashboard from Supabase...');

      final orgId = await _getOrgId();
      if (orgId == null) {
        developer.log(
          'No organization found for current user. Returning empty dashboard data.',
        );
        return DashboardData(
          forms: const [],
          submissions: const [],
          notifications: const [],
        );
      }

      final roleFuture = _getUserRole();
      final userId = _client.auth.currentUser?.id;
      final formsFuture = _client
          .from('forms')
          .select()
          .eq('org_id', orgId)
          .eq('is_published', true)
          .order('updated_at', ascending: false);
      final submissionsFuture = _client
          .from('submissions')
          .select()
          .eq('org_id', orgId)
          .order('submitted_at', ascending: false)
          .limit(50);
      final notificationsFuture = _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final results = await Future.wait([
        formsFuture,
        submissionsFuture,
        notificationsFuture,
      ]);

      developer.log('Supabase queries completed successfully');
      developer.log('Raw results - forms: ${(results[0] as List).length}, submissions: ${(results[1] as List).length}, notifications: ${(results[2] as List).length}');

      final forms = (results[0] as List<dynamic>)
          .map((e) => _mapFormDefinition(Map<String, dynamic>.from(e as Map)))
          .toList();
      final role = await roleFuture;
      final filteredForms = _filterFormsForRole(forms, role, userId);
      final formTitleIndex = {for (final f in filteredForms) f.id: f.title};
      final submissions = (results[1] as List<dynamic>)
          .map(
            (e) => _mapSubmission(
              Map<String, dynamic>.from(e as Map),
              formTitleIndex,
            ),
          )
          .toList();
      final allowedFormIds = filteredForms.map((f) => f.id).toSet();
      final scopedSubmissions = submissions.where((submission) {
        if (allowedFormIds.isEmpty) return false;
        return allowedFormIds.contains(submission.formId);
      }).toList();
      final signedSubmissions =
          await Future.wait(scopedSubmissions.map(_withSignedAttachments));
      final notifications = (results[2] as List<dynamic>)
          .map((e) => _mapNotification(Map<String, dynamic>.from(e as Map)))
          .toList();

      developer.log('Parsed ${forms.length} forms, ${submissions.length} submissions, ${notifications.length} notifications');

      return DashboardData(
        forms: filteredForms,
        submissions: signedSubmissions,
        notifications: notifications,
      );
    } on PostgrestException catch (e, st) {
      developer.log(
        'PostgreSQL error loading dashboard: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      throw Exception(
        'Supabase query failed (${e.code ?? 'unknown'}): ${e.message}. '
        'Confirm org membership and RLS policies, then retry.',
      );
    } catch (e, st) {
      developer.log(
        'Unexpected error loading dashboard',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<FormSubmission>> fetchSubmissions({
    SubmissionFilters? filters,
    int limit = 200,
  }) async {
    try {
      final orgId = await _getOrgId();
      if (orgId == null) return const <FormSubmission>[];
      final roleFuture = _getUserRole();
      final userId = _client.auth.currentUser?.id;
      var query = _client
          .from('submissions')
          .select()
          .eq('org_id', orgId);
      if (filters?.status != null) {
        query = query.eq('status', filters!.status!.name);
      }
      if (filters?.formId != null && filters!.formId!.isNotEmpty) {
        query = query.eq('form_id', filters.formId!);
      }
      if (filters?.startDate != null) {
        query = query.gte(
          'submitted_at',
          filters!.startDate!.toIso8601String(),
        );
      }
      if (filters?.endDate != null) {
        query = query.lte(
          'submitted_at',
          filters!.endDate!.toIso8601String(),
        );
      }
      final results =
          await query.order('submitted_at', ascending: false).limit(limit);
      final role = await roleFuture;
      final forms = await _fetchFormsForRole(orgId, role, userId);
      final formTitles = {for (final form in forms) form.id: form.title};
      final allowedFormIds = formTitles.keys.toSet();
      final submissions = (results as List<dynamic>)
          .map(
            (row) => _mapSubmission(
              Map<String, dynamic>.from(row as Map),
              formTitles,
            ),
          )
          .toList();
      final scoped = submissions.where((submission) {
        if (allowedFormIds.isEmpty) return false;
        return allowedFormIds.contains(submission.formId);
      }).toList();
      return Future.wait(scoped.map(_withSignedAttachments));
    } on PostgrestException catch (e, st) {
      developer.log(
        'PostgreSQL error fetching submissions: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } catch (e, st) {
      developer.log(
        'Unexpected error fetching submissions',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<FormSubmission> createSubmission({
    required String formId,
    required Map<String, dynamic> data,
    required String submittedBy,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? location,
    Map<String, dynamic>? metadata,
  }) async {
    final formMetadata = await _client
        .from('forms')
        .select('org_id, title')
        .eq('id', formId)
        .maybeSingle();
    final orgId = formMetadata?['org_id']?.toString() ?? await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization before submitting.');
    }

    final payload = {
      'org_id': orgId,
      'form_id': formId,
      'data': data,
      'submitted_by': _client.auth.currentUser?.id ?? submittedBy,
      'submitted_at': DateTime.now().toIso8601String(),
      'status': SubmissionStatus.submitted.name,
      if (attachments != null) 'attachments': attachments,
      if (location != null) 'location': location,
      if (metadata != null)
        'metadata': _withProvider(metadata),
    };
    try {
      final res = await _client
          .from('submissions')
          .insert(payload)
          .select()
          .single();
      final body = Map<String, dynamic>.from(res as Map);
      await _enqueueAutoReport(
        orgId: orgId,
        submissionId: body['id']?.toString() ?? '',
        formId: formId,
        formTitle: (formMetadata?['title'] ?? '') as String? ??
            resolveFormTitle(formId),
        data: data,
        attachments: attachments ?? const [],
      );
      return _mapSubmission(body, {
        formId: (formMetadata?['title'] ?? '') as String? ??
            resolveFormTitle(formId),
      });
    } catch (e, st) {
      developer.log(
        'Supabase createSubmission failed',
        error: e,
        stackTrace: st,
      );
    }
    throw Exception('Supabase createSubmission failed');
  }

  Future<void> _enqueueAutoReport({
    required String orgId,
    required String submissionId,
    required String formId,
    required String formTitle,
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> attachments,
  }) async {
    if (attachments.isEmpty) return;
    try {
      await _client.from('ai_jobs').insert({
        'org_id': orgId,
        'type': 'field_report',
        'status': 'pending',
        'input_text': jsonEncode(data),
        'input_media': attachments,
        'created_by': _client.auth.currentUser?.id,
        'metadata': {
          'source': 'submission',
          'submissionId': submissionId,
          'formId': formId,
          'formTitle': formTitle,
          'autoGenerated': true,
        },
      });
    } catch (e, st) {
      developer.log(
        'Auto report enqueue failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<FormSubmission> updateSubmissionStatus({
    required String submissionId,
    required SubmissionStatus status,
    String? note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    try {
      final current = await _client
          .from('submissions')
          .select('metadata')
          .eq('id', submissionId)
          .maybeSingle();
      final existingMeta = Map<String, dynamic>.from(
        current?['metadata'] as Map? ?? <String, dynamic>{},
      );
      existingMeta['review'] = {
        'status': status.name,
        if (note != null && note.isNotEmpty) 'note': note,
        'reviewedAt': DateTime.now().toIso8601String(),
        if (userId != null) 'reviewedBy': userId,
      };

      final res = await _client
          .from('submissions')
          .update({'status': status.name, 'metadata': existingMeta})
          .eq('id', submissionId)
          .select()
          .maybeSingle();
      if (res == null) {
        throw Exception('Submission update failed');
      }
      final formTitles = await _formTitleIndex();
      final updated = _mapSubmission(
        Map<String, dynamic>.from(res),
        formTitles,
      );
      return _withSignedAttachments(updated);
    } on PostgrestException catch (e, st) {
      developer.log(
        'PostgreSQL error updating submission: ${e.message} (code: ${e.code})',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } catch (e, st) {
      developer.log(
        'Unexpected error updating submission',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<FormDefinition> createForm(FormDefinition form) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization to create forms.');
    }

    try {
      final res = await _client
          .from('forms')
          .insert(_toSupabaseFormMap(form, orgId))
          .select()
          .single();
      return _mapFormDefinition(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      developer.log(
        'Supabase createForm failed',
        error: e,
        stackTrace: st,
      );
    }
    throw Exception('Supabase createForm failed');
  }

  @override
  Future<void> markNotificationRead(String id) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      return;
    } catch (e, st) {
      developer.log(
        'Supabase markNotificationRead failed',
        error: e,
        stackTrace: st,
      );
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
    } catch (_) {}
    try {
      final res = await _client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    developer.log('No org_id found for user $userId in org_members or profiles');
    return null;
  }

  Map<String, dynamic> _withProvider(Map<String, dynamic> metadata) {
    if (metadata.containsKey('provider')) return metadata;
    final user = _client.auth.currentUser;
    if (user == null) return metadata;
    final appMeta = user.appMetadata;
    final provider = appMeta['provider'];
    if (provider is String && provider.trim().isNotEmpty) {
      return {...metadata, 'provider': provider.trim()};
    }
    final providers = appMeta['providers'];
    if (providers is List && providers.isNotEmpty) {
      final value = providers.first.toString().trim();
      if (value.isNotEmpty) {
        return {...metadata, 'provider': value};
      }
    }
    return metadata;
  }

  List<FormDefinition> _filterFormsForRole(
    List<FormDefinition> forms,
    UserRole role,
    String? userId,
  ) {
    if (role.canManage) return forms;
    return forms.where((form) {
      if (userId != null && form.createdBy == userId) {
        return true;
      }
      final metadata = form.metadata ?? const <String, dynamic>{};
      final sharedRolesRaw = metadata['shared_roles'];
      final sharedUsersRaw = metadata['shared_users'];
      final sharedRoles = (sharedRolesRaw is List)
          ? sharedRolesRaw.map((e) => e.toString().toLowerCase()).toList()
          : const <String>[];
      final sharedUsers = (sharedUsersRaw is List)
          ? sharedUsersRaw.map((e) => e.toString()).toList()
          : const <String>[];
      if (sharedRoles.isEmpty && sharedUsers.isEmpty) {
        return true;
      }
      if (sharedUsers.contains(userId)) {
        return true;
      }
      final roleKey = role.name.toLowerCase();
      return sharedRoles.contains(roleKey) || sharedRoles.contains('all');
    }).toList();
  }

  Future<UserRole> _getUserRole() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return UserRole.viewer;
    try {
      final res = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final raw = res?['role']?.toString();
      if (raw != null) {
        return UserRole.values.firstWhere(
          (role) => role.name == raw,
          orElse: () => UserRole.viewer,
        );
      }
    } catch (_) {}
    try {
      final res = await _client
          .from('org_members')
          .select('role')
          .eq('user_id', userId)
          .maybeSingle();
      final raw = res?['role']?.toString();
      if (raw != null) {
        return UserRole.values.firstWhere(
          (role) => role.name == raw,
          orElse: () => UserRole.viewer,
        );
      }
    } catch (_) {}
    return UserRole.viewer;
  }

  Future<List<FormDefinition>> _fetchFormsForRole(
    String orgId,
    UserRole role,
    String? userId,
  ) async {
    final rows = await _client
        .from('forms')
        .select()
        .eq('org_id', orgId)
        .eq('is_published', true)
        .order('updated_at', ascending: false);
    final forms = (rows as List<dynamic>)
        .map((e) => _mapFormDefinition(Map<String, dynamic>.from(e as Map)))
        .toList();
    return _filterFormsForRole(forms, role, userId);
  }

  Future<Map<String, String>> _formTitleIndex() async {
    try {
      final rows = await _client.from('forms').select('id, title');
      return {
        for (final row in (rows as List))
          row['id'].toString(): row['title']?.toString() ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  FormDefinition _mapFormDefinition(Map<String, dynamic> row) {
    final rawFields = row['fields'];
    final parsedFields = rawFields is String
        ? jsonDecode(rawFields)
        : rawFields ?? <dynamic>[];
    final tags = row['tags'];

    return FormDefinition(
      id: row['id'].toString(),
      title: row['title'] as String? ?? 'Untitled form',
      description: row['description'] as String? ?? '',
      category: row['category'] as String?,
      tags: tags is List ? tags.map((e) => e.toString()).toList() : null,
      fields: (parsedFields as List)
          .map(
            (f) => FormField.fromJson(
              Map<String, dynamic>.from(f as Map),
            ),
          )
          .toList(),
      isPublished:
          (row['is_published'] as bool?) ?? (row['isPublished'] as bool?) ?? false,
      version:
          row['version'] as String? ?? row['current_version'] as String?,
      createdBy:
          row['created_by']?.toString() ?? row['createdBy']?.toString() ?? '',
      createdAt: _parseDate(row['created_at'] ?? row['createdAt']),
      updatedAt: _parseNullableDate(row['updated_at'] ?? row['updatedAt']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  FormSubmission _mapSubmission(
    Map<String, dynamic> row,
    Map<String, String> formTitles,
  ) {
    final formId = row['form_id']?.toString() ?? row['formId'] as String? ?? '';
    final statusValue = row['status']?.toString() ?? 'submitted';
    return FormSubmission(
      id: row['id'].toString(),
      formId: formId,
      formTitle:
          row['form_title'] as String? ?? formTitles[formId] ?? resolveFormTitle(formId),
      submittedBy:
          row['submitted_by']?.toString() ?? row['submittedBy']?.toString() ?? '',
      submittedByName: row['submitted_by_name'] as String?,
      submittedAt: _parseDate(row['submitted_at'] ?? row['submittedAt']),
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
      jobSiteId: row['job_site_id']?.toString() ?? row['jobSiteId'] as String?,
      companyId: row['company_id']?.toString() ?? row['companyId'] as String?,
      syncedAt: _parseNullableDate(row['synced_at'] ?? row['syncedAt']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Future<FormSubmission> _withSignedAttachments(
    FormSubmission submission,
  ) async {
    final attachments = submission.attachments;
    if (attachments == null || attachments.isEmpty) return submission;
    final signed = await Future.wait(attachments.map(_signAttachment));
    return FormSubmission(
      id: submission.id,
      formId: submission.formId,
      formTitle: submission.formTitle,
      submittedBy: submission.submittedBy,
      submittedByName: submission.submittedByName,
      submittedAt: submission.submittedAt,
      status: submission.status,
      data: submission.data,
      attachments: signed,
      location: submission.location,
      jobSiteId: submission.jobSiteId,
      companyId: submission.companyId,
      syncedAt: submission.syncedAt,
      metadata: submission.metadata,
    );
  }

  Future<MediaAttachment> _signAttachment(MediaAttachment attachment) async {
    try {
      final signedUrl = await createSignedStorageUrl(
        client: _client,
        url: attachment.url,
        defaultBucket: _bucketName,
        metadata: attachment.metadata,
        expiresInSeconds: kSignedUrlExpirySeconds,
      );
      if (signedUrl == null || signedUrl.isEmpty) return attachment;
      return MediaAttachment(
        id: attachment.id,
        type: attachment.type,
        url: signedUrl,
        localPath: attachment.localPath,
        filename: attachment.filename,
        fileSize: attachment.fileSize,
        mimeType: attachment.mimeType,
        capturedAt: attachment.capturedAt,
        location: attachment.location,
        metadata: attachment.metadata,
      );
    } catch (_) {
      return attachment;
    }
  }

  AppNotification _mapNotification(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'].toString(),
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      type: row['type'] as String?,
      targetUserId: row['user_id']?.toString() ?? row['targetUserId'] as String?,
      targetRole: row['targetRole'] as String?,
      data: row['data'] as Map<String, dynamic>?,
      isRead:
          (row['is_read'] as bool?) ?? (row['isRead'] as bool?) ?? false,
      createdAt: _parseDate(row['created_at'] ?? row['createdAt']),
      readAt: _parseNullableDate(row['read_at'] ?? row['readAt']),
      actionUrl:
          row['action_url'] as String? ?? row['actionUrl'] as String?,
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> _toSupabaseFormMap(
    FormDefinition form,
    String orgId,
  ) {
    return {
      'id': form.id,
      'org_id': orgId,
      'title': form.title,
      'description': form.description,
      'category': form.category,
      'tags': form.tags,
      'fields': form.fields.map((f) => f.toJson()).toList(),
      'is_published': form.isPublished,
      'version': form.version,
      'created_by': form.createdBy.isEmpty
          ? _client.auth.currentUser?.id
          : form.createdBy,
      'metadata': form.metadata,
    };
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.parse(value.toString());
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

List<FormSubmission> _applySubmissionFilters(
  List<FormSubmission> submissions,
  SubmissionFilters filters,
) {
  return submissions.where((submission) {
    if (filters.status != null && submission.status != filters.status) {
      return false;
    }
    if (filters.formId != null &&
        filters.formId!.isNotEmpty &&
        submission.formId != filters.formId) {
      return false;
    }
    if (filters.startDate != null &&
        submission.submittedAt.isBefore(filters.startDate!)) {
      return false;
    }
    if (filters.endDate != null &&
        submission.submittedAt.isAfter(filters.endDate!)) {
      return false;
    }
    return true;
  }).toList();
}

// ---------------------------------------------------------------------------
// Demo data used when the backend is offline or unreachable.
// ---------------------------------------------------------------------------

final List<FormDefinition> _demoForms = _buildDemoForms();

String resolveFormTitle(String formId) {
  final match = _demoForms.firstWhere(
    (f) => f.id == formId,
    orElse: () => FormDefinition(
      id: formId,
      title: 'Form $formId',
      description: '',
      fields: const [],
      createdBy: 'demo',
      createdAt: DateTime.now(),
    ),
  );
  return match.title;
}

List<FormDefinition> _buildDemoForms() {
  return [
    {
      'id': 'jobsite-safety',
      'title': 'Job Site Safety Walk',
      'description': '15-point safety walkthrough with photo capture',
      'category': 'Safety',
      'isPublished': true,
      'version': '1.0.0',
      'createdBy': 'system',
      'createdAt': DateTime.now()
          .subtract(const Duration(days: 2))
          .toIso8601String(),
      'updatedAt': DateTime.now()
          .subtract(const Duration(hours: 6))
          .toIso8601String(),
      'fields': [
        {
          'id': 'siteName',
          'label': 'Site name',
          'type': 'text',
          'placeholder': 'South Plant 7',
          'isRequired': true,
          'order': 1,
        },
        {
          'id': 'inspector',
          'label': 'Inspector',
          'type': 'text',
          'placeholder': 'Your name',
          'isRequired': true,
          'order': 2,
        },
        {
          'id': 'ppe',
          'label': 'PPE compliance',
          'type': 'checkbox',
          'options': ['Hard hat', 'Vest', 'Gloves', 'Eye protection'],
          'isRequired': true,
          'order': 3,
        },
        {
          'id': 'hazards',
          'label': 'Hazards observed',
          'type': 'textarea',
          'order': 4,
        },
        {'id': 'photos', 'label': 'Attach photos', 'type': 'photo', 'order': 5},
        {
          'id': 'location',
          'label': 'GPS location',
          'type': 'location',
          'order': 6,
        },
        {
          'id': 'signature',
          'label': 'Supervisor signature',
          'type': 'signature',
          'order': 7,
        },
      ],
      'metadata': {'riskLevel': 'medium'},
    },
    {
      'id': 'equipment-checkout',
      'title': 'Equipment Checkout',
      'description': 'Log equipment issue/return with QR scan',
      'category': 'Operations',
      'isPublished': true,
      'version': '1.1.0',
      'createdBy': 'system',
      'createdAt': DateTime.now()
          .subtract(const Duration(days: 5))
          .toIso8601String(),
      'fields': [
        {
          'id': 'assetTag',
          'label': 'Asset tag / QR',
          'type': 'barcode',
          'order': 1,
          'isRequired': true,
        },
        {
          'id': 'condition',
          'label': 'Condition',
          'type': 'radio',
          'options': ['Excellent', 'Good', 'Fair', 'Damaged'],
          'order': 2,
          'isRequired': true,
        },
        {'id': 'notes', 'label': 'Notes', 'type': 'textarea', 'order': 3},
        {
          'id': 'photos',
          'label': 'Proof of condition',
          'type': 'photo',
          'order': 4,
        },
      ],
      'metadata': {'requiresSupervisor': true},
    },
    {
      'id': 'visitor-log',
      'title': 'Visitor Log',
      'description': 'Quick intake with badge printing flag',
      'category': 'Security',
      'isPublished': true,
      'version': '0.9.0',
      'createdBy': 'system',
      'createdAt': DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
      'fields': [
        {
          'id': 'fullName',
          'label': 'Full name',
          'type': 'text',
          'order': 1,
          'isRequired': true,
        },
        {'id': 'company', 'label': 'Company', 'type': 'text', 'order': 2},
        {'id': 'host', 'label': 'Host', 'type': 'text', 'order': 3},
        {
          'id': 'purpose',
          'label': 'Purpose',
          'type': 'dropdown',
          'options': ['Delivery', 'Interview', 'Maintenance', 'Audit', 'Other'],
          'order': 4,
        },
        {
          'id': 'arrivedAt',
          'label': 'Arrival time',
          'type': 'datetime',
          'order': 5,
        },
        {
          'id': 'badge',
          'label': 'Badge required',
          'type': 'toggle',
          'order': 6,
        },
      ],
    },
  ].map((json) => FormDefinition.fromJson(json)).toList();
}
