import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../dashboard/data/role_override_provider.dart';
class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({required this.task, super.key});

  final Task task;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  late Task _task;
  late Future<UserRole> _roleFuture;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _roleFuture = _fetchUserRole();
  }

  @override
  Widget build(BuildContext context) {
    final roleOverride = ref.watch(roleOverrideProvider);
    final roleFuture =
        roleOverride == null ? _roleFuture : Future.value(roleOverride);
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<UserRole>(
          future: roleFuture,
          builder: (context, snapshot) {
            final role = snapshot.data ?? UserRole.viewer;
            final canManage = role.canManage || role.canSupervise;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Tasks'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHeader(context, canManage),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1000;
                    final main = Column(
                      children: [
                        _DetailsCard(task: _task),
                        const SizedBox(height: 16),
                        _NotesCard(task: _task),
                        const SizedBox(height: 16),
                        const _CommentsCard(),
                      ],
                    );
                    final sidebar = Column(
                      children: [
                        _QuickActionsCard(
                          onMarkComplete: _noopAction,
                          onAddComment: _noopAction,
                          onAttachFile: _noopAction,
                        ),
                        const SizedBox(height: 16),
                        _PriorityCard(priority: _task.priority),
                      ],
                    );
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: main),
                          const SizedBox(width: 16),
                          Expanded(child: sidebar),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        main,
                        const SizedBox(height: 16),
                        sidebar,
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool canManage) {
    final theme = Theme.of(context);
    final statusLabel = _statusLabel(_task.status);
    final statusColor = _statusColor(_task.status, theme.brightness);
    final description = _task.description?.trim() ?? '';

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _task.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            _Pill(label: statusLabel, color: statusColor),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    if (!canManage) {
      return titleBlock;
    }

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _noopAction,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
        FilledButton.icon(
          onPressed: _noopAction,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 12),
            actions,
          ],
        );
      },
    );
  }

  void _noopAction() {}

  Future<UserRole> _fetchUserRole() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return UserRole.viewer;
    try {
      final res = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final raw = res?['role']?.toString() ?? UserRole.viewer.name;
      return UserRole.fromRaw(raw);
    } catch (_) {
      return UserRole.viewer;
    }
  }

  String _statusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return 'pending';
      case TaskStatus.inProgress:
        return 'in progress';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.blocked:
        return 'blocked';
    }
  }

  Color _statusColor(TaskStatus status, Brightness brightness) {
    switch (status) {
      case TaskStatus.todo:
        return brightness == Brightness.dark
            ? const Color(0xFFB45309)
            : const Color(0xFFF59E0B);
      case TaskStatus.inProgress:
        return const Color(0xFF2563EB);
      case TaskStatus.completed:
        return const Color(0xFF16A34A);
      case TaskStatus.blocked:
        return const Color(0xFFDC2626);
    }
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final metadata = task.metadata ?? const <String, dynamic>{};
    final location = _readString(metadata['location'], 'Not specified');
    final createdBy = _readString(
      metadata['createdByName'] ?? metadata['createdBy'],
      task.createdBy ?? 'System',
    );
    final dueDateLabel = task.dueDate == null
        ? 'No due date'
        : DateFormat.yMMMd().format(task.dueDate!.toLocal());
    final createdLabel =
        DateFormat.yMMMd().format(task.createdAt.toLocal());
    final assignee =
        task.assignedToName ?? task.assignedTeam ?? 'Unassigned';

    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            'Task Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.person_outline,
            label: 'Assigned to',
            value: assignee,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.place_outlined,
            label: 'Location',
            value: location,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Due Date',
            value: dueDateLabel,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.schedule,
            label: 'Created',
            value: '$createdLabel by $createdBy',
          ),
        ],
      ),
    );
  }

  String _readString(dynamic value, String fallback) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final metadata = task.metadata ?? const <String, dynamic>{};
    final notes =
        _readString(metadata['notes'], task.instructions ?? 'No notes yet.');
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            'Notes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            notes,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  String _readString(dynamic value, String fallback) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}

class _CommentsCard extends StatelessWidget {
  const _CommentsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
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
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Comments',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'No comments yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onMarkComplete,
    required this.onAddComment,
    required this.onAttachFile,
  });

  final VoidCallback onMarkComplete;
  final VoidCallback onAddComment;
  final VoidCallback onAttachFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onMarkComplete,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Mark Complete'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onAddComment,
            child: const Text('Add Comment'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onAttachFile,
            child: const Text('Attach File'),
          ),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.priority});

  final String? priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final resolved = (priority ?? 'normal').toLowerCase();
    final color = _priorityColor(resolved);
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            'Priority',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _Pill(label: resolved, color: color),
        ],
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFDC2626);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF6B7280);
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
