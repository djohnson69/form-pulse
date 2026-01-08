import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../dashboard/data/role_override_provider.dart';

class OrganizationChartPage extends ConsumerStatefulWidget {
  const OrganizationChartPage({super.key, this.role});

  final UserRole? role;

  @override
  ConsumerState<OrganizationChartPage> createState() =>
      _OrganizationChartPageState();
}

class _OrganizationChartPageState
    extends ConsumerState<OrganizationChartPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _expandedSupervisors = {1};
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final override = ref.watch(roleOverrideProvider);
    final role = override ?? widget.role ?? UserRole.employee;
    final canEdit = role == UserRole.manager ||
        role == UserRole.admin ||
        role == UserRole.superAdmin;
    final data = _organizationData;
    final totalEmployees =
        data.fold<int>(0, (sum, supervisor) => sum + supervisor.teamSize);
    final totalProjects =
        data.fold<int>(0, (sum, supervisor) => sum + supervisor.projects);
    final filteredData = _applySearch(data, _searchTerm);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth > 1280 ? 1280.0 : constraints.maxWidth;
          final isWide = constraints.maxWidth >= 768;
          final pagePadding = EdgeInsets.all(isWide ? 24 : 16);
          final sectionSpacing = isWide ? 24.0 : 20.0;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: ListView(
                padding: pagePadding,
                children: [
                  _buildHeader(
                    context,
                    data.length,
                    totalEmployees,
                    totalProjects,
                    canEdit,
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSearchBar(context),
                  if (!canEdit) ...[
                    SizedBox(height: sectionSpacing),
                    _buildAccessBanner(context),
                  ],
                  SizedBox(height: sectionSpacing),
                  _buildStatsGrid(context, data.length, totalEmployees),
                  SizedBox(height: sectionSpacing),
                  _buildStructureSection(context, filteredData, canEdit),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int supervisorCount,
    int employeeCount,
    int projectCount,
    bool canEdit,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final summaryText =
        '$supervisorCount supervisors • $employeeCount employees • $projectCount active projects';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Chart',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summaryText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        );

        final actions = canEdit
            ? ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  elevation: 6,
                  shadowColor: const Color(0x332563EB),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                label: const Text('Add Employee'),
              )
            : const SizedBox.shrink();

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              if (canEdit) actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            if (canEdit) ...[
              const SizedBox(height: 12),
              actions,
            ],
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final inputBorderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final inputFill = isDark ? const Color(0xFF111827) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          final searchField = TextField(
            controller: _searchController,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.grey[900],
              fontSize: 14,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              hintText: 'Search by name, role, or department...',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
                fontSize: 14,
              ),
              filled: true,
              fillColor: inputFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: inputBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: inputBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchTerm = value.trim());
            },
          );
          final filterButton = OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_outlined, size: 16),
            label: const Text('Filter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
              side: BorderSide(color: inputBorderColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                filterButton,
              ],
            );
          }
          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: filterButton),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccessBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E3A8A).withOpacity(0.2)
            : const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF1D4ED8).withOpacity(0.5)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8),
                fontSize: 14,
              ),
          children: const [
            TextSpan(
              text: 'View-Only Access:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text:
                  ' You can view the organization chart, but editing requires Manager, Admin, or Super Admin permissions.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    int supervisorCount,
    int employeeCount,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final cardShadow = _cardShadow(isDark);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 3 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: columns == 1 ? 3.1 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              title: 'Supervisors',
              value: supervisorCount.toString(),
              icon: Icons.groups_outlined,
              iconColor: const Color(0xFF2563EB),
              borderColor: borderColor,
              cardShadow: cardShadow,
            ),
            _StatCard(
              title: 'Total Employees',
              value: employeeCount.toString(),
              icon: Icons.people_outline,
              iconColor: const Color(0xFF16A34A),
              borderColor: borderColor,
              cardShadow: cardShadow,
            ),
            _StatCard(
              title: 'Departments',
              value: '3',
              icon: Icons.account_tree_outlined,
              iconColor: const Color(0xFF7C3AED),
              borderColor: borderColor,
              cardShadow: cardShadow,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStructureSection(
    BuildContext context,
    List<_Supervisor> supervisors,
    bool canEdit,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final cardShadow = _cardShadow(isDark);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Text(
              'Organization Structure',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: supervisors.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                        'No results found for "$_searchTerm"',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: supervisors
                        .map((supervisor) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SupervisorCard(
                                supervisor: supervisor,
                                isExpanded:
                                    _expandedSupervisors.contains(supervisor.id),
                                onToggle: () {
                                  setState(() {
                                    if (_expandedSupervisors
                                        .contains(supervisor.id)) {
                                      _expandedSupervisors.remove(supervisor.id);
                                    } else {
                                      _expandedSupervisors.add(supervisor.id);
                                    }
                                  });
                                },
                                canEdit: canEdit,
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  List<_Supervisor> _applySearch(
    List<_Supervisor> data,
    String searchTerm,
  ) {
    final query = searchTerm.toLowerCase();
    if (query.isEmpty) return data;
    return data.where((supervisor) {
      final supervisorMatches = supervisor.name.toLowerCase().contains(query) ||
          supervisor.role.toLowerCase().contains(query) ||
          supervisor.department.toLowerCase().contains(query);
      final employeeMatches = supervisor.employees.any(
        (employee) =>
            employee.name.toLowerCase().contains(query) ||
            employee.role.toLowerCase().contains(query),
      );
      return supervisorMatches || employeeMatches;
    }).toList();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.cardShadow,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final List<BoxShadow> cardShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBackground = iconColor.withOpacity(isDark ? 0.25 : 0.15);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupervisorCard extends StatelessWidget {
  const _SupervisorCard({
    required this.supervisor,
    required this.isExpanded,
    required this.onToggle,
    required this.canEdit,
  });

  final _Supervisor supervisor;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final performanceColor = _performanceColor(supervisor.performance);
    final headerGradient = LinearGradient(
      colors: isDark
          ? [
              const Color(0xFF1E3A8A).withOpacity(0.35),
              const Color(0xFF312E81).withOpacity(0.3),
            ]
          : [
              const Color(0xFFDBEAFE),
              const Color(0xFFE0E7FF),
            ],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: onToggle,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  iconSize: 20,
                  icon: Icon(
                    isExpanded
                        ? Icons.expand_more
                        : Icons.chevron_right,
                    color: isDark ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF3B82F6),
                  child: Text(
                    supervisor.avatar,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supervisor.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${supervisor.role} • ${supervisor.department}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _InlineIconText(
                                      icon: Icons.email_outlined,
                                      label: supervisor.email,
                                    ),
                                    _InlineIconText(
                                      icon: Icons.phone_outlined,
                                      label: supervisor.phone,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (canEdit)
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                size: 20,
                                color:
                                    isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              color: isDark
                                  ? const Color(0xFF1F2937)
                                  : Colors.white,
                              onSelected: (value) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$value selected')),
                                );
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'Edit Details',
                                  child: _MenuItem(
                                    icon: Icons.edit_outlined,
                                    label: 'Edit Details',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'Add Team Member',
                                  child: _MenuItem(
                                    icon: Icons.person_add_alt_1_outlined,
                                    label: 'Add Team Member',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'Remove',
                                  child: _MenuItem(
                                    icon: Icons.delete_outline,
                                    label: 'Remove',
                                    isDestructive: true,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatMini(
                            label: 'Team',
                            value: supervisor.teamSize.toString(),
                          ),
                          _StatMini(
                            label: 'Projects',
                            value: supervisor.projects.toString(),
                          ),
                          _StatMini(
                            label: 'Performance',
                            value: '${supervisor.performance}%',
                            valueColor: performanceColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded && supervisor.employees.isNotEmpty)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFF3F4F6),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(0),
                      ),
                      border: Border(
                        top: BorderSide(color: borderColor),
                        bottom: BorderSide(color: borderColor),
                      ),
                    ),
                    child: Text(
                      'TEAM MEMBERS (${supervisor.employees.length})',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.4,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  ...supervisor.employees.map(
                    (employee) => _EmployeeRow(
                      employee: employee,
                      canEdit: canEdit,
                      showDivider: employee != supervisor.employees.last,
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

class _InlineIconText extends StatelessWidget {
  const _InlineIconText({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
        : (isDark ? Colors.grey[300] : Colors.grey[700]);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  fontSize: 18,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({
    required this.employee,
    required this.canEdit,
    required this.showDivider,
  });

  final _Employee employee;
  final bool canEdit;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final statusColor = _statusColor(employee.status);

    return Container(
      padding: const EdgeInsets.fromLTRB(64, 16, 16, 16),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: borderColor)) : null,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF9CA3AF),
                      Color(0xFF4B5563),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  employee.avatar,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  employee.role,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  employee.email,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.more_vert,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              iconSize: 16,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            ),
        ],
      ),
    );
  }
}

Color _performanceColor(int performance) {
  if (performance >= 90) {
    return const Color(0xFF22C55E);
  }
  if (performance >= 75) {
    return const Color(0xFF3B82F6);
  }
  return const Color(0xFFF97316);
}

Color _statusColor(_EmployeeStatus status) {
  switch (status) {
    case _EmployeeStatus.active:
      return const Color(0xFF22C55E);
    case _EmployeeStatus.away:
      return const Color(0xFFF59E0B);
    case _EmployeeStatus.onLeave:
      return const Color(0xFF9CA3AF);
  }
}

List<BoxShadow> _cardShadow(bool isDark) {
  return [
    BoxShadow(
      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

class _Supervisor {
  const _Supervisor({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
    required this.email,
    required this.phone,
    required this.teamSize,
    required this.projects,
    required this.performance,
    required this.department,
    required this.employees,
  });

  final int id;
  final String name;
  final String role;
  final String avatar;
  final String email;
  final String phone;
  final int teamSize;
  final int projects;
  final int performance;
  final String department;
  final List<_Employee> employees;
}

class _Employee {
  const _Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.performance,
    required this.email,
    required this.avatar,
  });

  final int id;
  final String name;
  final String role;
  final _EmployeeStatus status;
  final int performance;
  final String email;
  final String avatar;
}

enum _EmployeeStatus { active, away, onLeave }

const List<_Supervisor> _organizationData = [
  _Supervisor(
    id: 1,
    name: 'John Smith',
    role: 'Site Supervisor',
    avatar: 'JS',
    email: 'john.smith@company.com',
    phone: '(555) 123-4567',
    teamSize: 8,
    projects: 3,
    performance: 94,
    department: 'Construction',
    employees: [
      _Employee(
        id: 1,
        name: 'Mike Johnson',
        role: 'Electrician',
        status: _EmployeeStatus.active,
        performance: 92,
        email: 'mike.j@company.com',
        avatar: 'MJ',
      ),
      _Employee(
        id: 2,
        name: 'Sarah Davis',
        role: 'Plumber',
        status: _EmployeeStatus.active,
        performance: 88,
        email: 'sarah.d@company.com',
        avatar: 'SD',
      ),
      _Employee(
        id: 3,
        name: 'Tom Wilson',
        role: 'Carpenter',
        status: _EmployeeStatus.onLeave,
        performance: 90,
        email: 'tom.w@company.com',
        avatar: 'TW',
      ),
      _Employee(
        id: 4,
        name: 'Emma Brown',
        role: 'HVAC Tech',
        status: _EmployeeStatus.active,
        performance: 95,
        email: 'emma.b@company.com',
        avatar: 'EB',
      ),
      _Employee(
        id: 5,
        name: 'James Lee',
        role: 'General Labor',
        status: _EmployeeStatus.active,
        performance: 87,
        email: 'james.l@company.com',
        avatar: 'JL',
      ),
      _Employee(
        id: 6,
        name: 'Lisa Chen',
        role: 'Painter',
        status: _EmployeeStatus.active,
        performance: 91,
        email: 'lisa.c@company.com',
        avatar: 'LC',
      ),
      _Employee(
        id: 7,
        name: 'David Kim',
        role: 'Mason',
        status: _EmployeeStatus.active,
        performance: 89,
        email: 'david.k@company.com',
        avatar: 'DK',
      ),
      _Employee(
        id: 8,
        name: 'Anna Martinez',
        role: 'Welder',
        status: _EmployeeStatus.active,
        performance: 93,
        email: 'anna.m@company.com',
        avatar: 'AM',
      ),
    ],
  ),
  _Supervisor(
    id: 2,
    name: 'Sarah Johnson',
    role: 'Operations Supervisor',
    avatar: 'SJ',
    email: 'sarah.johnson@company.com',
    phone: '(555) 234-5678',
    teamSize: 6,
    projects: 2,
    performance: 96,
    department: 'Operations',
    employees: [
      _Employee(
        id: 9,
        name: 'Robert Taylor',
        role: 'Foreman',
        status: _EmployeeStatus.active,
        performance: 94,
        email: 'robert.t@company.com',
        avatar: 'RT',
      ),
      _Employee(
        id: 10,
        name: 'Jennifer White',
        role: 'Equipment Operator',
        status: _EmployeeStatus.active,
        performance: 90,
        email: 'jennifer.w@company.com',
        avatar: 'JW',
      ),
      _Employee(
        id: 11,
        name: 'Michael Garcia',
        role: 'Safety Inspector',
        status: _EmployeeStatus.active,
        performance: 97,
        email: 'michael.g@company.com',
        avatar: 'MG',
      ),
      _Employee(
        id: 12,
        name: 'Amanda Clark',
        role: 'Quality Control',
        status: _EmployeeStatus.active,
        performance: 91,
        email: 'amanda.c@company.com',
        avatar: 'AC',
      ),
      _Employee(
        id: 13,
        name: 'Chris Anderson',
        role: 'Site Engineer',
        status: _EmployeeStatus.onLeave,
        performance: 88,
        email: 'chris.a@company.com',
        avatar: 'CA',
      ),
      _Employee(
        id: 14,
        name: 'Rachel Moore',
        role: 'Technician',
        status: _EmployeeStatus.active,
        performance: 92,
        email: 'rachel.m@company.com',
        avatar: 'RM',
      ),
    ],
  ),
  _Supervisor(
    id: 3,
    name: 'Mike Chen',
    role: 'Maintenance Supervisor',
    avatar: 'MC',
    email: 'mike.chen@company.com',
    phone: '(555) 345-6789',
    teamSize: 5,
    projects: 4,
    performance: 91,
    department: 'Maintenance',
    employees: [
      _Employee(
        id: 15,
        name: 'Kevin Harris',
        role: 'Maintenance Tech',
        status: _EmployeeStatus.active,
        performance: 89,
        email: 'kevin.h@company.com',
        avatar: 'KH',
      ),
      _Employee(
        id: 16,
        name: 'Laura Thompson',
        role: 'Facilities Manager',
        status: _EmployeeStatus.active,
        performance: 93,
        email: 'laura.t@company.com',
        avatar: 'LT',
      ),
      _Employee(
        id: 17,
        name: 'Steven Jackson',
        role: 'Custodian',
        status: _EmployeeStatus.active,
        performance: 86,
        email: 'steven.j@company.com',
        avatar: 'SJ',
      ),
      _Employee(
        id: 18,
        name: 'Michelle Lewis',
        role: 'Equipment Tech',
        status: _EmployeeStatus.active,
        performance: 90,
        email: 'michelle.l@company.com',
        avatar: 'ML',
      ),
      _Employee(
        id: 19,
        name: 'Brian Walker',
        role: 'HVAC Specialist',
        status: _EmployeeStatus.active,
        performance: 92,
        email: 'brian.w@company.com',
        avatar: 'BW',
      ),
    ],
  ),
];
