/// Message model
class Message {
  final String id;
  final String threadId;
  final String orgId;
  final String? senderId;
  final String? senderName;
  final String? senderRole;
  final String body;
  final List<Map<String, dynamic>>? attachments;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  Message({
    required this.id,
    required this.threadId,
    required this.orgId,
    this.senderId,
    this.senderName,
    this.senderRole,
    required this.body,
    this.attachments,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'threadId': threadId,
      'orgId': orgId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'body': body,
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      orgId: json['orgId'] as String,
      senderId: json['senderId'] as String?,
      senderName: json['senderName'] as String?,
      senderRole: json['senderRole'] as String?,
      body: json['body'] as String? ?? '',
      attachments: (json['attachments'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
