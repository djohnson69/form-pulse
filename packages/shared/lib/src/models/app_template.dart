class AppTemplate {
  final String id;
  final String orgId;
  final String type;
  final String name;
  final String? description;
  final Map<String, dynamic> payload;
  final List<String> assignedUserIds;
  final List<String> assignedRoles;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  AppTemplate({
    required this.id,
    required this.orgId,
    required this.type,
    required this.name,
    this.description,
    this.payload = const {},
    this.assignedUserIds = const [],
    this.assignedRoles = const [],
    this.isActive = true,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'type': type,
      'name': name,
      'description': description,
      'payload': payload,
      'assignedUserIds': assignedUserIds,
      'assignedRoles': assignedRoles,
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory AppTemplate.fromJson(Map<String, dynamic> json) {
    return AppTemplate(
      id: json['id'] as String,
      orgId: json['orgId'] as String? ?? json['org_id'] as String? ?? '',
      type: json['type'] as String? ?? 'workflow',
      name: json['name'] as String? ?? 'Untitled template',
      description: json['description'] as String?,
      payload: json['payload'] as Map<String, dynamic>? ?? const {},
      assignedUserIds: (json['assignedUserIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['assigned_user_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      assignedRoles: (json['assignedRoles'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['assigned_roles'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      createdBy: json['createdBy']?.toString() ??
          json['created_by']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
