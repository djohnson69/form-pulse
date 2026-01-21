import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../data/projects_provider.dart';
import '../../../dashboard/data/active_role_provider.dart';
import 'project_detail_page.dart';
import 'project_editor_page.dart';

enum _ProjectsViewMode { grid, list }

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  String _searchQuery = '';
  String _filterStatus = 'all';
  _ProjectsViewMode _viewMode = _ProjectsViewMode.grid;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final role = ref.watch(activeRoleProvider);
    final canCreate = _canCreateProjects(role);
    final isWide = MediaQuery.sizeOf(context).width >= 768;
    final listPadding = EdgeInsets.all(isWide ? 24 : 16);
    return projectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ListView(
        padding: listPadding,
        children: [
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Projects Load Error',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load projects.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${e.toString()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => ref.invalidate(projectsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
      data: (projects) {
        final resolved = projects;
        final models = resolved
            .map((project) => _ProjectViewModel.fromProject(project))
            .toList();
        final filtered = _applyFilters(models);
        final stats = _ProjectStats.fromProjects(models);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(projectsProvider);
            await ref.read(projectsProvider.future);
          },
          child: ListView(
            padding: listPadding,
            children: [
              _buildHeader(context, canCreate),
              const SizedBox(height: 16),
              _ProjectStatsGrid(stats: stats),
              const SizedBox(height: 16),
              _buildFilters(context),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                _EmptyProjectsCard(canCreate: canCreate)
              else
                _buildProjectsBody(context, filtered),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool canCreate) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final showProjectLabel = constraints.maxWidth >= 640;
        final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: isWide ? 30 : 24,
            );
        final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: isWide ? 16 : 14,
            );
        final newProjectStyle = ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith(
            (states) => states.contains(MaterialState.hovered) ||
                    states.contains(MaterialState.pressed)
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF2563EB),
          ),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          elevation: MaterialStateProperty.all(2),
          shadowColor: MaterialStateProperty.all(
            const Color(0xFF2563EB).withValues(alpha: 0.2),
          ),
        );
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Projects',
              style: titleStyle,
            ),
            const SizedBox(height: 4),
            Text(
              'Manage all active and completed projects',
              style: subtitleStyle,
            ),
          ],
        );

        final controls = Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _ViewToggle(
              selected: _viewMode,
              onChanged: (mode) => setState(() => _viewMode = mode),
            ),
            if (canCreate)
              FilledButton(
                style: newProjectStyle,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProjectEditorPage(),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 20),
                    if (showProjectLabel) ...[
                      const SizedBox(width: 8),
                      const Text('New Project'),
                    ],
                  ],
                ),
              ),
          ],
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              controls,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 12),
            controls,
          ],
        );
      },
    );
  }

  bool _canCreateProjects(UserRole role) {
    switch (role) {
      case UserRole.supervisor:
      case UserRole.manager:
      case UserRole.admin:
      case UserRole.superAdmin:
      case UserRole.developer:
      case UserRole.maintenance:
        return true;
      case UserRole.employee:
      case UserRole.techSupport:
      case UserRole.client:
      case UserRole.vendor:
      case UserRole.viewer:
        return false;
    }
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final inputDecoration = InputDecoration(
      prefixIcon: const Icon(Icons.search),
      hintText: 'Search projects...',
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
      ),
      prefixIconColor:
          isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
      filled: true,
      fillColor: isDark ? const Color(0xFF111827) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
      ),
    );
    final outlineButtonStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      foregroundColor:
          isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      side: BorderSide(color: borderColor),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final children = [
            Expanded(
              flex: isWide ? 2 : 0,
              child: TextField(
                decoration: inputDecoration,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
              ),
            ),
            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _filterStatus,
                decoration: inputDecoration.copyWith(prefixIcon: null),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'on-hold', child: Text('On Hold')),
                ],
                onChanged: (value) {
                  setState(() => _filterStatus = value ?? 'all');
                },
              ),
            ),
            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
            OutlinedButton.icon(
              style: outlineButtonStyle,
              onPressed: () {},
              icon: const Icon(Icons.filter_list, size: 20),
              label: const Text('More Filters'),
            ),
          ];

          if (isWide) {
            return Row(children: children);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        },
      ),
    );
  }

  Widget _buildProjectsBody(
    BuildContext context,
    List<_ProjectViewModel> projects,
  ) {
    if (_viewMode == _ProjectsViewMode.grid) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1100 ? 3 : (width >= 720 ? 2 : 1);
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            childAspectRatio: crossAxisCount > 1 ? 0.9 : 0.85,
            children: projects
                .map((project) => _ProjectGridCard(project: project))
                .toList(),
          );
        },
      );
    }

    return _ProjectListTable(projects: projects);
  }

  List<_ProjectViewModel> _applyFilters(List<_ProjectViewModel> projects) {
    return projects.where((project) {
      final matchesSearch = _searchQuery.isEmpty ||
          project.name.toLowerCase().contains(_searchQuery) ||
          project.location.toLowerCase().contains(_searchQuery);
      final matchesStatus =
          _filterStatus == 'all' || project.status == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }
}

class _ProjectStatsGrid extends StatelessWidget {
  const _ProjectStatsGrid({required this.stats});

  final _ProjectStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final neutralNote =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final activeNote =
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    final progressNote =
        isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount > 2 ? 2.3 : 1.5,
          children: [
            _ProjectStatCard(
              label: 'Total Projects',
              value: stats.totalProjects.toString(),
              note: 'Across all locations',
              noteColor: neutralNote,
              icon: Icons.work_outline,
              color: const Color(0xFF3B82F6),
            ),
            _ProjectStatCard(
              label: 'Active Projects',
              value: stats.activeProjects.toString(),
              note: 'In progress',
              noteColor: activeNote,
              icon: Icons.track_changes,
              color: const Color(0xFF22C55E),
            ),
            _ProjectStatCard(
              label: 'Team Members',
              value: stats.teamMembers.toString(),
              note: 'Across all teams',
              noteColor: neutralNote,
              icon: Icons.people_outline,
              color: const Color(0xFF8B5CF6),
            ),
            _ProjectStatCard(
              label: 'Avg Progress',
              value: '${stats.avgProgress}%',
              note: 'Overall completion',
              noteColor: progressNote,
              icon: Icons.trending_up,
              color: const Color(0xFFF97316),
            ),
          ],
        );
      },
    );
  }
}

