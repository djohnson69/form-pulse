import 'package:shared/src/models/form_submission.dart';

/// Project model
class Project {
  final String id;
  final String? orgId;
  final String name;
  final String? description;
  final String status;
  final List<String> labels;
  final String? coverUrl;
  final String? shareToken;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  Project({
    required this.id,
    this.orgId,
    required this.name,
    this.description,
    this.status = 'active',
    this.labels = const [],
    this.coverUrl,
    this.shareToken,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'name': name,
      'description': description,
      'status': status,
      'labels': labels,
      'coverUrl': coverUrl,
      'shareToken': shareToken,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      orgId: json['orgId'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'active',
      labels: (json['labels'] as List?)?.cast<String>() ?? const [],
      coverUrl: json['coverUrl'] as String?,
      shareToken: json['shareToken'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Project update model for timeline entries
class ProjectUpdate {
  final String id;
  final String projectId;
  final String? orgId;
  final String? userId;
  final String type; // photo, note, audio, video, comment
  final String? title;
  final String? body;
  final List<String> tags;
  final List<MediaAttachment> attachments;
  final String? parentId;
  final bool isShared;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  ProjectUpdate({
    required this.id,
    required this.projectId,
    this.orgId,
    this.userId,
    required this.type,
    this.title,
    this.body,
    this.tags = const [],
    this.attachments = const [],
    this.parentId,
    this.isShared = false,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'orgId': orgId,
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'tags': tags,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'parentId': parentId,
      'isShared': isShared,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ProjectUpdate.fromJson(Map<String, dynamic> json) {
    return ProjectUpdate(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      orgId: json['orgId'] as String?,
      userId: json['userId'] as String?,
      type: json['type'] as String? ?? 'note',
      title: json['title'] as String?,
      body: json['body'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      attachments: (json['attachments'] as List?)
              ?.map(
                (a) => MediaAttachment.fromJson(
                  Map<String, dynamic>.from(a as Map),
                ),
              )
              .toList() ??
          const [],
      parentId: json['parentId'] as String?,
      isShared: json['isShared'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
