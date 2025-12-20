class PortfolioItem {
  final String id;
  final String orgId;
  final String? projectId;
  final String title;
  final String? description;
  final String? coverUrl;
  final List<String> galleryUrls;
  final bool isPublished;
  final String? shareToken;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  PortfolioItem({
    required this.id,
    required this.orgId,
    this.projectId,
    required this.title,
    this.description,
    this.coverUrl,
    this.galleryUrls = const [],
    this.isPublished = false,
    this.shareToken,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'projectId': projectId,
      'title': title,
      'description': description,
      'coverUrl': coverUrl,
      'galleryUrls': galleryUrls,
      'isPublished': isPublished,
      'shareToken': shareToken,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      projectId: json['projectId'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      coverUrl: json['coverUrl'] as String?,
      galleryUrls:
          (json['galleryUrls'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      isPublished: json['isPublished'] as bool? ?? false,
      shareToken: json['shareToken'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
