import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ai/ai_function_service.dart';
import '../../../core/services/push_dispatcher.dart';
import '../../../core/utils/storage_utils.dart';
import '../../tasks/data/tasks_repository.dart';

class AttachmentDraft {
  AttachmentDraft({
    required this.type,
    required this.bytes,
    required this.filename,
    required this.mimeType,
    this.metadata,
  });

  final String type;
  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final Map<String, dynamic>? metadata;
}

class AutomationRunSummary {
  AutomationRunSummary({
    required this.rulesChecked,
    required this.rulesFired,
    required this.notificationsSent,
    required this.breakdown,
  });

  final int rulesChecked;
  final int rulesFired;
  final int notificationsSent;
  final Map<String, int> breakdown;
}

class MentionCandidate {
  MentionCandidate({
    required this.id,
    required this.name,
    required this.handle,
    this.email,
  });

  final String id;
  final String name;
  final String handle;
  final String? email;
}

abstract class OpsRepositoryBase {
  Future<List<NewsPost>> fetchNewsPosts();
  Future<NewsPost> createNewsPost({
    required String title,
    String? body,
    String scope,
    bool isPublished,
    List<String> tags,
    String? siteId,
  });

  Future<List<NotificationRule>> fetchNotificationRules();
  Future<NotificationRule> createNotificationRule({
    required String name,
    required String triggerType,
    String targetType,
    List<String> targetIds,
    List<String> channels,
    String? schedule,
    String? messageTemplate,
  });
  Future<int> triggerRule({
    required NotificationRule rule,
    String? title,
    String? body,
  });
  Future<AutomationRunSummary> runDueAutomations();

  Future<List<NotebookPage>> fetchNotebookPages({String? projectId});
  Future<NotebookPage> createNotebookPage({
    required String title,
    String? body,
    String? projectId,
    List<String> tags,
  });
  Future<NotebookPage> updateNotebookPage({
    required String pageId,
    String? title,
    String? body,
    List<String>? tags,
  });

  Future<List<NotebookReport>> fetchNotebookReports({String? projectId});
  Future<NotebookReport> createNotebookReport({
    required String title,
    String? projectId,
    required List<String> pageIds,
    Uint8List? pdfBytes,
  });

  Future<List<SignatureRequest>> fetchSignatureRequests({String? documentId});
  Future<SignatureRequest> createSignatureRequest({
    required String requestName,
    required String signerName,
    String? signerEmail,
    String? documentId,
  });
  Future<SignatureRequest> signSignatureRequest({
    required SignatureRequest request,
    required Uint8List signatureBytes,
    String? signerName,
  });

  Future<List<ProjectPhoto>> fetchProjectPhotos({String? projectId});
  Future<ProjectPhoto> createProjectPhoto({
    required String? projectId,
    String? title,
    String? description,
    List<String> tags,
    List<AttachmentDraft> attachments,
    bool isFeatured,
    bool isShared,
  });
  Future<List<PhotoComment>> fetchPhotoComments(String photoId);
  Future<PhotoComment> addPhotoComment({
    required String photoId,
    required String body,
    List<String> mentions,
    AttachmentDraft? voiceNote,
  });
  Future<List<MentionCandidate>> fetchMentionCandidates();

  Future<List<WebhookEndpoint>> fetchWebhookEndpoints();
  Future<WebhookEndpoint> createWebhookEndpoint({
    required String name,
    required String url,
    List<String> events,
    String? secret,
    bool isActive,
  });
  Future<WebhookEndpoint> updateWebhookEndpoint({
    required String id,
    String? name,
    String? url,
    List<String>? events,
    bool? isActive,
  });

  Future<List<IntegrationProfile>> fetchIntegrations();
  Future<IntegrationProfile> upsertIntegration({
    required String provider,
    String status,
    Map<String, dynamic>? config,
  });

  Future<List<ExportJob>> fetchExportJobs();
  Future<ExportJob> createExportJob({
    required String type,
    String format,
    String status,
    String? fileUrl,
    Map<String, dynamic>? metadata,
  });
  Future<ExportJob> createExportJobWithFile({
    required String type,
    required String format,
    required String filename,
    required Uint8List bytes,
    Map<String, dynamic>? metadata,
  });
  Future<ExportJob> completeExportJob({
    required String id,
    required String status,
    String? fileUrl,
  });

  Future<List<AiJob>> fetchAiJobs();
  Future<AiJob> createAiJob({
    required String type,
    String? inputText,
    String? outputText,
    List<AttachmentDraft> inputMedia,
    Map<String, dynamic>? metadata,
  });
  Future<int> processPendingAiJobs({int maxJobs});

  Future<List<DailyLog>> fetchDailyLogs({String? projectId});
  Future<DailyLog> createDailyLog({
    required String content,
    DateTime? logDate,
    String? title,
    String? projectId,
    Map<String, dynamic>? metadata,
  });

  Future<List<GuestInvite>> fetchGuestInvites();
  Future<GuestInvite> createGuestInvite({
    required String email,
    String? role,
    DateTime? expiresAt,
  });

  Future<List<PaymentRequest>> fetchPaymentRequests();
  Future<PaymentRequest> createPaymentRequest({
    required double amount,
    String currency,
    String? description,
    String? projectId,
  });
  Future<PaymentRequest> createPaymentCheckout({
    required PaymentRequest request,
  });
  Future<PaymentRequest> updatePaymentStatus({
    required String id,
    required String status,
  });

  Future<List<Review>> fetchReviews();
  Future<Review> createReviewRequest({
    String? projectId,
    int? rating,
    String? comment,
    String? source,
  });
  Future<Review> updateReviewStatus({
    required String id,
    required String status,
  });

  Future<List<PortfolioItem>> fetchPortfolioItems();
  Future<PortfolioItem> createPortfolioItem({
    required String title,
    String? description,
    String? coverUrl,
    List<String> galleryUrls,
    String? projectId,
    bool isPublished,
  });
  Future<PortfolioItem> updatePortfolioPublish({
    required String id,
    required bool isPublished,
  });
}

class SupabaseOpsRepository implements OpsRepositoryBase {
  SupabaseOpsRepository(this._client)
      : _push = PushDispatcher(_client),
        _tasksRepository = SupabaseTasksRepository(_client);

  final SupabaseClient _client;
  final PushDispatcher _push;
  final SupabaseTasksRepository _tasksRepository;
  static const _bucketName =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');
  static const int _taskDueSoonHours = 24;
  static const int _assetMaintenanceWindowDays = 7;

