class NotificationEvent {
  final String id;
  final String orgId;
  final String? ruleId;
  final String status;
  final DateTime firedAt;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  NotificationEvent({
    required this.id,
    required this.orgId,
    this.ruleId,
    this.status = 'queued',
    required this.firedAt,
    this.payload,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'ruleId': ruleId,
      'status': status,
      'firedAt': firedAt.toIso8601String(),
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    return NotificationEvent(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      ruleId: json['ruleId'] as String?,
      status: json['status'] as String? ?? 'queued',
      firedAt: DateTime.parse(json['firedAt'] as String),
      payload: json['payload'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
