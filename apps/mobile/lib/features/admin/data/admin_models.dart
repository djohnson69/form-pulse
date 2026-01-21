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

/// Full organization details for platform role management
class AdminOrgDetail {
  const AdminOrgDetail({
    required this.id,
    required this.name,
    this.displayName,
    this.industry,
    this.companySize,
    this.website,
    this.phone,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.taxId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String? displayName;
  final String? industry;
  final String? companySize;
  final String? website;
  final String? phone;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? taxId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int memberCount;

  /// Create from Supabase row
  factory AdminOrgDetail.fromJson(Map<String, dynamic> json) {
    return AdminOrgDetail(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String?,
      industry: json['industry'] as String?,
      companySize: json['company_size'] as String?,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      taxId: json['tax_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      memberCount: json['member_count'] as int? ?? 0,
    );
  }

  /// Create from edge function response
  factory AdminOrgDetail.fromEdgeResponse(Map<String, dynamic> json) {
    return AdminOrgDetail(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      displayName: json['displayName'] as String?,
      industry: json['industry'] as String?,
      companySize: json['companySize'] as String?,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
      addressLine1: json['addressLine1'] as String?,
      addressLine2: json['addressLine2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postalCode'] as String?,
      country: json['country'] as String?,
      taxId: json['taxId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  /// Get formatted address string
  String get formattedAddress {
    final parts = <String>[];
    if (addressLine1?.isNotEmpty ?? false) parts.add(addressLine1!);
    if (addressLine2?.isNotEmpty ?? false) parts.add(addressLine2!);
    final cityStateZip = [
      city,
      state,
      postalCode,
    ].where((s) => s?.isNotEmpty ?? false).join(', ');
    if (cityStateZip.isNotEmpty) parts.add(cityStateZip);
    if (country?.isNotEmpty ?? false) parts.add(country!);
    return parts.join('\n');
  }

  /// Copy with modified fields
  AdminOrgDetail copyWith({
    String? name,
    String? displayName,
    String? industry,
    String? companySize,
    String? website,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? taxId,
    bool? isActive,
  }) {
    return AdminOrgDetail(
      id: id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      industry: industry ?? this.industry,
      companySize: companySize ?? this.companySize,
      website: website ?? this.website,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      taxId: taxId ?? this.taxId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      memberCount: memberCount,
    );
  }
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
