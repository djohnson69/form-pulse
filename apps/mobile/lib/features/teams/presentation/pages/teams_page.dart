import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../tasks/data/tasks_provider.dart';
import '../../../tasks/data/tasks_repository.dart';
import '../../../tasks/presentation/pages/tasks_page.dart';
import '../../../navigation/presentation/pages/user_directory_page.dart';

class TeamsPage extends ConsumerStatefulWidget {
  const TeamsPage({super.key});

  @override
  ConsumerState<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends ConsumerState<TeamsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';
  final List<_TeamMemberEntry> _localMembers = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _TeamColors.fromTheme(Theme.of(context));
    final membersAsync = ref.watch(taskAssigneesProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final tasks = tasksAsync.maybeWhen(
      data: (data) => data,
      orElse: () => const <Task>[],
    );
    final taskStats = _groupTasksByAssignee(tasks);
    final baseMembers = _buildBaseMembers(membersAsync, taskStats);
    final members = [...baseMembers, ..._localMembers];
    final filtered = _applyFilters(members);
    final stats = _TeamStats.fromMembers(members);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('My Team')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TeamHeader(
            colors: colors,
            onAdd: _handleAddMember,
          ),
          if (membersAsync.hasError) ...[
            const SizedBox(height: 12),
            _ErrorBanner(
              colors: colors,
              message: 'Failed to load team members.',
            ),
          ],
          const SizedBox(height: 16),
          _StatsGrid(colors: colors, stats: stats),
          const SizedBox(height: 16),
          _SearchFilterBar(
            colors: colors,
            searchController: _searchController,
            statusFilter: _statusFilter,
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onSearchChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            _EmptyState(colors: colors)
          else
            _TeamGrid(
              colors: colors,
              members: filtered,
              onAssign: _handleAssignTask,
              onViewDetails: _handleViewDetails,
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<_TeamMemberEntry> _buildBaseMembers(
    AsyncValue<List<TaskAssignee>> membersAsync,
    Map<String, List<Task>> tasksByAssignee,
  ) {
    final members = membersAsync.maybeWhen(
      data: (data) => data,
      orElse: () => const <TaskAssignee>[],
    );
    if (members.isEmpty) return const <_TeamMemberEntry>[];
    return members.map((assignee) {
      final assignedTasks = tasksByAssignee[assignee.id] ?? const <Task>[];
      return _mapAssignee(assignee, assignedTasks);
    }).toList();
  }

  List<_TeamMemberEntry> _applyFilters(List<_TeamMemberEntry> members) {
    final query = _searchController.text.trim().toLowerCase();
    return members.where((member) {
      final matchesSearch = query.isEmpty ||
          member.name.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query);
      final matchesFilter =
          _statusFilter == 'all' || member.status == _statusFilter;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _handleAddMember() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const UserDirectoryPage(),
      ),
    );
  }

  void _handleAssignTask(_TeamMemberEntry member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TasksPage(
          initialAssigneeId: member.id,
          initialAssigneeName: member.name,
        ),
      ),
    );
  }

  void _handleViewDetails(_TeamMemberEntry member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const UserDirectoryPage(),
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({
    required this.colors,
    required this.onAdd,
  });

  final _TeamColors colors;
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
              'My Team',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.title,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage and monitor your team members',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.muted),
            ),
          ],
        );
        final button = ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: const Text('Add Team Member'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
            shadowColor: colors.primary.withValues(alpha: 0.25),
          ),
        );
        if (isWide) {
          return Row(
            children: [
              Expanded(child: info),
              button,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            info,
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: button),
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

  final _TeamColors colors;
  final _TeamStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1000 ? 4 : 2;
        final items = [
          _StatCardData(
            label: 'Team Members',
            value: stats.total.toString(),
            icon: Icons.groups_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
            ),
          ),
          _StatCardData(
            label: 'Active Now',
            value: stats.active.toString(),
            icon: Icons.check_circle_outline,
            gradient: const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
            ),
          ),
          _StatCardData(
            label: 'Avg Performance',
            value: '${stats.avgPerformance}%',
            icon: Icons.emoji_events_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
            ),
          ),
          _StatCardData(
            label: 'Tasks Completed',
            value: stats.tasksCompleted.toString(),
            icon: Icons.track_changes_outlined,
            gradient: const LinearGradient(
              colors: [Color(0xFFF97316), Color(0xFFEA580C)],
            ),
          ),
        ];
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
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
    required this.icon,
    required this.gradient,
  });

  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.colors,
    required this.data,
  });

  final _TeamColors colors;
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: data.gradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: Colors.white),
          ),
          const Spacer(),
          Text(
            data.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({
    required this.colors,
    required this.searchController,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.onSearchChanged,
  });

  final _TeamColors colors;
  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          return Column(
            children: [
              TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: _inputDecoration(
                  colors,
                  hintText: 'Search team members...',
                  prefixIcon: Icons.search,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusOptions.map((status) {
                  final selected = statusFilter == status;
                  return TextButton(
                    onPressed: () => onStatusChanged(status),
                    style: TextButton.styleFrom(
                      backgroundColor:
                          selected ? colors.primary : colors.filterSurface,
                      foregroundColor:
                          selected ? Colors.white : colors.body,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_statusLabel(status)),
                  );
                }).toList(),
              ),
              if (!isWide) const SizedBox(height: 4),
            ],
          );
        },
      ),
    );
  }
}

