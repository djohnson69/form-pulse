class DailyLog {
  final String id;
  final String orgId;
  final String? projectId;
  final DateTime logDate;
  final String? title;
  final String? content;
  final String? createdBy;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  DailyLog({
    required this.id,
    required this.orgId,
    this.projectId,
    required this.logDate,
    this.title,
    this.content,
    this.createdBy,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'projectId': projectId,
      'logDate': logDate.toIso8601String(),
      'title': title,
      'content': content,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      projectId: json['projectId'] as String?,
      logDate: DateTime.parse(json['logDate'] as String),
      title: json['title'] as String?,
      content: json['content'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
