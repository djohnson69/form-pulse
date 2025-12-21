import 'package:shared/src/models/form_submission.dart';

class SopDocument {
  final String id;
  final String orgId;
  final String title;
  final String? summary;
  final String? category;
  final List<String> tags;
  final String status;
  final String? currentVersion;
  final String? currentVersionId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  SopDocument({
    required this.id,
    required this.orgId,
    required this.title,
    this.summary,
    this.category,
    this.tags = const [],
    this.status = 'draft',
    this.currentVersion,
    this.currentVersionId,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'title': title,
      'summary': summary,
      'category': category,
      'tags': tags,
      'status': status,
      'currentVersion': currentVersion,
      'currentVersionId': currentVersionId,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory SopDocument.fromJson(Map<String, dynamic> json) {
    return SopDocument(
      id: json['id'] as String,
      orgId: json['orgId'] as String? ?? json['org_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled SOP',
      summary: json['summary'] as String?,
      category: json['category'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      status: json['status'] as String? ?? 'draft',
      currentVersion: json['currentVersion'] as String? ??
          json['current_version'] as String?,
      currentVersionId: json['currentVersionId'] as String? ??
          json['current_version_id'] as String?,
      createdBy: json['createdBy']?.toString() ??
          json['created_by']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class SopVersion {
  final String id;
  final String orgId;
  final String sopId;
  final String version;
  final String? body;
  final List<MediaAttachment> attachments;
  final String? createdBy;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  SopVersion({
    required this.id,
    required this.orgId,
    required this.sopId,
    required this.version,
    this.body,
    this.attachments = const [],
    this.createdBy,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'sopId': sopId,
      'version': version,
      'body': body,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory SopVersion.fromJson(Map<String, dynamic> json) {
    return SopVersion(
      id: json['id'] as String,
      orgId: json['orgId'] as String? ?? json['org_id'] as String? ?? '',
      sopId: json['sopId'] as String? ?? json['sop_id'] as String? ?? '',
      version: json['version'] as String? ?? 'v1',
      body: json['body'] as String?,
      attachments: (json['attachments'] as List?)
              ?.map(
                (a) => MediaAttachment.fromJson(
                  Map<String, dynamic>.from(a as Map),
                ),
              )
              .toList() ??
          const [],
      createdBy: json['createdBy']?.toString() ??
          json['created_by']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class SopApproval {
  final String id;
  final String orgId;
  final String sopId;
  final String? versionId;
  final String status;
  final String? requestedBy;
  final DateTime requestedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;
  final Map<String, dynamic>? metadata;

  SopApproval({
    required this.id,
    required this.orgId,
    required this.sopId,
    this.versionId,
    this.status = 'pending',
    this.requestedBy,
    required this.requestedAt,
    this.approvedBy,
    this.approvedAt,
    this.notes,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'sopId': sopId,
      'versionId': versionId,
      'status': status,
      'requestedBy': requestedBy,
      'requestedAt': requestedAt.toIso8601String(),
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
      'notes': notes,
      'metadata': metadata,
    };
  }

  factory SopApproval.fromJson(Map<String, dynamic> json) {
    return SopApproval(
      id: json['id'] as String,
      orgId: json['orgId'] as String? ?? json['org_id'] as String? ?? '',
      sopId: json['sopId'] as String? ?? json['sop_id'] as String? ?? '',
      versionId: json['versionId'] as String? ??
          json['version_id']?.toString(),
      status: json['status'] as String? ?? 'pending',
      requestedBy: json['requestedBy']?.toString() ??
          json['requested_by']?.toString(),
      requestedAt: DateTime.tryParse(json['requestedAt']?.toString() ?? '') ??
          DateTime.tryParse(json['requested_at']?.toString() ?? '') ??
          DateTime.now(),
      approvedBy: json['approvedBy']?.toString() ??
          json['approved_by']?.toString(),
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : DateTime.tryParse(json['approved_at']?.toString() ?? ''),
      notes: json['notes'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class SopAcknowledgement {
  final String id;
  final String orgId;
  final String sopId;
  final String? versionId;
  final String? userId;
  final DateTime acknowledgedAt;
  final Map<String, dynamic>? metadata;

  SopAcknowledgement({
    required this.id,
    required this.orgId,
    required this.sopId,
    this.versionId,
    this.userId,
    required this.acknowledgedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'sopId': sopId,
      'versionId': versionId,
      'userId': userId,
      'acknowledgedAt': acknowledgedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory SopAcknowledgement.fromJson(Map<String, dynamic> json) {
    return SopAcknowledgement(
      id: json['id'] as String,
      orgId: json['orgId'] as String? ?? json['org_id'] as String? ?? '',
      sopId: json['sopId'] as String? ?? json['sop_id'] as String? ?? '',
      versionId: json['versionId'] as String? ??
          json['version_id']?.toString(),
      userId: json['userId']?.toString() ?? json['user_id']?.toString(),
      acknowledgedAt: DateTime.tryParse(json['acknowledgedAt']?.toString() ?? '') ??
          DateTime.tryParse(json['acknowledged_at']?.toString() ?? '') ??
          DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
