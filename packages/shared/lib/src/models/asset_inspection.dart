import 'package:shared/src/models/form_submission.dart';

/// Asset inspection record
class AssetInspection {
  final String id;
  final String orgId;
  final String equipmentId;
  final String status;
  final String? notes;
  final List<MediaAttachment>? attachments;
  final LocationData? location;
  final DateTime inspectedAt;
  final String? createdBy;
  final String? createdByName;
  final Map<String, dynamic>? metadata;

  AssetInspection({
    required this.id,
    required this.orgId,
    required this.equipmentId,
    required this.status,
    this.notes,
    this.attachments,
    this.location,
    required this.inspectedAt,
    this.createdBy,
    this.createdByName,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'equipmentId': equipmentId,
      'status': status,
      'notes': notes,
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      'location': location?.toJson(),
      'inspectedAt': inspectedAt.toIso8601String(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'metadata': metadata,
    };
  }

  factory AssetInspection.fromJson(Map<String, dynamic> json) {
    return AssetInspection(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      equipmentId: json['equipmentId'] as String,
      status: json['status'] as String? ?? 'pass',
      notes: json['notes'] as String?,
      attachments: (json['attachments'] as List?)
          ?.map((a) => MediaAttachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      location: json['location'] != null
          ? LocationData.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      inspectedAt: DateTime.parse(json['inspectedAt'] as String),
      createdBy: json['createdBy'] as String?,
      createdByName: json['createdByName'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
