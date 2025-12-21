class Team {
  Team({
    required this.id,
    required this.orgId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String orgId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id']?.toString() ?? '',
      orgId: json['orgId']?.toString() ?? json['org_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
