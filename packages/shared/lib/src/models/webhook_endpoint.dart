class WebhookEndpoint {
  final String id;
  final String orgId;
  final String name;
  final String url;
  final String? secret;
  final List<String> events;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  WebhookEndpoint({
    required this.id,
    required this.orgId,
    required this.name,
    required this.url,
    this.secret,
    this.events = const [],
    this.isActive = true,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'name': name,
      'url': url,
      'secret': secret,
      'events': events,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory WebhookEndpoint.fromJson(Map<String, dynamic> json) {
    return WebhookEndpoint(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      secret: json['secret'] as String?,
      events:
          (json['events'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
