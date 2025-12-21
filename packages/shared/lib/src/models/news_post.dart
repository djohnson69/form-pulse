import 'package:shared/src/models/form_submission.dart';

class NewsPost {
  final String id;
  final String orgId;
  final String title;
  final String? body;
  final String scope;
  final String? siteId;
  final List<String> tags;
  final bool isPublished;
  final DateTime publishedAt;
  final List<MediaAttachment>? attachments;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  NewsPost({
    required this.id,
    required this.orgId,
    required this.title,
    this.body,
    this.scope = 'company',
    this.siteId,
    this.tags = const [],
    this.isPublished = true,
    required this.publishedAt,
    this.attachments,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'title': title,
      'body': body,
      'scope': scope,
      'siteId': siteId,
      'tags': tags,
      'isPublished': isPublished,
      'publishedAt': publishedAt.toIso8601String(),
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory NewsPost.fromJson(Map<String, dynamic> json) {
    final publishedAt = json['publishedAt'] ?? json['published_at'];
    final createdAt = json['createdAt'] ?? json['created_at'];
    final updatedAt = json['updatedAt'] ?? json['updated_at'];
    return NewsPost(
      id: json['id'] as String,
      orgId: json['orgId'] as String? ?? json['org_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      scope: json['scope'] as String? ?? 'company',
      siteId: json['siteId'] as String? ?? json['site_id'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isPublished:
          json['isPublished'] as bool? ?? json['is_published'] as bool? ?? true,
      publishedAt: publishedAt != null
          ? DateTime.parse(publishedAt.toString())
          : DateTime.now(),
      attachments: (json['attachments'] as List?)
          ?.map((a) => MediaAttachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      createdBy: json['createdBy'] as String? ?? json['created_by'] as String?,
      createdAt: createdAt != null
          ? DateTime.parse(createdAt.toString())
          : DateTime.now(),
      updatedAt: updatedAt != null
          ? DateTime.parse(updatedAt.toString())
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
