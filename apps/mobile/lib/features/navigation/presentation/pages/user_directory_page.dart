import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin/data/admin_models.dart';
import '../../../admin/data/admin_providers.dart';

class UserDirectoryPage extends ConsumerStatefulWidget {
  const UserDirectoryPage({super.key});

  @override
  ConsumerState<UserDirectoryPage> createState() => _UserDirectoryPageState();
}

class _UserDirectoryPageState extends ConsumerState<UserDirectoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<_UserEntry> _localUsers = [];
  String _roleFilter = 'all';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _UserDirectoryColors.fromTheme(Theme.of(context));
    final usersAsync = ref.watch(adminUsersProvider);
    final baseUsers = _buildBaseUsers(usersAsync);
    final users = [...baseUsers, ..._localUsers];
    final filteredUsers = _applyFilters(users);
    final stats = _UserStats.fromUsers(users);

    return Scaffold(
      backgroundColor: colors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _UserDirectoryHeader(
            colors: colors,
            onExport: () => _handleExport(filteredUsers),
            onAdd: () => _openAddUserDialog(colors),
          ),
          if (usersAsync.hasError) ...[
            const SizedBox(height: 12),
            _ErrorBanner(colors: colors, message: 'Failed to load users.'),
          ],
          const SizedBox(height: 16),
          _StatsGrid(
            colors: colors,
            stats: stats,
          ),
          const SizedBox(height: 16),
          _RoleDistribution(
            colors: colors,
            roleCounts: stats.roleCounts,
          ),
          const SizedBox(height: 16),
          _FiltersBar(
            colors: colors,
            searchController: _searchController,
            roleFilter: _roleFilter,
            statusFilter: _statusFilter,
            onRoleChanged: (value) => setState(() => _roleFilter = value),
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onSearchChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _UsersTable(
            colors: colors,
            users: filteredUsers,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<_UserEntry> _buildBaseUsers(
    AsyncValue<List<AdminUserSummary>> usersAsync,
  ) {
    final baseUsers = usersAsync.maybeWhen(
      data: (users) => users,
      orElse: () => const <AdminUserSummary>[],
    );
    if (baseUsers.isEmpty) {
      return List<_UserEntry>.from(_demoUsers);
    }
    return baseUsers.map(_mapAdminUser).toList();
  }

  List<_UserEntry> _applyFilters(List<_UserEntry> users) {
    final query = _searchController.text.trim().toLowerCase();
    return users.where((user) {
      final matchesSearch = query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
      final matchesRole = _roleFilter == 'all' || user.role == _roleFilter;
      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'active' && user.isActive) ||
          (_statusFilter == 'inactive' && !user.isActive);
      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  Future<void> _handleExport(List<_UserEntry> users) async {
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No users to export.')),
      );
      return;
    }
    final csv = _buildUsersCsv(users);
    final filename =
        'users-export-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
    final file = XFile.fromData(
      utf8.encode(csv),
      mimeType: 'text/csv',
      name: filename,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'User export',
          files: [file],
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: csv));
    }
  }

  String _buildUsersCsv(List<_UserEntry> users) {
    const headers = [
      'Name',
      'Email',
      'Phone',
      'Role',
      'Department',
      'Location',
      'Status',
      'Joined Date',
      'Last Active',
      'Tasks Completed',
      'Forms Submitted',
      'Certifications',
    ];
    final rows = users.map((user) {
      final status = user.isActive ? 'active' : 'inactive';
      final joined = DateFormat('yyyy-MM-dd').format(user.joinedDate);
      return [
        user.name,
        user.email,
        user.phone,
        user.role,
        user.department,
        user.location,
        status,
        joined,
        user.lastActive,
        user.tasksCompleted.toString(),
        user.formsSubmitted.toString(),
        user.certifications.toString(),
      ];
    });
    return ([headers, ...rows])
        .map((row) => row.map(_csvEscape).join(','))
        .join('\n');
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  Future<void> _openAddUserDialog(_UserDirectoryColors colors) async {
    final invitedEmail = await showDialog<String>(
      context: context,
      builder: (_) => _AddUserDialog(colors: colors),
    );
    if (invitedEmail == null) return;
    ref.invalidate(adminUsersProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite sent to $invitedEmail'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _UserDirectoryHeader extends StatelessWidget {
  const _UserDirectoryHeader({
    required this.colors,
    required this.onExport,
    required this.onAdd,
  });

  final _UserDirectoryColors colors;
  final VoidCallback onExport;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Management',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.title,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage users, roles, and permissions across your organization',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.muted),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.body,
                backgroundColor: colors.surface,
                side: BorderSide(color: colors.border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                shadowColor: colors.primary.withValues(alpha: 0.25),
              ),
            ),
          ],
        );
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: info),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            info,
            const SizedBox(height: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.colors,
    required this.stats,
  });

  final _UserDirectoryColors colors;
  final _UserStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900 ? 4 : 2;
        final activeHelper =
            colors.isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
        final trendHelper =
            colors.isDark ? const Color(0xFFD8B4FE) : const Color(0xFFA855F7);
        final items = [
          _StatCardData(
            label: 'Total Users',
            value: stats.total.toString(),
            helper: 'All team members',
            icon: Icons.group_outlined,
            iconColor: const Color(0xFF3B82F6),
            helperColor: colors.muted,
          ),
          _StatCardData(
            label: 'Active Users',
            value: stats.active.toString(),
            helper: 'Currently active',
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF22C55E),
            helperColor: activeHelper,
          ),
          _StatCardData(
            label: 'Inactive Users',
            value: stats.inactive.toString(),
            helper: 'Not active',
            icon: Icons.person_off_outlined,
            iconColor: const Color(0xFF6B7280),
            helperColor: colors.muted,
          ),
          _StatCardData(
            label: 'New This Month',
            value: stats.newThisMonth.toString(),
            helper: '+33% from last month',
            icon: Icons.trending_up,
            iconColor: const Color(0xFFA855F7),
            helperColor: trendHelper,
          ),
        ];
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            for (final item in items)
              _StatCard(colors: colors, data: item),
          ],
        );
      },
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.iconColor,
    required this.helperColor,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color iconColor;
  final Color helperColor;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.colors,
    required this.data,
  });

  final _UserDirectoryColors colors;
  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          if (!colors.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Icon(data.icon, size: 20, color: data.iconColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            data.helper,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: data.helperColor),
          ),
        ],
      ),
    );
  }
}

