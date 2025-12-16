import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/api_client.dart';

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

/// Repository interface for dashboard data sources.
abstract class DashboardRepositoryBase {
  Future<DashboardData> loadDashboard();
  Future<FormSubmission> createSubmission({
    required String formId,
    required Map<String, dynamic> data,
    required String submittedBy,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? location,
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

      if (forms.isEmpty && submissions.isEmpty && notifications.isEmpty) {
        return _demoFallback('API returned empty payloads');
      }

      return DashboardData(
        forms: forms,
        submissions: submissions,
        notifications: notifications,
      );
    } on DioException catch (e, st) {
      developer.log(
        'Dashboard fetch failed, using demo data',
        error: e,
        stackTrace: st,
      );
      return _demoFallback(e.message ?? 'Network error');
    } catch (e, st) {
      developer.log(
        'Unexpected dashboard error, using demo data',
        error: e,
        stackTrace: st,
      );
      return _demoFallback(e.toString());
    }
  }

  Future<FormSubmission> createSubmission({
    required String formId,
    required Map<String, dynamic> data,
    required String submittedBy,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? location,
  }) async {
    final payload = {
      'formId': formId,
      'data': data,
      'submittedBy': submittedBy,
      'submittedAt': DateTime.now().toIso8601String(),
      'status': SubmissionStatus.submitted.name,
      if (attachments != null) 'attachments': attachments,
      if (location != null) 'location': location,
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
    } on DioException catch (e, st) {
      developer.log(
        'Submission POST failed, using local demo record',
        error: e,
        stackTrace: st,
      );
    }

    // Fallback when backend returns acknowledgement only or fails outright.
    final now = DateTime.now().toUtc();
    final submission = FormSubmission(
      id: now.microsecondsSinceEpoch.toString(),
      formId: formId,
      formTitle: resolveFormTitle(formId),
      submittedBy: submittedBy,
      submittedAt: now,
      status: SubmissionStatus.submitted,
      data: data,
      attachments: attachments
          ?.map((a) => MediaAttachment.fromJson(a))
          .toList(),
      location: location != null ? LocationData.fromJson(location) : null,
    );
    _demoSubmissions.insert(0, submission);
    return submission;
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

    final index = _demoNotifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final notif = _demoNotifications[index];
      _demoNotifications[index] = AppNotification(
        id: notif.id,
        title: notif.title,
        body: notif.body,
        type: notif.type,
        targetUserId: notif.targetUserId,
        targetRole: notif.targetRole,
        data: notif.data,
        isRead: true,
        createdAt: notif.createdAt,
        readAt: DateTime.now().toUtc(),
        actionUrl: notif.actionUrl,
        metadata: notif.metadata,
      );
    }
  }

  DashboardData _demoFallback(String reason) {
    developer.log('Using in-app demo data: $reason');
    return DashboardData(
      forms: List<FormDefinition>.from(_demoForms),
      submissions: List<FormSubmission>.from(_demoSubmissions),
      notifications: List<AppNotification>.from(_demoNotifications),
    );
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
    } on DioException catch (e, st) {
      developer.log(
        'Create form failed, using local save',
        error: e,
        stackTrace: st,
      );
    }

    _demoForms.insert(0, form);
    return form;
  }
}

/// Supabase-backed repository with demo fallback.
class SupabaseDashboardRepository implements DashboardRepositoryBase {
  SupabaseDashboardRepository(
    this._client, {
    required this.fallback,
  });

  final SupabaseClient _client;
  final DashboardRepositoryBase fallback;

  @override
  Future<DashboardData> loadDashboard() async {
    try {
      final formsFuture = _client.from('forms').select();
      final submissionsFuture = _client
          .from('submissions')
          .select()
          .order('submittedAt', ascending: false);
      final notificationsFuture = _client
          .from('notifications')
          .select()
          .order('createdAt', ascending: false);

      final results = await Future.wait([
        formsFuture,
        submissionsFuture,
        notificationsFuture,
      ]);

      final forms = (results[0] as List<dynamic>)
          .map((e) => FormDefinition.fromJson(e as Map<String, dynamic>))
          .toList();
      final submissions = (results[1] as List<dynamic>)
          .map((e) => FormSubmission.fromJson(e as Map<String, dynamic>))
          .toList();
      final notifications = (results[2] as List<dynamic>)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();

      return DashboardData(
        forms: forms,
        submissions: submissions,
        notifications: notifications,
      );
    } catch (e, st) {
      developer.log(
        'Supabase loadDashboard failed, falling back',
        error: e,
        stackTrace: st,
      );
      return fallback.loadDashboard();
    }
  }

  @override
  Future<FormSubmission> createSubmission({
    required String formId,
    required Map<String, dynamic> data,
    required String submittedBy,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? location,
  }) async {
    final payload = {
      'formId': formId,
      'data': data,
      'submittedBy': submittedBy,
      'submittedAt': DateTime.now().toIso8601String(),
      'status': SubmissionStatus.submitted.name,
      if (attachments != null) 'attachments': attachments,
      if (location != null) 'location': location,
    };
    try {
      final res = await _client.from('submissions').insert(payload).select();
      if (res.isNotEmpty) {
        final body = Map<String, dynamic>.from(res.first as Map);
        return FormSubmission.fromJson(
          body..putIfAbsent('formTitle', () => resolveFormTitle(formId)),
        );
      }
    } catch (e, st) {
      developer.log(
        'Supabase createSubmission failed, using fallback',
        error: e,
        stackTrace: st,
      );
    }
    return fallback.createSubmission(
      formId: formId,
      data: data,
      submittedBy: submittedBy,
      attachments: attachments,
      location: location,
    );
  }

