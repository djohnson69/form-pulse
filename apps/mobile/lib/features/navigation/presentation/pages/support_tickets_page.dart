import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../tasks/data/tasks_provider.dart';
import '../../../tasks/data/tasks_repository.dart';
import '../../../tasks/presentation/pages/task_detail_page.dart';

class SupportTicketsPage extends ConsumerStatefulWidget {
  const SupportTicketsPage({super.key});

  @override
  ConsumerState<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends ConsumerState<SupportTicketsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'all';
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _TicketColors.fromTheme(Theme.of(context));
    final tasksAsync = ref.watch(tasksProvider);
    final tasks = tasksAsync.asData?.value ?? const <Task>[];
    final tickets = _ticketsFromTasks(tasks);
    final filteredTickets = tickets.where((ticket) {
      final matchesSearch = ticket.title
              .toLowerCase()
              .contains(_searchTerm.toLowerCase()) ||
          ticket.description.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesTab =
          _selectedTab == 'all' || ticket.status == _selectedTab;
      return matchesSearch && matchesTab;
    }).toList();

    final stats = _TicketStats.fromTickets(tickets);

    return Scaffold(
      backgroundColor: colors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (tasksAsync.isLoading) const LinearProgressIndicator(),
          if (tasksAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ErrorBanner(
                message: tasksAsync.error.toString(),
              ),
            ),
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildStatsGrid(context, stats),
          const SizedBox(height: 16),
          _buildTabsAndSearch(context),
          const SizedBox(height: 16),
          if (filteredTickets.isEmpty)
            _EmptyTicketsCard(searchTerm: _searchTerm)
          else
            ...filteredTickets.map(
              (ticket) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TicketCard(
                  ticket: ticket,
                  onViewDetails: () => _handleViewDetails(ticket),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _TicketColors.fromTheme(theme);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support Tickets',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.title,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage and resolve user support requests',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.muted,
          ),
        ),
      ],
    );

    final actionButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      onPressed: () => _openCreateSheet(context),
      icon: const Icon(Icons.add, size: 20),
      label: const Text('Create Ticket'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              actionButton,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: actionButton),
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, _TicketStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _TicketStatCard(
              title: 'Total Tickets',
              value: stats.total.toString(),
              icon: Icons.confirmation_number_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
            ),
            _TicketStatCard(
              title: 'Open',
              value: stats.open.toString(),
              icon: Icons.error_outline,
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
              ),
            ),
            _TicketStatCard(
              title: 'In Progress',
              value: stats.inProgress.toString(),
              icon: Icons.schedule_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              ),
            ),
            _TicketStatCard(
              title: 'Resolved',
              value: stats.resolved.toString(),
              icon: Icons.check_circle_outline,
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabsAndSearch(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _TicketColors.fromTheme(theme);
    final tabs = const ['all', 'open', 'in-progress', 'resolved'];
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
          final tabsWidget = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tabs.map((tab) {
              final isSelected = _selectedTab == tab;
              return TextButton(
                onPressed: () => setState(() => _selectedTab = tab),
                style: TextButton.styleFrom(
                  backgroundColor:
                      isSelected ? colors.primary : colors.filterSurface,
                  foregroundColor: isSelected ? Colors.white : colors.body,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _tabLabel(tab),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          );
          final searchField = SizedBox(
            width: isWide ? 300 : double.infinity,
            child: TextField(
              controller: _searchController,
              decoration: _searchDecoration(colors),
              onChanged: (value) {
                setState(() => _searchTerm = value.trim());
              },
            ),
          );
          if (isWide) {
            return Row(
              children: [
                Expanded(child: tabsWidget),
                const SizedBox(width: 16),
                searchField,
              ],
            );
          }
          return Column(
            children: [
              tabsWidget,
              const SizedBox(height: 12),
              searchField,
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final priorities = const ['low', 'normal', 'high', 'urgent'];
    String priority = 'normal';
    TaskAssignee? assignee;
    bool saving = false;

    final assignees = await ref.read(taskAssigneesProvider.future);
    if (!context.mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Create support ticket',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Issue details',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: priorities
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => priority = value ?? 'normal'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskAssignee?>(
                    value: assignee,
                    decoration: const InputDecoration(
                      labelText: 'Assign to',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<TaskAssignee?>(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      ...assignees.map(
                        (entry) => DropdownMenuItem<TaskAssignee?>(
                          value: entry,
                          child: Text(entry.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => assignee = value),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (titleController.text.trim().isEmpty) return;
                            setState(() => saving = true);
                            await ref.read(tasksRepositoryProvider).createTask(
                                  title: titleController.text.trim(),
                                  description: descController.text.trim().isEmpty
                                      ? null
                                      : descController.text.trim(),
                                  priority: priority,
                                  assignedTo: assignee?.id,
                                  assignedToName: assignee?.name,
                                  metadata: const {'type': 'support_ticket'},
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                    child: Text(saving ? 'Saving...' : 'Create ticket'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    titleController.dispose();
    descController.dispose();
    if (result == true) {
      ref.invalidate(tasksProvider);
    }
  }

  void _handleViewDetails(_TicketItem ticket) {
    if (ticket.task != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskDetailPage(task: ticket.task!)),
      );
      return;
    }
  }

  String _tabLabel(String tab) {
    switch (tab) {
      case 'open':
        return 'Open';
      case 'in-progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return 'All';
    }
  }
}

class _TicketStatCard extends StatelessWidget {
  const _TicketStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final colors = _TicketColors.fromTheme(Theme.of(context));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.muted,
                ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onViewDetails});

  final _TicketItem ticket;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _TicketColors.fromTheme(theme);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _statusIcon(ticket.status),
            color: _statusColor(ticket.status),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      ticket.id,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    _Badge(
                      label: _capitalize(ticket.priority),
                      background:
                          _priorityBackground(ticket.priority, colors.isDark),
                      foreground:
                          _priorityForeground(ticket.priority, colors.isDark),
                    ),
                    _Badge(
                      label: ticket.category,
                      background: colors.filterSurface,
                      foreground: colors.body,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ticket.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.title,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ticket.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colors.primary,
                          child: Text(
                            ticket.userAvatar,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ticket.user,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.body,
                          ),
                        ),
                      ],
                    ),
                    _InlineMeta(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created ${ticket.created}',
                    ),
                    _InlineMeta(
                      icon: Icons.schedule_outlined,
                      label: 'Updated ${ticket.updated}',
                    ),
                    _InlineMeta(
                      icon: Icons.chat_bubble_outline,
                      label: '${ticket.messages} messages',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: onViewDetails,
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _TicketColors.fromTheme(Theme.of(context));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.muted),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.muted,
              ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EmptyTicketsCard extends StatelessWidget {
  const _EmptyTicketsCard({required this.searchTerm});

  final String searchTerm;

  @override
  Widget build(BuildContext context) {
    final colors = _TicketColors.fromTheme(Theme.of(context));
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 48,
            color: colors.muted,
          ),
          const SizedBox(height: 12),
          Text(
            'No tickets found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            searchTerm.isEmpty
                ? 'Try adjusting your search or filters'
                : 'No results for "$searchTerm"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.muted,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = _TicketColors.fromTheme(Theme.of(context));
    final background = colors.danger.withValues(alpha: colors.isDark ? 0.2 : 0.1);
    final border = colors.danger.withValues(alpha: colors.isDark ? 0.5 : 0.3);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.danger,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketColors {
  const _TicketColors({
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
    required this.danger,
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
  final Color danger;

  factory _TicketColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    return _TicketColors(
      isDark: isDark,
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      body: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      title: isDark ? Colors.white : const Color(0xFF111827),
      primary: primary,
      filterSurface:
          isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      inputFill: isDark ? const Color(0xFF0B1220) : Colors.white,
      inputBorder: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      danger: const Color(0xFFDC2626),
    );
  }
}

InputDecoration _searchDecoration(_TicketColors colors) {
  return InputDecoration(
    hintText: 'Search tickets...',
    prefixIcon: Icon(Icons.search, size: 18, color: colors.muted),
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

class _TicketItem {
  const _TicketItem({
    required this.id,
    required this.title,
    required this.description,
    required this.user,
    required this.userAvatar,
    required this.status,
    required this.priority,
    required this.category,
    required this.created,
    required this.updated,
    required this.messages,
    this.task,
  });

  final String id;
  final String title;
  final String description;
  final String user;
  final String userAvatar;
  final String status;
  final String priority;
  final String category;
  final String created;
  final String updated;
  final int messages;
  final Task? task;
}

class _TicketStats {
  const _TicketStats({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.resolved,
  });

  final int total;
  final int open;
  final int inProgress;
  final int resolved;

  factory _TicketStats.fromTickets(List<_TicketItem> tickets) {
    return _TicketStats(
      total: tickets.length,
      open: tickets.where((ticket) => ticket.status == 'open').length,
      inProgress: tickets.where((ticket) => ticket.status == 'in-progress').length,
      resolved: tickets.where((ticket) => ticket.status == 'resolved').length,
    );
  }
}

List<_TicketItem> _ticketsFromTasks(List<Task> tasks) {
  final supportTasks = tasks.where((task) {
    final metadata = task.metadata;
    if (metadata == null) return false;
    return metadata['type'] == 'support_ticket';
  }).toList();

  if (supportTasks.isEmpty) return [];

  return supportTasks.map((task) {
    final userName = task.assignedToName ?? 'Unassigned';
    final status = _statusFromTask(task.status);
    final priority = _priorityFromTask(task.priority);
    final category = task.metadata?['category']?.toString() ?? 'General';
    return _TicketItem(
      id: '#${task.id.substring(0, 6).toUpperCase()}',
      title: task.title,
      description: task.description ?? 'No description provided.',
      user: userName,
      userAvatar: _initials(userName),
      status: status,
      priority: priority,
      category: category,
      created: _relativeTime(task.createdAt),
      updated: _relativeTime(task.updatedAt ?? task.createdAt),
      messages: task.metadata?['messages'] is int
          ? task.metadata!['messages'] as int
          : 0,
      task: task,
    );
  }).toList();
}

String _statusFromTask(TaskStatus status) {
  switch (status) {
    case TaskStatus.inProgress:
      return 'in-progress';
    case TaskStatus.completed:
      return 'resolved';
    case TaskStatus.blocked:
    case TaskStatus.todo:
      return 'open';
  }
}

String _priorityFromTask(String? priority) {
  final normalized = priority?.toLowerCase() ?? 'low';
  switch (normalized) {
    case 'urgent':
      return 'urgent';
    case 'high':
      return 'high';
    case 'normal':
    case 'medium':
      return 'medium';
    default:
      return 'low';
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'open':
      return Icons.error_outline;
    case 'in-progress':
      return Icons.schedule_outlined;
    case 'resolved':
      return Icons.check_circle_outline;
    default:
      return Icons.error_outline;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'open':
      return const Color(0xFF3B82F6);
    case 'in-progress':
      return const Color(0xFFF97316);
    case 'resolved':
      return const Color(0xFF22C55E);
    default:
      return const Color(0xFF6B7280);
  }
}

Color _priorityBackground(String priority, bool isDark) {
  switch (priority) {
    case 'urgent':
      return isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
    case 'high':
      return isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5);
    case 'medium':
      return isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
    case 'low':
      return isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
    default:
      return isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
  }
}

Color _priorityForeground(String priority, bool isDark) {
  switch (priority) {
    case 'urgent':
      return isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
    case 'high':
      return isDark ? const Color(0xFFFDBA74) : const Color(0xFFEA580C);
    case 'medium':
      return isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
    case 'low':
      return isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A);
    default:
      return isDark ? Colors.grey[300]! : Colors.grey[700]!;
  }
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.isEmpty) return 'NA';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String _relativeTime(DateTime date) {
  final now = DateTime.now();
  final delta = now.difference(date);
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) {
    return '${delta.inMinutes} min ago';
  }
  if (delta.inHours < 24) {
    return '${delta.inHours} hours ago';
  }
  if (delta.inDays < 7) {
    return '${delta.inDays} days ago';
  }
  return DateFormat('MMM d').format(date);
}