  @override
  Future<List<NewsPost>> fetchNewsPosts() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('news_posts')
        .select()
        .eq('org_id', orgId)
        .order('published_at', ascending: false);
    final posts = (rows as List<dynamic>)
        .map((row) => _mapNewsPost(Map<String, dynamic>.from(row as Map)))
        .toList();
    return Future.wait(posts.map(_signNewsAttachments));
  }

  @override
  Future<NewsPost> createNewsPost({
    required String title,
    String? body,
    String scope = 'company',
    bool isPublished = true,
    List<String> tags = const [],
    String? siteId,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization.');
    }
    final payload = {
      'org_id': orgId,
      'title': title,
      'body': body,
      'scope': scope,
      if (siteId != null) 'site_id': siteId,
      'tags': tags,
      'is_published': isPublished,
      'published_at': DateTime.now().toIso8601String(),
      'created_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final res = await _client.from('news_posts').insert(payload).select().single();
    final post = _mapNewsPost(Map<String, dynamic>.from(res as Map));
    if (isPublished) {
      await _push.sendToOrg(
        orgId: orgId,
        title: title,
        body: body ?? 'New update posted.',
        data: {
          'type': 'news',
          'scope': scope,
          if (siteId != null) 'siteId': siteId,
        },
      );
    }
    return _signNewsAttachments(post);
  }

  @override
  Future<List<NotificationRule>> fetchNotificationRules() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('notification_rules')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _mapRule(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<NotificationRule> createNotificationRule({
    required String name,
    required String triggerType,
    String targetType = 'org',
    List<String> targetIds = const [],
    List<String> channels = const ['in_app'],
    String? schedule,
    String? messageTemplate,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final payload = {
      'org_id': orgId,
      'name': name,
      'trigger_type': triggerType,
      'target_type': targetType,
      'target_ids': targetIds,
      'channels': channels,
      'schedule': schedule,
      'message_template': messageTemplate,
      'created_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final res =
        await _client.from('notification_rules').insert(payload).select().single();
    return _mapRule(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<int> triggerRule({
    required NotificationRule rule,
    String? title,
    String? body,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final targets = await _resolveRuleTargets(rule: rule, orgId: orgId);
    await _client.from('notification_events').insert({
      'org_id': orgId,
      'rule_id': rule.id,
      'status': 'fired',
      'payload': {
        'trigger': rule.triggerType,
        'title': title,
        'body': body,
      },
    });
    if (targets.isEmpty) return 0;
    final payload = targets
        .map(
          (userId) => {
            'org_id': orgId,
            'user_id': userId,
            'title': title ?? rule.name,
            'body': body ?? rule.messageTemplate ?? 'Automation triggered',
            'type': rule.triggerType,
            'is_read': false,
          },
        )
        .toList();
    await _client.from('notifications').insert(payload);
    await _push.sendToUsers(
      userIds: targets,
      orgId: orgId,
      title: title ?? rule.name,
      body: body ?? rule.messageTemplate ?? 'Automation triggered',
      data: {'type': rule.triggerType},
    );
    return targets.length;
  }

  @override
  Future<AutomationRunSummary> runDueAutomations() async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');

    final rules = await fetchNotificationRules();
    final activeRules = rules.where((rule) => rule.isActive).toList();
    final breakdown = <String, int>{};
    int fired = 0;
    int notificationsSent = 0;

    final now = DateTime.now();
    final submissionsCount = await _countRecentSubmissions(orgId, now);
    final dueTasksCount = await _countDueTasks(orgId, now);
    final expiringTrainingCount = await _countExpiringTraining(orgId, now);
    final assetDueCount = await _countAssetMaintenance(orgId, now);
    final inspectionDueCount = await _countDueInspections(orgId, now);
    final sopAckCount = await _countPendingSopAcknowledgements(orgId);
    final scheduledInspections =
        await _scheduleInspectionTasks(orgId: orgId, now: now);
    if (scheduledInspections > 0) {
      breakdown['inspection_due'] = scheduledInspections;
    }

    for (final rule in activeRules) {
      int count = 0;
      String? defaultMessage;
      switch (rule.triggerType) {
        case 'submission':
          count = submissionsCount;
          defaultMessage = '$submissionsCount new submissions in the last 24 hours.';
          break;
        case 'task_due':
          count = dueTasksCount;
          defaultMessage = '$dueTasksCount tasks due within 24 hours.';
          break;
        case 'training_expire':
          count = expiringTrainingCount;
          defaultMessage =
              '$expiringTrainingCount certifications expiring soon.';
          break;
        case 'asset_due':
          count = assetDueCount;
          defaultMessage = '$assetDueCount assets need maintenance.';
          break;
        case 'inspection_due':
          count = inspectionDueCount;
          defaultMessage = '$inspectionDueCount inspections due.';
          break;
        case 'sop_ack_due':
          count = sopAckCount;
          defaultMessage = '$sopAckCount SOP acknowledgements pending.';
          break;
        default:
          count = 0;
          break;
      }
      if (count == 0) continue;
      breakdown.update(rule.triggerType, (value) => value + count,
          ifAbsent: () => count);
      final sent = await triggerRule(
        rule: rule,
        title: rule.name,
        body: rule.messageTemplate ?? defaultMessage,
      );
      fired += 1;
      notificationsSent += sent;
    }

    return AutomationRunSummary(
      rulesChecked: activeRules.length,
      rulesFired: fired,
      notificationsSent: notificationsSent,
      breakdown: breakdown,
    );
  }

  @override
  Future<List<NotebookPage>> fetchNotebookPages({String? projectId}) async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    var query = _client.from('notebook_pages').select().eq('org_id', orgId);
    if (projectId != null && projectId.isNotEmpty) {
      query = query.eq('project_id', projectId);
    }
    final rows = await query.order('updated_at', ascending: false);
    final pages = (rows as List<dynamic>)
        .map((row) => _mapNotebookPage(Map<String, dynamic>.from(row as Map)))
        .toList();
    return Future.wait(pages.map(_signNotebookAttachments));
  }

  @override
  Future<NotebookPage> createNotebookPage({
    required String title,
    String? body,
    String? projectId,
    List<String> tags = const [],
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final payload = {
      'org_id': orgId,
      'project_id': projectId,
      'title': title,
      'body': body,
      'tags': tags,
      'created_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final res = await _client.from('notebook_pages').insert(payload).select().single();
    final page = _mapNotebookPage(Map<String, dynamic>.from(res as Map));
    return _signNotebookAttachments(page);
  }

  @override
  Future<NotebookPage> updateNotebookPage({
    required String pageId,
    String? title,
    String? body,
    List<String>? tags,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (tags != null) 'tags': tags,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final res = await _client
        .from('notebook_pages')
        .update(payload)
        .eq('id', pageId)
        .select()
        .single();
    final page = _mapNotebookPage(Map<String, dynamic>.from(res as Map));
    return _signNotebookAttachments(page);
  }

  @override
  Future<List<NotebookReport>> fetchNotebookReports({String? projectId}) async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    var query = _client.from('notebook_reports').select().eq('org_id', orgId);
    if (projectId != null && projectId.isNotEmpty) {
      query = query.eq('project_id', projectId);
    }
    final rows = await query.order('created_at', ascending: false);
    final reports = (rows as List<dynamic>)
        .map((row) => _mapNotebookReport(Map<String, dynamic>.from(row as Map)))
        .toList();
    return Future.wait(reports.map(_signNotebookReportFile));
  }

  @override
  Future<NotebookReport> createNotebookReport({
    required String title,
    String? projectId,
    required List<String> pageIds,
    Uint8List? pdfBytes,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    String? filePath;
    if (pdfBytes != null) {
      filePath = await _uploadFile(
        orgId: orgId,
        folder: 'notebook-reports',
        filename: 'report_${DateTime.now().millisecondsSinceEpoch}.pdf',
        mimeType: 'application/pdf',
        bytes: pdfBytes,
      );
    }
    final payload = {
      'org_id': orgId,
      'project_id': projectId,
      'title': title,
      'page_ids': pageIds,
      'file_url': filePath,
      'created_by': _client.auth.currentUser?.id,
    };
    final res =
        await _client.from('notebook_reports').insert(payload).select().single();
    final report = _mapNotebookReport(Map<String, dynamic>.from(res as Map));
    return _signNotebookReportFile(report);
  }

  @override
  Future<List<SignatureRequest>> fetchSignatureRequests({String? documentId}) async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    var query = _client.from('signature_requests').select().eq('org_id', orgId);
    if (documentId != null && documentId.isNotEmpty) {
      query = query.eq('document_id', documentId);
    }
    final rows = await query.order('requested_at', ascending: false);
    final requests = (rows as List<dynamic>)
        .map((row) => _mapSignatureRequest(Map<String, dynamic>.from(row as Map)))
        .toList();
    return Future.wait(requests.map(_signSignatureFile));
  }

  @override
  Future<SignatureRequest> createSignatureRequest({
    required String requestName,
    required String signerName,
    String? signerEmail,
    String? documentId,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final payload = {
      'org_id': orgId,
      'document_id': documentId,
      'request_name': requestName,
      'signer_name': signerName,
      'signer_email': signerEmail,
      'status': 'pending',
      'token': const Uuid().v4(),
      'requested_by': _client.auth.currentUser?.id,
    };
    final res =
        await _client.from('signature_requests').insert(payload).select().single();
    return _mapSignatureRequest(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<SignatureRequest> signSignatureRequest({
    required SignatureRequest request,
    required Uint8List signatureBytes,
    String? signerName,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final path = await _uploadFile(
      orgId: orgId,
      folder: 'signatures',
      filename: 'signature_${DateTime.now().millisecondsSinceEpoch}.png',
      mimeType: 'image/png',
      bytes: signatureBytes,
    );
    final signatureData = {
      'url': path,
      'signedAt': DateTime.now().toIso8601String(),
      'signerName': signerName ?? request.signerName,
      'bucket': _bucketName,
    };
    final res = await _client
        .from('signature_requests')
        .update({
          'status': 'signed',
          'signed_at': DateTime.now().toIso8601String(),
          'signature_data': signatureData,
          'file_url': path,
        })
        .eq('id', request.id)
        .select()
        .single();
    final updated = _mapSignatureRequest(Map<String, dynamic>.from(res as Map));
    return _signSignatureFile(updated);
  }

  @override
  Future<List<ProjectPhoto>> fetchProjectPhotos({String? projectId}) async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    var query = _client.from('project_photos').select().eq('org_id', orgId);
    if (projectId != null && projectId.isNotEmpty) {
      query = query.eq('project_id', projectId);
    }
    final rows = await query.order('created_at', ascending: false);
    final photos = (rows as List<dynamic>)
        .map((row) => _mapProjectPhoto(Map<String, dynamic>.from(row as Map)))
        .toList();
    return Future.wait(photos.map(_signPhotoAttachments));
  }

  @override
  Future<ProjectPhoto> createProjectPhoto({
    required String? projectId,
    String? title,
    String? description,
    List<String> tags = const [],
    List<AttachmentDraft> attachments = const [],
    bool isFeatured = false,
    bool isShared = false,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final uploaded = await _uploadAttachments(
      orgId: orgId,
      folder: 'project-photos',
      attachments: attachments,
    );
    final payload = {
      'org_id': orgId,
      'project_id': projectId,
      'title': title,
      'description': description,
      'tags': tags,
      'attachments': uploaded.map((a) => a.toJson()).toList(),
      'is_featured': isFeatured,
      'is_shared': isShared,
      'created_by': _client.auth.currentUser?.id,
    };
    final res =
        await _client.from('project_photos').insert(payload).select().single();
    final photo = _mapProjectPhoto(Map<String, dynamic>.from(res as Map));
    return _signPhotoAttachments(photo);
  }

  @override
  Future<List<PhotoComment>> fetchPhotoComments(String photoId) async {
    final rows = await _client
        .from('photo_comments')
        .select()
        .eq('photo_id', photoId)
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .map((row) => _mapPhotoComment(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<PhotoComment> addPhotoComment({
    required String photoId,
    required String body,
    List<String> mentions = const [],
    AttachmentDraft? voiceNote,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final metadata = <String, dynamic>{};
    if (mentions.isNotEmpty) {
      metadata['mentions'] = mentions;
    }
    if (voiceNote != null) {
      final attachment = await _uploadAttachmentDraft(
        orgId: orgId,
        folder: 'photo-comments',
        draft: voiceNote,
      );
      metadata['voiceNote'] = attachment;
    }
    final res = await _client
        .from('photo_comments')
        .insert({
          'org_id': orgId,
          'photo_id': photoId,
          'author_id': _client.auth.currentUser?.id,
          'body': body,
          'metadata': metadata,
        })
        .select()
        .single();
    if (mentions.isNotEmpty) {
      final targets = await _resolveMentionTargets(
        orgId: orgId,
        mentions: mentions,
      );
      if (targets.isNotEmpty) {
        final notificationBody =
            'You were mentioned in a photo comment.';
        final payload = targets
            .map(
              (userId) => {
                'org_id': orgId,
                'user_id': userId,
                'title': 'Photo mention',
                'body': notificationBody,
                'type': 'photo_mention',
                'is_read': false,
              },
            )
            .toList();
        await _client.from('notifications').insert(payload);
        await _push.sendToUsers(
          userIds: targets,
          orgId: orgId,
          title: 'Photo mention',
          body: notificationBody,
          data: {'type': 'photo_mention', 'photoId': photoId},
        );
      }
    }
    return _mapPhotoComment(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<MentionCandidate>> fetchMentionCandidates() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    try {
      final rows = await _client
          .from('profiles')
          .select('id, email, first_name, last_name, is_active')
          .eq('org_id', orgId)
          .eq('is_active', true);
      return _mapMentionCandidates(rows);
    } on PostgrestException catch (e, st) {
      if (e.message.contains('is_active') || e.code == '42703') {
        try {
          final rows = await _client
              .from('profiles')
              .select('id, email, first_name, last_name')
              .eq('org_id', orgId);
          return _mapMentionCandidates(rows);
        } catch (err, stack) {
          developer.log(
            'Supabase fetchMentionCandidates failed',
            error: err,
            stackTrace: stack,
          );
          return const [];
        }
      }
      developer.log(
        'Supabase fetchMentionCandidates failed',
        error: e,
        stackTrace: st,
      );
      return const [];
    } catch (e, st) {
      developer.log(
        'Supabase fetchMentionCandidates failed',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  @override
  Future<List<WebhookEndpoint>> fetchWebhookEndpoints() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('webhook_endpoints')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _mapWebhook(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<WebhookEndpoint> createWebhookEndpoint({
    required String name,
    required String url,
    List<String> events = const [],
    String? secret,
    bool isActive = true,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final res = await _client
        .from('webhook_endpoints')
        .insert({
          'org_id': orgId,
          'name': name,
          'url': url,
          'secret': secret,
          'events': events,
          'is_active': isActive,
        })
        .select()
        .single();
    return _mapWebhook(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<WebhookEndpoint> updateWebhookEndpoint({
    required String id,
    String? name,
    String? url,
    List<String>? events,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (events != null) 'events': events,
      if (isActive != null) 'is_active': isActive,
    };
    final res = await _client
        .from('webhook_endpoints')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return _mapWebhook(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<IntegrationProfile>> fetchIntegrations() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('integrations')
        .select()
        .eq('org_id', orgId)
        .order('provider', ascending: true);
    return (rows as List<dynamic>)
        .map((row) => _mapIntegration(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<IntegrationProfile> upsertIntegration({
    required String provider,
    String status = 'inactive',
    Map<String, dynamic>? config,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final payload = {
      'org_id': orgId,
      'provider': provider,
      'status': status,
      'config': config ?? const {},
      'created_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final res = await _client
        .from('integrations')
        .upsert(payload, onConflict: 'org_id,provider')
        .select()
        .single();
    return _mapIntegration(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<ExportJob>> fetchExportJobs() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('export_jobs')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);
    final jobs = (rows as List<dynamic>)
        .map((row) => _mapExportJob(Map<String, dynamic>.from(row as Map)))
        .toList();
    return Future.wait(jobs.map(_signExportJob));
  }

  @override
  Future<ExportJob> createExportJob({
    required String type,
    String format = 'csv',
    String status = 'queued',
    String? fileUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final res = await _client
        .from('export_jobs')
        .insert({
          'org_id': orgId,
          'type': type,
          'format': format,
          'status': status,
          'file_url': fileUrl,
          'metadata': metadata ?? const {},
          'requested_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    return _mapExportJob(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<ExportJob> createExportJobWithFile({
    required String type,
    required String format,
    required String filename,
    required Uint8List bytes,
    Map<String, dynamic>? metadata,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final path = await _uploadFile(
      orgId: orgId,
      folder: 'exports',
      filename: filename,
      mimeType: _exportMimeType(format),
      bytes: bytes,
    );
    final res = await _client
        .from('export_jobs')
        .insert({
          'org_id': orgId,
          'type': type,
          'format': format,
          'status': 'completed',
          'file_url': path,
          'metadata': metadata ?? const {},
          'requested_by': _client.auth.currentUser?.id,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return _mapExportJob(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<ExportJob> completeExportJob({
    required String id,
    required String status,
    String? fileUrl,
  }) async {
    final res = await _client
        .from('export_jobs')
        .update({
          'status': status,
          'file_url': fileUrl,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return _mapExportJob(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<AiJob>> fetchAiJobs() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('ai_jobs')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);
    final jobs = (rows as List<dynamic>)
        .map((row) => _mapAiJob(Map<String, dynamic>.from(row as Map)))
        .toList();
    return Future.wait(jobs.map(_signAiMedia));
  }

  @override
  Future<AiJob> createAiJob({
    required String type,
    String? inputText,
    String? outputText,
    List<AttachmentDraft> inputMedia = const [],
    Map<String, dynamic>? metadata,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final uploaded = await _uploadAttachments(
      orgId: orgId,
      folder: 'ai-jobs',
      attachments: inputMedia,
    );
    final res = await _client
        .from('ai_jobs')
        .insert({
          'org_id': orgId,
          'type': type,
          'status': outputText != null ? 'completed' : 'pending',
          'input_text': inputText,
      'input_media': uploaded.map((a) => a.toJson()).toList(),
      'output_text': outputText,
      'metadata': metadata ?? const {},
      'created_by': _client.auth.currentUser?.id,
          'completed_at':
              outputText != null ? DateTime.now().toIso8601String() : null,
        })
        .select()
        .single();
    final job = _mapAiJob(Map<String, dynamic>.from(res as Map));
    return _signAiMedia(job);
  }

  @override
  Future<int> processPendingAiJobs({int maxJobs = 3}) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final rows = await _client
        .from('ai_jobs')
        .select()
        .eq('org_id', orgId)
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(maxJobs);
    int processed = 0;

    for (final row in rows as List<dynamic>) {
      final job = _mapAiJob(Map<String, dynamic>.from(row as Map));
      final locked = await _client
          .from('ai_jobs')
          .update({
            'status': 'processing',
            'metadata': {
              ...?job.metadata,
              'processingStartedAt': DateTime.now().toIso8601String(),
            },
          })
          .eq('id', job.id)
          .eq('status', 'pending')
          .select()
          .maybeSingle();
      if (locked == null) continue;

      try {
        final signedJob = await _signAiMedia(job);
        final output = await _runAiJob(signedJob);
        await _client.from('ai_jobs').update({
          'status': 'completed',
          'output_text': output,
          'completed_at': DateTime.now().toIso8601String(),
          'metadata': {
            ...?job.metadata,
            'processedBy': 'client',
            'processedAt': DateTime.now().toIso8601String(),
          },
        }).eq('id', job.id);
        processed += 1;
      } catch (e) {
        await _client.from('ai_jobs').update({
          'status': 'failed',
          'completed_at': DateTime.now().toIso8601String(),
          'metadata': {
            ...?job.metadata,
            'error': e.toString(),
          },
        }).eq('id', job.id);
      }
    }

    return processed;
  }

  @override
  Future<List<DailyLog>> fetchDailyLogs({String? projectId}) async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    var query = _client.from('daily_logs').select().eq('org_id', orgId);
    if (projectId != null && projectId.isNotEmpty) {
      query = query.eq('project_id', projectId);
    }
    final rows = await query.order('log_date', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _mapDailyLog(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<DailyLog> createDailyLog({
    required String content,
    DateTime? logDate,
    String? title,
    String? projectId,
    Map<String, dynamic>? metadata,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final res = await _client
        .from('daily_logs')
        .insert({
          'org_id': orgId,
          'project_id': projectId,
          'log_date':
              (logDate ?? DateTime.now()).toIso8601String(),
          'title': title,
          'content': content,
          'created_by': _client.auth.currentUser?.id,
          'metadata': metadata ?? const {},
        })
        .select()
        .single();
    return _mapDailyLog(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<GuestInvite>> fetchGuestInvites() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('guest_invites')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _mapGuestInvite(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<GuestInvite> createGuestInvite({
    required String email,
    String? role,
    DateTime? expiresAt,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final res = await _client
        .from('guest_invites')
        .insert({
          'org_id': orgId,
          'email': email,
          'role': role,
          'status': 'invited',
          'token': const Uuid().v4(),
          'expires_at': expiresAt?.toIso8601String(),
          'created_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    return _mapGuestInvite(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<PaymentRequest>> fetchPaymentRequests() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('payment_requests')
        .select()
        .eq('org_id', orgId)
        .order('requested_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _mapPaymentRequest(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<PaymentRequest> createPaymentRequest({
    required double amount,
    String currency = 'USD',
    String? description,
    String? projectId,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final res = await _client
        .from('payment_requests')
        .insert({
          'org_id': orgId,
          'project_id': projectId,
          'amount': amount,
          'currency': currency,
          'description': description,
          'requested_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    return _mapPaymentRequest(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<PaymentRequest> createPaymentCheckout({
    required PaymentRequest request,
  }) async {
    final response = await _client.functions.invoke(
      'payments',
      body: {
        'requestId': request.id,
        'amount': request.amount,
        'currency': request.currency,
        'description': request.description,
        'projectId': request.projectId,
        'orgId': request.orgId,
      },
    );
    if (response.status != 200) {
      throw Exception('Payments function failed (${response.status}).');
    }
    final updated = await _client
        .from('payment_requests')
        .select()
        .eq('id', request.id)
        .single();
    return _mapPaymentRequest(Map<String, dynamic>.from(updated as Map));
  }

  @override
  Future<PaymentRequest> updatePaymentStatus({
    required String id,
    required String status,
  }) async {
    final res = await _client
        .from('payment_requests')
        .update({
          'status': status,
          if (status == 'paid') 'paid_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return _mapPaymentRequest(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<Review>> fetchReviews() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('reviews')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _mapReview(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<Review> createReviewRequest({
    String? projectId,
    int? rating,
    String? comment,
    String? source,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final res = await _client
        .from('reviews')
        .insert({
          'org_id': orgId,
          'project_id': projectId,
          'rating': rating,
          'comment': comment,
          'source': source,
          'status': 'requested',
          'requested_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    return _mapReview(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<Review> updateReviewStatus({
    required String id,
    required String status,
  }) async {
    final res = await _client
        .from('reviews')
        .update({'status': status})
        .eq('id', id)
        .select()
        .single();
    return _mapReview(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<List<PortfolioItem>> fetchPortfolioItems() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('portfolio_items')
        .select()
        .eq('org_id', orgId)
        .order('updated_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _mapPortfolioItem(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<PortfolioItem> createPortfolioItem({
    required String title,
    String? description,
    String? coverUrl,
    List<String> galleryUrls = const [],
    String? projectId,
    bool isPublished = false,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final res = await _client
        .from('portfolio_items')
        .insert({
          'org_id': orgId,
          'project_id': projectId,
          'title': title,
          'description': description,
          'cover_url': coverUrl,
          'gallery_urls': galleryUrls,
          'is_published': isPublished,
          'share_token': const Uuid().v4(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return _mapPortfolioItem(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<PortfolioItem> updatePortfolioPublish({
    required String id,
    required bool isPublished,
  }) async {
    final res = await _client
        .from('portfolio_items')
        .update({
          'is_published': isPublished,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return _mapPortfolioItem(Map<String, dynamic>.from(res as Map));
  }

  Future<List<MediaAttachment>> _uploadAttachments({
    required String orgId,
    required String folder,
    required List<AttachmentDraft> attachments,
  }) async {
    if (attachments.isEmpty) return const [];
    final uploads = <MediaAttachment>[];
    for (final draft in attachments) {
      final path = await _uploadFile(
        orgId: orgId,
        folder: folder,
        filename: draft.filename,
        mimeType: draft.mimeType,
        bytes: draft.bytes,
      );
      uploads.add(
        MediaAttachment(
          id: const Uuid().v4(),
          type: draft.type,
          url: path,
          filename: draft.filename,
          fileSize: draft.bytes.length,
          mimeType: draft.mimeType,
          capturedAt: DateTime.now(),
          metadata: {
            'bucket': _bucketName,
            if (draft.metadata != null) ...draft.metadata!,
          },
        ),
      );
    }
    return uploads;
  }

  Future<String> _uploadFile({
    required String orgId,
    required String folder,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final prefix = orgId.isNotEmpty ? 'org-$orgId' : 'public';
    final safeName = filename.replaceAll(' ', '_');
    final path =
        '$prefix/$folder/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: mimeType,
          ),
        );
    return path;
  }

  Future<Map<String, dynamic>> _uploadAttachmentDraft({
    required String orgId,
    required String folder,
    required AttachmentDraft draft,
  }) async {
    final path = await _uploadFile(
      orgId: orgId,
      folder: folder,
      filename: draft.filename,
      mimeType: draft.mimeType,
      bytes: draft.bytes,
    );
    final url = _client.storage.from(_bucketName).getPublicUrl(path);
    return {
      'url': url,
      'filename': draft.filename,
      'mimeType': draft.mimeType,
      'storagePath': path,
      'bucket': _bucketName,
      if (draft.metadata != null) 'metadata': draft.metadata,
    };
  }

  Future<List<String>> _resolveMentionTargets({
    required String orgId,
    required List<String> mentions,
  }) async {
    final targetHandles =
        mentions.map((mention) => mention.trim().toLowerCase()).toSet();
    if (targetHandles.isEmpty) return const [];
    try {
      final rows = await _client
          .from('profiles')
          .select('id, email, first_name, last_name, is_active')
          .eq('org_id', orgId)
          .eq('is_active', true);
      final matches = <String>[];
      for (final row in rows as List<dynamic>) {
        final data = Map<String, dynamic>.from(row as Map);
        final id = data['id']?.toString();
        if (id == null) continue;
        final handles = _profileHandles(data);
        if (handles.any(targetHandles.contains)) {
          matches.add(id);
        }
      }
      return matches;
    } on PostgrestException catch (e) {
      if (e.message.contains('is_active') || e.code == '42703') {
        try {
          final rows = await _client
              .from('profiles')
              .select('id, email, first_name, last_name')
              .eq('org_id', orgId);
          final matches = <String>[];
          for (final row in rows as List<dynamic>) {
            final data = Map<String, dynamic>.from(row as Map);
            final id = data['id']?.toString();
            if (id == null) continue;
            final handles = _profileHandles(data);
            if (handles.any(targetHandles.contains)) {
              matches.add(id);
            }
          }
          return matches;
        } catch (_) {
          return const [];
        }
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  List<MentionCandidate> _mapMentionCandidates(List<dynamic> rows) {
    final candidates = <MentionCandidate>[];
    for (final row in rows) {
      final data = Map<String, dynamic>.from(row as Map);
      final id = data['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final email = data['email']?.toString();
      final first = data['first_name']?.toString().trim();
      final last = data['last_name']?.toString().trim();
      final fullName = [
        if (first != null && first.isNotEmpty) first,
        if (last != null && last.isNotEmpty) last,
      ].join(' ');
      final handle = _primaryHandleForProfile(data);
      final name = fullName.isNotEmpty
          ? fullName
          : (email?.isNotEmpty == true ? email! : handle);
      candidates.add(
        MentionCandidate(
          id: id,
          name: name,
          handle: handle,
          email: email,
        ),
      );
    }
    candidates.sort((a, b) => a.name.compareTo(b.name));
    return candidates;
  }

  String _primaryHandleForProfile(Map<String, dynamic> row) {
    final email = row['email']?.toString().toLowerCase() ?? '';
    if (email.isNotEmpty) {
      final prefix = email.split('@').first;
      if (prefix.isNotEmpty) return prefix;
      return email;
    }
    final first = row['first_name']?.toString().toLowerCase().trim() ?? '';
    final last = row['last_name']?.toString().toLowerCase().trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) return '$first$last';
    if (first.isNotEmpty) return first;
    if (last.isNotEmpty) return last;
    return row['id']?.toString() ?? 'user';
  }

  Set<String> _profileHandles(Map<String, dynamic> row) {
    final handles = <String>{};
    final email = row['email']?.toString().toLowerCase() ?? '';
    if (email.isNotEmpty) {
      handles.add(email);
      final prefix = email.split('@').first;
      if (prefix.isNotEmpty) handles.add(prefix);
    }
    final first = row['first_name']?.toString().toLowerCase().trim() ?? '';
    final last = row['last_name']?.toString().toLowerCase().trim() ?? '';
    if (first.isNotEmpty) handles.add(first);
    if (last.isNotEmpty) handles.add(last);
    if (first.isNotEmpty && last.isNotEmpty) {
      handles.add('$first$last');
      handles.add('$first.$last');
      handles.add('${first}_$last');
      handles.add('$first-$last');
    }
    return handles;
  }

  NewsPost _mapNewsPost(Map<String, dynamic> row) {
    return NewsPost(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      title: row['title'] as String? ?? '',
      body: row['body'] as String?,
      scope: row['scope'] as String? ?? 'company',
      siteId: row['site_id']?.toString(),
      tags: (row['tags'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isPublished: row['is_published'] as bool? ?? true,
      publishedAt: _parseDate(row['published_at']),
      attachments: _mapAttachments(row['attachments']),
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  NotificationRule _mapRule(Map<String, dynamic> row) {
    return NotificationRule(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      name: row['name'] as String? ?? '',
      triggerType: row['trigger_type'] as String? ?? 'submission',
      targetType: row['target_type'] as String? ?? 'org',
      targetIds: (row['target_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      channels: (row['channels'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['in_app'],
      schedule: row['schedule'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      messageTemplate: row['message_template'] as String?,
      payload: row['payload'] as Map<String, dynamic>?,
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  NotebookPage _mapNotebookPage(Map<String, dynamic> row) {
    return NotebookPage(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      projectId: row['project_id']?.toString(),
      title: row['title'] as String? ?? '',
      body: row['body'] as String?,
      tags: (row['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      attachments: _mapAttachments(row['attachments']),
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  NotebookReport _mapNotebookReport(Map<String, dynamic> row) {
    return NotebookReport(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      projectId: row['project_id']?.toString(),
      title: row['title'] as String? ?? '',
      pageIds: (row['page_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      fileUrl: row['file_url'] as String?,
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  SignatureRequest _mapSignatureRequest(Map<String, dynamic> row) {
    return SignatureRequest(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      documentId: row['document_id']?.toString(),
      requestName: row['request_name'] as String?,
      signerName: row['signer_name'] as String?,
      signerEmail: row['signer_email'] as String?,
      status: row['status'] as String? ?? 'pending',
      token: row['token'] as String?,
      requestedBy: row['requested_by']?.toString(),
      requestedAt: _parseDate(row['requested_at']),
      signedAt: _parseNullableDate(row['signed_at']),
      signatureData: row['signature_data'] as Map<String, dynamic>?,
      fileUrl: row['file_url'] as String?,
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  ProjectPhoto _mapProjectPhoto(Map<String, dynamic> row) {
    return ProjectPhoto(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      projectId: row['project_id']?.toString(),
      title: row['title'] as String?,
      description: row['description'] as String?,
      tags: (row['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      attachments: _mapAttachments(row['attachments']),
      isFeatured: row['is_featured'] as bool? ?? false,
      isShared: row['is_shared'] as bool? ?? false,
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  PhotoComment _mapPhotoComment(Map<String, dynamic> row) {
    return PhotoComment(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      photoId: row['photo_id']?.toString() ?? '',
      authorId: row['author_id']?.toString(),
      body: row['body'] as String? ?? '',
      createdAt: _parseDate(row['created_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  WebhookEndpoint _mapWebhook(Map<String, dynamic> row) {
    return WebhookEndpoint(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      name: row['name'] as String? ?? '',
      url: row['url'] as String? ?? '',
      secret: row['secret'] as String?,
      events: (row['events'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isActive: row['is_active'] as bool? ?? true,
      createdAt: _parseDate(row['created_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  IntegrationProfile _mapIntegration(Map<String, dynamic> row) {
    return IntegrationProfile(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      provider: row['provider'] as String? ?? '',
      status: row['status'] as String? ?? 'inactive',
      config: row['config'] as Map<String, dynamic>? ?? const {},
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  ExportJob _mapExportJob(Map<String, dynamic> row) {
    return ExportJob(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      type: row['type'] as String? ?? '',
      format: row['format'] as String? ?? 'csv',
      status: row['status'] as String? ?? 'queued',
      requestedBy: row['requested_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      completedAt: _parseNullableDate(row['completed_at']),
      fileUrl: row['file_url'] as String?,
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  AiJob _mapAiJob(Map<String, dynamic> row) {
    return AiJob(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      type: row['type'] as String? ?? '',
      status: row['status'] as String? ?? 'pending',
      inputText: row['input_text'] as String?,
      inputMedia: _mapAttachments(row['input_media']),
      outputText: row['output_text'] as String?,
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      completedAt: _parseNullableDate(row['completed_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  DailyLog _mapDailyLog(Map<String, dynamic> row) {
    return DailyLog(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      projectId: row['project_id']?.toString(),
      logDate: _parseDate(row['log_date']),
      title: row['title'] as String?,
      content: row['content'] as String?,
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  GuestInvite _mapGuestInvite(Map<String, dynamic> row) {
    return GuestInvite(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      email: row['email'] as String? ?? '',
      role: row['role'] as String?,
      status: row['status'] as String? ?? 'invited',
      token: row['token'] as String?,
      expiresAt: _parseNullableDate(row['expires_at']),
      createdBy: row['created_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  PaymentRequest _mapPaymentRequest(Map<String, dynamic> row) {
    return PaymentRequest(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      projectId: row['project_id']?.toString(),
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'USD',
      status: row['status'] as String? ?? 'requested',
      description: row['description'] as String?,
      requestedBy: row['requested_by']?.toString(),
      requestedAt: _parseDate(row['requested_at']),
      paidAt: _parseNullableDate(row['paid_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Review _mapReview(Map<String, dynamic> row) {
    return Review(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      projectId: row['project_id']?.toString(),
      rating: row['rating'] as int?,
      comment: row['comment'] as String?,
      source: row['source'] as String?,
      status: row['status'] as String? ?? 'requested',
      requestedBy: row['requested_by']?.toString(),
      createdAt: _parseDate(row['created_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  PortfolioItem _mapPortfolioItem(Map<String, dynamic> row) {
    return PortfolioItem(
      id: row['id'].toString(),
      orgId: row['org_id']?.toString() ?? '',
      projectId: row['project_id']?.toString(),
      title: row['title'] as String? ?? '',
      description: row['description'] as String?,
      coverUrl: row['cover_url'] as String?,
      galleryUrls: (row['gallery_urls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isPublished: row['is_published'] as bool? ?? false,
      shareToken: row['share_token'] as String?,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  List<MediaAttachment>? _mapAttachments(dynamic raw) {
    if (raw is! List) return null;
    return raw
        .map((a) => MediaAttachment.fromJson(Map<String, dynamic>.from(a as Map)))
        .toList();
  }

  Future<NewsPost> _signNewsAttachments(NewsPost post) async {
    final attachments = post.attachments;
    if (attachments == null || attachments.isEmpty) return post;
    final signed = await Future.wait(attachments.map(_signAttachment));
    return NewsPost(
      id: post.id,
      orgId: post.orgId,
      title: post.title,
      body: post.body,
      scope: post.scope,
      siteId: post.siteId,
      tags: post.tags,
      isPublished: post.isPublished,
      publishedAt: post.publishedAt,
      attachments: signed,
      createdBy: post.createdBy,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      metadata: post.metadata,
    );
  }

  Future<NotebookPage> _signNotebookAttachments(NotebookPage page) async {
    final attachments = page.attachments;
    if (attachments == null || attachments.isEmpty) return page;
    final signed = await Future.wait(attachments.map(_signAttachment));
    return NotebookPage(
      id: page.id,
      orgId: page.orgId,
      projectId: page.projectId,
      title: page.title,
      body: page.body,
      tags: page.tags,
      attachments: signed,
      createdBy: page.createdBy,
      createdAt: page.createdAt,
      updatedAt: page.updatedAt,
      metadata: page.metadata,
    );
  }

  Future<NotebookReport> _signNotebookReportFile(NotebookReport report) async {
    final signed = await _signUrlIfNeeded(report.fileUrl);
    return NotebookReport(
      id: report.id,
      orgId: report.orgId,
      projectId: report.projectId,
      title: report.title,
      pageIds: report.pageIds,
      fileUrl: signed ?? report.fileUrl,
      createdBy: report.createdBy,
      createdAt: report.createdAt,
      metadata: report.metadata,
    );
  }

  Future<SignatureRequest> _signSignatureFile(SignatureRequest request) async {
    final signed = await _signUrlIfNeeded(request.fileUrl);
    return SignatureRequest(
      id: request.id,
      orgId: request.orgId,
      documentId: request.documentId,
      requestName: request.requestName,
      signerName: request.signerName,
      signerEmail: request.signerEmail,
      status: request.status,
      token: request.token,
      requestedBy: request.requestedBy,
      requestedAt: request.requestedAt,
      signedAt: request.signedAt,
      signatureData: request.signatureData,
      fileUrl: signed ?? request.fileUrl,
      metadata: request.metadata,
    );
  }

  Future<ProjectPhoto> _signPhotoAttachments(ProjectPhoto photo) async {
    final attachments = photo.attachments;
    if (attachments == null || attachments.isEmpty) return photo;
    final signed = await Future.wait(attachments.map(_signAttachment));
    return ProjectPhoto(
      id: photo.id,
      orgId: photo.orgId,
      projectId: photo.projectId,
      title: photo.title,
      description: photo.description,
      tags: photo.tags,
      attachments: signed,
      isFeatured: photo.isFeatured,
      isShared: photo.isShared,
      createdBy: photo.createdBy,
      createdAt: photo.createdAt,
      metadata: photo.metadata,
    );
  }

  Future<AiJob> _signAiMedia(AiJob job) async {
    final media = job.inputMedia;
    if (media == null || media.isEmpty) return job;
    final signed = await Future.wait(media.map(_signAttachment));
    return AiJob(
      id: job.id,
      orgId: job.orgId,
      type: job.type,
      status: job.status,
      inputText: job.inputText,
      inputMedia: signed,
      outputText: job.outputText,
      createdBy: job.createdBy,
      createdAt: job.createdAt,
      completedAt: job.completedAt,
      metadata: job.metadata,
    );
  }

  Future<String> _runAiJob(AiJob job) async {
    final attachments = job.inputMedia ?? const <MediaAttachment>[];
    final imageAttachment = _firstAttachmentOfType(attachments, 'photo') ??
        _firstAttachmentOfType(attachments, 'image');
    final audioAttachment = _firstAttachmentOfType(attachments, 'audio');
    final imageBytes = await _downloadAttachment(imageAttachment);
    final audioBytes = await _downloadAttachment(audioAttachment);
    final inputText = job.inputText?.trim() ?? '';

    if (inputText.isEmpty && imageBytes == null && audioBytes == null) {
      throw Exception('AI job missing input text or media.');
    }

    final meta = job.metadata ?? const <String, dynamic>{};
    final checklistRaw = meta['checklistCount'];
    final checklistCount = checklistRaw is int
        ? checklistRaw
        : int.tryParse(checklistRaw?.toString() ?? '');
    final targetLanguage = meta['targetLanguage']?.toString();

    final ai = AiFunctionService(_client);
    return ai.runJob(
      type: job.type,
      inputText: inputText.isEmpty ? null : inputText,
      imageBytes: imageBytes,
      audioBytes: audioBytes,
      audioMimeType: audioAttachment?.mimeType,
      targetLanguage: targetLanguage,
      checklistCount: checklistCount,
    );
  }

  MediaAttachment? _firstAttachmentOfType(
    List<MediaAttachment> attachments,
    String type,
  ) {
    for (final attachment in attachments) {
      if (attachment.type == type) return attachment;
    }
    return null;
  }

  Future<Uint8List?> _downloadAttachment(
    MediaAttachment? attachment,
  ) async {
    if (attachment == null) return null;
    final url = attachment.url;
    if (url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (e) {
      developer.log('AI input download failed', error: e);
      return null;
    }
  }

  Future<ExportJob> _signExportJob(ExportJob job) async {
    final url = job.fileUrl;
    if (url == null || url.isEmpty) return job;
    final signed = await _signUrlIfNeeded(url);
    if (signed == null || signed.isEmpty) return job;
    return ExportJob(
      id: job.id,
      orgId: job.orgId,
      type: job.type,
      format: job.format,
      status: job.status,
      requestedBy: job.requestedBy,
      createdAt: job.createdAt,
      completedAt: job.completedAt,
      fileUrl: signed,
      metadata: job.metadata,
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
    } catch (e) {
      developer.log('Sign attachment failed', error: e);
      return attachment;
    }
  }

  Future<int> _countRecentSubmissions(String orgId, DateTime now) async {
    final since = now.subtract(const Duration(hours: 24)).toIso8601String();
    final rows = await _client
        .from('submissions')
        .select('id')
        .eq('org_id', orgId)
        .gte('created_at', since);
    return (rows as List).length;
  }

  Future<int> _countDueTasks(String orgId, DateTime now) async {
    final rows = await _client
        .from('tasks')
        .select('id, due_date, status')
        .eq('org_id', orgId);
    int count = 0;
    for (final row in (rows as List<dynamic>)) {
      final map = Map<String, dynamic>.from(row as Map);
      final dueDate = _parseNullableDate(map['due_date']);
      if (dueDate == null) continue;
      final status = map['status']?.toString() ?? TaskStatus.todo.name;
      if (status == TaskStatus.completed.name) continue;
      final diff = dueDate.difference(now);
      if (diff.inHours >= 0 && diff.inHours <= _taskDueSoonHours) {
        count += 1;
      }
    }
    return count;
  }

  Future<int> _countExpiringTraining(String orgId, DateTime now) async {
    final rows = await _client
        .from('training_records')
        .select('id, expiration_date, status')
        .eq('org_id', orgId);
    int count = 0;
    for (final row in (rows as List<dynamic>)) {
      final map = Map<String, dynamic>.from(row as Map);
      final expiration = _parseNullableDate(map['expiration_date']);
      if (expiration == null) continue;
      final status = map['status']?.toString() ?? TrainingStatus.notStarted.name;
      if (status == TrainingStatus.expired.name) continue;
      final days = expiration.difference(now).inDays;
      if (days >= 0 && days <= AppConstants.certificationExpiryWarningDays) {
        count += 1;
      }
    }
    return count;
  }

  Future<int> _countAssetMaintenance(String orgId, DateTime now) async {
    final rows = await _client
        .from('equipment')
        .select('id, next_maintenance_date, is_active')
        .eq('org_id', orgId)
        .eq('is_active', true);
    int count = 0;
    for (final row in (rows as List<dynamic>)) {
      final map = Map<String, dynamic>.from(row as Map);
      final nextDate = _parseNullableDate(map['next_maintenance_date']);
      if (nextDate == null) continue;
      final days = nextDate.difference(now).inDays;
      if (days <= _assetMaintenanceWindowDays) {
        count += 1;
      }
    }
    return count;
  }

  Future<int> _countDueInspections(String orgId, DateTime now) async {
    final rows = await _client
        .from('equipment')
        .select('id, next_inspection_at, inspection_cadence, is_active')
        .eq('org_id', orgId)
        .eq('is_active', true);
    int count = 0;
    for (final row in (rows as List<dynamic>)) {
      final map = Map<String, dynamic>.from(row as Map);
      final cadence = map['inspection_cadence']?.toString();
      if (cadence == null || cadence.isEmpty) continue;
      final nextAt = _parseNullableDate(map['next_inspection_at']);
      if (nextAt == null) continue;
      if (!nextAt.isAfter(now)) {
        count += 1;
      }
    }
    return count;
  }

  Future<int> _scheduleInspectionTasks({
    required String orgId,
    required DateTime now,
  }) async {
    final equipmentRows = await _client
        .from('equipment')
        .select('id, name, assigned_to, inspection_cadence, next_inspection_at')
        .eq('org_id', orgId)
        .eq('is_active', true);

    final openTasks = await _client
        .from('tasks')
        .select('metadata, status')
        .eq('org_id', orgId)
        .eq('metadata->>type', 'inspection')
        .neq('status', TaskStatus.completed.name);
    final existingEquipmentIds = <String>{};
    for (final row in (openTasks as List<dynamic>)) {
      final metadata = Map<String, dynamic>.from(
        (row as Map)['metadata'] as Map? ?? const {},
      );
      final equipmentId = metadata['equipment_id']?.toString();
      if (equipmentId != null) existingEquipmentIds.add(equipmentId);
    }

    int created = 0;
    for (final row in (equipmentRows as List<dynamic>)) {
      final map = Map<String, dynamic>.from(row as Map);
      final cadence = map['inspection_cadence']?.toString();
      if (cadence == null || cadence.isEmpty) continue;
      final nextAt = _parseNullableDate(map['next_inspection_at']);
      if (nextAt == null || nextAt.isAfter(now)) continue;
      final equipmentId = map['id']?.toString();
      if (equipmentId == null || existingEquipmentIds.contains(equipmentId)) {
        continue;
      }
      final name = map['name']?.toString() ?? 'Asset';
      final assignedTo = map['assigned_to']?.toString();
      await _tasksRepository.createTask(
        title: 'Inspection due: $name',
        description: 'Inspection scheduled by cadence ($cadence).',
        dueDate: nextAt,
        assignedTo: assignedTo,
        metadata: {
          'type': 'inspection',
          'equipment_id': equipmentId,
          'inspection_cadence': cadence,
          'inspection_due_at': nextAt.toIso8601String(),
        },
      );
      created += 1;
      existingEquipmentIds.add(equipmentId);
    }

    return created;
  }

  Future<int> _countPendingSopAcknowledgements(String orgId) async {
    try {
      final docs = await _client
        .from('sop_documents')
          .select('id, current_version_id, status')
          .eq('org_id', orgId)
          .eq('status', 'published');
      final documentRows = docs as List<dynamic>;
      if (documentRows.isEmpty) return 0;
      final members = await _client
          .from('org_members')
          .select('user_id')
          .eq('org_id', orgId);
      final memberIds = (members as List<dynamic>)
          .map((row) => (row as Map)['user_id']?.toString())
          .whereType<String>()
          .toList();
      if (memberIds.isEmpty) return 0;
      final sopIds = documentRows
          .map((row) => (row as Map)['id']?.toString())
          .whereType<String>()
          .toList();
      if (sopIds.isEmpty) return 0;
      final ackRows = await _client
          .from('sop_acknowledgements')
          .select('sop_id, version_id, user_id')
          .eq('org_id', orgId)
          .inFilter('sop_id', sopIds);
      final acked = <String>{};
      for (final row in ackRows as List<dynamic>) {
        final map = Map<String, dynamic>.from(row as Map);
        final sopId = map['sop_id']?.toString();
        final versionId = map['version_id']?.toString();
        final userId = map['user_id']?.toString();
        if (sopId == null || versionId == null || userId == null) continue;
        acked.add('$sopId:$versionId:$userId');
      }
      int count = 0;
      for (final row in documentRows) {
        final map = Map<String, dynamic>.from(row as Map);
        final sopId = map['id']?.toString();
        final versionId = map['current_version_id']?.toString();
        if (sopId == null || versionId == null) continue;
        for (final userId in memberIds) {
          if (!acked.contains('$sopId:$versionId:$userId')) {
            count += 1;
          }
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<List<String>> _resolveRuleTargets({
    required NotificationRule rule,
    required String orgId,
  }) async {
    if (rule.targetType == 'org') {
      final rows = await _client
          .from('org_members')
          .select('user_id')
          .eq('org_id', orgId);
      return (rows as List<dynamic>)
          .map((row) => (row as Map)['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
    }
    if (rule.targetType == 'user' || rule.targetType == 'team') {
      final ids = rule.targetIds;
      if (ids.isNotEmpty) return ids.toSet().toList();
    }
    final currentUserId = _client.auth.currentUser?.id;
    return currentUserId == null ? const [] : [currentUserId];
  }

  Future<String?> _signUrlIfNeeded(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      return await createSignedStorageUrl(
        client: _client,
        url: url,
        defaultBucket: _bucketName,
        expiresInSeconds: kSignedUrlExpirySeconds,
      );
    } catch (_) {
      return url;
    }
  }

  String _exportMimeType(String format) {
    switch (format) {
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
      default:
        return 'text/csv';
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
    return null;
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
