class Review {
  final String id;
  final String orgId;
  final String? projectId;
  final int? rating;
  final String? comment;
  final String? source;
  final String status;
  final String? requestedBy;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  Review({
    required this.id,
    required this.orgId,
    this.projectId,
    this.rating,
    this.comment,
    this.source,
    this.status = 'requested',
    this.requestedBy,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'projectId': projectId,
      'rating': rating,
      'comment': comment,
      'source': source,
      'status': status,
      'requestedBy': requestedBy,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      projectId: json['projectId'] as String?,
      rating: json['rating'] as int?,
      comment: json['comment'] as String?,
      source: json['source'] as String?,
      status: json['status'] as String? ?? 'requested',
      requestedBy: json['requestedBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
