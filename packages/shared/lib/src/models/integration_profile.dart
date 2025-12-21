class IntegrationProfile {
  final String id;
  final String orgId;
  final String provider;
  final String status;
  final Map<String, dynamic> config;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  IntegrationProfile({
    required this.id,
    required this.orgId,
    required this.provider,
    required this.status,
    this.config = const {},
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'provider': provider,
      'status': status,
      'config': config,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory IntegrationProfile.fromJson(Map<String, dynamic> json) {
    return IntegrationProfile(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      provider: json['provider'] as String,
      status: json['status'] as String? ?? 'inactive',
      config: json['config'] as Map<String, dynamic>? ?? const {},
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
