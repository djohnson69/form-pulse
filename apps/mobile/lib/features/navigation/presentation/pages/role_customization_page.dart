import 'package:flutter/material.dart';

class RoleCustomizationPage extends StatefulWidget {
  const RoleCustomizationPage({super.key});

  @override
  State<RoleCustomizationPage> createState() => _RoleCustomizationPageState();
}

class _RoleCustomizationPageState extends State<RoleCustomizationPage> {
  final List<_RoleConfig> _roles = [
    _RoleConfig(
      id: 'employee',
      defaultName: 'Employee',
      customName: 'Field Worker',
      description: 'Front-line workers performing tasks and submitting reports',
      color: const Color(0xFF3B82F6),
    ),
    _RoleConfig(
      id: 'supervisor',
      defaultName: 'Supervisor',
      customName: 'Team Lead',
      description: 'Oversees team members and approves daily operations',
      color: const Color(0xFF8B5CF6),
    ),
    _RoleConfig(
      id: 'manager',
      defaultName: 'Manager',
      customName: 'Project Manager',
      description: 'Manages projects, teams, and organizational resources',
      color: const Color(0xFF22C55E),
    ),
    _RoleConfig(
      id: 'maintenance',
      defaultName: 'Maintenance',
      customName: 'Maintenance Technician',
      description: 'Equipment maintenance and repair specialists',
      color: const Color(0xFFF97316),
    ),
    _RoleConfig(
      id: 'admin',
      defaultName: 'Admin',
      customName: 'Administrator',
      description: 'System configuration and user management',
      color: const Color(0xFFEF4444),
    ),
    _RoleConfig(
      id: 'techsupport',
      defaultName: 'Tech Support',
      customName: 'IT Support',
      description: 'Technical support and troubleshooting',
      color: const Color(0xFF06B6D4),
    ),
    _RoleConfig(
      id: 'superadmin',
      defaultName: 'Super Admin',
      customName: 'System Administrator',
      description: 'Full system access and control',
      color: const Color(0xFFEC4899),
    ),
  ];

  String? _editingRoleId;
  String _tempName = '';

  void _startEdit(_RoleConfig role) {
    setState(() {
      _editingRoleId = role.id;
      _tempName = role.customName;
    });
  }

  void _saveEdit(String roleId) {
    setState(() {
      final idx = _roles.indexWhere((role) => role.id == roleId);
      if (idx >= 0) {
        _roles[idx] = _roles[idx].copyWith(customName: _tempName.trim());
      }
      _editingRoleId = null;
      _tempName = '';
    });
  }

