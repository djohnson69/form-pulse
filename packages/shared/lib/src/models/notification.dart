/// Notification model for push notifications and in-app alerts
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? type;
  final String? targetUserId;
  final String? targetRole;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.targetUserId,
    this.targetRole,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.actionUrl,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'targetUserId': targetUserId,
      'targetRole': targetRole,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'actionUrl': actionUrl,
      'metadata': metadata,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String?,
      targetUserId: json['targetUserId'] as String?,
      targetRole: json['targetRole'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      actionUrl: json['actionUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
