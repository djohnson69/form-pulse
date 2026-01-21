/// User role enumeration for access control
enum UserRole {
  /// Super administrator with full system access
  superAdmin,

  /// Company administrator
  admin,

  /// Developer with full-access inspector tooling
  developer,

  /// Site manager with limited administrative access
  manager,

  /// Frontline supervisor with scoped administrative access
  supervisor,

  /// Standard employee user
  employee,

  /// Maintenance technician
  maintenance,
  
  /// Technical support
  techSupport,
  
  /// Client portal user
  client,
  
  /// Vendor portal user
  vendor,
  
  /// Read-only viewer
  viewer;

  /// Get display name for the role
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
      return 'Super Admin';
    case UserRole.admin:
      return 'Administrator';
    case UserRole.developer:
      return 'Developer';
    case UserRole.manager:
      return 'Manager';
    case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.employee:
        return 'Employee';
      case UserRole.maintenance:
        return 'Maintenance';
      case UserRole.techSupport:
        return 'Tech Support';
      case UserRole.client:
        return 'Client';
      case UserRole.vendor:
        return 'Vendor';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  /// Check if role has administrative privileges
  bool get isAdmin =>
      this == UserRole.superAdmin ||
      this == UserRole.admin ||
      this == UserRole.developer;

  /// Check if role can view across organizations.
  bool get canViewAcrossOrgs =>
      this == UserRole.developer || this == UserRole.techSupport;

  /// Check if role has management privileges
  bool get canManage => isAdmin || this == UserRole.manager;

  /// Check if role has supervisor privileges
  bool get canSupervise => canManage || this == UserRole.supervisor;

  /// Check if role can access the admin console
  bool get canAccessAdminConsole =>
      isAdmin || this == UserRole.manager || this == UserRole.supervisor;

  /// Check if role is a platform-level role (cross-org capable)
  bool get isPlatformRole =>
      this == UserRole.developer || this == UserRole.techSupport;

  /// Check if role is an org-level role (bound to a single organization)
  bool get isOrgRole => !isPlatformRole;

  /// Roles that a SuperAdmin (org owner) can assign within their organization.
  /// Excludes platform roles (developer, techSupport) and superAdmin (only one per org).
  static List<UserRole> get superAdminAssignableRoles => const [
    UserRole.admin,
    UserRole.manager,
    UserRole.supervisor,
    UserRole.employee,
    UserRole.maintenance,
    UserRole.client,
    UserRole.vendor,
    UserRole.viewer,
  ];

  /// Roles that an Admin can assign (excludes admin-level and above).
  static List<UserRole> get adminAssignableRoles => const [
    UserRole.manager,
    UserRole.supervisor,
    UserRole.employee,
    UserRole.maintenance,
    UserRole.client,
    UserRole.vendor,
    UserRole.viewer,
  ];

  static UserRole fromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) return UserRole.viewer;
    final normalized = raw.replaceAll('_', '').replaceAll('-', '').toLowerCase();
    switch (normalized) {
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'developer':
        return UserRole.developer;
      case 'manager':
        return UserRole.manager;
      case 'supervisor':
        return UserRole.supervisor;
      case 'employee':
        return UserRole.employee;
      case 'maintenance':
        return UserRole.maintenance;
      case 'techsupport':
        return UserRole.techSupport;
      case 'client':
        return UserRole.client;
      case 'vendor':
        return UserRole.vendor;
      case 'viewer':
      default:
        return UserRole.viewer;
    }
  }
}
