class GuestInvite {
  final String id;
  final String orgId;
  final String email;
  final String? role;
  final String status;
  final String? token;
  final DateTime? expiresAt;
  final String? createdBy;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  GuestInvite({
    required this.id,
    required this.orgId,
    required this.email,
    this.role,
    this.status = 'invited',
    this.token,
    this.expiresAt,
    this.createdBy,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'email': email,
      'role': role,
      'status': status,
      'token': token,
      'expiresAt': expiresAt?.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory GuestInvite.fromJson(Map<String, dynamic> json) {
    return GuestInvite(
      id: json['id'] as String,
      orgId: json['orgId'] as String,
      email: json['email'] as String? ?? '',
      role: json['role'] as String?,
      status: json['status'] as String? ?? 'invited',
      token: json['token'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