class _ProjectStatCard extends StatelessWidget {
  const _ProjectStatCard({
    required this.label,
    required this.value,
    required this.note,
    required this.noteColor,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String note;
  final Color noteColor;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
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
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: noteColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.selected, required this.onChanged});

  final _ProjectsViewMode selected;
  final ValueChanged<_ProjectsViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: Icons.grid_view_outlined,
            isSelected: selected == _ProjectsViewMode.grid,
            onTap: () => onChanged(_ProjectsViewMode.grid),
          ),
          _ToggleButton(
            icon: Icons.view_list_outlined,
            isSelected: selected == _ProjectsViewMode.list,
            onTap: () => onChanged(_ProjectsViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF374151) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF111827))
              : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

class _ProjectGridCard extends StatelessWidget {
  const _ProjectGridCard({required this.project});

  final _ProjectViewModel project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProjectDetailPage(project: project.project),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      hoverColor:
          isDark ? const Color(0xFF374151).withValues(alpha: 0.4) : const Color(0xFFF9FAFB),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
                        project.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              project.location,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  hoverColor: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFF3F4F6),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _StatusPill(status: project.status),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${project.progress}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: project.progress / 100,
                minHeight: 8,
                backgroundColor:
                    isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation(
                  _progressColor(project.progress),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: border),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Budget',
                          value: project.budgetLabel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: 'Spent',
                          value: project.spentLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Tasks',
                          value: '${project.completedTasks}/${project.tasks}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: 'Team',
                          value: '${project.team} members',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _ManagerAvatar(name: project.manager),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manager',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              project.manager,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Due Date',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      project.dueDateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectListTable extends StatelessWidget {
  const _ProjectListTable({required this.projects});

  final List<_ProjectViewModel> projects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 900),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827).withValues(alpha: 0.5)
                      : const Color(0xFFF9FAFB),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  children: [
                    _TableHeader(label: 'Project', flex: 3),
                    _TableHeader(label: 'Location', flex: 2),
                    _TableHeader(label: 'Manager', flex: 2),
                    _TableHeader(label: 'Progress', flex: 2),
                    _TableHeader(label: 'Budget', flex: 2),
                    _TableHeader(label: 'Team', flex: 1),
                    _TableHeader(label: 'Due Date', flex: 2),
                    _TableHeader(label: 'Status', flex: 1),
                  ],
                ),
              ),
              ...projects.map(
                (project) => InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProjectDetailPage(
                          project: project.project,
                        ),
                      ),
                    );
                  },
                  hoverColor: isDark
                      ? const Color(0xFF374151).withValues(alpha: 0.5)
                      : const Color(0xFFF9FAFB),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: border)),
                    ),
                    child: Row(
                      children: [
                        _TableCell(
                          flex: 3,
                          child: Text(
                            project.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        _TableCell(
                          flex: 2,
                          child: Text(
                            project.location,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        _TableCell(
                          flex: 2,
                          child: Text(
                            project.manager,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        _TableCell(
                          flex: 2,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 96,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: project.progress / 100,
                                    minHeight: 8,
                                    backgroundColor: isDark
                                        ? const Color(0xFF374151)
                                        : const Color(0xFFE5E7EB),
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${project.progress}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TableCell(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.budgetLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '${project.spentLabel} spent',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TableCell(
                          flex: 1,
                          child: Text(
                            '${project.team}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        _TableCell(
                          flex: 2,
                          child: Text(
                            project.dueDateLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        _TableCell(
                          flex: 1,
                          child: _ListStatusPill(status: project.status),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.label, required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.child, required this.flex});

  final Widget child;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: child);
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
      ),
    );
  }
}

class _ListStatusPill extends StatelessWidget {
  const _ListStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = status == 'active';
    final background = isActive
        ? const Color(0xFF22C55E).withValues(alpha: 0.2)
        : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6));
    final textColor = isActive
        ? const Color(0xFF4ADE80)
        : (isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ManagerAvatar extends StatelessWidget {
  const _ManagerAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join();
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
        ),
      ),
    );
  }
}

class _EmptyProjectsCard extends StatelessWidget {
  const _EmptyProjectsCard({required this.canCreate});

  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No projects found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              canCreate
                  ? 'Create a project to start tracking progress and tasks.'
                  : 'No projects are assigned to you yet.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectViewModel {
  const _ProjectViewModel({
    required this.project,
    required this.name,
    required this.location,
    required this.team,
    required this.progress,
    required this.status,
    required this.dueDate,
    required this.budgetLabel,
    required this.spentLabel,
    required this.tasks,
    required this.completedTasks,
    required this.manager,
  });

  final Project project;
  final String name;
  final String location;
  final int team;
  final int progress;
  final String status;
  final DateTime? dueDate;
  final String budgetLabel;
  final String spentLabel;
  final int tasks;
  final int completedTasks;
  final String manager;

  String get dueDateLabel {
    if (dueDate == null) return 'TBD';
    return DateFormat.yMd().format(dueDate!);
  }

  factory _ProjectViewModel.fromProject(Project project) {
    final metadata = project.metadata ?? const {};
    final location = _readString(metadata['location'], 'Unknown');
    final manager = _readString(metadata['manager'], project.createdBy ?? '');
    final progress = _readInt(metadata['progress'], project.status == 'completed' ? 100 : 45);
    final team = _readInt(metadata['team'], _readInt(metadata['teamSize'], 0));
    final tasks = _readInt(metadata['tasks'], 0);
    final completedTasks = _readInt(metadata['completedTasks'], 0);
    final dueDate = _readDate(metadata['dueDate']);
    final budgetLabel = _readString(metadata['budget'], 'TBD');
    final spentLabel = _readString(metadata['spent'], 'TBD');

    return _ProjectViewModel(
      project: project,
      name: project.name,
      location: location,
      team: team,
      progress: progress.clamp(0, 100),
      status: project.status,
      dueDate: dueDate,
      budgetLabel: budgetLabel,
      spentLabel: spentLabel,
      tasks: tasks,
      completedTasks: completedTasks,
      manager: manager.isEmpty ? 'Unassigned' : manager,
    );
  }
}

class _ProjectStats {
  const _ProjectStats({
    required this.totalProjects,
    required this.activeProjects,
    required this.teamMembers,
    required this.avgProgress,
  });

  final int totalProjects;
  final int activeProjects;
  final int teamMembers;
  final int avgProgress;

  factory _ProjectStats.fromProjects(List<_ProjectViewModel> projects) {
    if (projects.isEmpty) {
      return const _ProjectStats(
        totalProjects: 0,
        activeProjects: 0,
        teamMembers: 0,
        avgProgress: 0,
      );
    }
    final total = projects.length;
    final active = projects.where((p) => p.status == 'active').length;
    final team = projects.fold<int>(0, (sum, p) => sum + p.team);
    final avgProgress =
        (projects.fold<int>(0, (sum, p) => sum + p.progress) / total).round();
    return _ProjectStats(
      totalProjects: total,
      activeProjects: active,
      teamMembers: team,
      avgProgress: avgProgress,
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'active':
      return const Color(0xFF22C55E);
    case 'completed':
      return const Color(0xFF3B82F6);
    case 'on-hold':
      return const Color(0xFF9CA3AF);
    default:
      return const Color(0xFF9CA3AF);
  }
}

Color _progressColor(int progress) {
  if (progress >= 100) return const Color(0xFF22C55E);
  if (progress >= 75) return const Color(0xFF3B82F6);
  if (progress >= 50) return const Color(0xFFF59E0B);
  return const Color(0xFFF97316);
}

String _readString(dynamic value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return fallback;
}

int _readInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback;
}

DateTime? _readDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
