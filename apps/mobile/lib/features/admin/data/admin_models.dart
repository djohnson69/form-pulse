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
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String orgId;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
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
    this.attachmentsCount = 0,
    this.metadata,
  });

  final String id;
  final String formId;
  final String status;
  final DateTime submittedAt;
  final String? submittedBy;
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
