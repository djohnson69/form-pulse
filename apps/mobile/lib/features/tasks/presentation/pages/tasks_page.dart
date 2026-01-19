import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../dashboard/data/active_role_provider.dart';
import '../../../dashboard/data/dashboard_permissions_provider.dart';
import '../../../teams/data/teams_provider.dart';
import '../../data/tasks_provider.dart';
import '../../data/tasks_repository.dart';
import 'task_detail_page.dart';

enum _TaskViewMode { list, board, calendar }

class _TeamAccessInfo {
  const _TeamAccessInfo({
    required this.teams,
    required this.userTeamNames,
    required this.teamMemberIds,
    required this.teamMemberCounts,
  });

  const _TeamAccessInfo.empty()
      : teams = const [],
        userTeamNames = const <String>{},
        teamMemberIds = const <String>{},
        teamMemberCounts = const <String, int>{};

  final List<Team> teams;
  final Set<String> userTeamNames;
  final Set<String> teamMemberIds;
  final Map<String, int> teamMemberCounts;
}

final _taskTeamAccessProvider =
    FutureProvider.autoDispose<_TeamAccessInfo>((ref) async {
  final teams = await ref.watch(teamsProvider.future);
  if (teams.isEmpty) {
    return const _TeamAccessInfo.empty();
  }

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  final teamIds = teams.map((team) => team.id).toList();
  if (teamIds.isEmpty) {
    return _TeamAccessInfo(
      teams: teams,
      userTeamNames: const <String>{},
      teamMemberIds: const <String>{},
      teamMemberCounts: const <String, int>{},
    );
  }

  final rows = await client
      .from('team_members')
      .select('team_id, user_id')
      .inFilter('team_id', teamIds);

  final membersByTeamId = <String, Set<String>>{};
  for (final row in rows as List<dynamic>) {
    final data = Map<String, dynamic>.from(row as Map);
    final teamId = data['team_id']?.toString();
    final memberId = data['user_id']?.toString();
    if (teamId == null || memberId == null) continue;
    membersByTeamId.putIfAbsent(teamId, () => <String>{}).add(memberId);
  }

  final userTeamNames = <String>{};
  final teamMemberIds = <String>{};
  final teamMemberCounts = <String, int>{};

  for (final team in teams) {
    final members = membersByTeamId[team.id] ?? const <String>{};
    final normalizedName = team.name.toLowerCase();
    teamMemberCounts[normalizedName] = members.length;
    if (userId != null && members.contains(userId)) {
      userTeamNames.add(normalizedName);
      teamMemberIds.addAll(members);
    }
  }

  return _TeamAccessInfo(
    teams: teams,
    userTeamNames: userTeamNames,
    teamMemberIds: teamMemberIds,
    teamMemberCounts: teamMemberCounts,
  );
});

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({
    super.key,
    this.initialAssigneeId,
    this.initialAssigneeName,
  });

  final String? initialAssigneeId;
  final String? initialAssigneeName;

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  String _searchQuery = '';
  String _filterStatus = 'all';
  String _filterPriority = 'all';
  String? _assigneeFilterId;
  String? _assigneeFilterName;
  _TaskViewMode _viewMode = _TaskViewMode.list;
  DateTime _calendarDate = DateTime.now();
  DateTime? _selectedDate;
  List<_TaskNotification> _notifications = const [];
  Timer? _notificationTimer;
  DateTime _notificationNow = DateTime.now();
  RealtimeChannel? _tasksChannel;

  @override
  void initState() {
    super.initState();
    _assigneeFilterId = widget.initialAssigneeId;
    _assigneeFilterName = widget.initialAssigneeName;
    _subscribeToTaskChanges();
    _startNotificationTimer();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _tasksChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToTaskChanges() {
    final client = Supabase.instance.client;
    _tasksChannel = client.channel('tasks-changes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tasks',
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(tasksProvider);
        },
      )
      ..subscribe();
  }

  void _startNotificationTimer() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _notificationNow = DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(activeRoleProvider);
    final permissions = ref.watch(dashboardPermissionsProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final assigneesAsync = ref.watch(taskAssigneesProvider);
    final teamAccessAsync = ref.watch(_taskTeamAccessProvider);
    final colors = _TaskColors.fromTheme(Theme.of(context));
    final canManageTasks = permissions.manageTasks;

    final isSupervisorOrHigher =
        role == UserRole.supervisor || role.canManage;

    return Scaffold(
      backgroundColor: colors.background,
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _TasksErrorView(error: e.toString()),
        data: (tasks) {
          final teamAccess =
              teamAccessAsync.asData?.value ?? const _TeamAccessInfo.empty();
          final mappedTasks = tasks.map(_mapTask).toList();
          final allTasks = mappedTasks;
          final roleTasks = _applyRoleFilter(allTasks, role, teamAccess);
          final filteredTasks = _applyFilters(roleTasks);
          final nextNotifications = _buildNotifications(
            roleTasks,
            now: _notificationNow,
            previous: _notifications,
          );
          _syncNotifications(nextNotifications);
          final userId = Supabase.instance.client.auth.currentUser?.id;
          final isLimitedView = role == UserRole.employee ||
              role == UserRole.maintenance ||
              role == UserRole.techSupport ||
              role == UserRole.supervisor;
          final accessLabel = isLimitedView
              ? (role == UserRole.supervisor
                  ? "Showing only your team's tasks (${filteredTasks.length})"
                  : 'Showing only tasks assigned to you (${filteredTasks.length})')
              : null;
          final upcomingMilestones = nextNotifications
              .where((notification) => notification.type == 'milestone')
              .length;
          final milestoneTotals = _countMilestones(roleTasks);
          final pendingCount = _countStatus(allTasks, 'pending');
          final inProgressCount = _countStatus(allTasks, 'in-progress');
          final completedCount = _countStatus(allTasks, 'completed');
          final teamTasksCount =
              allTasks.where((task) => task.assignedTeam != null).length;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 768;
              const sectionSpacing = 24.0;
              return ListView(
                padding: EdgeInsets.all(isWide ? 24 : 16),
                children: [
                  _TasksHeader(
                    role: role,
                    onExport: () => _handleExport(filteredTasks),
                    canManageTasks: canManageTasks,
                    onCreate: () =>
                        _openCreateTaskDialog(assigneesAsync, teamAccess),
                    accessLabel: accessLabel,
                  ),
                  if (isSupervisorOrHigher && _notifications.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: sectionSpacing),
                      child: _NotificationsCard(
                        notifications: _notifications,
                        onMarkAllRead: _markAllNotificationsRead,
                        onMarkRead: _markNotificationRead,
                      ),
                    ),
                  if (upcomingMilestones > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: sectionSpacing),
                      child: _MilestoneBanner(count: upcomingMilestones),
                    ),
                  _TaskStatsGrid(
                    totalTasks: roleTasks.length,
                    pending: pendingCount,
                    inProgress: inProgressCount,
                    completed: completedCount,
                    milestoneComplete: milestoneTotals.completed,
                    milestoneTotal: milestoneTotals.total,
                    teamTasks: teamTasksCount,
                    role: role,
                  ),
                  if (_assigneeFilterId != null || _assigneeFilterName != null)
                    ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InputChip(
                          label: Text(
                            'Assignee: ${_assigneeFilterName ?? _assigneeFilterId}',
                          ),
                          onDeleted: _clearAssigneeFilter,
                        ),
                      ),
                    ],
                  const SizedBox(height: sectionSpacing),
                  _TaskFilters(
                    searchQuery: _searchQuery,
                    status: _filterStatus,
                    priority: _filterPriority,
                    onSearchChanged: (value) => setState(
                      () => _searchQuery = value.trim().toLowerCase(),
                    ),
                    onStatusChanged: (value) =>
                        setState(() => _filterStatus = value),
                    onPriorityChanged: (value) =>
                        setState(() => _filterPriority = value),
                  ),
                  const SizedBox(height: sectionSpacing),
                  _TaskViewSection(
                    viewMode: _viewMode,
                    onViewModeChanged: (mode) => setState(() => _viewMode = mode),
                    tasks: filteredTasks,
                    teamMemberCounts: teamAccess.teamMemberCounts,
                    selectedDate: _selectedDate,
                    calendarDate: _calendarDate,
                    onCalendarNext: _nextMonth,
                    onCalendarPrev: _previousMonth,
                    onDateSelected: (date) =>
                        setState(() => _selectedDate = date),
                    onOpenTask: (task) => _openTaskDetail(task, userId),
                  ),
                  const SizedBox(height: 80),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<_TaskView> _applyRoleFilter(
    List<_TaskView> tasks,
    UserRole role,
    _TeamAccessInfo teamAccess,
  ) {
    if (role == UserRole.techSupport) {
      return tasks;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    bool isTeamAssignment(_TaskView task) {
      final teamName = task.assignedTeam?.toLowerCase();
      if (teamName == null || teamName.isEmpty) return false;
      return teamAccess.userTeamNames.contains(teamName);
    }
    if (role == UserRole.employee || role == UserRole.maintenance) {
      if (userId == null) return const [];
      return tasks
          .where((task) => task.assigneeId == userId || isTeamAssignment(task))
          .toList();
    }
    if (role == UserRole.supervisor) {
      final filtered = tasks.where((task) {
        final isDirectAssignee =
            userId != null && task.assigneeId == userId;
        final isTeamMemberTask = task.assigneeId != null &&
            teamAccess.teamMemberIds.contains(task.assigneeId);
        return isDirectAssignee ||
            isTeamAssignment(task) ||
            isTeamMemberTask;
      }).toList();
      return filtered;
    }
    return tasks;
  }

  void _clearAssigneeFilter() {
    setState(() {
      _assigneeFilterId = null;
      _assigneeFilterName = null;
    });
  }

  List<_TaskView> _applyFilters(List<_TaskView> tasks) {
    return tasks.where((task) {
      final matchesQuery = _searchQuery.isEmpty ||
          task.title.toLowerCase().contains(_searchQuery) ||
          task.description.toLowerCase().contains(_searchQuery);
      final matchesAssignee = _assigneeFilterId == null &&
              _assigneeFilterName == null
          ? true
          : task.assigneeId == _assigneeFilterId ||
              (_assigneeFilterName != null &&
                  task.assignee.toLowerCase() ==
                      _assigneeFilterName!.toLowerCase());
      final matchesStatus =
          _filterStatus == 'all' || task.status == _filterStatus;
      final matchesPriority =
          _filterPriority == 'all' || task.priority == _filterPriority;
      return matchesQuery &&
          matchesAssignee &&
          matchesStatus &&
          matchesPriority;
    }).toList();
  }

  Future<void> _handleExport(List<_TaskView> tasks) async {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tasks to export.')),
      );
      return;
    }
    final csv = _buildTasksCsv(tasks);
    final filename =
        'tasks_export_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
    final file = XFile.fromData(
      utf8.encode(csv),
      mimeType: 'text/csv',
      name: filename,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Task export',
          files: [file],
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: csv));
    }
  }

  String _buildTasksCsv(List<_TaskView> tasks) {
    const headers = [
      'Title',
      'Assignee',
      'Team',
      'Status',
      'Priority',
      'Due Date',
      'Location',
      'Category',
    ];
    final rows = tasks.map((task) {
      final dueDate = task.dueDate == null
          ? ''
          : DateFormat('yyyy-MM-dd').format(task.dueDate!);
      return [
        task.title,
        task.assignee,
        task.assignedTeam ?? 'None',
        task.status,
        task.priority,
        dueDate,
        task.location,
        task.category,
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

  Future<void> _openCreateTaskDialog(
    AsyncValue<List<TaskAssignee>> assignees,
    _TeamAccessInfo teamAccess,
  ) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    DateTime? dueDate;
    String priority = 'medium';
    String category = 'Safety';
    String? assignedTeam;
    final teamOptions = teamAccess.teams;
    final teamMemberCounts = teamAccess.teamMemberCounts;
    TaskAssignee? selectedAssignee;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final border =
                isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
            final inputFill =
                isDark ? const Color(0xFF374151) : Colors.white;
            final inputBorder =
                isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);
            final inputTextColor =
                isDark ? Colors.white : const Color(0xFF111827);
            final hintColor =
                isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
            final maxDialogHeight = MediaQuery.of(context).size.height * 0.9;
            final labelStyle = theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color:
                  isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
              fontSize: 14,
            );

            InputDecoration inputDecoration({String? hintText}) {
              return InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: hintColor, fontSize: 16),
                filled: true,
                fillColor: inputFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                ),
              );
            }

            Widget labeledField(
              String label,
              Widget field, {
              IconData? icon,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon == null)
                    Text(label, style: labelStyle)
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: labelStyle?.color,
                        ),
                        const SizedBox(width: 6),
                        Text(label, style: labelStyle),
                      ],
                    ),
                  const SizedBox(height: 8),
                  field,
                ],
              );
            }

            final dateField = InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: dueDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked == null) return;
                setModalState(() => dueDate = picked);
              },
              child: InputDecorator(
                decoration: inputDecoration(),
                child: Text(
                  dueDate == null ? 'Select date' : _formatDate(dueDate!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: inputTextColor,
                    fontSize: 16,
                  ),
                ),
              ),
            );

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor:
                  isDark ? const Color(0xFF1F2937) : Colors.white,
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: 768, maxHeight: maxDialogHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Task',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      labeledField(
                        'Task Title',
                        TextField(
                          controller: titleController,
                          decoration:
                              inputDecoration(hintText: 'Enter task title'),
                          style: TextStyle(color: inputTextColor, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      labeledField(
                        'Description',
                        TextField(
                          controller: descriptionController,
                          decoration: inputDecoration(
                              hintText: 'Enter task description'),
                          style: TextStyle(color: inputTextColor, fontSize: 16),
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          final assigneeField = labeledField(
                            'Assign to Individual',
                            DropdownButtonFormField<TaskAssignee?>(
                              value: selectedAssignee,
                              decoration: inputDecoration(),
                              hint: Text(
                                'Select individual...',
                                style: TextStyle(color: hintColor, fontSize: 16),
                              ),
                              dropdownColor: inputFill,
                              iconEnabledColor: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              style:
                                  TextStyle(color: inputTextColor, fontSize: 16),
                              items: (assignees.asData?.value ??
                                      const <TaskAssignee>[])
                                  .map(
                                    (assignee) =>
                                        DropdownMenuItem<TaskAssignee?>(
                                      value: assignee,
                                      child: Text(assignee.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setModalState(() => selectedAssignee = value),
                            ),
                          );
                          final teamField = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              labeledField(
                                'Assign to Team',
                                DropdownButtonFormField<String>(
                                  value: assignedTeam,
                                  decoration: inputDecoration(),
                                  hint: Text(
                                    teamOptions.isEmpty
                                        ? 'No teams available'
                                        : 'Select team (optional)...',
                                    style:
                                        TextStyle(color: hintColor, fontSize: 16),
                                  ),
                                  dropdownColor: inputFill,
                                  iconEnabledColor: isDark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                  style: TextStyle(
                                      color: inputTextColor, fontSize: 16),
                                  items: teamOptions
                                      .map(
                                        (team) => DropdownMenuItem(
                                          value: team.name,
                                          child: Text(
                                            '${team.name} (${teamMemberCounts[team.name.toLowerCase()] ?? 0} members)',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: teamOptions.isEmpty
                                      ? null
                                      : (value) => setModalState(
                                            () => assignedTeam = value,
                                          ),
                                ),
                                icon: Icons.groups_outlined,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Team assignment enables collaboration and shared progress tracking',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          );
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: assigneeField),
                                const SizedBox(width: 16),
                                Expanded(child: teamField),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              assigneeField,
                              const SizedBox(height: 16),
                              teamField,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          final priorityField = labeledField(
                            'Priority',
                            DropdownButtonFormField<String>(
                              value: priority,
                              decoration: inputDecoration(),
                              dropdownColor: inputFill,
                              iconEnabledColor: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              style:
                                  TextStyle(color: inputTextColor, fontSize: 16),
                              items: const [
                                DropdownMenuItem(
                                  value: 'high',
                                  child: Text('High'),
                                ),
                                DropdownMenuItem(
                                  value: 'medium',
                                  child: Text('Medium'),
                                ),
                                DropdownMenuItem(
                                  value: 'low',
                                  child: Text('Low'),
                                ),
                              ],
                              onChanged: (value) => setModalState(
                                () => priority = value ?? 'medium',
                              ),
                            ),
                          );
                          final dueDateField =
                              labeledField('Due Date', dateField);
                          final categoryField = labeledField(
                            'Category',
                            DropdownButtonFormField<String>(
                              value: category,
                              decoration: inputDecoration(),
                              dropdownColor: inputFill,
                              iconEnabledColor: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              style:
                                  TextStyle(color: inputTextColor, fontSize: 16),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Safety',
                                  child: Text('Safety'),
                                ),
                                DropdownMenuItem(
                                  value: 'Maintenance',
                                  child: Text('Maintenance'),
                                ),
                                DropdownMenuItem(
                                  value: 'Installation',
                                  child: Text('Installation'),
                                ),
                                DropdownMenuItem(
                                  value: 'Quality',
                                  child: Text('Quality'),
                                ),
                                DropdownMenuItem(
                                  value: 'Reporting',
                                  child: Text('Reporting'),
                                ),
                              ],
                              onChanged: (value) => setModalState(
                                () => category = value ?? 'Safety',
                              ),
                            ),
                          );
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: priorityField),
                                const SizedBox(width: 16),
                                Expanded(child: dueDateField),
                                const SizedBox(width: 16),
                                Expanded(child: categoryField),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              priorityField,
                              const SizedBox(height: 16),
                              dueDateField,
                              const SizedBox(height: 16),
                              categoryField,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      labeledField(
                        'Location',
                        TextField(
                          controller: locationController,
                          decoration:
                              inputDecoration(hintText: 'Enter task location'),
                          style: TextStyle(color: inputTextColor, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(height: 1, color: border),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.track_changes,
                            size: 16,
                            color: labelStyle?.color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Milestones (Optional)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color:
                                  isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add milestones to track progress and receive proactive reminders',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Milestone'),
                        style: ButtonStyle(
                          padding: MaterialStateProperty.all(
                            const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          foregroundColor: MaterialStateProperty.all(
                            isDark
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFF374151),
                          ),
                          textStyle: MaterialStateProperty.all(
                            theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                          ),
                          backgroundColor: MaterialStateProperty.resolveWith(
                            (states) => states.contains(MaterialState.hovered)
                                ? (isDark
                                    ? const Color(0xFF4B5563)
                                    : const Color(0xFFE5E7EB))
                                : (isDark
                                    ? const Color(0xFF374151)
                                    : const Color(0xFFF3F4F6)),
                          ),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (titleController.text.trim().isEmpty) {
                                        return;
                                      }
                                      setModalState(() => saving = true);
                                      try {
                                        await ref
                                            .read(tasksRepositoryProvider)
                                            .createTask(
                                              title: titleController.text.trim(),
                                              description:
                                                  descriptionController.text.trim(),
                                              dueDate: dueDate,
                                              priority: priority,
                                              assignedTo: selectedAssignee?.id,
                                              assignedToName: selectedAssignee?.name,
                                              assignedTeam: assignedTeam == null ||
                                                      assignedTeam!.trim().isEmpty
                                                  ? null
                                                  : assignedTeam,
                                              metadata: {
                                                'location':
                                                    locationController.text.trim(),
                                                'category': category,
                                              },
                                            );
                                        ref.invalidate(tasksProvider);
                                        if (!mounted) return;
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Task created'),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Create failed: $e'),
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setModalState(() => saving = false);
                                        }
                                      }
                                    },
                              style: ButtonStyle(
                                padding: MaterialStateProperty.all(
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                                backgroundColor: MaterialStateProperty.resolveWith(
                                  (states) => states.contains(MaterialState.hovered)
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF2563EB),
                                ),
                                foregroundColor:
                                    MaterialStateProperty.all(Colors.white),
                                elevation: MaterialStateProperty.all(0),
                                shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Create Task',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed:
                                saving ? null : () => Navigator.of(context).pop(),
                            style: ButtonStyle(
                              padding: MaterialStateProperty.all(
                                const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              backgroundColor: MaterialStateProperty.resolveWith(
                                (states) => states.contains(MaterialState.hovered)
                                    ? (isDark
                                        ? const Color(0xFF4B5563)
                                        : const Color(0xFFD1D5DB))
                                    : (isDark
                                        ? const Color(0xFF374151)
                                        : const Color(0xFFE5E7EB)),
                              ),
                              foregroundColor: MaterialStateProperty.all(
                                isDark ? Colors.white : const Color(0xFF111827),
                              ),
                              shape: MaterialStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
  }

  void _markNotificationRead(int id) {
    setState(() {
      _notifications = _notifications
          .map(
            (item) => item.id == id
                ? item.copyWith(read: true)
                : item,
          )
          .toList();
    });
  }

  void _markAllNotificationsRead() {
    setState(() {
      _notifications =
          _notifications.map((item) => item.copyWith(read: true)).toList();
    });
  }

  void _syncNotifications(List<_TaskNotification> next) {
    if (_notificationsEqual(next, _notifications)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_notificationsEqual(next, _notifications)) return;
      setState(() => _notifications = next);
    });
  }

  bool _notificationsEqual(
    List<_TaskNotification> a,
    List<_TaskNotification> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id) return false;
      if (left.read != right.read) return false;
      if (left.message != right.message) return false;
      if (left.timestamp != right.timestamp) return false;
    }
    return true;
  }

  int _daysUntil(DateTime dueDate, DateTime now) {
    final diffDays = dueDate.difference(now).inSeconds /
        Duration.secondsPerDay;
    return diffDays.ceil();
  }

  List<_TaskNotification> _buildNotifications(
    List<_TaskView> tasks, {
    required DateTime now,
    List<_TaskNotification> previous = const [],
  }) {
    final readById = <int, bool>{
      for (final item in previous) item.id: item.read,
    };
    final List<_TaskNotification> completions = [];
    final List<_TaskNotification> milestones = [];

    for (final task in tasks) {
      if (task.completedAt != null) {
        final id = 'completion-${task.id}'.hashCode;
        completions.add(
          _TaskNotification(
            id: id,
            type: 'completion',
            taskTitle: task.title,
            message:
                'Task completed by ${task.completedBy ?? task.assignee}${task.assignedTeam != null ? " (${task.assignedTeam})" : ""}',
            timestamp: task.completedAt!,
            icon: Icons.check_circle,
            assignee: task.completedBy ?? task.assignee,
            team: task.assignedTeam,
            read: readById[id] ?? false,
          ),
        );
      }

      if (task.status == 'completed') continue;
      for (final milestone in task.milestones) {
        if (milestone.completed) continue;
        final daysUntil = _daysUntil(milestone.dueDate, now);
        if (daysUntil < 0) {
          final id =
              'overdue-milestone-${task.id}-${milestone.title}'.hashCode;
          milestones.add(
            _TaskNotification(
              id: id,
              type: 'overdue',
              taskTitle: task.title,
              message:
                  'Milestone "${milestone.title}" is ${daysUntil.abs()} day${daysUntil.abs() == 1 ? "" : "s"} overdue',
              timestamp: now,
              icon: Icons.warning_amber_outlined,
              assignee: task.assignee,
              team: task.assignedTeam,
              read: readById[id] ?? false,
            ),
          );
        } else if (daysUntil <= milestone.reminderDays) {
          final id =
              'milestone-${task.id}-${milestone.title}'.hashCode;
          milestones.add(
            _TaskNotification(
              id: id,
              type: 'milestone',
              taskTitle: task.title,
              message:
                  'Milestone "${milestone.title}" due in $daysUntil day${daysUntil == 1 ? "" : "s"}',
              timestamp: now,
              icon: Icons.track_changes,
              assignee: task.assignee,
              team: task.assignedTeam,
              read: readById[id] ?? false,
            ),
          );
        }
      }
    }

    return [...completions, ...milestones];
  }

  void _openTaskDetail(_TaskView task, String? userId) {
    if (task.sourceTask != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TaskDetailPage(task: task.sourceTask!),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Open ${task.title}')),
    );
  }

  void _nextMonth() {
    setState(() {
      _calendarDate =
          DateTime(_calendarDate.year, _calendarDate.month + 1, 1);
    });
  }

  void _previousMonth() {
    setState(() {
      _calendarDate =
          DateTime(_calendarDate.year, _calendarDate.month - 1, 1);
    });
  }
}

class _TasksHeader extends StatelessWidget {
  const _TasksHeader({
    required this.role,
    required this.onExport,
    required this.canManageTasks,
    required this.onCreate,
    required this.accessLabel,
  });

  final UserRole role;
  final VoidCallback onExport;
  final bool canManageTasks;
  final VoidCallback onCreate;
  final String? accessLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final exportTextColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final exportHoverColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    final subtitle = switch (role) {
      UserRole.employee || UserRole.maintenance || UserRole.techSupport =>
        'Your assigned tasks and milestones',
      UserRole.supervisor => 'Your team\'s tasks and milestones',
      UserRole.manager => 'Department tasks and milestones',
      _ => 'Manage tasks, track milestones, and collaborate with teams',
    };

    final exportButton = TextButton.icon(
      onPressed: onExport,
      icon: const Icon(Icons.download_outlined, size: 16),
      label: const Text('Export'),
      style: ButtonStyle(
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        foregroundColor: MaterialStateProperty.all(exportTextColor),
        textStyle: MaterialStateProperty.all(
          theme.textTheme.bodySmall?.copyWith(fontSize: 14),
        ),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        backgroundColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.hovered)
              ? exportHoverColor
              : Colors.transparent,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideLayout = constraints.maxWidth >= 768;
        final isSmUp = constraints.maxWidth >= 640;
        final titleSize = isWideLayout ? 30.0 : 24.0;
        final createPadding = EdgeInsets.symmetric(
          horizontal: isWideLayout ? 16 : 24,
          vertical: isWideLayout ? 8 : 12,
        );
        final createLabel = isSmUp ? 'Create Task' : 'New Task';
        final createButton = ElevatedButton.icon(
          onPressed: onCreate,
          style: ButtonStyle(
            padding: MaterialStateProperty.all(createPadding),
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.hovered) ||
                  states.contains(MaterialState.pressed)) {
                return const Color(0xFF1D4ED8);
              }
              return const Color(0xFF2563EB);
            }),
            foregroundColor: MaterialStateProperty.all(Colors.white),
            shadowColor: MaterialStateProperty.all(const Color(0x332563EB)),
            elevation: MaterialStateProperty.resolveWith(
              (states) => states.contains(MaterialState.disabled) ? 0 : 6,
            ),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            createLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        );
        final headerText = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Management',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: titleSize,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                fontSize: 16,
              ),
            ),
            if (accessLabel != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withOpacity(0.3)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF3B82F6).withOpacity(0.3)
                        : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: isDark
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      accessLabel!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

        if (isWideLayout) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: headerText),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    exportButton,
                    if (canManageTasks) createButton,
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerText,
              const SizedBox(height: 12),
              exportButton,
              if (canManageTasks) ...[
                const SizedBox(height: 12),
                if (isSmUp)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: createButton,
                  )
                else
                  SizedBox(width: double.infinity, child: createButton),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.notifications,
    required this.onMarkAllRead,
    required this.onMarkRead,
  });

  final List<_TaskNotification> notifications;
  final VoidCallback onMarkAllRead;
  final ValueChanged<int> onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unreadCount = notifications.where((item) => !item.read).length;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 20,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF4B5563),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unreadCount new',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (unreadCount > 0)
                TextButton(
                  onPressed: onMarkAllRead,
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    foregroundColor: MaterialStateProperty.all(
                      isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF4B5563),
                    ),
                    textStyle: MaterialStateProperty.all(
                      theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                    ),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    backgroundColor: MaterialStateProperty.resolveWith(
                      (states) => states.contains(MaterialState.hovered)
                          ? (isDark
                              ? const Color(0xFF374151)
                              : const Color(0xFFF3F4F6))
                          : Colors.transparent,
                    ),
                  ),
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (var i = 0;
                  i < (notifications.length > 5 ? 5 : notifications.length);
                  i++)
                _NotificationRow(
                  notification: notifications[i],
                  onMarkRead: onMarkRead,
                  showDivider:
                      i !=
                          (notifications.length > 5
                              ? 4
                              : notifications.length - 1),
                ),
            ],
          ),
          if (notifications.length > 5) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Text(
                'Showing 5 of ${notifications.length} notifications',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onMarkRead,
    required this.showDivider,
  });

  final _TaskNotification notification;
  final ValueChanged<int> onMarkRead;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _notificationAccent(notification.type);
    final metaColor =
        isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280);
    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.background.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(notification.icon, color: accent.icon, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.taskTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notification.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (notification.assignee != null)
                    _MetaTag(
                      icon: Icons.person_outline,
                      label: notification.assignee!,
                      iconSize: 12,
                      fontSize: 12,
                      colorOverride: metaColor,
                    ),
                  if (notification.team != null)
                    _MetaTag(
                      icon: Icons.groups_outlined,
                      label: notification.team!,
                      highlighted: true,
                      iconSize: 12,
                      fontSize: 12,
                    ),
                  Text(
                    _formatDateTime(notification.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!notification.read)
          IconButton(
            onPressed: () => onMarkRead(notification.id),
            icon: const Icon(Icons.check, size: 16),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            hoverColor:
                isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          ),
      ],
    );

    return Opacity(
      opacity: notification.read ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFE5E7EB),
                  ),
                )
              : null,
        ),
        child: rowContent,
      ),
    );
  }
}

