/// Messaging thread model
class MessageThread {
  final String id;
  final String orgId;
  final String title;
  final String? type;
  final String? clientId;
  final String? vendorId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  MessageThread({
    required this.id,
    required this.orgId,
    required this.title,
    this.type,
    this.clientId,
    this.vendorId,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'title': title,
      'type': type,
      'clientId': clientId,
      'vendorId': vendorId,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    return MessageThread(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      title: json['title'] as String? ?? '',
      type: json['type'] as String?,
      clientId: json['clientId'] as String?,
      vendorId: json['vendorId'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
