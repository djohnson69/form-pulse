import 'package:shared/src/models/form_submission.dart';

class AiJob {
  final String id;
  final String orgId;
  final String type;
  final String status;
  final String? inputText;
  final List<MediaAttachment>? inputMedia;
  final String? outputText;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  AiJob({
    required this.id,
    required this.orgId,
    required this.type,
    this.status = 'pending',
    this.inputText,
    this.inputMedia,
    this.outputText,
    this.createdBy,
    required this.createdAt,
    this.completedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'type': type,
      'status': status,
      'inputText': inputText,
      'inputMedia': inputMedia?.map((a) => a.toJson()).toList(),
      'outputText': outputText,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory AiJob.fromJson(Map<String, dynamic> json) {
    return AiJob(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      inputText: json['inputText'] as String?,
      inputMedia: (json['inputMedia'] as List?)
          ?.map((a) => MediaAttachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      outputText: json['outputText'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