class _TeamGrid extends StatelessWidget {
  const _TeamGrid({
    required this.colors,
    required this.members,
    required this.onAssign,
    required this.onViewDetails,
  });

  final _TeamColors colors;
  final List<_TeamMemberEntry> members;
  final ValueChanged<_TeamMemberEntry> onAssign;
  final ValueChanged<_TeamMemberEntry> onViewDetails;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        final cardWidth =
            isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final member in members)
              SizedBox(
                width: cardWidth,
                child: _TeamMemberCard(
                  colors: colors,
                  member: member,
                  onAssign: () => onAssign(member),
                  onViewDetails: () => onViewDetails(member),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.colors,
    required this.member,
    required this.onAssign,
    required this.onViewDetails,
  });

  final _TeamColors colors;
  final _TeamMemberEntry member;
  final VoidCallback onAssign;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final performanceColor = _performanceColor(member.performance);
    final statusColor = _statusColor(member.status);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MemberAvatar(
                colors: colors,
                initials: _initialsFor(member.name),
                statusColor: statusColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.title,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.role,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Last active: ${member.lastActive}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.more_vert, color: colors.muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            colors: colors,
            icon: Icons.mail_outline,
            text: member.email,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            colors: colors,
            icon: Icons.phone_outlined,
            text: member.phone,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            colors: colors,
            icon: Icons.place_outlined,
            text: member.location,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            colors: colors,
            icon: Icons.calendar_today_outlined,
            text: 'Joined ${_formatJoinDate(member.joinDate)}',
          ),
          const SizedBox(height: 16),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Task Progress',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.muted),
              ),
              Text(
                '${member.tasksCompleted}/${member.tasksTotal}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.title,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: member.tasksTotal == 0
                  ? 0
                  : member.tasksCompleted / member.tasksTotal,
              minHeight: 8,
              backgroundColor: colors.progressTrack,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.muted),
              ),
              Text(
                '${member.performance}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: performanceColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAssign,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Assign Task'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: onViewDetails,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.body,
                    backgroundColor: colors.filterSurface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.colors,
    required this.initials,
    required this.statusColor,
  });

  final _TeamColors colors;
  final String initials;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final borderColor = colors.isDark ? colors.surface : Colors.white;
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
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
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.colors,
    required this.icon,
    required this.text,
  });

  final _TeamColors colors;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.body),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});

  final _TeamColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 48, color: colors.muted),
          const SizedBox(height: 12),
          Text(
            'No team members found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search or filters',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.colors,
    required this.message,
  });

  final _TeamColors colors;
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

class _TeamColors {
  const _TeamColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.border,
    required this.muted,
    required this.body,
    required this.title,
    required this.primary,
    required this.filterSurface,
    required this.inputFill,
    required this.inputBorder,
    required this.progressTrack,
    required this.avatarStart,
    required this.avatarEnd,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color border;
  final Color muted;
  final Color body;
  final Color title;
  final Color primary;
  final Color filterSurface;
  final Color inputFill;
  final Color inputBorder;
  final Color progressTrack;
  final Color avatarStart;
  final Color avatarEnd;

  factory _TeamColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return _TeamColors(
      isDark: isDark,
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      body: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      title: isDark ? Colors.white : const Color(0xFF111827),
      primary: const Color(0xFF2563EB),
      filterSurface:
          isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      inputFill: isDark ? const Color(0xFF0B1220) : Colors.white,
      inputBorder: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      progressTrack:
          isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      avatarStart: const Color(0xFF3B82F6),
      avatarEnd: const Color(0xFF2563EB),
    );
  }
}

