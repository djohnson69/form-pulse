import 'dart:developer' as developer;

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
            final canManage = role == UserRole.maintenance ||
                role == UserRole.supervisor ||
                role.canManage;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final isWideLayout =
                MediaQuery.of(context).size.width >= 768;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1024),
                child: ListView(
                  padding: EdgeInsets.all(isWideLayout ? 24 : 16),
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, size: 20),
                      label: const Text('Back to Tasks'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        foregroundColor: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildHeader(context, canManage),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 1024;
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool canManage) {
    final theme = Theme.of(context);
    final statusLabel = _statusLabel(_task.status);
    final statusColors = _statusPillColors(_task.status);
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
            _Pill(
              label: statusLabel,
              backgroundColor: statusColors.background,
              textColor: statusColors.text,
            ),
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
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: const Color(0x332563EB),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          label: const Text('Edit'),
        ),
        FilledButton.icon(
          onPressed: _noopAction,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: const Color(0x33DC2626),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
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
    } catch (e, st) {
      developer.log('TaskDetailPage get user role failed',
          error: e, stackTrace: st, name: 'TaskDetailPage._getUserRole');
      return UserRole.viewer;
    }
  }

  String _statusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return 'pending';
      case TaskStatus.inProgress:
        return 'in-progress';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.blocked:
        return 'blocked';
    }
  }

  _PillPalette _statusPillColors(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return const _PillPalette(
          background: Color(0xFFFEF3C7),
          text: Color(0xFFB45309),
        );
      case TaskStatus.inProgress:
        return const _PillPalette(
          background: Color(0xFFDBEAFE),
          text: Color(0xFF1D4ED8),
        );
      case TaskStatus.completed:
        return const _PillPalette(
          background: Color(0xFFD1FAE5),
          text: Color(0xFF047857),
        );
      case TaskStatus.blocked:
        return const _PillPalette(
          background: Color(0xFFFEE2E2),
          text: Color(0xFFB91C1C),
        );
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
        : DateFormat('M/d/y').format(task.dueDate!.toLocal());
    final createdLabel =
        DateFormat('M/d/y').format(task.createdAt.toLocal());
    final assignee = _readString(task.assignedToName, 'Unassigned');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
            'No comments yet',
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
    final isDark = theme.brightness == Brightness.dark;
    final border = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
            icon: const Icon(Icons.check_circle),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 2,
              shadowColor: const Color(0x3316A34A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            label: const Text('Mark Complete'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onAddComment,
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFF374151),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFD1D5DB),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add Comment'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onAttachFile,
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFF374151),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFD1D5DB),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
    final resolved = _normalizePriority((priority ?? 'normal').toLowerCase());
    final colors = _priorityPillColors(resolved);
    final label = _capitalize(resolved);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
          Text(
            'Priority',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _Pill(
            label: label,
            backgroundColor: colors.background,
            textColor: colors.text,
          ),
        ],
      ),
    );
  }

  String _normalizePriority(String priority) {
    if (priority == 'normal') return 'medium';
    if (priority == 'urgent') return 'high';
    return priority;
  }

  _PillPalette _priorityPillColors(String priority) {
    switch (priority) {
      case 'high':
        return const _PillPalette(
          background: Color(0xFFFEE2E2),
          text: Color(0xFFB91C1C),
        );
      case 'medium':
        return const _PillPalette(
          background: Color(0xFFFEF3C7),
          text: Color(0xFFB45309),
        );
      case 'low':
        return const _PillPalette(
          background: Color(0xFFD1FAE5),
          text: Color(0xFF047857),
        );
      default:
        return const _PillPalette(
          background: Color(0xFFF3F4F6),
          text: Color(0xFF374151),
        );
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    this.color,
    this.backgroundColor,
    this.textColor,
  }) : assert(
          color != null || (backgroundColor != null && textColor != null),
        );

  final String label;
  final Color? color;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final resolvedBackground =
        backgroundColor ?? color!.withValues(alpha: 0.15);
    final resolvedText = textColor ?? color!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: resolvedText,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PillPalette {
  const _PillPalette({required this.background, required this.text});

  final Color background;
  final Color text;
}
