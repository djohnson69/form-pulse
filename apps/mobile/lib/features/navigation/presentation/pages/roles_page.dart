import 'package:flutter/material.dart';

import 'role_customization_page.dart';

class RolesPage extends StatefulWidget {
  const RolesPage({super.key});

  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> {
  final List<_RoleSummary> _roles = [
    _RoleSummary(
      id: 'employee',
      name: 'Employee',
      description: 'Basic field worker with limited access',
      userCount: 180,
      color: const Color(0xFF2563EB),
    ),
    _RoleSummary(
      id: 'supervisor',
      name: 'Supervisor',
      description: 'Team leader who manages employees',
      userCount: 35,
      color: const Color(0xFF7C3AED),
    ),
    _RoleSummary(
      id: 'manager',
      name: 'Manager',
      description: 'Oversees multiple supervisors and projects',
      userCount: 20,
      color: const Color(0xFF16A34A),
    ),
    _RoleSummary(
      id: 'maintenance',
      name: 'Maintenance',
      description: 'Equipment maintenance and repair specialists',
      userCount: 15,
      color: const Color(0xFFF97316),
    ),
    _RoleSummary(
      id: 'admin',
      name: 'Admin',
      description: 'System administrator with full user management',
      userCount: 10,
      color: const Color(0xFFDC2626),
    ),
    _RoleSummary(
      id: 'techsupport',
      name: 'Tech Support',
      description: 'Technical support staff',
      userCount: 5,
      color: const Color(0xFF6366F1),
    ),
    _RoleSummary(
      id: 'superadmin',
      name: 'Super Admin',
      description: 'Full system access and control',
      userCount: 2,
      color: const Color(0xFFEC4899),
    ),
  ];

  final List<_Permission> _permissions = const [
    _Permission(id: 'viewDashboard', label: 'View Dashboard', category: 'General'),
    _Permission(id: 'manageTasks', label: 'Manage Tasks', category: 'Tasks'),
    _Permission(id: 'assignTasks', label: 'Assign Tasks', category: 'Tasks'),
    _Permission(id: 'manageUsers', label: 'Manage Users', category: 'Users'),
    _Permission(id: 'viewTeam', label: 'View Team', category: 'Users'),
    _Permission(
      id: 'manageDocuments',
      label: 'Manage Documents',
      category: 'Documents',
    ),
    _Permission(id: 'manageAssets', label: 'Manage Assets', category: 'Assets'),
    _Permission(id: 'manageTraining', label: 'Manage Training', category: 'Training'),
    _Permission(id: 'manageForms', label: 'Manage Forms', category: 'Forms'),
    _Permission(id: 'approveReports', label: 'Approve Reports', category: 'Reports'),
    _Permission(id: 'viewAnalytics', label: 'View Analytics', category: 'Analytics'),
    _Permission(
      id: 'manageRoles',
      label: 'Manage Roles',
      category: 'Administration',
    ),
    _Permission(
      id: 'manageIncidents',
      label: 'Manage Incidents',
      category: 'Incidents',
    ),
    _Permission(
      id: 'manageProjects',
      label: 'Manage Projects',
      category: 'Projects',
    ),
    _Permission(
      id: 'systemAccess',
      label: 'System Access',
      category: 'Administration',
    ),
    _Permission(
      id: 'techSupport',
      label: 'Tech Support',
      category: 'Support',
    ),
  ];

  final Map<String, List<String>> _rolePermissions = const {
    'employee': [
      'viewDashboard',
      'manageDocuments',
      'manageAssets',
      'manageTraining',
    ],
    'supervisor': [
      'viewDashboard',
      'manageTasks',
      'assignTasks',
      'viewTeam',
      'manageDocuments',
      'manageAssets',
      'manageTraining',
      'manageForms',
      'approveReports',
      'viewAnalytics',
      'manageIncidents',
    ],
    'manager': [
      'viewDashboard',
      'manageTasks',
      'assignTasks',
      'manageUsers',
      'viewTeam',
      'manageDocuments',
      'manageAssets',
      'manageTraining',
      'manageForms',
      'approveReports',
      'viewAnalytics',
      'manageIncidents',
      'manageProjects',
    ],
    'maintenance': [
      'viewDashboard',
      'manageAssets',
      'manageTraining',
    ],
    'admin': [
      'viewDashboard',
      'manageTasks',
      'assignTasks',
      'manageUsers',
      'viewTeam',
      'manageDocuments',
      'manageAssets',
      'manageTraining',
      'manageForms',
      'approveReports',
      'viewAnalytics',
      'manageRoles',
      'manageIncidents',
      'manageProjects',
    ],
    'techsupport': [
      'viewDashboard',
      'manageDocuments',
      'manageAssets',
      'viewAnalytics',
      'manageIncidents',
      'techSupport',
    ],
    'superadmin': [
      'viewDashboard',
      'manageTasks',
      'assignTasks',
      'manageUsers',
      'viewTeam',
      'manageDocuments',
      'manageAssets',
      'manageTraining',
      'manageForms',
      'approveReports',
      'viewAnalytics',
      'manageRoles',
      'manageIncidents',
      'manageProjects',
      'systemAccess',
      'techSupport',
    ],
  };

  String _selectedRoleId = 'employee';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories = _permissions
        .map((permission) => permission.category)
        .toSet()
        .toList();
    final selectedRole =
        _roles.firstWhere((role) => role.id == _selectedRoleId);
    final selectedPermissions = _rolePermissions[_selectedRoleId] ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Roles & Permissions')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(context, isDark),
                  const SizedBox(height: 16),
                  _buildMainGrid(
                    context,
                    isDark,
                    categories,
                    selectedRole,
                    selectedPermissions,
                  ),
                  const SizedBox(height: 16),
                  _buildStatsGrid(context),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Roles & Permissions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage user roles and their access permissions',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RoleCustomizationPage()),
            );
          },
          icon: const Icon(Icons.settings_outlined, size: 20),
          label: const Text('Customize Role Names'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          onPressed: () {},
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Create New Role'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 12),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildMainGrid(
    BuildContext context,
    bool isDark,
    List<String> categories,
    _RoleSummary selectedRole,
    List<String> selectedPermissions,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final rolesCard = _buildRolesCard(context, isDark);
        final permissionsCard = _buildPermissionsCard(
          context,
          isDark,
          categories,
          selectedRole,
          selectedPermissions,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: rolesCard),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: permissionsCard),
            ],
          );
        }
        return Column(
          children: [
            rolesCard,
            const SizedBox(height: 16),
            permissionsCard,
          ],
        );
      },
    );
  }

  Widget _buildRolesCard(BuildContext context, bool isDark) {
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Roles',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          ..._roles.map((role) {
            final isSelected = role.id == _selectedRoleId;
            final backgroundColor = isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB));
            final textColor = isSelected ? Colors.white : null;
            return GestureDetector(
              onTap: () => setState(() => _selectedRoleId = role.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          role.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : (isDark
                                    ? const Color(0xFF374151)
                                    : const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            role.userCount.toString(),
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700]),
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      role.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? const Color(0xFFDBEAFE)
                                : (isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600]),
                          ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(
    BuildContext context,
    bool isDark,
    List<String> categories,
    _RoleSummary selectedRole,
    List<String> selectedPermissions,
  ) {
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selectedRole.name} Permissions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${selectedPermissions.length} permissions granted',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Changes saved.')),
                  );
                },
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save Changes'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...categories.map((category) {
            final categoryPermissions = _permissions
                .where((permission) => permission.category == category)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                ...categoryPermissions.map((permission) {
                  final isGranted =
                      selectedPermissions.contains(permission.id);
                  final boxColor = isGranted
                      ? const Color(0xFF2563EB)
                      : Colors.transparent;
                  final border = isGranted
                      ? const Color(0xFF2563EB)
                      : (isDark
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFD1D5DB));
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                      color: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF9FAFB),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: boxColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: border, width: 2),
                          ),
                          child: isGranted
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            permission.label,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.grey[200]
                                          : Colors.grey[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840 ? 3 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 3.4 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _GradientStatCard(
              title: 'Total Users',
              value: '247',
              icon: Icons.people_outline,
              gradient: LinearGradient(
                colors: [Color(0xFFDBEAFE), Color(0xFFE0E7FF)],
              ),
              iconColor: Color(0xFF2563EB),
            ),
            _GradientStatCard(
              title: 'System Roles',
              value: '6',
              icon: Icons.shield_outlined,
              gradient: LinearGradient(
                colors: [Color(0xFFF3E8FF), Color(0xFFFCE7F3)],
              ),
              iconColor: Color(0xFF7C3AED),
            ),
            _GradientStatCard(
              title: 'Permissions',
              value: '16',
              icon: Icons.lock_outline,
              gradient: LinearGradient(
                colors: [Color(0xFFDCFCE7), Color(0xFFD1FAE5)],
              ),
              iconColor: Color(0xFF16A34A),
            ),
          ],
        );
      },
    );
  }
}

class _RoleSummary {
  const _RoleSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.userCount,
    required this.color,
  });

  final String id;
  final String name;
  final String description;
  final int userCount;
  final Color color;
}

class _Permission {
  const _Permission({
    required this.id,
    required this.label,
    required this.category,
  });

  final String id;
  final String label;
  final String category;
}

class _GradientStatCard extends StatelessWidget {
  const _GradientStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                colors: [
                  iconColor.withOpacity(0.2),
                  iconColor.withOpacity(0.05),
                ],
              )
            : gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