  void _resetRole(String roleId) {
    setState(() {
      final idx = _roles.indexWhere((role) => role.id == roleId);
      if (idx >= 0) {
        final role = _roles[idx];
        _roles[idx] = role.copyWith(customName: role.defaultName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = _RoleCustomizationColors.fromTheme(Theme.of(context));
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Role Name Customization')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(muted: colors.muted),
          const SizedBox(height: 16),
          _InfoBanner(colors: colors),
          const SizedBox(height: 16),
          _RoleGrid(
            roles: _roles,
            editingRoleId: _editingRoleId,
            tempName: _tempName,
            colors: colors,
            onEdit: _startEdit,
            onSave: _saveEdit,
            onCancel: () => setState(() {
              _editingRoleId = null;
              _tempName = '';
            }),
            onReset: _resetRole,
            onNameChanged: (value) => setState(() => _tempName = value),
          ),
          const SizedBox(height: 16),
          _ExamplesSection(colors: colors),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF111827);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Role Name Customization',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          "Customize role names to match your organization's terminology",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.colors});

  final _RoleCustomizationColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.infoSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.infoBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customize for Your Organization',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.info,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Change role names to match your company structure. '
                  'These custom names will appear throughout the application.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.infoText,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleGrid extends StatelessWidget {
  const _RoleGrid({
    required this.roles,
    required this.editingRoleId,
    required this.tempName,
    required this.colors,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    required this.onReset,
    required this.onNameChanged,
  });

  final List<_RoleConfig> roles;
  final String? editingRoleId;
  final String tempName;
  final _RoleCustomizationColors colors;
  final ValueChanged<_RoleConfig> onEdit;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;
  final ValueChanged<String> onReset;
  final ValueChanged<String> onNameChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        final aspectRatio = columns == 1 ? 2.2 : 2.0;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: roles.map((role) {
            final isEditing = role.id == editingRoleId;
            final isCustom = role.customName != role.defaultName;
            final color = role.color;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: color.withValues(alpha: 0.18),
                          border: Border.all(color: color.withValues(alpha: 0.35)),
                        ),
                        child: Icon(Icons.shield_outlined, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default: ${role.defaultName}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colors.muted),
                            ),
                            const SizedBox(height: 6),
                            if (isEditing)
                              TextFormField(
                                initialValue: tempName,
                                autofocus: true,
                                onChanged: onNameChanged,
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: colors.subtleSurface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: colors.border),
                                  ),
                                ),
                              )
                            else
                              Text(
                                role.customName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.title,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    role.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.muted),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      if (isEditing) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => onSave(role.id),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            child: const Text('Cancel'),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => onEdit(role),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Name'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (isCustom) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => onReset(role.id),
                            icon: Icon(Icons.refresh, color: colors.muted),
                          ),
                        ],
                      ],
                    ],
                  ),
                  if (isCustom && !isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: colors.success, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Custom name applied',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.success),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ExamplesSection extends StatelessWidget {
  const _ExamplesSection({required this.colors});

  final _RoleCustomizationColors colors;

  @override
  Widget build(BuildContext context) {
    final examples = _exampleGroups();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 3 : 1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Common Customization Examples',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.title,
                    ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: columns == 1 ? 2.4 : 2.2,
                children: examples.map((group) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.title,
                            ),
                      ),
                      const SizedBox(height: 6),
                      ...group.examples.map(
                        (example) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '- $example',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.muted),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoleCustomizationColors {
  const _RoleCustomizationColors({
    required this.background,
    required this.surface,
    required this.subtleSurface,
    required this.border,
    required this.muted,
    required this.title,
    required this.primary,
    required this.success,
    required this.info,
    required this.infoSurface,
    required this.infoBorder,
    required this.infoText,
  });

  final Color background;
  final Color surface;
  final Color subtleSurface;
  final Color border;
  final Color muted;
  final Color title;
  final Color primary;
  final Color success;
  final Color info;
  final Color infoSurface;
  final Color infoBorder;
  final Color infoText;

  factory _RoleCustomizationColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    const success = Color(0xFF16A34A);
    const info = Color(0xFF3B82F6);
    return _RoleCustomizationColors(
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      subtleSurface:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      title: isDark ? Colors.white : const Color(0xFF111827),
      primary: primary,
      success: success,
      info: info,
      infoSurface: isDark
          ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
          : const Color(0xFFDBEAFE),
      infoBorder: isDark ? const Color(0xFF1E40AF) : const Color(0xFF93C5FD),
      infoText: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8),
    );
  }
}

class _RoleConfig {
  const _RoleConfig({
    required this.id,
    required this.defaultName,
    required this.customName,
    required this.description,
    required this.color,
  });

  final String id;
  final String defaultName;
  final String customName;
  final String description;
  final Color color;

  _RoleConfig copyWith({String? customName}) {
    return _RoleConfig(
      id: id,
      defaultName: defaultName,
      customName: customName ?? this.customName,
      description: description,
      color: color,
    );
  }
}

class _ExampleGroup {
  const _ExampleGroup({required this.title, required this.examples});

  final String title;
  final List<String> examples;
}

List<_ExampleGroup> _exampleGroups() {
  return const [
    _ExampleGroup(
      title: 'Construction',
      examples: [
        'Employee -> Crew Member',
        'Supervisor -> Foreman',
        'Manager -> Site Manager',
        'Maintenance -> Equipment Tech',
      ],
    ),
    _ExampleGroup(
      title: 'Facilities',
      examples: [
        'Employee -> Technician',
        'Supervisor -> Lead Tech',
        'Manager -> Facilities Manager',
        'Maintenance -> Maintenance Crew',
      ],
    ),
    _ExampleGroup(
      title: 'Service Industry',
      examples: [
        'Employee -> Field Agent',
        'Supervisor -> Team Lead',
        'Manager -> Operations Manager',
        'Maintenance -> Service Tech',
      ],
    ),
  ];
}
