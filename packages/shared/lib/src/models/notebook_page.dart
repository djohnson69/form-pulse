import 'package:shared/src/models/form_submission.dart';

class NotebookPage {
  final String id;
  final String orgId;
  final String? projectId;
  final String title;
  final String? body;
  final List<String> tags;
  final List<MediaAttachment>? attachments;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  NotebookPage({
    required this.id,
    required this.orgId,
    this.projectId,
    required this.title,
    this.body,
    this.tags = const [],
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
      'projectId': projectId,
      'title': title,
      'body': body,
      'tags': tags,
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory NotebookPage.fromJson(Map<String, dynamic> json) {
    return NotebookPage(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      projectId: json['projectId'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      attachments: (json['attachments'] as List?)
          ?.map((a) => MediaAttachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
