class ExportJob {
  final String id;
  final String orgId;
  final String type;
  final String format;
  final String status;
  final String? requestedBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? fileUrl;
  final Map<String, dynamic>? metadata;

  ExportJob({
    required this.id,
    required this.orgId,
    required this.type,
    this.format = 'csv',
    this.status = 'queued',
    this.requestedBy,
    required this.createdAt,
    this.completedAt,
    this.fileUrl,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'type': type,
      'format': format,
      'status': status,
      'requestedBy': requestedBy,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'fileUrl': fileUrl,
      'metadata': metadata,
    };
  }

  factory ExportJob.fromJson(Map<String, dynamic> json) {
    return ExportJob(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      type: json['type'] as String? ?? '',
      format: json['format'] as String? ?? 'csv',
      status: json['status'] as String? ?? 'queued',
      requestedBy: json['requestedBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      fileUrl: json['fileUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
