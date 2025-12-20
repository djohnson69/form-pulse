import 'package:shared/src/enums/task_status.dart';

/// Task model
class Task {
  final String id;
  final String? orgId;
  final String title;
  final String? description;
  final String? instructions;
  final TaskStatus status;
  final int progress;
  final DateTime? dueDate;
  final String? priority;
  final String? assignedTo;
  final String? assignedToName;
  final String? assignedTeam;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  Task({
    required this.id,
    this.orgId,
    required this.title,
    this.description,
    this.instructions,
    this.status = TaskStatus.todo,
    this.progress = 0,
    this.dueDate,
    this.priority,
    this.assignedTo,
    this.assignedToName,
    this.assignedTeam,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orgId': orgId,
      'title': title,
      'description': description,
      'instructions': instructions,
      'status': status.name,
      'progress': progress,
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedTeam': assignedTeam,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    final progress = rawProgress is num
        ? rawProgress.round()
        : int.tryParse(rawProgress?.toString() ?? '') ?? 0;
    return Task(
      id: json['id'] as String,
      orgId: json['orgId'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      instructions: json['instructions'] as String?,
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.todo,
      ),
      progress: progress,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      priority: json['priority'] as String?,
      assignedTo: json['assignedTo'] as String?,
      assignedToName: json['assignedToName'] as String?,
      assignedTeam: json['assignedTeam'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  bool get isComplete => status == TaskStatus.completed;
}
