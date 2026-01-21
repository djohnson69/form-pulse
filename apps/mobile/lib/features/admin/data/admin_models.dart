import 'package:shared/shared.dart';

class AdminStats {
  const AdminStats({
    required this.forms,
    required this.submissions,
    required this.attachments,
    required this.projects,
    required this.tasks,
    required this.assets,
    required this.inspections,
    required this.incidents,
    required this.documents,
    required this.trainingRecords,
    required this.notifications,
    required this.webhooks,
    required this.exportJobs,
    required this.aiJobs,
    required this.newsPosts,
    required this.notificationRules,
    required this.notebookPages,
    required this.notebookReports,
    required this.signatureRequests,
    required this.projectPhotos,
    required this.paymentRequests,
    required this.reviews,
    required this.portfolioItems,
    required this.guestInvites,
    required this.clients,
    required this.vendors,
    required this.messageThreads,
    required this.formsByCategory,
  });

  final int forms;
  final int submissions;
  final int attachments;
  final int projects;
  final int tasks;
  final int assets;
  final int inspections;
  final int incidents;
  final int documents;
  final int trainingRecords;
  final int notifications;
  final int webhooks;
  final int exportJobs;
  final int aiJobs;
  final int newsPosts;
  final int notificationRules;
  final int notebookPages;
  final int notebookReports;
  final int signatureRequests;
  final int projectPhotos;
  final int paymentRequests;
  final int reviews;
  final int portfolioItems;
  final int guestInvites;
  final int clients;
  final int vendors;
  final int messageThreads;
  final Map<String, int> formsByCategory;
}

class AdminAiUsageSummary {
  const AdminAiUsageSummary({
    required this.totalJobs,
    required this.byType,
    required this.topUsers,
    required this.windowLabel,
  });

  final int totalJobs;
  final Map<String, int> byType;
  final List<AdminAiUserUsage> topUsers;
  final String windowLabel;
}

class AdminAiUserUsage {
  const AdminAiUserUsage({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.jobs,
  });

  final String userId;
  final String displayName;
  final String email;
  final int jobs;
}

class AdminOrgSummary {
  const AdminOrgSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.memberCount,
    required this.roleCounts,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int memberCount;
  final Map<String, int> roleCounts;
}

class AdminUserSummary {
  const AdminUserSummary({
    required this.id,
    required this.orgId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String orgId;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? email : full;
  }
}

class AdminFormSummary {
  const AdminFormSummary({
    required this.id,
    required this.title,
    this.category,
    this.tags = const [],
    this.version,
    required this.isPublished,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? category;
  final List<String> tags;
  final String? version;
  final bool isPublished;
  final DateTime updatedAt;
}

class AdminSubmissionSummary {
  const AdminSubmissionSummary({
    required this.id,
    required this.formId,
    required this.status,
    required this.submittedAt,
    this.submittedBy,
    this.formTitle,
    this.submittedByName,
    this.submittedByRole,
    this.attachmentsCount = 0,
    this.metadata,
  });

  final String id;
  final String formId;
  final String status;
  final DateTime submittedAt;
  final String? submittedBy;
  final String? formTitle;
  final String? submittedByName;
  final UserRole? submittedByRole;
  final int attachmentsCount;
  final Map<String, dynamic>? metadata;
}

class AdminAuditEvent {
  const AdminAuditEvent({
    required this.id,
    required this.orgId,
    required this.actorId,
    required this.resourceType,
    required this.resourceId,
    required this.action,
    required this.createdAt,
    this.payload,
  });

  final int id;
  final String? orgId;
  final String? actorId;
  final String resourceType;
  final String? resourceId;
  final String action;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;
}

/// Represents a pending user invitation
class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.orgId,
    required this.email,
    required this.role,
    required this.invitedAt,
    required this.status,
    this.firstName,
    this.lastName,
    this.invitedBy,
    this.expiresAt,
  });

  final String id;
  final String orgId;
  final String email;
  final String role;
  final DateTime invitedAt;
  final String status;
  final String? firstName;
  final String? lastName;
  final String? invitedBy;
  final DateTime? expiresAt;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory PendingInvitation.fromJson(Map<String, dynamic> json) {
    return PendingInvitation(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      invitedAt: DateTime.parse(json['invited_at'] as String),
      status: json['status'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      invitedBy: json['invited_by'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }
}