class _MilestoneBanner extends StatelessWidget {
  const _MilestoneBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = const Color(0xFFF59E0B);
    final background =
        isDark ? accent.withValues(alpha: 0.1) : const Color(0xFFFFFBEB);
    final border =
        isDark ? accent.withValues(alpha: 0.5) : const Color(0xFFFCD34D);
    final titleColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    final bodyColor =
        isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming Milestones Reminder',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count milestone${count == 1 ? '' : 's'} due soon - review and prioritize to stay on track',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: bodyColor,
                    fontSize: 14,
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

class _TaskStatsGrid extends StatelessWidget {
  const _TaskStatsGrid({
    required this.totalTasks,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.milestoneComplete,
    required this.milestoneTotal,
    required this.teamTasks,
    required this.role,
  });

  final int totalTasks;
  final int pending;
  final int inProgress;
  final int completed;
  final int milestoneComplete;
  final int milestoneTotal;
  final int teamTasks;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitle = role == UserRole.employee ||
            role == UserRole.maintenance ||
            role == UserRole.techSupport
        ? 'Assigned to you'
        : role == UserRole.supervisor
            ? 'Team tasks'
            : 'Across all projects';
    final completedSubtitleColor =
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = 2;
        if (width >= 1024) {
          columns = 6;
        } else if (width >= 768) {
          columns = 3;
        }
        final aspectRatio = columns >= 6 ? 1.4 : (columns == 3 ? 1.6 : 1.6);
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _TaskStatCard(
              label: 'Total Tasks',
              value: totalTasks.toString(),
              icon: Icons.bar_chart,
              subtitle: subtitle,
            ),
            _TaskStatCard(
              label: 'Pending',
              value: pending.toString(),
              icon: Icons.error_outline,
              iconColor: const Color(0xFFEAB308),
              subtitle: 'Awaiting start',
            ),
            _TaskStatCard(
              label: 'In Progress',
              value: inProgress.toString(),
              icon: Icons.schedule,
              iconColor: const Color(0xFF3B82F6),
              subtitle: 'Active now',
            ),
            _TaskStatCard(
              label: 'Completed',
              value: completed.toString(),
              icon: Icons.check_circle,
              iconColor: const Color(0xFF22C55E),
              subtitle: 'Successfully done',
              subtitleColor: completedSubtitleColor,
            ),
            _TaskStatCard(
              label: 'Milestones',
              value: '$milestoneComplete/$milestoneTotal',
              icon: Icons.track_changes,
              iconColor: const Color(0xFFA855F7),
              subtitle: 'Progress tracking',
            ),
            _TaskStatCard(
              label: 'Team Tasks',
              value: teamTasks.toString(),
              icon: Icons.groups_outlined,
              iconColor: const Color(0xFF6366F1),
              subtitle: 'Collaborative work',
            ),
          ],
        );
      },
    );
  }
}

