import 'package:shared/src/models/form_submission.dart';

/// Incident report model
class IncidentReport {
  final String id;
  final String orgId;
  final String? equipmentId;
  final String? jobSiteId;
  final String title;
  final String? description;
  final String status;
  final String? category;
  final String? severity;
  final DateTime occurredAt;
  final String? submittedBy;
  final String? submittedByName;
  final LocationData? location;
  final List<MediaAttachment>? attachments;
  final Map<String, dynamic>? metadata;

  IncidentReport({
    required this.id,
    required this.orgId,
    this.equipmentId,
    this.jobSiteId,
    required this.title,
    this.description,
    this.status = 'open',
    this.category,
    this.severity,
    required this.occurredAt,
    this.submittedBy,
    this.submittedByName,
    this.location,
    this.attachments,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'equipmentId': equipmentId,
      'jobSiteId': jobSiteId,
      'title': title,
      'description': description,
      'status': status,
      'category': category,
      'severity': severity,
      'occurredAt': occurredAt.toIso8601String(),
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      'location': location?.toJson(),
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory IncidentReport.fromJson(Map<String, dynamic> json) {
    return IncidentReport(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      equipmentId: json['equipmentId'] as String?,
      jobSiteId: json['jobSiteId'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'open',
      category: json['category'] as String?,
      severity: json['severity'] as String?,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      submittedBy: json['submittedBy'] as String?,
      submittedByName: json['submittedByName'] as String?,
      location: json['location'] != null
          ? LocationData.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      attachments: (json['attachments'] as List?)
          ?.map((a) => MediaAttachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