class _RoleDistribution extends StatelessWidget {
  const _RoleDistribution({
    required this.colors,
    required this.roleCounts,
  });

  final _UserDirectoryColors colors;
  final Map<String, int> roleCounts;

  @override
  Widget build(BuildContext context) {
    final items = _roleOptions.map((role) {
      return _RoleDistributionItem(
        role: role,
        count: roleCounts[role] ?? 0,
        color: _roleBaseColor(role),
      );
    }).toList();

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
          Text(
            'Team Distribution by Role',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 900 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  for (final item in items)
                    _RoleCard(colors: colors, item: item),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoleDistributionItem {
  const _RoleDistributionItem({
    required this.role,
    required this.count,
    required this.color,
  });

  final String role;
  final int count;
  final Color color;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.colors,
    required this.item,
  });

  final _UserDirectoryColors colors;
  final _RoleDistributionItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.filterSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, color: item.color, size: 28),
          const SizedBox(height: 8),
          Text(
            item.count.toString(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            item.role,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.colors,
    required this.searchController,
    required this.roleFilter,
    required this.statusFilter,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
  });

  final _UserDirectoryColors colors;
  final TextEditingController searchController;
  final String roleFilter;
  final String statusFilter;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final fieldWidth =
              isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: _inputDecoration(
                    colors,
                    hintText: 'Search users by name or email...',
                    prefixIcon: Icons.search,
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<String>(
                  value: roleFilter,
                  decoration: _inputDecoration(
                    colors,
                    hintText: 'All Roles',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Roles'),
                    ),
                    for (final role in _roleOptions)
                      DropdownMenuItem(
                        value: role,
                        child: Text(role),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onRoleChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<String>(
                  value: statusFilter,
                  decoration: _inputDecoration(
                    colors,
                    hintText: 'All Status',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All Status'),
                    ),
                    DropdownMenuItem(
                      value: 'active',
                      child: Text('Active'),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onStatusChanged(value);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.colors,
    required this.users,
  });

  final _UserDirectoryColors colors;
  final List<_UserEntry> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          'No users found.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colors.muted),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTableTheme(
            data: DataTableThemeData(
              headingRowColor: MaterialStateProperty.all(colors.tableHeader),
              dataRowColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.hovered)) {
                  return colors.rowHover;
                }
                return null;
              }),
              headingTextStyle: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
              dataTextStyle: TextStyle(
                color: colors.body,
                fontSize: 13,
              ),
            ),
            child: DataTable(
              columnSpacing: 20,
              headingRowHeight: 48,
              dataRowMinHeight: 70,
              dataRowMaxHeight: 80,
              columns: const [
                DataColumn(label: Text('USER')),
                DataColumn(label: Text('CONTACT')),
                DataColumn(label: Text('ROLE')),
                DataColumn(label: Text('DEPARTMENT')),
                DataColumn(label: Text('LOCATION')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('PERFORMANCE')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: users.map((user) {
                return DataRow(
                  cells: [
                    DataCell(_UserCell(colors: colors, user: user)),
                    DataCell(_ContactCell(colors: colors, user: user)),
                    DataCell(_RoleBadge(colors: colors, role: user.role)),
                    DataCell(Text(user.department)),
                    DataCell(_LocationCell(colors: colors, location: user.location)),
                    DataCell(_StatusCell(colors: colors, user: user)),
                    DataCell(_PerformanceCell(colors: colors, user: user)),
                    DataCell(_ActionButtons(colors: colors)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCell extends StatelessWidget {
  const _UserCell({
    required this.colors,
    required this.user,
  });

  final _UserDirectoryColors colors;
  final _UserEntry user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _InitialsAvatar(
          colors: colors,
          initials: _initialsFor(user.name),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user.name,
              style: TextStyle(
                color: colors.title,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Joined ${_formatDate(user.joinedDate)}',
              style: TextStyle(
                color: colors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContactCell extends StatelessWidget {
  const _ContactCell({
    required this.colors,
    required this.user,
  });

  final _UserDirectoryColors colors;
  final _UserEntry user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(Icons.mail_outline, size: 14, color: colors.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                user.email,
                style: TextStyle(color: colors.body, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.phone_outlined, size: 14, color: colors.muted),
            const SizedBox(width: 6),
            Text(
              user.phone,
              style: TextStyle(color: colors.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationCell extends StatelessWidget {
  const _LocationCell({
    required this.colors,
    required this.location,
  });

  final _UserDirectoryColors colors;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.place_outlined, size: 14, color: colors.muted),
        const SizedBox(width: 6),
        Text(location, style: TextStyle(color: colors.muted)),
      ],
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({
    required this.colors,
    required this.user,
  });

  final _UserDirectoryColors colors;
  final _UserEntry user;

  @override
  Widget build(BuildContext context) {
    final status = user.isActive ? 'Active' : 'Inactive';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatusBadge(colors: colors, isActive: user.isActive, label: status),
        const SizedBox(height: 4),
        Text(
          user.lastActive,
          style: TextStyle(color: colors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _PerformanceCell extends StatelessWidget {
  const _PerformanceCell({
    required this.colors,
    required this.user,
  });

  final _UserDirectoryColors colors;
  final _UserEntry user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${user.tasksCompleted} tasks',
          style: TextStyle(color: colors.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '${user.formsSubmitted} forms',
          style: TextStyle(color: colors.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '${user.certifications} certs',
          style: TextStyle(color: colors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.colors});

  final _UserDirectoryColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.edit_outlined, color: colors.primary),
          iconSize: 18,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          tooltip: 'Edit',
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.more_vert, color: colors.muted),
          iconSize: 18,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          tooltip: 'More',
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.colors,
    required this.role,
  });

  final _UserDirectoryColors colors;
  final String role;

  @override
  Widget build(BuildContext context) {
    final style = _roleBadgeStyle(role, colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: style.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.colors,
    required this.isActive,
    required this.label,
  });

  final _UserDirectoryColors colors;
  final bool isActive;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF16A34A) : const Color(0xFF6B7280);
    final background = color.withValues(alpha: colors.isDark ? 0.2 : 0.15);
    final foreground = colors.isDark
        ? (isActive ? const Color(0xFF4ADE80) : const Color(0xFFD1D5DB))
        : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.colors,
    required this.initials,
  });

  final _UserDirectoryColors colors;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [colors.avatarStart, colors.avatarEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.colors,
    required this.message,
  });

  final _UserDirectoryColors colors;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.filterSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog({required this.colors});

  final _UserDirectoryColors colors;

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _role = 'Employee';
  String? _error;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add New User',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.title,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.muted),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: colors.danger),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 520;
                  final fields = [
                    _DialogField(
                      label: 'Name',
                      child: TextField(
                        controller: _nameController,
                        decoration: _inputDecoration(
                          colors,
                          hintText: 'Enter full name',
                        ),
                      ),
                    ),
                    _DialogField(
                      label: 'Email',
                      child: TextField(
                        controller: _emailController,
                        decoration: _inputDecoration(
                          colors,
                          hintText: 'email@formbridge.com',
                        ),
                      ),
                    ),
                    _DialogField(
                      label: 'Phone',
                      child: TextField(
                        controller: _phoneController,
                        decoration: _inputDecoration(
                          colors,
                          hintText: '+1 (555) 123-4567',
                        ),
                      ),
                    ),
                    _DialogField(
                      label: 'Role',
                      child: DropdownButtonFormField<String>(
                        value: _role,
                        decoration: _inputDecoration(colors, hintText: ''),
                        items: [
                          for (final role in _roleOptions)
                            DropdownMenuItem(value: role, child: Text(role)),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _role = value);
                          }
                        },
                      ),
                    ),
                    _DialogField(
                      label: 'Department',
                      child: TextField(
                        controller: _departmentController,
                        decoration: _inputDecoration(
                          colors,
                          hintText: 'e.g., Field Services',
                        ),
                      ),
                    ),
                    _DialogField(
                      label: 'Location',
                      child: TextField(
                        controller: _locationController,
                        decoration: _inputDecoration(
                          colors,
                          hintText: 'City, State',
                        ),
                      ),
                    ),
                  ];

                  if (isWide) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: fields[0]),
                            const SizedBox(width: 12),
                            Expanded(child: fields[1]),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: fields[2]),
                            const SizedBox(width: 12),
                            Expanded(child: fields[3]),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: fields[4]),
                            const SizedBox(width: 12),
                            Expanded(child: fields[5]),
                          ],
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (final field in fields) ...[
                        field,
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.body,
                      backgroundColor: colors.filterSurface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: colors.primary.withValues(alpha: 0.25),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add User'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final department = _departmentController.text.trim();
    final location = _locationController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      setState(() => _error = 'Name and email are required.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Please enter a valid email.');
      return;
    }

    final appRole = _toAppRole(_role);
    if (appRole == null) {
      setState(() => _error = 'Unsupported role selected.');
      return;
    }

    final nameParts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'org-invite',
        body: {
          'email': email,
          'role': appRole,
          if (firstName.isNotEmpty) 'firstName': firstName,
          if (lastName.isNotEmpty) 'lastName': lastName,
          if (phone.isNotEmpty) 'phone': phone,
          if (department.isNotEmpty) 'department': department,
          if (location.isNotEmpty) 'location': location,
        },
      );

      if (!mounted) return;
      final data = res.data;
      final ok = data is Map && data['ok'] == true;
      if (!ok) {
        final serverMessage = data is Map ? data['error']?.toString() : null;
        setState(
          () => _error = serverMessage ?? 'Invite failed. Please try again.',
        );
        return;
      }

      Navigator.of(context).pop(email);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to invite user: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

String? _toAppRole(String roleLabel) {
  switch (roleLabel) {
    case 'Super Admin':
      return 'superadmin';
    case 'Admin':
      return 'admin';
    case 'Manager':
      return 'manager';
    case 'Supervisor':
      return 'supervisor';
    case 'Employee':
      return 'employee';
    case 'Tech Support':
      return 'techsupport';
    case 'Maintenance':
      return 'maintenance';
  }
  return null;
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration _inputDecoration(
  _UserDirectoryColors colors, {
  required String hintText,
  IconData? prefixIcon,
}) {
  return InputDecoration(
    hintText: hintText.isEmpty ? null : hintText,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
    filled: true,
    fillColor: colors.inputFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.inputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.inputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

class _UserDirectoryColors {
  const _UserDirectoryColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.border,
    required this.muted,
    required this.body,
    required this.title,
    required this.primary,
    required this.tableHeader,
    required this.rowHover,
    required this.filterSurface,
    required this.inputFill,
    required this.inputBorder,
    required this.avatarStart,
    required this.avatarEnd,
    required this.danger,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color border;
  final Color muted;
  final Color body;
  final Color title;
  final Color primary;
  final Color tableHeader;
  final Color rowHover;
  final Color filterSurface;
  final Color inputFill;
  final Color inputBorder;
  final Color avatarStart;
  final Color avatarEnd;
  final Color danger;

  factory _UserDirectoryColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    return _UserDirectoryColors(
      isDark: isDark,
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      body: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      title: isDark ? Colors.white : const Color(0xFF111827),
      primary: primary,
      tableHeader:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      rowHover:
          isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
      filterSurface:
          isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      inputFill: isDark ? const Color(0xFF0B1220) : Colors.white,
      inputBorder: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      avatarStart: const Color(0xFF60A5FA),
      avatarEnd: const Color(0xFF2563EB),
      danger: const Color(0xFFDC2626),
    );
  }
}

class _UserStats {
  const _UserStats({
    required this.total,
    required this.active,
    required this.inactive,
    required this.newThisMonth,
    required this.roleCounts,
  });

  final int total;
  final int active;
  final int inactive;
  final int newThisMonth;
  final Map<String, int> roleCounts;

  factory _UserStats.fromUsers(List<_UserEntry> users) {
    final now = DateTime.now();
    final roleCounts = {
      for (final role in _roleOptions) role: 0,
    };
    for (final user in users) {
      if (roleCounts.containsKey(user.role)) {
        roleCounts[user.role] = (roleCounts[user.role] ?? 0) + 1;
      }
    }
    return _UserStats(
      total: users.length,
      active: users.where((user) => user.isActive).length,
      inactive: users.where((user) => !user.isActive).length,
      newThisMonth: users
          .where(
            (user) =>
                user.joinedDate.month == now.month &&
                user.joinedDate.year == now.year,
          )
          .length,
      roleCounts: roleCounts,
    );
  }
}

class _UserEntry {
  const _UserEntry({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.department,
    required this.isActive,
    required this.location,
    required this.joinedDate,
    required this.lastActive,
    required this.tasksCompleted,
    required this.formsSubmitted,
    required this.certifications,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String department;
  final bool isActive;
  final String location;
  final DateTime joinedDate;
  final String lastActive;
  final int tasksCompleted;
  final int formsSubmitted;
  final int certifications;
}

const List<String> _roleOptions = [
  'Super Admin',
  'Admin',
  'Manager',
  'Supervisor',
  'Employee',
  'Tech Support',
  'Maintenance',
];

final List<_UserEntry> _demoUsers = [
  _UserEntry(
    id: '1',
    name: 'John Doe',
    email: 'john.doe@formbridge.com',
    phone: '+1 (555) 123-4567',
    role: 'Super Admin',
    department: 'IT',
    isActive: true,
    location: 'San Francisco, CA',
    joinedDate: DateTime(2024, 1, 15),
    lastActive: '2 hours ago',
    tasksCompleted: 145,
    formsSubmitted: 32,
    certifications: 5,
  ),
  _UserEntry(
    id: '2',
    name: 'Jane Smith',
    email: 'jane.smith@formbridge.com',
    phone: '+1 (555) 234-5678',
    role: 'Admin',
    department: 'Administration',
    isActive: true,
    location: 'New York, NY',
    joinedDate: DateTime(2024, 2, 20),
    lastActive: '5 hours ago',
    tasksCompleted: 98,
    formsSubmitted: 28,
    certifications: 4,
  ),
  _UserEntry(
    id: '3',
    name: 'Mike Johnson',
    email: 'mike.johnson@formbridge.com',
    phone: '+1 (555) 345-6789',
    role: 'Manager',
    department: 'Operations',
    isActive: true,
    location: 'Los Angeles, CA',
    joinedDate: DateTime(2024, 3, 10),
    lastActive: '1 day ago',
    tasksCompleted: 234,
    formsSubmitted: 45,
    certifications: 6,
  ),
  _UserEntry(
    id: '4',
    name: 'Sarah Williams',
    email: 'sarah.w@formbridge.com',
    phone: '+1 (555) 456-7890',
    role: 'Supervisor',
    department: 'Field Services',
    isActive: true,
    location: 'Chicago, IL',
    joinedDate: DateTime(2024, 4, 5),
    lastActive: '30 minutes ago',
    tasksCompleted: 187,
    formsSubmitted: 52,
    certifications: 3,
  ),
  _UserEntry(
    id: '5',
    name: 'Tom Brown',
    email: 'tom.brown@formbridge.com',
    phone: '+1 (555) 567-8901',
    role: 'Employee',
    department: 'Field Services',
    isActive: false,
    location: 'Houston, TX',
    joinedDate: DateTime(2024, 5, 12),
    lastActive: '2 weeks ago',
    tasksCompleted: 67,
    formsSubmitted: 18,
    certifications: 2,
  ),
  _UserEntry(
    id: '6',
    name: 'Lisa Anderson',
    email: 'lisa.a@formbridge.com',
    phone: '+1 (555) 678-9012',
    role: 'Tech Support',
    department: 'IT Support',
    isActive: true,
    location: 'Seattle, WA',
    joinedDate: DateTime(2024, 6, 8),
    lastActive: '3 hours ago',
    tasksCompleted: 156,
    formsSubmitted: 38,
    certifications: 5,
  ),
  _UserEntry(
    id: '7',
    name: 'David Martinez',
    email: 'david.m@formbridge.com',
    phone: '+1 (555) 789-0123',
    role: 'Maintenance',
    department: 'Facilities',
    isActive: true,
    location: 'Phoenix, AZ',
    joinedDate: DateTime(2024, 7, 15),
    lastActive: '1 hour ago',
    tasksCompleted: 92,
    formsSubmitted: 24,
    certifications: 3,
  ),
];

_UserEntry _mapAdminUser(AdminUserSummary user) {
  final roleLabel = _roleLabel(user.role);
  final seed = user.id.hashCode.abs();
  final phone = _phoneOptions[seed % _phoneOptions.length];
  final location = _locationOptions[seed % _locationOptions.length];
  final department = _departmentForRole(roleLabel);
  return _UserEntry(
    id: user.id,
    name: user.displayName,
    email: user.email,
    phone: phone,
    role: roleLabel,
    department: department,
    isActive: user.isActive,
    location: location,
    joinedDate: user.createdAt,
    lastActive: _relativeTime(user.updatedAt),
    tasksCompleted: 60 + (seed % 220),
    formsSubmitted: 12 + (seed % 50),
    certifications: 1 + (seed % 6),
  );
}

String _roleLabel(UserRole role) {
  switch (role) {
    case UserRole.superAdmin:
      return 'Super Admin';
    case UserRole.admin:
      return 'Admin';
    case UserRole.manager:
      return 'Manager';
    case UserRole.supervisor:
      return 'Supervisor';
    case UserRole.employee:
      return 'Employee';
    case UserRole.techSupport:
      return 'Tech Support';
    case UserRole.maintenance:
      return 'Maintenance';
    case UserRole.client:
      return 'Client';
    case UserRole.vendor:
      return 'Vendor';
    case UserRole.viewer:
      return 'Viewer';
  }
}

String _departmentForRole(String role) {
  switch (role) {
    case 'Super Admin':
      return 'IT';
    case 'Admin':
      return 'Administration';
    case 'Manager':
      return 'Operations';
    case 'Supervisor':
      return 'Field Services';
    case 'Tech Support':
      return 'IT Support';
    case 'Maintenance':
      return 'Facilities';
    default:
      return 'Operations';
  }
}

const List<String> _phoneOptions = [
  '+1 (555) 123-4567',
  '+1 (555) 234-5678',
  '+1 (555) 345-6789',
  '+1 (555) 456-7890',
  '+1 (555) 567-8901',
  '+1 (555) 678-9012',
  '+1 (555) 789-0123',
];

const List<String> _locationOptions = [
  'San Francisco, CA',
  'New York, NY',
  'Los Angeles, CA',
  'Chicago, IL',
  'Houston, TX',
  'Seattle, WA',
  'Phoenix, AZ',
];

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '';
  if (parts.length == 1) {
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
  }
  final first = parts.first.isNotEmpty ? parts.first[0] : '';
  final last = parts.last.isNotEmpty ? parts.last[0] : '';
  return '${first.toUpperCase()}${last.toUpperCase()}';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[date.month - 1];
  return '$month ${date.day}, ${date.year}';
}

String _relativeTime(DateTime updatedAt) {
  final diff = DateTime.now().difference(updatedAt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  final weeks = (diff.inDays / 7).floor();
  return '$weeks weeks ago';
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

_BadgeStyle _roleBadgeStyle(String role, _UserDirectoryColors colors) {
  final base = _roleBaseColor(role);
  final background = base.withValues(alpha: colors.isDark ? 0.2 : 0.15);
  final foreground = colors.isDark
      ? _softRoleForeground(role, base)
      : base;
  return _BadgeStyle(background: background, foreground: foreground);
}

Color _roleBaseColor(String role) {
  switch (role) {
    case 'Super Admin':
      return const Color(0xFF7C3AED);
    case 'Admin':
      return const Color(0xFF2563EB);
    case 'Manager':
      return const Color(0xFFF59E0B);
    case 'Supervisor':
      return const Color(0xFF16A34A);
    case 'Employee':
      return const Color(0xFF6B7280);
    case 'Tech Support':
      return const Color(0xFF06B6D4);
    case 'Maintenance':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF6B7280);
  }
}

Color _softRoleForeground(String role, Color base) {
  switch (role) {
    case 'Super Admin':
      return const Color(0xFFD8B4FE);
    case 'Admin':
      return const Color(0xFF93C5FD);
    case 'Manager':
      return const Color(0xFFFCD34D);
    case 'Supervisor':
      return const Color(0xFF86EFAC);
    case 'Employee':
      return const Color(0xFFD1D5DB);
    case 'Tech Support':
      return const Color(0xFF67E8F9);
    case 'Maintenance':
      return const Color(0xFFFCA5A5);
    default:
      return base;
  }
}
