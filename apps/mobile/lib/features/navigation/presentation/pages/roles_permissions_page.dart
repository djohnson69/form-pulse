import 'package:flutter/material.dart';

class RolesPermissionsPage extends StatefulWidget {
  const RolesPermissionsPage({super.key});

  @override
  State<RolesPermissionsPage> createState() => _RolesPermissionsPageState();
}

class _RolesPermissionsPageState extends State<RolesPermissionsPage> {
  late final List<_PermissionCategory> _categories;
  late List<_RoleDefinition> _roles;
  final Set<String> _expandedCategories = {'time-tracking'};
  String? _editingRoleId;

  @override
  void initState() {
    super.initState();
    _categories = _buildCategories();
    _roles = _buildDefaultRoles();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final headerIconColor =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    return Scaffold(
      backgroundColor: background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;
          final paddingValue = isWide ? 24.0 : 16.0;
          final maxWidth =
              constraints.maxWidth > 1280 ? 1280.0 : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.all(paddingValue),
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield, size: 32, color: headerIconColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Roles & Permissions',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: isWide ? 30 : 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage user roles and configure granular permissions for your organization.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: isWide ? 16 : 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildRolesGrid(context),
                  const SizedBox(height: 32),
                  _buildPermissionMatrix(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRolesGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth >= 1024;
        final cards = [
          ..._roles.map(
            (role) => _RoleCard(
              role: role,
              isEditing: _editingRoleId == role.id,
              categories: _categories,
              onEdit: () => setState(() => _editingRoleId = role.id),
              onSave: () => setState(() => _editingRoleId = null),
              onDuplicate: () => _duplicateRole(role.id),
              onDelete: () => _deleteRole(role.id),
              onUpdateName: (value) => _updateRoleName(role.id, value),
              onUpdateDescription: (value) =>
                  _updateRoleDescription(role.id, value),
            ),
          ),
          _CreateRoleCard(onTap: _createRole),
        ];

        if (!isTwoColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 24),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < cards.length; i += 2) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 24),
                Expanded(
                  child: i + 1 < cards.length
                      ? cards[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
          if (i + 2 < cards.length) {
            rows.add(const SizedBox(height: 24));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }

  Widget _buildPermissionMatrix(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final matrixBackground =
        isDark ? const Color(0xFF1F2937) : Colors.white;
    final expandedBackground =
        isDark ? const Color(0xFF2A3444) : const Color(0xFFF9FAFB);
    final hoverBackground = expandedBackground;
    return Container(
      decoration: BoxDecoration(
        color: matrixBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Permission Matrix',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Text(
              'Configure granular permissions for each role.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          const Divider(height: 1),
          ..._categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final isExpanded = _expandedCategories.contains(category.id);
            return Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedCategories.remove(category.id);
                      } else {
                        _expandedCategories.add(category.id);
                      }
                    });
                  },
                  hoverColor: hoverBackground,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E3A8A)
                                    .withValues(alpha: 0.3)
                                : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            category.icon,
                            size: 20,
                            color: isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                category.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${category.permissions.length} permissions',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  Container(
                    width: double.infinity,
                    color: expandedBackground,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _PermissionMatrixTable(
                            category: category,
                            roles: _roles,
                            onToggle: _togglePermission,
                            isDark: isDark,
                            viewportWidth: constraints.maxWidth,
                          ),
                        );
                      },
                    ),
                  ),
                if (index != _categories.length - 1)
                  Divider(height: 1, color: border),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _togglePermission(String roleId, String permissionKey) {
    setState(() {
      _roles = _roles.map((role) {
        if (role.id != roleId) return role;
        final hasPermission = role.permissions.contains(permissionKey);
        final updated = hasPermission
            ? role.permissions.where((p) => p != permissionKey).toList()
            : [...role.permissions, permissionKey];
        return role.copyWith(permissions: updated);
      }).toList();
    });
  }

  void _duplicateRole(String roleId) {
    final role = _roles.firstWhere((r) => r.id == roleId);
    final copy = role.copyWith(
      id: '${role.id}-copy-${DateTime.now().millisecondsSinceEpoch}',
      name: '${role.name} (Copy)',
      isCustom: true,
      userCount: 0,
    );
    setState(() {
      _roles = [..._roles, copy];
      _editingRoleId = copy.id;
    });
  }

  void _deleteRole(String roleId) {
    final role = _roles.firstWhere((r) => r.id == roleId);
    if (!role.isCustom) {
      _showMessage('Default roles cannot be deleted.');
      return;
    }
    if (role.userCount > 0) {
      _showMessage('Cannot delete roles with assigned users.');
      return;
    }
    setState(() {
      _roles = _roles.where((r) => r.id != roleId).toList();
      if (_editingRoleId == roleId) {
        _editingRoleId = null;
      }
    });
  }

  void _createRole() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final role = _RoleDefinition(
      id: 'custom-$now',
      name: 'New Role',
      description: 'Custom role description',
      color: Colors.blue,
      userCount: 0,
      isCustom: true,
      permissions: const [],
    );
    setState(() {
      _roles = [..._roles, role];
      _editingRoleId = role.id;
    });
  }

  void _updateRoleName(String roleId, String name) {
    setState(() {
      _roles = _roles.map((role) {
        return role.id == roleId ? role.copyWith(name: name) : role;
      }).toList();
    });
  }

  void _updateRoleDescription(String roleId, String description) {
    setState(() {
      _roles = _roles.map((role) {
        return role.id == roleId
            ? role.copyWith(description: description)
            : role;
      }).toList();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<_PermissionCategory> _buildCategories() {
    return [
      _PermissionCategory(
        id: 'time-tracking',
        name: 'Time Tracking',
        description: 'Clock in/out, timesheets, and payroll',
        icon: Icons.schedule,
        permissions: const [
          _PermissionItem(
            id: 'clock-in-out',
            label: 'Clock In/Out',
            key: 'canClockInOut',
          ),
          _PermissionItem(
            id: 'view-timesheets',
            label: 'View Own Timesheets',
            key: 'canViewTimesheets',
          ),
          _PermissionItem(
            id: 'submit-timesheets',
            label: 'Submit Timesheets',
            key: 'canSubmitTimesheets',
          ),
          _PermissionItem(
            id: 'approve-timesheets',
            label: 'Approve Timesheets',
            key: 'canApproveTimesheets',
          ),
          _PermissionItem(
            id: 'manage-payroll',
            label: 'Manage Payroll',
            key: 'canManagePayroll',
          ),
        ],
      ),
      _PermissionCategory(
        id: 'tasks-projects',
        name: 'Tasks & Projects',
        description: 'Task management and project oversight',
        icon: Icons.checklist,
        permissions: const [
          _PermissionItem(
            id: 'view-tasks',
            label: 'View Own Tasks',
            key: 'canViewTasks',
          ),
          _PermissionItem(
            id: 'create-tasks',
            label: 'Create Tasks',
            key: 'canCreateTasks',
          ),
          _PermissionItem(
            id: 'assign-tasks',
            label: 'Assign Tasks to Others',
            key: 'canAssignTasks',
          ),
          _PermissionItem(
            id: 'approve-tasks',
            label: 'Approve Tasks',
            key: 'canApproveTasks',
          ),
          _PermissionItem(
            id: 'view-all-projects',
            label: 'View All Projects',
            key: 'canViewAllProjects',
          ),
          _PermissionItem(
            id: 'manage-projects',
            label: 'Manage Projects',
            key: 'canManageProjects',
          ),
        ],
      ),
      _PermissionCategory(
        id: 'documents',
        name: 'Documents & Files',
        description: 'Document access and management',
        icon: Icons.description,
        permissions: const [
          _PermissionItem(
            id: 'view-documents',
            label: 'View Documents',
            key: 'canViewDocuments',
          ),
          _PermissionItem(
            id: 'upload-documents',
            label: 'Upload Documents',
            key: 'canUploadDocuments',
          ),
          _PermissionItem(
            id: 'manage-documents',
            label: 'Manage All Documents',
            key: 'canManageDocuments',
          ),
          _PermissionItem(
            id: 'approve-documents',
            label: 'Approve Documents',
            key: 'canApproveDocuments',
          ),
        ],
      ),
      _PermissionCategory(
        id: 'incidents-safety',
        name: 'Incidents & Safety',
        description: 'Safety reporting and incident management',
        icon: Icons.warning_amber,
        permissions: const [
          _PermissionItem(
            id: 'report-incidents',
            label: 'Report Incidents',
            key: 'canReportIncidents',
          ),
          _PermissionItem(
            id: 'view-incidents',
            label: 'View Incidents',
            key: 'canViewIncidents',
          ),
          _PermissionItem(
            id: 'manage-incidents',
            label: 'Manage & Investigate',
            key: 'canManageIncidents',
          ),
          _PermissionItem(
            id: 'approve-incidents',
            label: 'Approve & Close',
            key: 'canApproveIncidents',
          ),
        ],
      ),
      _PermissionCategory(
        id: 'assets-inventory',
        name: 'Assets & Inventory',
        description: 'Equipment and inventory tracking',
        icon: Icons.inventory_2,
        permissions: const [
          _PermissionItem(
            id: 'view-assets',
            label: 'View Assets',
            key: 'canViewAssets',
          ),
          _PermissionItem(
            id: 'checkout-assets',
            label: 'Check Out Assets',
            key: 'canCheckoutAssets',
          ),
          _PermissionItem(
            id: 'manage-assets',
            label: 'Manage Assets',
            key: 'canManageAssets',
          ),
          _PermissionItem(
            id: 'approve-asset-requests',
            label: 'Approve Requests',
            key: 'canApproveAssetRequests',
          ),
        ],
      ),
      _PermissionCategory(
        id: 'training',
        name: 'Training & Certifications',
        description: 'Training programs and certifications',
        icon: Icons.school,
        permissions: const [
          _PermissionItem(
            id: 'view-training',
            label: 'View Training',
            key: 'canViewTraining',
          ),
          _PermissionItem(
            id: 'complete-training',
            label: 'Complete Training',
            key: 'canCompleteTraining',
          ),
          _PermissionItem(
            id: 'assign-training',
            label: 'Assign Training',
            key: 'canAssignTraining',
          ),
          _PermissionItem(
            id: 'manage-training',
            label: 'Manage Training Programs',
            key: 'canManageTraining',
          ),
        ],
      ),
      _PermissionCategory(
        id: 'messaging',
        name: 'Messaging & Communication',
        description: 'Internal messaging and announcements',
        icon: Icons.message,
        permissions: const [
          _PermissionItem(
            id: 'send-messages',
            label: 'Send Messages',
            key: 'canSendMessages',
          ),
          _PermissionItem(
            id: 'view-company-news',
            label: 'View Company News',
            key: 'canViewCompanyNews',
          ),
          _PermissionItem(
            id: 'post-announcements',
            label: 'Post Announcements',
            key: 'canPostAnnouncements',
          ),
          _PermissionItem(
            id: 'manage-communications',
            label: 'Manage All Communications',
            key: 'canManageCommunications',
          ),
        ],
      ),
      _PermissionCategory(
        id: 'analytics',
        name: 'Analytics & Reports',
        description: 'Data analytics and reporting',
        icon: Icons.analytics,
        permissions: const [
          _PermissionItem(
            id: 'view-own-analytics',
            label: 'View Own Analytics',
            key: 'canViewOwnAnalytics',
          ),
          _PermissionItem(
            id: 'view-team-analytics',
            label: 'View Team Analytics',
            key: 'canViewTeamAnalytics',
          ),
          _PermissionItem(
            id: 'view-all-analytics',
            label: 'View All Analytics',
            key: 'canViewAllAnalytics',
          ),
          _PermissionItem(
            id: 'export-reports',
            label: 'Export Reports',
            key: 'canExportReports',
          ),
        ],
      ),
      _PermissionCategory(
        id: 'user-management',
        name: 'User Management',
        description: 'Manage users and teams',
        icon: Icons.people,
        permissions: const [
          _PermissionItem(
            id: 'view-users',
            label: 'View Users',
            key: 'canViewUsers',
          ),
          _PermissionItem(
            id: 'add-users',
            label: 'Add Users',
            key: 'canAddUsers',
          ),
          _PermissionItem(
            id: 'edit-users',
            label: 'Edit Users',
            key: 'canEditUsers',
          ),
          _PermissionItem(
            id: 'deactivate-users',
            label: 'Deactivate Users',
            key: 'canDeactivateUsers',
          ),
          _PermissionItem(
            id: 'manage-teams',
            label: 'Manage Team Structure',
            key: 'canManageTeams',
          ),
        ],
      ),
      _PermissionCategory(
        id: 'system-settings',
        name: 'System Settings',
        description: 'System configuration and roles',
        icon: Icons.settings,
        permissions: const [
          _PermissionItem(
            id: 'view-settings',
            label: 'View Settings',
            key: 'canViewSettings',
          ),
          _PermissionItem(
            id: 'manage-roles',
            label: 'Manage Roles & Permissions',
            key: 'canManageRoles',
          ),
          _PermissionItem(
            id: 'system-config',
            label: 'System Configuration',
            key: 'canSystemConfig',
          ),
          _PermissionItem(
            id: 'billing-access',
            label: 'Billing & Subscription',
            key: 'canAccessBilling',
          ),
        ],
      ),
    ];
  }

  List<_RoleDefinition> _buildDefaultRoles() {
    final allPermissions = _categories
        .expand((category) => category.permissions)
        .map((permission) => permission.key)
        .toSet()
        .toList();
    return [
      _RoleDefinition(
        id: 'employee',
        name: 'Employee',
        description: 'Standard employee with basic access',
        color: Colors.blue,
        userCount: 45,
        isCustom: false,
        permissions: const [
          'canClockInOut',
          'canViewTimesheets',
          'canSubmitTimesheets',
          'canViewTasks',
          'canViewDocuments',
          'canReportIncidents',
          'canViewAssets',
          'canCheckoutAssets',
          'canViewTraining',
          'canCompleteTraining',
          'canSendMessages',
          'canViewCompanyNews',
          'canViewOwnAnalytics',
        ],
      ),
      _RoleDefinition(
        id: 'supervisor',
        name: 'Supervisor',
        description: 'Team lead with approval permissions',
        color: Colors.purple,
        userCount: 8,
        isCustom: false,
        permissions: const [
          'canClockInOut',
          'canViewTimesheets',
          'canSubmitTimesheets',
          'canApproveTimesheets',
          'canViewTasks',
          'canCreateTasks',
          'canAssignTasks',
          'canApproveTasks',
          'canViewDocuments',
          'canUploadDocuments',
          'canReportIncidents',
          'canViewIncidents',
          'canManageIncidents',
          'canViewAssets',
          'canCheckoutAssets',
          'canApproveAssetRequests',
          'canViewTraining',
          'canCompleteTraining',
          'canAssignTraining',
          'canSendMessages',
          'canViewCompanyNews',
          'canPostAnnouncements',
          'canViewTeamAnalytics',
          'canViewUsers',
        ],
      ),
      _RoleDefinition(
        id: 'manager',
        name: 'Manager',
        description: 'Department manager with full team oversight',
        color: Colors.green,
        userCount: 3,
        isCustom: false,
        permissions: const [
          'canClockInOut',
          'canViewTimesheets',
          'canSubmitTimesheets',
          'canApproveTimesheets',
          'canViewTasks',
          'canCreateTasks',
          'canAssignTasks',
          'canApproveTasks',
          'canViewAllProjects',
          'canManageProjects',
          'canViewDocuments',
          'canUploadDocuments',
          'canManageDocuments',
          'canReportIncidents',
          'canViewIncidents',
          'canManageIncidents',
          'canApproveIncidents',
          'canViewAssets',
          'canCheckoutAssets',
          'canManageAssets',
          'canApproveAssetRequests',
          'canViewTraining',
          'canCompleteTraining',
          'canAssignTraining',
          'canManageTraining',
          'canSendMessages',
          'canViewCompanyNews',
          'canPostAnnouncements',
          'canManageCommunications',
          'canViewAllAnalytics',
          'canExportReports',
          'canViewUsers',
          'canAddUsers',
          'canEditUsers',
          'canManageTeams',
        ],
      ),
      _RoleDefinition(
        id: 'admin',
        name: 'Admin',
        description: 'Administrative role with payroll access',
        color: Colors.orange,
        userCount: 2,
        isCustom: false,
        permissions: const [
          'canClockInOut',
          'canViewTimesheets',
          'canSubmitTimesheets',
          'canApproveTimesheets',
          'canManagePayroll',
          'canViewTasks',
          'canCreateTasks',
          'canViewAllProjects',
          'canViewDocuments',
          'canUploadDocuments',
          'canManageDocuments',
          'canApproveDocuments',
          'canViewIncidents',
          'canManageIncidents',
          'canViewAssets',
          'canManageAssets',
          'canViewTraining',
          'canManageTraining',
          'canSendMessages',
          'canViewCompanyNews',
          'canPostAnnouncements',
          'canViewAllAnalytics',
          'canExportReports',
          'canViewUsers',
          'canAddUsers',
          'canEditUsers',
          'canDeactivateUsers',
        ],
      ),
      _RoleDefinition(
        id: 'tech-support',
        name: 'Tech Support',
        description: 'Technical support and system access',
        color: Colors.cyan,
        userCount: 2,
        isCustom: false,
        permissions: const [
          'canViewUsers',
          'canEditUsers',
          'canViewDocuments',
          'canManageDocuments',
          'canViewAssets',
          'canManageAssets',
          'canViewTraining',
          'canManageTraining',
          'canViewAllAnalytics',
          'canViewSettings',
        ],
      ),
      _RoleDefinition(
        id: 'maintenance',
        name: 'Maintenance',
        description: 'Maintenance and facilities staff',
        color: Colors.yellow,
        userCount: 6,
        isCustom: false,
        permissions: const [
          'canClockInOut',
          'canViewTimesheets',
          'canSubmitTimesheets',
          'canViewTasks',
          'canViewDocuments',
          'canUploadDocuments',
          'canReportIncidents',
          'canViewIncidents',
          'canViewAssets',
          'canCheckoutAssets',
          'canManageAssets',
          'canViewTraining',
          'canCompleteTraining',
          'canSendMessages',
          'canViewCompanyNews',
        ],
      ),
      _RoleDefinition(
        id: 'superadmin',
        name: 'Super Admin',
        description: 'Full system access and control',
        color: Colors.red,
        userCount: 1,
        isCustom: false,
        permissions: allPermissions,
      ),
    ];
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.isEditing,
    required this.categories,
    required this.onEdit,
    required this.onSave,
    required this.onDuplicate,
    required this.onDelete,
    required this.onUpdateName,
    required this.onUpdateDescription,
  });

  final _RoleDefinition role;
  final bool isEditing;
  final List<_PermissionCategory> categories;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<String> onUpdateName;
  final ValueChanged<String> onUpdateDescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tone = _RoleTone.fromColor(role.color, isDark);
    final cardBorder =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final cardBackground =
        isDark ? const Color(0xFF1F2937) : Colors.white;
    final actionHover =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final actionIcon =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final saveIcon =
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    final deleteIcon =
        isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    final disabledIcon =
        isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final inputDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF111827) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6),
        ),
      ),
    );
    final customBadge = _BadgeTone(
      background: isDark
          ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
          : const Color(0xFFDBEAFE),
      text: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tone.border),
                  ),
                  child: Icon(Icons.shield, size: 24, color: tone.text),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isEditing)
                        TextFormField(
                          initialValue: role.name,
                          onChanged: onUpdateName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          decoration: inputDecoration,
                        )
                      else
                        Text(
                          role.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (isEditing)
                        TextFormField(
                          initialValue: role.description,
                          minLines: 2,
                          maxLines: 3,
                          onChanged: onUpdateDescription,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          decoration: inputDecoration,
                        )
                      else
                        Text(
                          role.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${role.userCount} ${role.userCount == 1 ? 'user' : 'users'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (role.isCustom)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: customBadge.background,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Custom',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: customBadge.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      icon: Icon(
                        isEditing ? Icons.save : Icons.edit,
                        size: 16,
                      ),
                      color: isEditing ? saveIcon : actionIcon,
                      hoverColor: actionHover,
                      onPressed: isEditing ? onSave : onEdit,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      color: actionIcon,
                      hoverColor: actionHover,
                      onPressed: onDuplicate,
                    ),
                    if (role.isCustom)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        color: deleteIcon,
                        hoverColor: actionHover,
                        disabledColor: disabledIcon,
                        onPressed: role.userCount > 0 ? null : onDelete,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: cardBorder),
            const SizedBox(height: 12),
            Text(
              'Permissions (${role.permissions.length})',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            ...categories.map((category) {
              final count = category.permissions
                  .where((permission) => role.permissions.contains(permission.key))
                  .length;
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(category.icon, size: 16, color: scheme.onSurface),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${category.name}: $count/${category.permissions.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RoleTone {
  const _RoleTone({
    required this.background,
    required this.text,
    required this.border,
  });

  final Color background;
  final Color text;
  final Color border;

  static _RoleTone fromColor(Color color, bool isDark) {
    switch (color.value) {
      case 0xFF2196F3: // blue
        return _RoleTone(
          background: isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
              : const Color(0xFFDBEAFE),
          text: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
          border: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE),
        );
      case 0xFF9C27B0: // purple
        return _RoleTone(
          background: isDark
              ? const Color(0xFF581C87).withValues(alpha: 0.3)
              : const Color(0xFFF3E8FF),
          text: isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
          border: isDark ? const Color(0xFF7E22CE) : const Color(0xFFE9D5FF),
        );
      case 0xFF4CAF50: // green
        return _RoleTone(
          background: isDark
              ? const Color(0xFF14532D).withValues(alpha: 0.3)
              : const Color(0xFFDCFCE7),
          text: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
          border: isDark ? const Color(0xFF15803D) : const Color(0xFFBBF7D0),
        );
      case 0xFFFF9800: // orange
        return _RoleTone(
          background: isDark
              ? const Color(0xFF7C2D12).withValues(alpha: 0.3)
              : const Color(0xFFFFEDD5),
          text: isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C),
          border: isDark ? const Color(0xFFC2410C) : const Color(0xFFFED7AA),
        );
      case 0xFFF44336: // red
        return _RoleTone(
          background: isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
              : const Color(0xFFFEE2E2),
          text: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
          border: isDark ? const Color(0xFFB91C1C) : const Color(0xFFFECACA),
        );
      case 0xFF00BCD4: // cyan
        return _RoleTone(
          background: isDark
              ? const Color(0xFF164E63).withValues(alpha: 0.3)
              : const Color(0xFFCFFAFE),
          text: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490),
          border: isDark ? const Color(0xFF0E7490) : const Color(0xFFA5F3FC),
        );
      case 0xFFFFEB3B: // yellow
        return _RoleTone(
          background: isDark
              ? const Color(0xFF713F12).withValues(alpha: 0.3)
              : const Color(0xFFFEF9C3),
          text: isDark ? const Color(0xFFFACC15) : const Color(0xFFA16207),
          border: isDark ? const Color(0xFFA16207) : const Color(0xFFFEF08A),
        );
      default:
        return _RoleTone(
          background: isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
              : const Color(0xFFDBEAFE),
          text: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
          border: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE),
        );
    }
  }
}

