class PhotoComment {
  final String id;
  final String orgId;
  final String photoId;
  final String? authorId;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  PhotoComment({
    required this.id,
    required this.orgId,
    required this.photoId,
    this.authorId,
    required this.body,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'photoId': photoId,
      'authorId': authorId,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory PhotoComment.fromJson(Map<String, dynamic> json) {
    return PhotoComment(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      photoId: json['photoId'] as String,
      authorId: json['authorId'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
