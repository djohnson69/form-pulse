import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/storage_utils.dart';

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

abstract class OpsRepositoryBase {
  Future<List<NewsPost>> fetchNewsPosts();
  Future<NewsPost> createNewsPost({
    required String title,
    String? body,
    String scope,
    bool isPublished,
    List<String> tags,
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
  Future<void> triggerRule({
    required NotificationRule rule,
    String? title,
    String? body,
  });

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
  });

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

  Future<List<ExportJob>> fetchExportJobs();
  Future<ExportJob> createExportJob({
    required String type,
    String format,
    String status,
    String? fileUrl,
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
  SupabaseOpsRepository(this._client);

  final SupabaseClient _client;
  static const _bucketName =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

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
      'tags': tags,
      'is_published': isPublished,
      'published_at': DateTime.now().toIso8601String(),
      'created_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final res = await _client.from('news_posts').insert(payload).select().single();
    final post = _mapNewsPost(Map<String, dynamic>.from(res as Map));
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
  Future<void> triggerRule({
    required NotificationRule rule,
    String? title,
    String? body,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
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
    await _client.from('notifications').insert({
      'org_id': orgId,
      'user_id': _client.auth.currentUser?.id,
      'title': title ?? rule.name,
      'body': body ?? rule.messageTemplate ?? 'Automation triggered',
      'type': rule.triggerType,
      'is_read': false,
    });
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
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) throw Exception('User must belong to an organization.');
    final res = await _client
        .from('photo_comments')
        .insert({
          'org_id': orgId,
          'photo_id': photoId,
          'author_id': _client.auth.currentUser?.id,
          'body': body,
          'metadata': {'mentions': mentions},
        })
        .select()
        .single();
    return _mapPhotoComment(Map<String, dynamic>.from(res as Map));
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
  Future<List<ExportJob>> fetchExportJobs() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    final rows = await _client
        .from('export_jobs')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _mapExportJob(Map<String, dynamic>.from(row as Map)))
        .toList();
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
