/// News item model for company-wide and site-specific alerts
class NewsItem {
  final String id;
  final String title;
  final String content;
  final String? summary;
  final String? imageUrl;
  final String author;
  final String? authorName;
  final DateTime publishedAt;
  final DateTime? updatedAt;
  final bool isPinned;
  final String? category;
  final List<String>? tags;
  final String? targetAudience; // 'all', 'site-specific', etc.
  final String? jobSiteId;
  final String? companyId;
  final Map<String, dynamic>? metadata;

  NewsItem({
    required this.id,
    required this.title,
    required this.content,
    this.summary,
    this.imageUrl,
    required this.author,
    this.authorName,
    required this.publishedAt,
    this.updatedAt,
    this.isPinned = false,
    this.category,
    this.tags,
    this.targetAudience,
    this.jobSiteId,
    this.companyId,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'summary': summary,
      'imageUrl': imageUrl,
      'author': author,
      'authorName': authorName,
      'publishedAt': publishedAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isPinned': isPinned,
      'category': category,
      'tags': tags,
      'targetAudience': targetAudience,
      'jobSiteId': jobSiteId,
      'companyId': companyId,
      'metadata': metadata,
    };
  }

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      summary: json['summary'] as String?,
      imageUrl: json['imageUrl'] as String?,
      author: json['author'] as String,
      authorName: json['authorName'] as String?,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isPinned: json['isPinned'] as bool? ?? false,
      category: json['category'] as String?,
      tags: (json['tags'] as List?)?.cast<String>(),
      targetAudience: json['targetAudience'] as String?,
      jobSiteId: json['jobSiteId'] as String?,
      companyId: json['companyId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
