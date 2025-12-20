class NotificationRule {
  final String id;
  final String orgId;
  final String name;
  final String triggerType;
  final String targetType;
  final List<String> targetIds;
  final List<String> channels;
  final String? schedule;
  final bool isActive;
  final String? messageTemplate;
  final Map<String, dynamic>? payload;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  NotificationRule({
    required this.id,
    required this.orgId,
    required this.name,
    required this.triggerType,
    this.targetType = 'org',
    this.targetIds = const [],
    this.channels = const ['in_app'],
    this.schedule,
    this.isActive = true,
    this.messageTemplate,
    this.payload,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'name': name,
      'triggerType': triggerType,
      'targetType': targetType,
      'targetIds': targetIds,
      'channels': channels,
      'schedule': schedule,
      'isActive': isActive,
      'messageTemplate': messageTemplate,
      'payload': payload,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory NotificationRule.fromJson(Map<String, dynamic> json) {
    return NotificationRule(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      name: json['name'] as String? ?? '',
      triggerType: json['triggerType'] as String? ?? 'submission',
      targetType: json['targetType'] as String? ?? 'org',
      targetIds:
          (json['targetIds'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      channels:
          (json['channels'] as List?)?.map((e) => e.toString()).toList() ??
              const ['in_app'],
      schedule: json['schedule'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      messageTemplate: json['messageTemplate'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
