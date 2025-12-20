import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/tasks_provider.dart';
import '../pages/task_editor_page.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({required this.task, super.key});

  final Task task;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  late Task _task;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(tasksRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_task.title),
        actions: [
          IconButton(
            tooltip: 'Edit task',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await Navigator.of(context).push<Task?>(
                MaterialPageRoute(
                  builder: (_) => TaskEditorPage(existing: _task),
                ),
              );
              if (updated == null || !mounted) return;
              setState(() => _task = updated);
              ref.invalidate(tasksProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoTile(
            icon: Icons.flag,
            title: 'Status',
            child: DropdownButtonFormField<TaskStatus>(
              initialValue: _task.status,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: TaskStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.displayName),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (status) async {
                      if (status == null) return;
                      setState(() => _saving = true);
                      final updated = await repo.updateTask(
                        taskId: _task.id,
                        status: status,
                      );
                      if (!mounted) return;
                      setState(() {
                        _task = updated;
                        _saving = false;
                      });
                      ref.invalidate(tasksProvider);
                    },
            ),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.linear_scale,
            title: 'Progress',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _task.progress.toDouble().clamp(0, 100).toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_task.progress}%',
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _task = Task(
                              id: _task.id,
                              orgId: _task.orgId,
                              title: _task.title,
                              description: _task.description,
                              instructions: _task.instructions,
                              status: _task.status,
                              progress: value.round(),
                              dueDate: _task.dueDate,
                              priority: _task.priority,
                              assignedTo: _task.assignedTo,
                              assignedToName: _task.assignedToName,
                              assignedTeam: _task.assignedTeam,
                              createdBy: _task.createdBy,
                              createdAt: _task.createdAt,
                              updatedAt: _task.updatedAt,
                              completedAt: _task.completedAt,
                              metadata: _task.metadata,
                            );
                          });
                        },
                  onChangeEnd: _saving
                      ? null
                      : (value) async {
                          setState(() => _saving = true);
                          final updated = await repo.updateTask(
                            taskId: _task.id,
                            progress: value.round(),
                          );
                          if (!mounted) return;
                          setState(() {
                            _task = updated;
                            _saving = false;
                          });
                          ref.invalidate(tasksProvider);
                        },
                ),
                Text('${_task.progress}% complete'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.calendar_today,
            title: 'Due date',
            child: Row(
              children: [
                Text(
                  _task.dueDate == null
                      ? 'No due date'
                      : _formatDate(_task.dueDate!),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : _pickDueDate,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.person,
            title: 'Assigned to',
            child: Text(_task.assignedToName ?? _task.assignedTeam ?? 'Unassigned'),
          ),
          const SizedBox(height: 12),
          if ((_task.description ?? '').isNotEmpty)
            _InfoTile(
              icon: Icons.description,
              title: 'Description',
              child: Text(_task.description!),
            ),
          if ((_task.instructions ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.list_alt,
              title: 'Instructions',
              child: Text(_task.instructions!),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed:
                _saving || _task.status == TaskStatus.completed ? null : _markComplete,
            icon: const Icon(Icons.check_circle),
            label: const Text('Mark completed'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                _saving || _task.assignedTo == null ? null : _sendReminder,
            icon: const Icon(Icons.notifications_active),
            label: const Text('Send reminder'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final repo = ref.read(tasksRepositoryProvider);
    final selected = await showDatePicker(
      context: context,
      initialDate: _task.dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (selected == null) return;
    setState(() => _saving = true);
    final updated = await repo.updateTask(
      taskId: _task.id,
      dueDate: selected,
    );
    if (!mounted) return;
    setState(() {
      _task = updated;
      _saving = false;
    });
    ref.invalidate(tasksProvider);
  }

  Future<void> _markComplete() async {
    final repo = ref.read(tasksRepositoryProvider);
    setState(() => _saving = true);
    final updated = await repo.updateTask(
      taskId: _task.id,
      status: TaskStatus.completed,
    );
    if (!mounted) return;
    setState(() {
      _task = updated;
      _saving = false;
    });
    ref.invalidate(tasksProvider);
  }

  Future<void> _sendReminder() async {
    final repo = ref.read(tasksRepositoryProvider);
    await repo.sendReminder(_task);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder sent')),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