class _TeamStats {
  const _TeamStats({
    required this.total,
    required this.active,
    required this.avgPerformance,
    required this.tasksCompleted,
  });

  final int total;
  final int active;
  final int avgPerformance;
  final int tasksCompleted;

  factory _TeamStats.fromMembers(List<_TeamMemberEntry> members) {
    if (members.isEmpty) {
      return const _TeamStats(
        total: 0,
        active: 0,
        avgPerformance: 0,
        tasksCompleted: 0,
      );
    }
    final totalPerformance =
        members.fold<int>(0, (sum, member) => sum + member.performance);
    final totalTasksCompleted =
        members.fold<int>(0, (sum, member) => sum + member.tasksCompleted);
    return _TeamStats(
      total: members.length,
      active: members.where((member) => member.status == 'active').length,
      avgPerformance: (totalPerformance / members.length).round(),
      tasksCompleted: totalTasksCompleted,
    );
  }
}

class _TeamMemberEntry {
  const _TeamMemberEntry({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.location,
    required this.status,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.performance,
    required this.joinDate,
    required this.lastActive,
  });

  final String id;
  final String name;
  final String role;
  final String email;
  final String phone;
  final String location;
  final String status;
  final int tasksCompleted;
  final int tasksTotal;
  final int performance;
  final DateTime joinDate;
  final String lastActive;
}

const List<String> _statusOptions = ['all', 'active', 'offline'];

String _statusLabel(String status) {
  if (status.isEmpty) return 'Unknown';
  return status[0].toUpperCase() + status.substring(1);
}

Color _statusColor(String status) {
  switch (status) {
    case 'active':
      return const Color(0xFF22C55E);
    case 'offline':
      return const Color(0xFF9CA3AF);
    default:
      return const Color(0xFF9CA3AF);
  }
}

Color _performanceColor(int value) {
  if (value >= 90) return const Color(0xFF22C55E);
  if (value >= 75) return const Color(0xFF3B82F6);
  return const Color(0xFFF97316);
}

InputDecoration _inputDecoration(
  _TeamColors colors, {
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

Map<String, List<Task>> _groupTasksByAssignee(List<Task> tasks) {
  final Map<String, List<Task>> grouped = {};
  for (final task in tasks) {
    final assigneeId = task.assignedTo;
    if (assigneeId == null || assigneeId.isEmpty) continue;
    grouped.putIfAbsent(assigneeId, () => []).add(task);
  }
  return grouped;
}

_TeamMemberEntry _mapAssignee(
  TaskAssignee assignee,
  List<Task> tasks,
) {
  final totalTasks = tasks.length;
  final completedTasks =
      tasks.where((t) => t.status == TaskStatus.completed).length;
  final performance =
      totalTasks == 0 ? 0 : ((completedTasks / totalTasks) * 100).round();
  final lastActivity = _latestActivity(tasks) ?? assignee.createdAt;
  final lastActive = _formatRelative(lastActivity);
  final email = assignee.email ?? _buildEmail(assignee.name);
  final joinDate = assignee.createdAt ?? DateTime.now();

  return _TeamMemberEntry(
    id: assignee.id,
    name: assignee.name,
    role: assignee.role?.isNotEmpty == true ? assignee.role! : 'Member',
    email: email,
    phone: 'Not provided',
    location: 'Not set',
    status: assignee.isActive ? 'active' : 'offline',
    tasksCompleted: completedTasks,
    tasksTotal: totalTasks,
    performance: performance,
    joinDate: joinDate,
    lastActive: lastActive,
  );
}

DateTime? _latestActivity(List<Task> tasks) {
  DateTime? latest;
  for (final task in tasks) {
    final candidate = task.updatedAt ?? task.completedAt ?? task.createdAt;
    if (latest == null || candidate.isAfter(latest)) {
      latest = candidate;
    }
  }
  return latest;
}

String _formatRelative(DateTime? value) {
  if (value == null) return 'No activity';
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _buildEmail(String name) {
  final parts = name.trim().toLowerCase().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'user@company.com';
  final prefix = parts.take(2).join('.');
  return '$prefix@company.com';
}

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

String _formatJoinDate(DateTime date) {
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
  return '${months[date.month - 1]} ${date.year}';
}
