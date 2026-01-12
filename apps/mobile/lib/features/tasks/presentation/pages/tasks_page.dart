import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../dashboard/data/active_role_provider.dart';
import '../../data/tasks_provider.dart';
import '../../data/tasks_repository.dart';
import 'task_detail_page.dart';

enum _TaskViewMode { list, board, calendar }

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
  String _filterCategory = 'all';
  String _filterTeam = 'all';
  String? _assigneeFilterId;
  String? _assigneeFilterName;
  final bool _showMoreFilters = false;
  _TaskViewMode _viewMode = _TaskViewMode.list;
  DateTime _calendarDate = DateTime.now();
  DateTime? _selectedDate;
  List<_TaskNotification> _notifications = const [];
  RealtimeChannel? _tasksChannel;

  @override
  void initState() {
    super.initState();
    _assigneeFilterId = widget.initialAssigneeId;
    _assigneeFilterName = widget.initialAssigneeName;
    _subscribeToTaskChanges();
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(activeRoleProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final assigneesAsync = ref.watch(taskAssigneesProvider);
    final colors = _TaskColors.fromTheme(Theme.of(context));
    final canManageTasks = role == UserRole.maintenance ||
        role == UserRole.supervisor ||
        role.canManage;
    
    final isSupervisorOrHigher =
        role == UserRole.supervisor || role.canManage;

    return Scaffold(
      backgroundColor: colors.background,
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _TasksErrorView(error: e.toString()),
        data: (tasks) {
          final mappedTasks = tasks.map(_mapTask).toList();
          final allTasks = mappedTasks;
          final roleTasks = _applyRoleFilter(allTasks, role);
          final filteredTasks = _applyFilters(roleTasks);
          _syncNotifications(roleTasks);
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
          final upcomingMilestones = _countUpcomingMilestones(roleTasks);
          final milestoneTotals = _countMilestones(roleTasks);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TasksHeader(
                role: role,
                onExport: () => _handleExport(filteredTasks),
                canManageTasks: canManageTasks,
                onCreate: () => _openCreateTaskDialog(assigneesAsync),
                accessLabel: accessLabel,
              ),
              if (isSupervisorOrHigher && _notifications.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _NotificationsCard(
                    notifications: _notifications,
                    onMarkAllRead: _markAllNotificationsRead,
                    onMarkRead: _markNotificationRead,
                  ),
                ),
              if (upcomingMilestones > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _MilestoneBanner(count: upcomingMilestones),
                ),
              _TaskStatsGrid(
                totalTasks: roleTasks.length,
                pending: _countStatus(roleTasks, 'pending'),
                inProgress: _countStatus(roleTasks, 'in-progress'),
                completed: _countStatus(roleTasks, 'completed'),
                milestoneComplete: milestoneTotals.completed,
                milestoneTotal: milestoneTotals.total,
                teamTasks:
                    roleTasks.where((task) => task.assignedTeam != null).length,
                role: role,
              ),
              if (_assigneeFilterId != null || _assigneeFilterName != null) ...[
                const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              _TaskFilters(
                searchQuery: _searchQuery,
                status: _filterStatus,
                priority: _filterPriority,
                category: _filterCategory,
                team: _filterTeam,
                categories: _categories(roleTasks),
                teams: _teams(roleTasks),
                showMoreFilters: _showMoreFilters,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
                onStatusChanged: (value) =>
                    setState(() => _filterStatus = value),
                onPriorityChanged: (value) =>
                    setState(() => _filterPriority = value),
                onCategoryChanged: (value) =>
                    setState(() => _filterCategory = value),
                onTeamChanged: (value) =>
                    setState(() => _filterTeam = value),
                onToggleMore: () {},
              ),
              const SizedBox(height: 16),
              _TaskViewSection(
                viewMode: _viewMode,
                onViewModeChanged: (mode) => setState(() => _viewMode = mode),
                tasks: filteredTasks,
                selectedDate: _selectedDate,
                calendarDate: _calendarDate,
                onCalendarNext: _nextMonth,
                onCalendarPrev: _previousMonth,
                onDateSelected: (date) => setState(() => _selectedDate = date),
                onOpenTask: (task) => _openTaskDetail(task, userId),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  List<_TaskView> _applyRoleFilter(List<_TaskView> tasks, UserRole role) {
    if (role == UserRole.techSupport) {
      return tasks;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (role == UserRole.employee || role == UserRole.maintenance) {
      if (userId == null) return tasks;
      final filtered =
          tasks.where((task) => task.assigneeId == userId).toList();
      return filtered.isEmpty ? tasks : filtered;
    }
    if (role == UserRole.supervisor) {
      final filtered = tasks.where((task) {
        final hasTeamAssignment = task.assignedTeam != null;
        final isDirectAssignee =
            userId != null && task.assigneeId == userId;
        return hasTeamAssignment || isDirectAssignee;
      }).toList();
      return filtered.isEmpty ? tasks : filtered;
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
          task.description.toLowerCase().contains(_searchQuery) ||
          task.assignee.toLowerCase().contains(_searchQuery) ||
          task.location.toLowerCase().contains(_searchQuery);
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
      final matchesCategory =
          _filterCategory == 'all' || task.category == _filterCategory;
      final matchesTeam = _filterTeam == 'all' ||
          (task.assignedTeam != null && task.assignedTeam == _filterTeam);
      return matchesQuery &&
          matchesAssignee &&
          matchesStatus &&
          matchesPriority &&
          matchesCategory &&
          matchesTeam;
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
        'tasks-export-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
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
  ) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController =
        TextEditingController(text: 'Main Construction Site');
    DateTime? dueDate;
    String priority = 'medium';
    String category = 'Safety';
    String? assignedTeam;
    const teamOptions = {
      'Safety Team': 3,
      'Maintenance Crew': 3,
      'Installation Squad': 3,
      'Quality Assurance': 3,
      'Electrical Team': 3,
    };
    TaskAssignee? selectedAssignee;

    await showDialog<void>(
      context: context,
      builder: (context) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final border =
                isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
            final labelStyle = theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            );

            Widget labeledField(String label, Widget field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: labelStyle),
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
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  dueDate == null ? 'Select date' : _formatDate(dueDate!),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            );

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Task',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      labeledField(
                        'Task Title',
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            hintText: 'Enter task title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      labeledField(
                        'Description',
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            hintText: 'Enter task description',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          final assigneeField = labeledField(
                            'Assign to Individual',
                            DropdownButtonFormField<TaskAssignee?>(
                              value: selectedAssignee,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              hint: const Text('Select individual...'),
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
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                  ),
                                  hint: const Text('Select team (optional)...'),
                                  items: teamOptions.entries
                                      .map(
                                        (entry) => DropdownMenuItem(
                                          value: entry.key,
                                          child: Text(
                                            '${entry.key} (${entry.value} members)',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setModalState(() => assignedTeam = value),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Team assignment enables collaboration and shared progress tracking',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
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
                              const SizedBox(height: 12),
                              teamField,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          final priorityField = labeledField(
                            'Priority',
                            DropdownButtonFormField<String>(
                              value: priority,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
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
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
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
                              const SizedBox(height: 12),
                              dueDateField,
                              const SizedBox(height: 12),
                              categoryField,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      labeledField(
                        'Location',
                        TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            hintText: 'Enter task location',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(height: 1, color: border),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.flag_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Milestones (Optional)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add milestones to track progress and receive proactive reminders',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add),
                        label: const Text('Add Milestone'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
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
                              child: Text(saving ? 'Saving...' : 'Create Task'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed:
                                saving ? null : () => Navigator.of(context).pop(),
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

  void _syncNotifications(List<_TaskView> tasks) {
    final next = _buildNotifications(tasks);
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
      if (a[i].id != b[i].id || a[i].read != b[i].read) return false;
    }
    return true;
  }

  List<_TaskNotification> _buildNotifications(List<_TaskView> tasks) {
    final now = DateTime.now();
    final List<_TaskNotification> items = [];

    for (final task in tasks) {
      if (task.completedAt != null) {
        items.add(
          _TaskNotification(
            id: 'completion-${task.id}'.hashCode,
            type: 'completion',
            taskTitle: task.title,
            message:
                'Task completed by ${task.assignee}${task.assignedTeam != null ? " (${task.assignedTeam})" : ""}',
            timestamp: task.completedAt!,
            icon: Icons.check_circle,
            assignee: task.assignee,
            team: task.assignedTeam,
            read: false,
          ),
        );
      }

      for (final milestone in task.milestones) {
        if (milestone.completed) continue;
        final daysUntil =
            milestone.dueDate.difference(now).inDays;
        if (daysUntil < 0) {
          items.add(
            _TaskNotification(
              id: 'overdue-${task.id}-${milestone.title}'.hashCode,
              type: 'overdue',
              taskTitle: task.title,
              message:
                  'Milestone "${milestone.title}" is ${daysUntil.abs()} day${daysUntil.abs() == 1 ? "" : "s"} overdue',
              timestamp: now,
              icon: Icons.warning_amber_outlined,
              assignee: task.assignee,
              team: task.assignedTeam,
              read: false,
            ),
          );
        } else if (daysUntil <= milestone.reminderDays) {
          items.add(
            _TaskNotification(
              id: 'milestone-${task.id}-${milestone.title}'.hashCode,
              type: 'milestone',
              taskTitle: task.title,
              message:
                  'Milestone "${milestone.title}" due in $daysUntil day${daysUntil == 1 ? "" : "s"}',
              timestamp: now,
              icon: Icons.flag_outlined,
              assignee: task.assignee,
              team: task.assignedTeam,
              read: false,
            ),
          );
        }
      }

      if (task.status == 'overdue' && task.dueDate != null) {
        final daysOver = now.difference(task.dueDate!).inDays;
        items.add(
          _TaskNotification(
            id: 'task-overdue-${task.id}'.hashCode,
            type: 'overdue',
            taskTitle: task.title,
            message: daysOver == 0
                ? 'Task is overdue today'
                : 'Task is $daysOver day${daysOver == 1 ? "" : "s"} overdue',
            timestamp: now,
            icon: Icons.warning_amber_outlined,
            assignee: task.assignee,
            team: task.assignedTeam,
            read: false,
          ),
        );
      }
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
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
      style: TextButton.styleFrom(
        foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;
        final createLabel = isWide ? 'Create Task' : 'New Task';
        final createButton = FilledButton.icon(
          onPressed: onCreate,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shadowColor: const Color(0x332563EB),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add, size: 20),
          label: Text(createLabel),
        );
        final headerText = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Management',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            if (accessLabel != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withOpacity(0.3)
                      : const Color(0xFFDBEAFE),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
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
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerText,
              const SizedBox(height: 12),
              exportButton,
              if (canManageTasks) ...[
                const SizedBox(height: 12),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
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
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unreadCount new',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (unreadCount > 0)
                TextButton(
                  onPressed: onMarkAllRead,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    foregroundColor:
                        isDark ? Colors.grey[400] : Colors.grey[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (var i = 0; i < (notifications.length > 5 ? 5 : notifications.length); i++)
                _NotificationRow(
                  notification: notifications[i],
                  onMarkRead: onMarkRead,
                  showDivider:
                      i != (notifications.length > 5 ? 4 : notifications.length - 1),
                ),
            ],
          ),
          if (notifications.length > 5) ...[
            const SizedBox(height: 12),
            Text(
              'Showing 5 of ${notifications.length} notifications',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
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
    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.background,
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notification.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                    ),
                  if (notification.team != null)
                    _MetaTag(
                      icon: Icons.groups_outlined,
                      label: notification.team!,
                      highlighted: true,
                    ),
                  Text(
                    _formatDateTime(notification.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            color: isDark ? Colors.grey[400] : Colors.grey[500],
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
                    color:
                        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
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
        isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
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
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count milestone${count == 1 ? '' : 's'} due soon - review and prioritize to stay on track',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: bodyColor,
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
    final subtitle = role == UserRole.employee ||
            role == UserRole.maintenance ||
            role == UserRole.techSupport
        ? 'Assigned to you'
        : role == UserRole.supervisor
            ? 'Team tasks'
            : 'Across all projects';
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = 2;
        if (width >= 1100) {
          columns = 6;
        } else if (width >= 900) {
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
              iconColor: Colors.orange,
              subtitle: 'Awaiting start',
            ),
            _TaskStatCard(
              label: 'In Progress',
              value: inProgress.toString(),
              icon: Icons.schedule,
              iconColor: Colors.blue,
              subtitle: 'Active now',
            ),
            _TaskStatCard(
              label: 'Completed',
              value: completed.toString(),
              icon: Icons.check_circle,
              iconColor: Colors.green,
              subtitle: 'Successfully done',
            ),
            _TaskStatCard(
              label: 'Milestones',
              value: '$milestoneComplete/$milestoneTotal',
              icon: Icons.flag_outlined,
              iconColor: Colors.purple,
              subtitle: 'Progress tracking',
            ),
            _TaskStatCard(
              label: 'Team Tasks',
              value: teamTasks.toString(),
              icon: Icons.groups_outlined,
              iconColor: Colors.indigo,
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
  });

  final String label;
  final String value;
  final IconData icon;
  final String subtitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconTint = iconColor ?? (isDark ? Colors.grey[400]! : Colors.grey[600]!);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
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
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w600,
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
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
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
    required this.category,
    required this.team,
    required this.categories,
    required this.teams,
    required this.showMoreFilters,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onCategoryChanged,
    required this.onTeamChanged,
    required this.onToggleMore,
  });

  final String searchQuery;
  final String status;
  final String priority;
  final String category;
  final String team;
  final List<String> categories;
  final List<String> teams;
  final bool showMoreFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onTeamChanged;
  final VoidCallback onToggleMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final inputFill = isDark ? const Color(0xFF111827) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    InputDecoration inputDecoration({
      String? hintText,
      IconData? prefixIcon,
    }) {
      return InputDecoration(
        hintText: hintText,
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final searchField = Expanded(
                flex: isWide ? 2 : 0,
                child: TextField(
                  decoration: inputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: Icons.search,
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                  onChanged: onSearchChanged,
                ),
              );
              final statusField = Expanded(
                child: DropdownButtonFormField<String>(
                  value: status,
                  isExpanded: true,
                  decoration: inputDecoration(),
                  dropdownColor: inputFill,
                  iconEnabledColor:
                      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
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
                ),
              );
              final priorityField = Expanded(
                child: DropdownButtonFormField<String>(
                  value: priority,
                  isExpanded: true,
                  decoration: inputDecoration(),
                  dropdownColor: inputFill,
                  iconEnabledColor:
                      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
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
                ),
              );
              final filterButton = OutlinedButton.icon(
                onPressed: onToggleMore,
                icon: const Icon(Icons.filter_list, size: 20),
                label: Text(showMoreFilters ? 'Hide Filters' : 'More Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                  side: BorderSide(color: inputBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );

              if (isWide) {
                return Row(
                  children: [
                    searchField,
                    const SizedBox(width: 12),
                    statusField,
                    const SizedBox(width: 12),
                    priorityField,
                    const SizedBox(width: 12),
                    filterButton,
                  ],
                );
              }

              return Column(
                children: [
                  searchField,
                  const SizedBox(height: 12),
                  statusField,
                  const SizedBox(height: 12),
                  priorityField,
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: filterButton,
                  ),
                ],
              );
            },
          ),
          if (showMoreFilters) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final children = [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: category,
                      isExpanded: true,
                      decoration: inputDecoration(hintText: 'All Categories'),
                      dropdownColor: inputFill,
                      iconEnabledColor: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                      items: categories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item == 'all' ? 'All Categories' : item,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => onCategoryChanged(value ?? 'all'),
                    ),
                  ),
                  SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: team,
                      isExpanded: true,
                      decoration: inputDecoration(hintText: 'All Teams'),
                      dropdownColor: inputFill,
                      iconEnabledColor: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                      items: teams
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item == 'all' ? 'All Teams' : item,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => onTeamChanged(value ?? 'all'),
                    ),
                  ),
                ];
                if (isWide) {
                  return Row(children: children);
                }
                return Column(children: children);
              },
            ),
          ],
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
    return _ViewCard(
      title: '${tasks.length} Tasks',
      viewMode: viewMode,
      onViewModeChanged: onViewModeChanged,
      child: tasks.isEmpty
          ? const Text('No tasks match your filters.')
          : Column(
              children: tasks
                  .map(
                    (task) => _TaskListCard(
                      task: task,
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
  });

  final List<_TaskView> tasks;
  final _TaskViewMode viewMode;
  final ValueChanged<_TaskViewMode> onViewModeChanged;

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
          final isWide = constraints.maxWidth >= 1024;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  Expanded(
                    child: _BoardColumn(
                      title: columns[i].label,
                      status: columns[i].status,
                      tasks: tasks
                          .where((task) => task.status == columns[i].status)
                          .toList(),
                    ),
                  ),
                  if (i != columns.length - 1) const SizedBox(width: 16),
                ],
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  _BoardColumn(
                    title: columns[i].label,
                    status: columns[i].status,
                    tasks: tasks
                        .where((task) => task.status == columns[i].status)
                        .toList(),
                    width: 280,
                  ),
                  if (i != columns.length - 1) const SizedBox(width: 16),
                ],
              ],
            ),
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
        child: Padding(
          padding: const EdgeInsets.all(6),
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
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Center(
                              child: Text(
                                isCompact ? label[0] : label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            _ViewModeSelector(
              viewMode: viewMode,
              onChanged: onViewModeChanged,
            ),
          ],
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
          ),
          _ViewModeButton(
            label: 'Board',
            icon: Icons.grid_view,
            selected: viewMode == _TaskViewMode.board,
            onTap: () => onChanged(_TaskViewMode.board),
          ),
          _ViewModeButton(
            label: 'Calendar',
            icon: Icons.calendar_today_outlined,
            selected: viewMode == _TaskViewMode.calendar,
            onTap: () => onChanged(_TaskViewMode.calendar),
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
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedBackground = isDark ? const Color(0xFF374151) : Colors.white;
    final selectedColor = isDark ? Colors.white : Colors.black;
    final unselectedColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
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
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskListCard extends StatelessWidget {
  const _TaskListCard({required this.task, required this.onTap});

  final _TaskView task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColors = _statusColors(task.status, isDark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 60,
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _MetaTag(
                          icon: Icons.person_outline,
                          label: task.assignee,
                        ),
                        if (task.assignedTeam != null)
                          _MetaTag(
                            icon: Icons.groups_outlined,
                            label: task.assignedTeam!,
                            highlighted: true,
                          ),
                        _MetaTag(
                          icon: Icons.location_on_outlined,
                          label: task.location,
                        ),
                        if (task.dueDate != null)
                          _MetaTag(
                            icon: Icons.calendar_today_outlined,
                            label: _formatDate(task.dueDate!),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColors.background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColors.border),
                ),
                child: Text(
                  task.status.replaceAll('-', ' '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
                const Icon(Icons.track_changes, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Milestones: $completed/$total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
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
    this.width,
  });

  final String title;
  final String status;
  final List<_TaskView> tasks;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColors = _statusColors(status, isDark);
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
                    fontWeight: FontWeight.w600,
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
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < tasks.length; i++) ...[
                        _BoardTaskCard(task: tasks[i]),
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
      ),
      child: content,
    );
  }
}

class _BoardTaskCard extends StatelessWidget {
  const _BoardTaskCard({required this.task});

  final _TaskView task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF374151).withValues(alpha: 0.5)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
          ),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _MetaTag(
                        icon: Icons.person_outline,
                        label: task.assignee,
                      ),
                      if (task.dueDate != null)
                        _MetaTag(
                          icon: Icons.calendar_today_outlined,
                          label: _formatShortDate(task.dueDate!),
                        ),
                      if (task.assignedTeam != null)
                        _MetaTag(
                          icon: Icons.groups_outlined,
                          label: task.assignedTeam!,
                          highlighted: true,
                        ),
                    ],
                  ),
                  if (task.milestones.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.track_changes,
                            size: 12, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 4),
                        Text(
                          '${task.milestones.where((m) => m.completed).length}/${task.milestones.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
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
    );
  }
}

class _CalendarTaskCard extends StatelessWidget {
  const _CalendarTaskCard({required this.task, required this.onTap});

  final _TaskView task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColors = _statusColors(task.status, isDark);
    final background = isDark
        ? const Color(0xFF374151).withValues(alpha: 0.5)
        : const Color(0xFFF9FAFB);
    final borderColor =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
    final baseMetaColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final teamMetaColor =
        isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);

    Widget metaTag(IconData icon, String label, Color color) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
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
                        fontWeight: FontWeight.w600,
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
                            task.status.replaceAll('-', ' '),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
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
        ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
        : const Color(0xFFF5F3FF);
    final borderColor = isDark
        ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
        : const Color(0xFFE9D5FF);
    final titleColor =
        isDark ? const Color(0xFFD8B4FE) : const Color(0xFF4C1D95);
    final subtitleColor =
        isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);

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
              color: Color(0xFF8B5CF6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Task: ${task.title}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: subtitleColor,
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

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.tasks,
    required this.milestoneCount,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final List<_TaskView> tasks;
  final int milestoneCount;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = selected
        ? const Color(0xFF2563EB)
        : isToday
            ? const Color(0xFF8B5CF6)
            : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB));
    final background = selected
        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
        : isToday
            ? (isDark
                ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                : const Color(0xFFF5F3FF))
            : (isDark
                ? const Color(0xFF1F2937).withValues(alpha: 0.5)
                : Colors.white);
    final dayColor = isToday
        ? (isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED))
        : (isDark ? Colors.white : const Color(0xFF111827));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date.day.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: dayColor,
              ),
            ),
            const SizedBox(height: 4),
            if (tasks.isNotEmpty) ...[
              for (final task in tasks.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: _calendarTaskChipColor(task).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (tasks.length > 2)
                Text(
                  '+${tasks.length - 2} more',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                  ),
                ),
            ] else if (milestoneCount > 0) ...[
              Row(
                children: [
                  const Icon(
                    Icons.track_changes,
                    size: 12,
                    color: Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    milestoneCount.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
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
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = highlighted
        ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
        : (isDark ? Colors.grey[400] : Colors.grey[600]);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
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
          color: isDark ? Colors.grey[300] : Colors.grey[700],
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
  final dueDate = task.dueDate;
  final status = _mapStatus(task, now);
  return _TaskView(
    id: task.id,
    title: task.title,
    description: task.description ?? task.instructions ?? '',
    assignee: task.assignedToName ?? 'Unassigned',
    assigneeId: task.assignedTo,
    assignedTeam: task.assignedTeam,
    location: metadata['location']?.toString() ?? 'Main Construction Site',
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

int _countUpcomingMilestones(List<_TaskView> tasks) {
  final now = DateTime.now();
  return tasks.fold<int>(0, (count, task) {
    return count +
        task.milestones.where((milestone) {
          if (milestone.completed) return false;
          final diff = milestone.dueDate.difference(now).inDays;
          return diff >= 0 && diff <= milestone.reminderDays;
        }).length;
  });
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

List<String> _categories(List<_TaskView> tasks) {
  final values = tasks.map((task) => task.category).toSet().toList()..sort();
  return ['all', ...values];
}

List<String> _teams(List<_TaskView> tasks) {
  final values = tasks
      .map((task) => task.assignedTeam)
      .whereType<String>()
      .toSet()
      .toList()
    ..sort();
  return ['all', ...values];
}

String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}

String _formatShortDate(DateTime date) {
  return '${date.month}/${date.day}';
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

_PillColors _statusColors(String status, bool isDark) {
  switch (status) {
    case 'completed':
      return _PillColors(
        background: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
        text: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
        border: isDark ? const Color(0xFF065F46) : const Color(0xFF6EE7B7),
      );
    case 'in-progress':
      return _PillColors(
        background: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
        text: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
        border: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE),
      );
    case 'pending':
      return _PillColors(
        background: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
        text: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        border: isDark ? const Color(0xFF92400E) : const Color(0xFFFCD34D),
      );
    case 'overdue':
      return _PillColors(
        background: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
        text: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
        border: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5),
      );
    default:
      return _PillColors(
        background: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        text: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
        border: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
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
        background: Color(0xFFD1FAE5),
        icon: Color(0xFF10B981),
      );
    case 'milestone':
      return const _NotificationAccent(
        background: Color(0xFFEDE9FE),
        icon: Color(0xFF8B5CF6),
      );
    default:
      return const _NotificationAccent(
        background: Color(0xFFFEE2E2),
        icon: Color(0xFFEF4444),
      );
  }
}

class _NotificationAccent {
  const _NotificationAccent({required this.background, required this.icon});

  final Color background;
  final Color icon;
}
