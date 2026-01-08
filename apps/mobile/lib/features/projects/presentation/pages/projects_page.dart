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
    return projectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ListView(
        padding: const EdgeInsets.all(16),
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
        final resolved = projects.isEmpty ? _demoProjects() : projects;
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
            padding: const EdgeInsets.all(16),
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
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Projects',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage all active and completed projects',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );

        final controls = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ViewToggle(
              selected: _viewMode,
              onChanged: (mode) => setState(() => _viewMode = mode),
            ),
            if (canCreate)
              FilledButton(
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
                    const Icon(Icons.add),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final children = [
            Expanded(
              flex: isWide ? 2 : 0,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search projects...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
              ),
            ),
            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _filterStatus,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
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
              onPressed: () {},
              icon: const Icon(Icons.filter_list),
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
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
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
              icon: Icons.work_outline,
              color: const Color(0xFF3B82F6),
            ),
            _ProjectStatCard(
              label: 'Active Projects',
              value: stats.activeProjects.toString(),
              note: 'In progress',
              icon: Icons.track_changes,
              color: const Color(0xFF22C55E),
            ),
            _ProjectStatCard(
              label: 'Team Members',
              value: stats.teamMembers.toString(),
              note: 'Across all teams',
              icon: Icons.people_outline,
              color: const Color(0xFF8B5CF6),
            ),
            _ProjectStatCard(
              label: 'Avg Progress',
              value: '${stats.avgProgress}%',
              note: 'Overall completion',
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
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                ),
              ),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
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
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF374151) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
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
    final background = theme.colorScheme.surface;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProjectDetailPage(project: project.project),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              project.location,
                              style: theme.textTheme.bodySmall,
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
                  icon: Icon(
                    Icons.more_horiz,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _StatusPill(status: project.status),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress', style: theme.textTheme.bodySmall),
                Text(
                  '${project.progress}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
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
                              style: theme.textTheme.labelSmall,
                            ),
                            Text(
                              project.manager,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
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
                      style: theme.textTheme.labelSmall,
                    ),
                    Text(
                      project.dueDateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 900),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF9FAFB),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
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
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            ),
                          ),
                        ),
                        _TableCell(flex: 2, child: Text(project.location)),
                        _TableCell(flex: 2, child: Text(project.manager)),
                        _TableCell(
                          flex: 2,
                          child: Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: project.progress / 100,
                                    minHeight: 6,
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
                              Text('${project.progress}%'),
                            ],
                          ),
                        ),
                        _TableCell(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(project.budgetLabel),
                              Text(
                                '${project.spentLabel} spent',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TableCell(flex: 1, child: Text('${project.team}')),
                        _TableCell(flex: 2, child: Text(project.dueDateLabel)),
                        _TableCell(
                          flex: 1,
                          child: _StatusPill(status: project.status),
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
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
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
    return DateFormat.yMMMd().format(dueDate!);
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

List<Project> _demoProjects() {
  final now = DateTime.now();
  final items = [
    {
      'id': 'demo-1',
      'name': 'Main Construction Site',
      'location': 'Downtown',
      'team': 12,
      'progress': 75,
      'status': 'active',
      'dueDate': '2026-03-15',
      'budget': r'$2.5M',
      'spent': r'$1.8M',
      'tasks': 45,
      'completedTasks': 34,
      'manager': 'Sarah Johnson',
    },
    {
      'id': 'demo-2',
      'name': 'Residential Complex',
      'location': 'North District',
      'team': 8,
      'progress': 45,
      'status': 'active',
      'dueDate': '2026-06-30',
      'budget': r'$1.8M',
      'spent': r'$810K',
      'tasks': 32,
      'completedTasks': 14,
      'manager': 'Mike Chen',
    },
    {
      'id': 'demo-3',
      'name': 'Office Building Renovation',
      'location': 'Business Park',
      'team': 15,
      'progress': 90,
      'status': 'active',
      'dueDate': '2025-12-31',
      'budget': r'$3.2M',
      'spent': r'$2.9M',
      'tasks': 56,
      'completedTasks': 50,
      'manager': 'Emily Davis',
    },
    {
      'id': 'demo-4',
      'name': 'Warehouse Expansion',
      'location': 'Industrial Zone',
      'team': 6,
      'progress': 100,
      'status': 'completed',
      'dueDate': '2025-11-15',
      'budget': r'$950K',
      'spent': r'$920K',
      'tasks': 28,
      'completedTasks': 28,
      'manager': 'Alex Martinez',
    },
    {
      'id': 'demo-5',
      'name': 'HVAC System Installation',
      'location': 'Tech Campus',
      'team': 10,
      'progress': 60,
      'status': 'active',
      'dueDate': '2026-02-28',
      'budget': r'$1.2M',
      'spent': r'$720K',
      'tasks': 38,
      'completedTasks': 23,
      'manager': 'Tom Brown',
    },
    {
      'id': 'demo-6',
      'name': 'Parking Structure Build',
      'location': 'City Center',
      'team': 14,
      'progress': 35,
      'status': 'active',
      'dueDate': '2026-08-15',
      'budget': r'$4.5M',
      'spent': r'$1.6M',
      'tasks': 67,
      'completedTasks': 23,
      'manager': 'Lisa Anderson',
    },
  ];

  return items
      .map(
        (item) => Project(
          id: item['id'] as String,
          name: item['name'] as String,
          status: item['status'] as String,
          createdAt: now,
          metadata: {
            'location': item['location'],
            'team': item['team'],
            'progress': item['progress'],
            'tasks': item['tasks'],
            'completedTasks': item['completedTasks'],
            'dueDate': item['dueDate'],
            'budget': item['budget'],
            'spent': item['spent'],
            'manager': item['manager'],
          },
        ),
      )
      .toList();
}
