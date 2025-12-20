class NotebookReport {
  final String id;
  final String orgId;
  final String? projectId;
  final String title;
  final List<String> pageIds;
  final String? fileUrl;
  final String? createdBy;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  NotebookReport({
    required this.id,
    required this.orgId,
    this.projectId,
    required this.title,
    this.pageIds = const [],
    this.fileUrl,
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
      'pageIds': pageIds,
      'fileUrl': fileUrl,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory NotebookReport.fromJson(Map<String, dynamic> json) {
    return NotebookReport(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      projectId: json['projectId'] as String?,
      title: json['title'] as String? ?? '',
      pageIds:
          (json['pageIds'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      fileUrl: json['fileUrl'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
