import 'package:shared/src/models/form_submission.dart';

class ProjectPhoto {
  final String id;
  final String orgId;
  final String? projectId;
  final String? title;
  final String? description;
  final List<String> tags;
  final List<MediaAttachment>? attachments;
  final bool isFeatured;
  final bool isShared;
  final String? createdBy;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  ProjectPhoto({
    required this.id,
    required this.orgId,
    this.projectId,
    this.title,
    this.description,
    this.tags = const [],
    this.attachments,
    this.isFeatured = false,
    this.isShared = false,
    this.createdBy,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'projectId': projectId,
      'title': title,
      'description': description,
      'tags': tags,
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      'isFeatured': isFeatured,
      'isShared': isShared,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ProjectPhoto.fromJson(Map<String, dynamic> json) {
    return ProjectPhoto(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      projectId: json['projectId'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      attachments: (json['attachments'] as List?)
          ?.map((a) => MediaAttachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      isFeatured: json['isFeatured'] as bool? ?? false,
      isShared: json['isShared'] as bool? ?? false,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
