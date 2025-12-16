/// User role enumeration for access control
enum UserRole {
  /// Super administrator with full system access
  superAdmin,
  
  /// Company administrator
  admin,
  
  /// Site manager with limited administrative access
  manager,
  
  /// Standard employee user
  employee,
  
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
      case UserRole.manager:
        return 'Manager';
      case UserRole.employee:
        return 'Employee';
      case UserRole.client:
        return 'Client';
      case UserRole.vendor:
        return 'Vendor';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  /// Check if role has administrative privileges
  bool get isAdmin => this == UserRole.superAdmin || this == UserRole.admin;

  /// Check if role has management privileges
  bool get canManage => isAdmin || this == UserRole.manager;
}