  @override
  Future<FormDefinition> createForm(FormDefinition form) async {
    try {
      final res = await _client.from('forms').insert(form.toJson()).select();
      if (res.isNotEmpty) {
        return FormDefinition.fromJson(Map<String, dynamic>.from(res.first as Map));
      }
    } catch (e, st) {
      developer.log(
        'Supabase createForm failed, using fallback',
        error: e,
        stackTrace: st,
      );
    }
    return fallback.createForm(form);
  }

  @override
  Future<void> markNotificationRead(String id) async {
    try {
      await _client
          .from('notifications')
          .update({'isRead': true, 'readAt': DateTime.now().toIso8601String()})
          .eq('id', id);
      return;
    } catch (e, st) {
      developer.log(
        'Supabase markNotificationRead failed, using fallback',
        error: e,
        stackTrace: st,
      );
    }
    await fallback.markNotificationRead(id);
  }

}

// ---------------------------------------------------------------------------
// Demo data used when the backend is offline or unreachable.
// ---------------------------------------------------------------------------

final List<FormDefinition> _demoForms = _buildDemoForms();
final List<FormSubmission> _demoSubmissions = _buildDemoSubmissions();
final List<AppNotification> _demoNotifications = _buildDemoNotifications();

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

List<FormSubmission> _buildDemoSubmissions() {
  return [
    {
      'id': 'sub-1001',
      'formId': 'jobsite-safety',
      'formTitle': 'Job Site Safety Walk',
      'submittedBy': 'sarah.c',
      'submittedByName': 'Sarah Chen',
      'submittedAt': DateTime.now()
          .subtract(const Duration(hours: 3))
          .toIso8601String(),
      'status': 'underReview',
      'data': {
        'siteName': 'South Plant 7',
        'inspector': 'Sarah Chen',
        'ppe': ['Hard hat', 'Vest', 'Gloves'],
        'hazards': 'Loose cabling near east stairwell, blocked exit near bay 4',
      },
      'attachments': [
        {
          'id': 'att-1',
          'type': 'photo',
          'url': 'https://placehold.co/400x300?text=Exit+Blocked',
          'filename': 'exit-blocked.jpg',
          'capturedAt': DateTime.now()
              .subtract(const Duration(hours: 3, minutes: 15))
              .toIso8601String(),
        },
      ],
      'location': {
        'latitude': 37.7765,
        'longitude': -122.4192,
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 3))
            .toIso8601String(),
        'accuracy': 8.5,
        'address': 'Bay 4, South Plant 7',
      },
      'metadata': {'priority': 'high'},
    },
    {
      'id': 'sub-1002',
      'formId': 'equipment-checkout',
      'formTitle': 'Equipment Checkout',
      'submittedBy': 'mike.l',
      'submittedByName': 'Mike Lopez',
      'submittedAt': DateTime.now()
          .subtract(const Duration(hours: 18))
          .toIso8601String(),
      'status': 'submitted',
      'data': {
        'assetTag': 'FORK-2231',
        'condition': 'Good',
        'notes': 'Tires look new. Fuel at 80%.',
      },
      'attachments': [
        {
          'id': 'att-2',
          'type': 'photo',
          'url': 'https://placehold.co/400x300?text=Forklift',
          'filename': 'forklift.jpg',
          'capturedAt': DateTime.now()
              .subtract(const Duration(hours: 18, minutes: 20))
              .toIso8601String(),
        },
      ],
      'metadata': {'handoff': 'Dock A'},
    },
    {
      'id': 'sub-1003',
      'formId': 'visitor-log',
      'formTitle': 'Visitor Log',
      'submittedBy': 'reception',
      'submittedByName': 'Reception Desk',
      'submittedAt': DateTime.now()
          .subtract(const Duration(days: 1, hours: 2))
          .toIso8601String(),
      'status': 'approved',
      'data': {
        'fullName': 'Alex Morgan',
        'company': 'Bright Manufacturing',
        'host': 'Taylor Brooks',
        'purpose': 'Audit',
        'badge': true,
      },
    },
  ].map((json) => FormSubmission.fromJson(json)).toList();
}

List<AppNotification> _buildDemoNotifications() {
  return [
    {
      'id': 'notif-1',
      'title': 'Action required: Blocked exit',
      'body':
          'Resolve the blocked exit near Bay 4 and attach a photo once clear.',
      'type': 'task',
      'targetRole': 'Supervisor',
      'isRead': false,
      'createdAt': DateTime.now()
          .subtract(const Duration(hours: 1, minutes: 15))
          .toIso8601String(),
      'data': {'submissionId': 'sub-1001'},
    },
    {
      'id': 'notif-2',
      'title': 'New visitor awaiting host',
      'body': 'Alex Morgan (Bright Manufacturing) is waiting in the lobby.',
      'type': 'alert',
      'targetRole': 'Security',
      'isRead': true,
      'createdAt': DateTime.now()
          .subtract(const Duration(hours: 5))
          .toIso8601String(),
      'readAt': DateTime.now()
          .subtract(const Duration(hours: 3))
          .toIso8601String(),
      'data': {'formId': 'visitor-log'},
    },
    {
      'id': 'notif-3',
      'title': 'Equipment checkout approved',
      'body': 'FORK-2231 checked out to Mike Lopez.',
      'type': 'info',
      'isRead': true,
      'createdAt': DateTime.now()
          .subtract(const Duration(days: 1, hours: 4))
          .toIso8601String(),
    },
  ].map((json) => AppNotification.fromJson(json)).toList();
}
