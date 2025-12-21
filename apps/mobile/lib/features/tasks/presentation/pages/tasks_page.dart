import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/tasks_provider.dart';
import 'task_detail_page.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  String _query = '';
  TaskStatus? _statusFilter;
  bool _mineOnly = false;
  bool _sendingReminders = false;
  RealtimeChannel? _tasksChannel;

  @override
  void initState() {
    super.initState();
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
    final tasksAsync = ref.watch(tasksProvider);
    return tasksAsync.when(
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
                        'Tasks Load Error',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load tasks.',
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
            onPressed: () => ref.invalidate(tasksProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
      data: (tasks) {
        final filtered = _applyFilters(tasks);
        final dueSoon = tasks
            .where((task) => _isDueSoon(task) && task.assignedTo != null)
            .toList();
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tasksProvider);
            await ref.read(tasksProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (dueSoon.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${dueSoon.length} task${dueSoon.length == 1 ? '' : 's'} due soon',
                          ),
                        ),
                        TextButton(
                          onPressed: _sendingReminders
                              ? null
                              : () => _sendDueSoonReminders(dueSoon),
                          child: Text(_sendingReminders ? 'Sending...' : 'Remind'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (dueSoon.isNotEmpty) const SizedBox(height: 12),
              _buildSearchField(),
              const SizedBox(height: 12),
              _buildStatusFilters(),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('My tasks only'),
                value: _mineOnly,
                onChanged: (value) => setState(() => _mineOnly = value),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'No tasks found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Create tasks to assign work and track progress.'),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.map((task) => _TaskCard(task: task)),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Search tasks',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
    );
  }

  Widget _buildStatusFilters() {
    final options = <TaskStatus?>[
      null,
      TaskStatus.todo,
      TaskStatus.inProgress,
      TaskStatus.completed,
      TaskStatus.blocked,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((status) {
        final label = status?.displayName ?? 'All';
        final selected = _statusFilter == status;
        return FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _statusFilter = status),
        );
      }).toList(),
    );
  }

  List<Task> _applyFilters(List<Task> tasks) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return tasks.where((task) {
      final matchesQuery = _query.isEmpty ||
          task.title.toLowerCase().contains(_query) ||
          (task.description?.toLowerCase().contains(_query) ?? false) ||
          (task.instructions?.toLowerCase().contains(_query) ?? false);
      final matchesStatus =
          _statusFilter == null || task.status == _statusFilter;
      final matchesMine = !_mineOnly || (userId != null && task.assignedTo == userId);
      return matchesQuery && matchesStatus && matchesMine;
    }).toList();
  }

  Future<void> _sendDueSoonReminders(List<Task> tasks) async {
    setState(() => _sendingReminders = true);
    final repo = ref.read(tasksRepositoryProvider);
    for (final task in tasks) {
      await repo.sendReminder(task);
    }
    if (!mounted) return;
    setState(() => _sendingReminders = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminders sent')),
    );
  }

  bool _isDueSoon(Task task) {
    if (task.dueDate == null || task.isComplete) return false;
    final diff = task.dueDate!.difference(DateTime.now());
    return diff.inHours >= 0 && diff.inHours <= 24;
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueText = _formatDueDate(task.dueDate);
    final overdue = _isOverdue(task);
    final dueSoon = _isDueSoon(task);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(context, task.status).withValues(alpha: 0.15),
          child: Icon(
            _statusIcon(task.status),
            color: _statusColor(context, task.status),
          ),
        ),
        title: Text(task.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((task.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(task.description!),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (dueText != null)
                  Text(
                    dueText,
                    style: TextStyle(
                      color: overdue
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                if (dueSoon && !overdue) ...[
                  const SizedBox(width: 8),
                  _Pill(
                    label: 'Due soon',
                    color: Colors.orange.shade100,
                  ),
                ],
                if (overdue) ...[
                  const SizedBox(width: 8),
                  _Pill(
                    label: 'Overdue',
                    color: Theme.of(context).colorScheme.errorContainer,
                  ),
                ],
              ],
            ),
            if ((task.assignedToName ?? task.assignedTeam ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.assignedToName ?? task.assignedTeam ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (task.progress.clamp(0, 100)) / 100,
              backgroundColor: Colors.grey.shade200,
              minHeight: 6,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TaskDetailPage(task: task)),
          );
          ref.invalidate(tasksProvider);
        },
      ),
    );
  }

  String? _formatDueDate(DateTime? dueDate) {
    if (dueDate == null) return null;
    final local = dueDate.toLocal();
    return 'Due ${local.month}/${local.day}/${local.year}';
  }

  bool _isOverdue(Task task) {
    if (task.dueDate == null || task.isComplete) return false;
    return task.dueDate!.isBefore(DateTime.now());
  }

  bool _isDueSoon(Task task) {
    if (task.dueDate == null || task.isComplete) return false;
    final diff = task.dueDate!.difference(DateTime.now());
    return diff.inHours >= 0 && diff.inHours <= 24;
  }

  Color _statusColor(BuildContext context, TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.blocked:
        return Theme.of(context).colorScheme.error;
      case TaskStatus.todo:
        return Colors.orange;
    }
  }

  IconData _statusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.inProgress:
        return Icons.timelapse;
      case TaskStatus.blocked:
        return Icons.block;
      case TaskStatus.todo:
        return Icons.playlist_add_check;
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