class _BadgeTone {
  const _BadgeTone({required this.background, required this.text});

  final Color background;
  final Color text;
}

class _CreateRoleCard extends StatefulWidget {
  const _CreateRoleCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CreateRoleCard> createState() => _CreateRoleCardState();
}

class _CreateRoleCardState extends State<_CreateRoleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseBorder =
        isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final hoverBorder =
        isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6);
    final borderColor = _isHovered ? hoverBorder : baseBorder;
    final backgroundColor = _isHovered
        ? isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.1)
            : const Color(0xFFEFF6FF)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: _DashedBorder(
        color: borderColor,
        radius: 12,
        child: Material(
          color: backgroundColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 280),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 24,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create New Role',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a custom role',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends StatelessWidget {
  const _DashedBorder({
    required this.color,
    required this.radius,
    required this.child,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final extract = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _PermissionMatrixTable extends StatelessWidget {
  const _PermissionMatrixTable({
    required this.category,
    required this.roles,
    required this.onToggle,
    required this.isDark,
    required this.viewportWidth,
  });

  final _PermissionCategory category;
  final List<_RoleDefinition> roles;
  final void Function(String roleId, String permissionKey) onToggle;
  final bool isDark;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final headerText =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final bodyText =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    const roleColumnWidth = 96.0;
    const permissionMinWidth = 240.0;
    final minWidth = roles.length * roleColumnWidth + permissionMinWidth;
    final safeViewportWidth = viewportWidth.isFinite ? viewportWidth : minWidth;
    final tableWidth =
        minWidth < safeViewportWidth ? safeViewportWidth : minWidth;
    return SizedBox(
      width: tableWidth,
      child: Column(
        children: [
          _MatrixRow(
            border: border,
            children: [
              Expanded(
                child: _MatrixCell(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Permission',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: headerText,
                    ),
                  ),
                ),
              ),
              ...roles.map(
                (role) => SizedBox(
                  width: roleColumnWidth,
                  child: _MatrixCell(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        role.name,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: headerText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ...category.permissions.map((permission) {
            return _MatrixRow(
              border: border,
              children: [
                Expanded(
                  child: _MatrixCell(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      permission.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 14,
                        color: bodyText,
                      ),
                    ),
                  ),
                ),
                ...roles.map((role) {
                  final enabled = role.permissions.contains(permission.key);
                  return SizedBox(
                    width: roleColumnWidth,
                    child: _MatrixCell(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      alignment: Alignment.center,
                      child: _PermissionToggle(
                        enabled: enabled,
                        isDark: isDark,
                        onTap: () => onToggle(role.id, permission.key),
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MatrixRow extends StatelessWidget {
  const _MatrixRow({
    required this.children,
    required this.border,
  });

  final List<Widget> children;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({
    required this.child,
    required this.padding,
    this.alignment,
  });

  final Widget child;
  final EdgeInsets padding;
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: alignment ?? Alignment.centerLeft,
        child: child,
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({
    required this.enabled,
    required this.onTap,
    required this.isDark,
  });

  final bool enabled;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6);
    final inactiveColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final iconColor = enabled
        ? Colors.white
        : isDark
            ? const Color(0xFF6B7280)
            : const Color(0xFF9CA3AF);
    final hoverOverlay = enabled
        ? isDark
            ? const Color(0xFF1D4ED8)
            : const Color(0xFF2563EB)
        : isDark
            ? const Color(0xFF4B5563)
            : const Color(0xFFD1D5DB);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: hoverOverlay.withOpacity(0.2),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: enabled ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(
            enabled ? Icons.check : Icons.crop_square_rounded,
            size: 16,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

class _PermissionCategory {
  const _PermissionCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.permissions,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<_PermissionItem> permissions;
}

class _PermissionItem {
  const _PermissionItem({
    required this.id,
    required this.label,
    required this.key,
  });

  final String id;
  final String label;
  final String key;
}

class _RoleDefinition {
  const _RoleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.userCount,
    required this.isCustom,
    required this.permissions,
  });

  final String id;
  final String name;
  final String description;
  final Color color;
  final int userCount;
  final bool isCustom;
  final List<String> permissions;

  _RoleDefinition copyWith({
    String? id,
    String? name,
    String? description,
    Color? color,
    int? userCount,
    bool? isCustom,
    List<String>? permissions,
  }) {
    return _RoleDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      userCount: userCount ?? this.userCount,
      isCustom: isCustom ?? this.isCustom,
      permissions: permissions ?? this.permissions,
    );
  }
}