class _TaskStatCard extends StatelessWidget {
  const _TaskStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.subtitle,
    this.iconColor,
    this.subtitleColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final String subtitle;
  final Color? iconColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconTint =
        iconColor ?? (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              Icon(icon, color: iconTint, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: subtitleColor ??
                  (isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280)),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskFilters extends StatelessWidget {
  const _TaskFilters({
    required this.searchQuery,
    required this.status,
    required this.priority,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
  });

  final String searchQuery;
  final String status;
  final String priority;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPriorityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final cardBackground = isDark ? const Color(0xFF1F2937) : Colors.white;
    final inputFill = isDark ? const Color(0xFF111827) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final inputTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final placeholderColor =
        isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    InputDecoration inputDecoration({
      String? hintText,
      IconData? prefixIcon,
    }) {
      return InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: placeholderColor, fontSize: 16),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(
                prefixIcon,
                size: 20,
                color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              ),
        filled: true,
        fillColor: inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 768;
              final searchInput = TextField(
                decoration: inputDecoration(
                  hintText: 'Search tasks...',
                  prefixIcon: Icons.search,
                ),
                style: TextStyle(color: inputTextColor, fontSize: 16),
                onChanged: onSearchChanged,
              );
              final statusField = DropdownButtonFormField<String>(
                value: status,
                isExpanded: true,
                decoration: inputDecoration(),
                dropdownColor: inputFill,
                iconEnabledColor:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                style: TextStyle(color: inputTextColor, fontSize: 16),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      'All Status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text(
                      'Pending',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'in-progress',
                    child: Text(
                      'In Progress',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text(
                      'Completed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'overdue',
                    child: Text(
                      'Overdue',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (value) => onStatusChanged(value ?? 'all'),
              );
              final priorityField = DropdownButtonFormField<String>(
                value: priority,
                isExpanded: true,
                decoration: inputDecoration(),
                dropdownColor: inputFill,
                iconEnabledColor:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                style: TextStyle(color: inputTextColor, fontSize: 16),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      'All Priorities',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text(
                      'High',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text(
                      'Medium',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'low',
                    child: Text(
                      'Low',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (value) => onPriorityChanged(value ?? 'all'),
              );
                final filterButton = OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list, size: 20),
                  label: const Text('More Filters'),
                  style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all(
                      isDark
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF374151),
                    ),
                    textStyle: MaterialStateProperty.all(
                      theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                    ),
                    side: MaterialStateProperty.all(BorderSide(color: inputBorder)),
                    padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  backgroundColor: MaterialStateProperty.resolveWith(
                    (states) => states.contains(MaterialState.hovered)
                        ? (isDark
                            ? const Color(0xFF374151)
                            : const Color(0xFFF9FAFB))
                        : Colors.transparent,
                  ),
                ),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 2, child: searchInput),
                    const SizedBox(width: 16),
                    Expanded(child: statusField),
                    const SizedBox(width: 16),
                    Expanded(child: priorityField),
                    const SizedBox(width: 16),
                    filterButton,
                  ],
                );
              }

              return Column(
                children: [
                  searchInput,
                  const SizedBox(height: 16),
                  statusField,
                  const SizedBox(height: 16),
                  priorityField,
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: filterButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TaskViewSection extends StatelessWidget {
  const _TaskViewSection({
    required this.viewMode,
    required this.onViewModeChanged,
    required this.tasks,
    required this.teamMemberCounts,
    required this.calendarDate,
    required this.onCalendarNext,
    required this.onCalendarPrev,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onOpenTask,
  });

  final _TaskViewMode viewMode;
  final ValueChanged<_TaskViewMode> onViewModeChanged;
  final List<_TaskView> tasks;
  final Map<String, int> teamMemberCounts;
  final DateTime calendarDate;
  final VoidCallback onCalendarNext;
  final VoidCallback onCalendarPrev;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;
  final ValueChanged<_TaskView> onOpenTask;

  @override
  Widget build(BuildContext context) {
    switch (viewMode) {
      case _TaskViewMode.board:
        return _TaskBoardView(
          tasks: tasks,
          viewMode: viewMode,
          onViewModeChanged: onViewModeChanged,
          onOpenTask: onOpenTask,
        );
      case _TaskViewMode.calendar:
        return _TaskCalendarView(
          tasks: tasks,
          viewMode: viewMode,
          onViewModeChanged: onViewModeChanged,
          calendarDate: calendarDate,
          onNext: onCalendarNext,
          onPrev: onCalendarPrev,
          selectedDate: selectedDate,
          onDateSelected: onDateSelected,
          onOpenTask: onOpenTask,
        );
      case _TaskViewMode.list:
        return _TaskListView(
          tasks: tasks,
          teamMemberCounts: teamMemberCounts,
          viewMode: viewMode,
          onViewModeChanged: onViewModeChanged,
          onOpenTask: onOpenTask,
        );
    }
  }
}

class _TaskListView extends StatelessWidget {
  const _TaskListView({
    required this.tasks,
    required this.teamMemberCounts,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onOpenTask,
  });

  final List<_TaskView> tasks;
  final Map<String, int> teamMemberCounts;
  final _TaskViewMode viewMode;
  final ValueChanged<_TaskViewMode> onViewModeChanged;
  final ValueChanged<_TaskView> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _ViewCard(
      title: '${tasks.length} Tasks',
      viewMode: viewMode,
      onViewModeChanged: onViewModeChanged,
      child: tasks.isEmpty
          ? Text(
              'No tasks match your filters.',
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                fontSize: 14,
              ),
            )
          : Column(
              children: tasks
                  .map(
                    (task) => _TaskListCard(
                      task: task,
                      teamMemberCounts: teamMemberCounts,
                      onTap: () => onOpenTask(task),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _BoardStatus {
  const _BoardStatus(this.status, this.label);

  final String status;
  final String label;
}

class _TaskBoardView extends StatelessWidget {
  const _TaskBoardView({
    required this.tasks,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onOpenTask,
  });

  final List<_TaskView> tasks;
  final _TaskViewMode viewMode;
  final ValueChanged<_TaskViewMode> onViewModeChanged;
  final ValueChanged<_TaskView> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final columns = [
      _BoardStatus('pending', 'Pending'),
      _BoardStatus('in-progress', 'In Progress'),
      _BoardStatus('completed', 'Completed'),
      _BoardStatus('overdue', 'Overdue'),
    ];

    return _ViewCard(
      title: 'Task Board',
      viewMode: viewMode,
      onViewModeChanged: onViewModeChanged,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          var columnCount = 1;
          if (width >= 1024) {
            columnCount = 4;
          } else if (width >= 768) {
            columnCount = 2;
          }
          final spacing = 16.0;
          final columnWidth = columnCount == 1
              ? width
              : (width - (columnCount - 1) * spacing) / columnCount;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var i = 0; i < columns.length; i++)
                _BoardColumn(
                  title: columns[i].label,
                  status: columns[i].status,
                  tasks: tasks
                      .where((task) => task.status == columns[i].status)
                      .toList(),
                  width: columnWidth,
                  onOpenTask: onOpenTask,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskCalendarView extends StatelessWidget {
  const _TaskCalendarView({
    required this.tasks,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.calendarDate,
    required this.onNext,
    required this.onPrev,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onOpenTask,
  });

  final List<_TaskView> tasks;
  final _TaskViewMode viewMode;
  final ValueChanged<_TaskViewMode> onViewModeChanged;
  final DateTime calendarDate;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;
  final ValueChanged<_TaskView> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final days = _buildCalendarDays(calendarDate);
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final cardBackground = isDark ? const Color(0xFF1F2937) : Colors.white;

    List<_TaskView> tasksForDate(DateTime date) {
      return tasks
          .where((task) =>
              task.dueDate != null && _isSameDay(task.dueDate!, date))
          .toList();
    }

    List<({ _TaskView task, _Milestone milestone })> milestonesForDate(
        DateTime date) {
      final results = <({ _TaskView task, _Milestone milestone })>[];
      for (final task in tasks) {
        for (final milestone in task.milestones) {
          if (_isSameDay(milestone.dueDate, date)) {
            results.add((task: task, milestone: milestone));
          }
        }
      }
      return results;
    }

    final selectedTasks =
        selectedDate == null ? <_TaskView>[] : tasksForDate(selectedDate!);
    final selectedMilestones = selectedDate == null
        ? <({ _TaskView task, _Milestone milestone })>[]
        : milestonesForDate(selectedDate!);

    Widget navButton(IconData icon, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor:
            isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
          ),
        ),
      );
    }

    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return _ViewCard(
      title: 'Calendar View',
      viewMode: viewMode,
      onViewModeChanged: onViewModeChanged,
      child: Container(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  navButton(Icons.chevron_left, onPrev),
                  Text(
                    _formatMonth(calendarDate),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  navButton(Icons.chevron_right, onNext),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final label in dayLabels)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                isCompact ? label[0] : label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: isDark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    physics: const NeverScrollableScrollPhysics(),
                    children: days.map((day) {
                      if (day == null) {
                        return const SizedBox.shrink();
                      }
                      final dayTasks = tasksForDate(day);
                      final milestonesForDay = milestonesForDate(day);
                      final isSelected = selectedDate != null &&
                          _isSameDay(day, selectedDate!);
                      return _CalendarDayCell(
                        date: day,
                        tasks: dayTasks,
                        milestoneCount: milestonesForDay.length,
                        selected: isSelected,
                        isToday: _isToday(day),
                        compact: isCompact,
                        onTap: () => onDateSelected(day),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (selectedDate != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d, y').format(selectedDate!),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white : const Color(0xFF111827),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedTasks.isEmpty && selectedMilestones.isEmpty)
                      Text(
                        'No tasks or milestones scheduled',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      )
                    else
                      Column(
                        children: [
                          ...selectedTasks.map(
                            (task) => _CalendarTaskCard(
                              task: task,
                              onTap: () => onOpenTask(task),
                            ),
                          ),
                          ...selectedMilestones.map(
                            (entry) => _CalendarMilestoneCard(
                              task: entry.task,
                              milestone: entry.milestone,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewCard extends StatelessWidget {
  const _ViewCard({
    required this.title,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.child,
  });

  final String title;
  final _TaskViewMode viewMode;
  final ValueChanged<_TaskViewMode> onViewModeChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 640;
            final titleText = Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            );
            final selector = _ViewModeSelector(
              viewMode: viewMode,
              onChanged: onViewModeChanged,
            );
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleText,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: selector),
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                titleText,
                selector,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ViewModeSelector extends StatelessWidget {
  const _ViewModeSelector({required this.viewMode, required this.onChanged});

  final _TaskViewMode viewMode;
  final ValueChanged<_TaskViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    final showLabels = MediaQuery.of(context).size.width >= 640;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _ViewModeButton(
            label: 'List',
            icon: Icons.list,
            selected: viewMode == _TaskViewMode.list,
            onTap: () => onChanged(_TaskViewMode.list),
            showLabel: showLabels,
          ),
          _ViewModeButton(
            label: 'Board',
            icon: Icons.grid_view,
            selected: viewMode == _TaskViewMode.board,
            onTap: () => onChanged(_TaskViewMode.board),
            showLabel: showLabels,
          ),
          _ViewModeButton(
            label: 'Calendar',
            icon: Icons.calendar_today_outlined,
            selected: viewMode == _TaskViewMode.calendar,
            onTap: () => onChanged(_TaskViewMode.calendar),
            showLabel: showLabels,
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.showLabel,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedBackground = isDark ? const Color(0xFF374151) : Colors.white;
    final selectedColor =
        isDark ? Colors.white : const Color(0xFF111827);
    final unselectedColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? selectedColor : unselectedColor,
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? selectedColor : unselectedColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskListCard extends StatefulWidget {
  const _TaskListCard({
    required this.task,
    required this.teamMemberCounts,
    required this.onTap,
  });

  final _TaskView task;
  final Map<String, int> teamMemberCounts;
  final VoidCallback onTap;

  @override
  State<_TaskListCard> createState() => _TaskListCardState();
}

class _TaskListCardState extends State<_TaskListCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final task = widget.task;
    final statusColors = _statusColors(task.status);
    final teamColor =
        isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    final teamMemberCount = task.assignedTeam == null
        ? null
        : widget.teamMemberCounts[task.assignedTeam!.toLowerCase()];
    final hasLocation = task.location.trim().isNotEmpty;
    final borderColor = _hovered
        ? (isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB))
        : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB));
    final hoverShadow = _hovered
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: hoverShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    constraints: const BoxConstraints(minHeight: 60),
                    decoration: BoxDecoration(
                      color: _priorityBarColor(task.priority),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _MetaTag(
                              icon: Icons.person_outline,
                              label: task.assignee,
                              iconSize: 16,
                              fontSize: 14,
                            ),
                            if (task.assignedTeam != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.groups_outlined,
                                      size: 16, color: teamColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.assignedTeam!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: teamColor,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (teamMemberCount != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '($teamMemberCount members)',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: const Color(0xFF6B7280),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            if (hasLocation)
                              _MetaTag(
                                icon: Icons.location_on_outlined,
                                label: task.location,
                                iconSize: 16,
                                fontSize: 14,
                              ),
                            if (task.dueDate != null)
                              _MetaTag(
                                icon: Icons.calendar_today_outlined,
                                label: _formatDate(task.dueDate!),
                                iconSize: 16,
                                fontSize: 14,
                              ),
                            _CategoryChip(label: task.category),
                          ],
                        ),
                        if (task.milestones.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _MilestoneProgress(
                            completed: task.milestones
                                .where((milestone) => milestone.completed)
                                .length,
                            total: task.milestones.length,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColors.background,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColors.border),
                      ),
                      child: Text(
                        task.status.replaceAll('-', ' '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColors.text,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MilestoneProgress extends StatelessWidget {
  const _MilestoneProgress({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = total == 0 ? 0.0 : completed / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.track_changes, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Milestones: $completed/$total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor:
                isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
          ),
        ),
      ],
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.title,
    required this.status,
    required this.tasks,
    required this.onOpenTask,
    this.width,
  });

  final String title;
  final String status;
  final List<_TaskView> tasks;
  final ValueChanged<_TaskView> onOpenTask;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColors = _statusColors(status);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColors.background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColors.border),
                ),
                child: Text(
                  tasks.length.toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColors.text,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: tasks.isEmpty
                ? Text(
                    'No tasks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < tasks.length; i++) ...[
                        _BoardTaskCard(
                          task: tasks[i],
                          onTap: () => onOpenTask(tasks[i]),
                        ),
                        if (i != tasks.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _BoardTaskCard extends StatefulWidget {
  const _BoardTaskCard({
    required this.task,
    required this.onTap,
  });

  final _TaskView task;
  final VoidCallback onTap;

  @override
  State<_BoardTaskCard> createState() => _BoardTaskCardState();
}

class _BoardTaskCardState extends State<_BoardTaskCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = _hovered
        ? (isDark ? const Color(0xFF374151) : Colors.white)
        : (isDark
            ? const Color(0xFF374151).withValues(alpha: 0.5)
            : const Color(0xFFF9FAFB));
    final shadow = _hovered
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
        : null;
    final task = widget.task;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
              ),
              boxShadow: shadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _priorityBarColor(task.priority),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _MetaTag(
                            icon: Icons.person_outline,
                            label: _firstName(task.assignee),
                            iconSize: 12,
                            fontSize: 12,
                          ),
                          if (task.dueDate != null)
                            _MetaTag(
                              icon: Icons.calendar_today_outlined,
                              label: _formatDate(task.dueDate!),
                              iconSize: 12,
                              fontSize: 12,
                            ),
                          if (task.assignedTeam != null)
                            _MetaTag(
                              icon: Icons.groups_outlined,
                              label: task.assignedTeam!,
                              highlighted: true,
                              iconSize: 12,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                        ],
                      ),
                      if (task.milestones.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.track_changes,
                                size: 12, color: Color(0xFFA855F7)),
                            const SizedBox(width: 4),
                            Text(
                              '${task.milestones.where((m) => m.completed).length}/${task.milestones.length}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: task.milestones.isEmpty
                                ? 0
                                : task.milestones
                                        .where((m) => m.completed)
                                        .length /
                                    task.milestones.length,
                            minHeight: 4,
                            backgroundColor: isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFE5E7EB),
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarTaskCard extends StatefulWidget {
  const _CalendarTaskCard({required this.task, required this.onTap});

  final _TaskView task;
  final VoidCallback onTap;

  @override
  State<_CalendarTaskCard> createState() => _CalendarTaskCardState();
}

class _CalendarTaskCardState extends State<_CalendarTaskCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final task = widget.task;
    final statusColors = _statusColors(task.status);
    final background = _hovered
        ? (isDark ? const Color(0xFF374151) : Colors.white)
        : (isDark
            ? const Color(0xFF374151).withValues(alpha: 0.5)
            : const Color(0xFFF9FAFB));
    final borderColor =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
    final baseMetaColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final teamMetaColor =
        isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    final hoverShadow = _hovered
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
        : null;

    Widget metaTag(IconData icon, String label, Color color) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
                boxShadow: hoverShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _priorityBarColor(task.priority),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color:
                                isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            metaTag(Icons.person_outline, task.assignee,
                                baseMetaColor),
                            if (task.assignedTeam != null)
                              metaTag(Icons.groups_outlined, task.assignedTeam!,
                                  teamMetaColor),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColors.background,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: statusColors.border),
                              ),
                              child: Text(
                                task.status,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: statusColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarMilestoneCard extends StatelessWidget {
  const _CalendarMilestoneCard({
    required this.task,
    required this.milestone,
  });

  final _TaskView task;
  final _Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFFA855F7).withValues(alpha: 0.1)
        : const Color(0xFFF5F3FF);
    final borderColor = isDark
        ? const Color(0xFFA855F7).withValues(alpha: 0.3)
        : const Color(0xFFE9D5FF);
    final titleColor =
        isDark ? const Color(0xFFD8B4FE) : const Color(0xFF581C87);
    final subtitleColor =
        isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.track_changes,
              size: 16,
              color: Color(0xFFA855F7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Task: ${task.title}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: subtitleColor,
                      fontSize: 12,
                    ),
                  ),
                  if (milestone.completed) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 12, color: Color(0xFF22C55E)),
                        const SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF22C55E),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatefulWidget {
  const _CalendarDayCell({
    required this.date,
    required this.tasks,
    required this.milestoneCount,
    required this.selected,
    required this.isToday,
    required this.compact,
    required this.onTap,
  });

  final DateTime date;
  final List<_TaskView> tasks;
  final int milestoneCount;
  final bool selected;
  final bool isToday;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseBorder =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final hoverBorder =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);
    final border = widget.selected
        ? const Color(0xFF3B82F6)
        : widget.isToday
            ? const Color(0xFFA855F7)
            : (_hovered ? hoverBorder : baseBorder);
    final background = widget.selected
        ? (isDark
            ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
            : const Color(0xFFEFF6FF))
        : widget.isToday
            ? (isDark
                ? const Color(0xFFA855F7).withValues(alpha: 0.1)
                : const Color(0xFFF5F3FF))
            : (isDark
                ? const Color(0xFF1F2937).withValues(alpha: 0.5)
                : Colors.white);
    final dayColor = widget.isToday
        ? (isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED))
        : (isDark ? Colors.white : const Color(0xFF111827));
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(widget.compact ? 4 : 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.date.day.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: dayColor,
                  fontSize: widget.compact ? 12 : 14,
                ),
              ),
              const SizedBox(height: 4),
              if (widget.tasks.isNotEmpty) ...[
                for (final task in widget.tasks.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            _calendarTaskChipColor(task).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: widget.compact ? 8 : 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (widget.tasks.length > 2)
                  Text(
                    '+${widget.tasks.length - 2} more',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: widget.compact ? 8 : 10,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ] else if (widget.milestoneCount > 0) ...[
                Row(
                  children: [
                    Icon(
                      Icons.track_changes,
                      size: widget.compact ? 8 : 12,
                      color: const Color(0xFFA855F7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.milestoneCount.toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: widget.compact ? 8 : 10,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({
    required this.icon,
    required this.label,
    this.highlighted = false,
    this.iconSize = 14,
    this.fontSize = 12,
    this.fontWeight,
    this.colorOverride,
  });

  final IconData icon;
  final String label;
  final bool highlighted;
  final double iconSize;
  final double fontSize;
  final FontWeight? fontWeight;
  final Color? colorOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = colorOverride ??
        (highlighted
            ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
            : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TasksErrorView extends StatelessWidget {
  const _TasksErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 12),
            Text(
              'Unable to load tasks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TaskColors {
  const _TaskColors({required this.background});

  final Color background;

  factory _TaskColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return _TaskColors(
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
    );
  }
}

class _TaskView {
  const _TaskView({
    required this.id,
    required this.title,
    required this.description,
    required this.assignee,
    required this.location,
    required this.priority,
    required this.status,
    required this.category,
    required this.milestones,
    this.assigneeId,
    this.assignedTeam,
    this.dueDate,
    this.completedAt,
    this.completedBy,
    this.sourceTask,
  });

  final String id;
  final String title;
  final String description;
  final String assignee;
  final String location;
  final String priority;
  final String status;
  final String category;
  final List<_Milestone> milestones;
  final String? assigneeId;
  final String? assignedTeam;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? completedBy;
  final Task? sourceTask;
}

class _Milestone {
  const _Milestone({
    required this.title,
    required this.dueDate,
    required this.completed,
    required this.reminderDays,
  });

  final String title;
  final DateTime dueDate;
  final bool completed;
  final int reminderDays;
}

class _TaskNotification {
  const _TaskNotification({
    required this.id,
    required this.type,
    required this.taskTitle,
    required this.message,
    required this.timestamp,
    required this.icon,
    this.assignee,
    this.team,
    this.read = false,
  });

  final int id;
  final String type;
  final String taskTitle;
  final String message;
  final DateTime timestamp;
  final IconData icon;
  final String? assignee;
  final String? team;
  final bool read;

  _TaskNotification copyWith({bool? read}) {
    return _TaskNotification(
      id: id,
      type: type,
      taskTitle: taskTitle,
      message: message,
      timestamp: timestamp,
      icon: icon,
      assignee: assignee,
      team: team,
      read: read ?? this.read,
    );
  }
}

_TaskView _mapTask(Task task) {
  final now = DateTime.now();
  final metadata = task.metadata ?? const <String, dynamic>{};
  final assignedTeam = task.assignedTeam;
  final normalizedTeam = assignedTeam == null || assignedTeam.trim().isEmpty
      ? null
      : assignedTeam.trim();
  final location = metadata['location']?.toString().trim() ?? '';
  final dueDate = task.dueDate;
  final status = _mapStatus(task, now);
  return _TaskView(
    id: task.id,
    title: task.title,
    description: task.description ?? task.instructions ?? '',
    assignee: task.assignedToName ?? 'Unassigned',
    assigneeId: task.assignedTo,
    assignedTeam: normalizedTeam,
    location: location,
    dueDate: dueDate,
    priority: _normalizePriority(task.priority),
    status: status,
    category: metadata['category']?.toString() ?? 'General',
    milestones: _parseMilestones(metadata['milestones']),
    completedAt: task.completedAt,
    completedBy: task.assignedToName,
    sourceTask: task,
  );
}

String _mapStatus(Task task, DateTime now) {
  if (task.isComplete) return 'completed';
  if (task.status == TaskStatus.inProgress) return 'in-progress';
  if (task.dueDate != null && task.dueDate!.isBefore(now)) {
    return 'overdue';
  }
  return 'pending';
}

String _normalizePriority(String? raw) {
  final value = raw?.toLowerCase() ?? 'medium';
  if (value == 'normal') return 'medium';
  if (value == 'urgent') return 'high';
  if (value == 'low' || value == 'medium' || value == 'high') return value;
  return 'medium';
}

List<_Milestone> _parseMilestones(dynamic raw) {
  if (raw is List) {
    return raw.map((item) {
      if (item is Map<String, dynamic>) {
        return _Milestone(
          title: item['title']?.toString() ?? 'Milestone',
          dueDate: DateTime.tryParse(item['dueDate']?.toString() ?? '') ??
              DateTime.now(),
          completed: item['completed'] == true,
          reminderDays: item['reminderDays'] as int? ?? 1,
        );
      }
      return _Milestone(
        title: 'Milestone',
        dueDate: DateTime.now(),
        completed: false,
        reminderDays: 1,
      );
    }).toList();
  }
  return const [];
}

({int completed, int total}) _countMilestones(List<_TaskView> tasks) {
  var completed = 0;
  var total = 0;
  for (final task in tasks) {
    total += task.milestones.length;
    completed += task.milestones.where((milestone) => milestone.completed).length;
  }
  return (completed: completed, total: total);
}

int _countStatus(List<_TaskView> tasks, String status) {
  return tasks.where((task) => task.status == status).length;
}

String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}

String _formatMonth(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _formatDateTime(DateTime date) {
  final local = date.toLocal();
  return '${local.month}/${local.day}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _firstName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return name;
  return trimmed.split(RegExp(r'\s+')).first;
}

List<DateTime?> _buildCalendarDays(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
  final firstWeekday = firstDay.weekday % 7;
  final totalCells =
      ((firstWeekday + daysInMonth) / 7).ceil() * 7;
  return List<DateTime?>.generate(totalCells, (index) {
    final dayNumber = index - firstWeekday + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) return null;
    return DateTime(month.year, month.month, dayNumber);
  });
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isToday(DateTime date) {
  final today = DateTime.now();
  return _isSameDay(date, today);
}

class _PillColors {
  const _PillColors({
    required this.background,
    required this.text,
    required this.border,
  });

  final Color background;
  final Color text;
  final Color border;
}

_PillColors _statusColors(String status) {
  switch (status) {
    case 'completed':
      return _PillColors(
        background: const Color(0xFFD1FAE5),
        text: const Color(0xFF047857),
        border: const Color(0xFFBBF7D0),
      );
    case 'in-progress':
      return _PillColors(
        background: const Color(0xFFDBEAFE),
        text: const Color(0xFF1D4ED8),
        border: const Color(0xFFBFDBFE),
      );
    case 'pending':
      return _PillColors(
        background: const Color(0xFFFEF9C3),
        text: const Color(0xFFA16207),
        border: const Color(0xFFFEF08A),
      );
    case 'overdue':
      return _PillColors(
        background: const Color(0xFFFEE2E2),
        text: const Color(0xFFB91C1C),
        border: const Color(0xFFFECACA),
      );
    default:
      return _PillColors(
        background: const Color(0xFFF3F4F6),
        text: const Color(0xFF374151),
        border: const Color(0xFFE5E7EB),
      );
  }
}

Color _priorityBarColor(String priority) {
  switch (priority) {
    case 'high':
      return const Color(0xFFEF4444);
    case 'medium':
      return const Color(0xFFF59E0B);
    case 'low':
      return const Color(0xFF22C55E);
    default:
      return const Color(0xFF9CA3AF);
  }
}

Color _calendarTaskChipColor(_TaskView task) {
  if (task.status == 'completed') {
    return const Color(0xFF22C55E);
  }
  if (task.status == 'overdue') {
    return const Color(0xFFEF4444);
  }
  if (task.priority == 'high') {
    return const Color(0xFFEF4444);
  }
  if (task.priority == 'medium') {
    return const Color(0xFFF59E0B);
  }
  return const Color(0xFF22C55E);
}

_NotificationAccent _notificationAccent(String type) {
  switch (type) {
    case 'completion':
      return const _NotificationAccent(
        background: Color(0xFF22C55E),
        icon: Color(0xFF22C55E),
      );
    case 'milestone':
      return const _NotificationAccent(
        background: Color(0xFFA855F7),
        icon: Color(0xFFA855F7),
      );
    default:
      return const _NotificationAccent(
        background: Color(0xFFEF4444),
        icon: Color(0xFFEF4444),
      );
  }
}

class _NotificationAccent {
  const _NotificationAccent({required this.background, required this.icon});

  final Color background;
  final Color icon;
}
