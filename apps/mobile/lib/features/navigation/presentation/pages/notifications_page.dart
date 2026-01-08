import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../dashboard/data/dashboard_provider.dart';
import '../../../dashboard/data/active_role_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  _PriorityFilter _filter = _PriorityFilter.all;
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final colors = _NotificationColors.fromTheme(Theme.of(context));
    final role = ref.watch(activeRoleProvider);
    final data = ref.watch(dashboardDataProvider);
    final live = data.asData?.value.notifications ?? const <AppNotification>[];
    final display = _buildDisplayNotifications(role: role, live: live)
        .where((item) => !_dismissed.contains(item.id))
        .toList();
    final filtered = display
        .where(
          (item) => _filter == _PriorityFilter.all || item.priority == _filter,
        )
        .toList();
    final counts = _priorityCounts(display);

    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          const maxWidth = 1024.0;
          final horizontal = constraints.maxWidth > maxWidth
              ? (constraints.maxWidth - maxWidth) / 2
              : 16.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16),
            children: [
              _NotificationsHeader(
                colors: colors,
                roleLabel: _roleDisplayName(role),
                total: display.length,
                onClearAll: display.isEmpty
                    ? null
                    : () => setState(() {
                          _dismissed
                            ..clear()
                            ..addAll(display.map((item) => item.id));
                        }),
              ),
              if (data.hasError) ...[
                const SizedBox(height: 12),
                _ErrorBanner(
                  colors: colors,
                  message: 'Failed to load notifications.',
                ),
              ],
              const SizedBox(height: 16),
              _PriorityFilterCard(
                colors: colors,
                active: _filter,
                counts: counts,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                _EmptyState(colors: colors, filter: _filter)
              else
                Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      _NotificationCard(
                        colors: colors,
                        notification: filtered[i],
                        onDismiss: () => setState(() {
                          _dismissed.add(filtered[i].id);
                        }),
                      ),
                      if (i != filtered.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  List<_NotificationDisplay> _buildDisplayNotifications({
    required UserRole role,
    required List<AppNotification> live,
  }) {
    if (live.isNotEmpty) {
      return live.map(_mapFromAppNotification).toList();
    }
    return _demoNotificationsForRole(role);
  }

  _NotificationDisplay _mapFromAppNotification(AppNotification notification) {
    final priority = _priorityFromNotification(notification);
    final icon = _iconForType(notification.type);
    final time = _formatRelative(notification.createdAt);
    return _NotificationDisplay(
      id: notification.id,
      title: notification.title,
      description: notification.body,
      timeLabel: time,
      priority: priority,
      icon: icon,
    );
  }

  _PriorityFilter _priorityFromNotification(AppNotification notification) {
    final candidates = [
      notification.metadata?['priority'],
      notification.metadata?['priorityLevel'],
      notification.metadata?['severity'],
      notification.metadata?['level'],
      notification.data?['priority'],
      notification.data?['severity'],
      notification.type,
    ];
    for (final candidate in candidates) {
      final parsed = _priorityFromValue(candidate);
      if (parsed != null) return parsed;
    }
    return _PriorityFilter.low;
  }

  _PriorityFilter? _priorityFromValue(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      switch (value.toInt()) {
        case 1:
          return _PriorityFilter.urgent;
        case 2:
          return _PriorityFilter.high;
        case 3:
          return _PriorityFilter.medium;
        case 4:
          return _PriorityFilter.low;
      }
    }
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return null;
    switch (text) {
      case 'urgent':
      case 'critical':
      case 'p1':
      case 'sev1':
      case 'emergency':
      case 'outage':
        return _PriorityFilter.urgent;
      case 'high':
      case 'p2':
      case 'sev2':
      case 'alert':
      case 'error':
      case 'warning':
      case 'incident':
      case 'task':
      case 'task_approval':
      case 'overdue':
      case 'approval':
        return _PriorityFilter.high;
      case 'medium':
      case 'p3':
      case 'sev3':
      case 'training':
      case 'milestone':
      case 'support':
      case 'ticket':
      case 'system':
      case 'request':
        return _PriorityFilter.medium;
      case 'low':
      case 'p4':
      case 'sev4':
      case 'info':
      case 'success':
      case 'message':
      case 'document':
      case 'sop':
      case 'comment':
      case 'update':
      case 'completion':
      case 'backup':
      case 'sync':
        return _PriorityFilter.low;
      default:
        return null;
    }
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'task':
        return Icons.schedule;
      case 'training':
        return Icons.school;
      case 'document':
        return Icons.description;
      case 'alert':
      case 'incident':
        return Icons.warning_amber;
      case 'message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  String _formatRelative(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    final weeks = (diff.inDays / 7).floor();
    return '$weeks weeks ago';
  }

  Map<_PriorityFilter, int> _priorityCounts(
    List<_NotificationDisplay> notifications,
  ) {
    return {
      _PriorityFilter.all: notifications.length,
      _PriorityFilter.urgent:
          notifications.where((n) => n.priority == _PriorityFilter.urgent).length,
      _PriorityFilter.high:
          notifications.where((n) => n.priority == _PriorityFilter.high).length,
      _PriorityFilter.medium:
          notifications.where((n) => n.priority == _PriorityFilter.medium).length,
      _PriorityFilter.low:
          notifications.where((n) => n.priority == _PriorityFilter.low).length,
    };
  }

  List<_NotificationDisplay> _demoNotificationsForRole(UserRole role) {
    final items = <_NotificationDisplay>[];
    void add({
      required String id,
      required String title,
      required String desc,
      required _PriorityFilter priority,
      required String time,
      required IconData icon,
    }) {
      items.add(
        _NotificationDisplay(
          id: id,
          title: title,
          description: desc,
          priority: priority,
          timeLabel: time,
          icon: icon,
        ),
      );
    }

    switch (role) {
      case UserRole.employee:
        add(
          id: 'e-1',
          title: 'New Task Assigned',
          desc: 'Complete safety inspection for Building A by Friday',
          priority: _PriorityFilter.high,
          time: '15 min ago',
          icon: Icons.schedule,
        );
        add(
          id: 'e-2',
          title: 'Training Due Soon',
          desc: 'Annual OSHA certification expires in 7 days',
          priority: _PriorityFilter.medium,
          time: '1 hour ago',
          icon: Icons.school,
        );
        add(
          id: 'e-3',
          title: 'Timesheet Reminder',
          desc: 'Submit your timesheet for this week by EOD tomorrow',
          priority: _PriorityFilter.medium,
          time: '3 hours ago',
          icon: Icons.access_time,
        );
        add(
          id: 'e-4',
          title: 'Message from Supervisor',
          desc: 'Sarah Johnson: Great work on the Johnson project!',
          priority: _PriorityFilter.low,
          time: '5 hours ago',
          icon: Icons.message,
        );
        add(
          id: 'e-5',
          title: 'Asset Assignment',
          desc: 'Equipment #A-1234 has been assigned to you',
          priority: _PriorityFilter.medium,
          time: '6 hours ago',
          icon: Icons.inventory_2,
        );
        add(
          id: 'e-6',
          title: 'Document Updated',
          desc: 'Safety manual v2.1 has been published',
          priority: _PriorityFilter.low,
          time: '1 day ago',
          icon: Icons.description,
        );
        break;
      case UserRole.supervisor:
        add(
          id: 's-1',
          title: 'URGENT: Team Emergency',
          desc: 'Employee reported injury on site - immediate attention needed',
          priority: _PriorityFilter.urgent,
          time: 'Just now',
          icon: Icons.warning_amber,
        );
        add(
          id: 's-2',
          title: 'Approval Required',
          desc: 'Mike Chen submitted timesheet for review - 3 pending approvals',
          priority: _PriorityFilter.high,
          time: '30 min ago',
          icon: Icons.assignment_turned_in,
        );
        add(
          id: 's-3',
          title: 'Task Overdue',
          desc: 'Equipment maintenance task assigned to Sarah is 2 days overdue',
          priority: _PriorityFilter.high,
          time: '1 hour ago',
          icon: Icons.error_outline,
        );
        add(
          id: 's-4',
          title: 'Team Achievement',
          desc: 'Your team completed 95% of weekly tasks - excellent work!',
          priority: _PriorityFilter.low,
          time: '2 hours ago',
          icon: Icons.check_circle,
        );
        add(
          id: 's-5',
          title: 'New Team Member',
          desc: 'Emily Davis has been assigned to your team',
          priority: _PriorityFilter.medium,
          time: '4 hours ago',
          icon: Icons.person_add,
        );
        add(
          id: 's-6',
          title: 'Form Submission',
          desc: 'Daily inspection form completed by Chris Wilson',
          priority: _PriorityFilter.low,
          time: '5 hours ago',
          icon: Icons.description,
        );
        break;
      case UserRole.manager:
        add(
          id: 'm-1',
          title: 'Budget Alert',
          desc: 'Department spending at 85% - review Q4 allocations',
          priority: _PriorityFilter.high,
          time: '30 min ago',
          icon: Icons.attach_money,
        );
        add(
          id: 'm-2',
          title: 'Supervisor Report Due',
          desc: "John Smith's quarterly performance review needs approval",
          priority: _PriorityFilter.medium,
          time: '2 hours ago',
          icon: Icons.people,
        );
        add(
          id: 'm-3',
          title: 'Project Milestone',
          desc: 'Building A construction 90% complete - ahead of schedule',
          priority: _PriorityFilter.low,
          time: '4 hours ago',
          icon: Icons.business_center,
        );
        add(
          id: 'm-4',
          title: 'Team Performance',
          desc: 'Department exceeded productivity goals by 12% this month',
          priority: _PriorityFilter.low,
          time: '1 day ago',
          icon: Icons.trending_up,
        );
        add(
          id: 'm-5',
          title: 'Resource Request',
          desc: 'Maria Garcia requested 3 additional team members for Q1',
          priority: _PriorityFilter.medium,
          time: '1 day ago',
          icon: Icons.group_add,
        );
        add(
          id: 'm-6',
          title: 'Critical Issue',
          desc: 'Equipment Upgrade project budget overrun detected',
          priority: _PriorityFilter.high,
          time: '2 days ago',
          icon: Icons.warning,
        );
        break;
      case UserRole.admin:
        add(
          id: 'a-1',
          title: 'Payroll Processing',
          desc: 'Weekly payroll ready for review - 68 timesheets to approve',
          priority: _PriorityFilter.high,
          time: '1 hour ago',
          icon: Icons.attach_money,
        );
        add(
          id: 'a-2',
          title: 'ADP Integration',
          desc: 'Payroll data successfully synced with ADP',
          priority: _PriorityFilter.medium,
          time: '3 hours ago',
          icon: Icons.check_circle,
        );
        add(
          id: 'a-3',
          title: 'Document Approval',
          desc: '5 documents pending your approval',
          priority: _PriorityFilter.medium,
          time: '5 hours ago',
          icon: Icons.description,
        );
        add(
          id: 'a-4',
          title: 'User Account Request',
          desc: 'New user registration requires admin approval',
          priority: _PriorityFilter.medium,
          time: '6 hours ago',
          icon: Icons.person_add,
        );
        add(
          id: 'a-5',
          title: 'Compliance Report',
          desc: 'Monthly compliance report generated and ready for review',
          priority: _PriorityFilter.low,
          time: '1 day ago',
          icon: Icons.article,
        );
        break;
      case UserRole.techSupport:
        add(
          id: 't-1',
          title: 'Support Ticket Urgent',
          desc: 'Ticket #1234: User cannot access critical system - Priority 1',
          priority: _PriorityFilter.urgent,
          time: 'Just now',
          icon: Icons.support_agent,
        );
        add(
          id: 't-2',
          title: 'System Performance',
          desc: 'Database response time increased by 40% - investigate',
          priority: _PriorityFilter.high,
          time: '45 min ago',
          icon: Icons.storage,
        );
        add(
          id: 't-3',
          title: 'New Support Ticket',
          desc: 'Ticket #1235: Password reset request from Sarah Johnson',
          priority: _PriorityFilter.medium,
          time: '2 hours ago',
          icon: Icons.shield,
        );
        add(
          id: 't-4',
          title: 'Ticket Resolved',
          desc: 'Ticket #1230: Email configuration issue successfully resolved',
          priority: _PriorityFilter.low,
          time: '4 hours ago',
          icon: Icons.check_circle,
        );
        add(
          id: 't-5',
          title: 'System Update',
          desc: 'Security patch scheduled for deployment tonight at 11 PM',
          priority: _PriorityFilter.medium,
          time: '6 hours ago',
          icon: Icons.security,
        );
        break;
      case UserRole.maintenance:
        add(
          id: 'mt-1',
          title: 'Equipment Failure',
          desc: 'HVAC Unit #3 reported malfunction - immediate repair needed',
          priority: _PriorityFilter.urgent,
          time: '20 min ago',
          icon: Icons.warning_amber,
        );
        add(
          id: 'mt-2',
          title: 'Work Order Assigned',
          desc: 'Repair electrical outlet in Conference Room B',
          priority: _PriorityFilter.high,
          time: '1 hour ago',
          icon: Icons.build,
        );
        add(
          id: 'mt-3',
          title: 'Preventive Maintenance',
          desc: 'Monthly generator inspection due this week',
          priority: _PriorityFilter.medium,
          time: '3 hours ago',
          icon: Icons.schedule,
        );
        add(
          id: 'mt-4',
          title: 'Asset Checkout',
          desc: 'Tool Kit #45 checked out successfully',
          priority: _PriorityFilter.low,
          time: '5 hours ago',
          icon: Icons.inventory_2,
        );
        add(
          id: 'mt-5',
          title: 'Safety Alert',
          desc: 'Ladder inspection certifications expire in 10 days',
          priority: _PriorityFilter.medium,
          time: '1 day ago',
          icon: Icons.report,
        );
        break;
      case UserRole.superAdmin:
        add(
          id: 'sa-1',
          title: 'CRITICAL: System Outage',
          desc: 'Database server is down - immediate action required',
          priority: _PriorityFilter.urgent,
          time: 'Just now',
          icon: Icons.warning_amber,
        );
        add(
          id: 'sa-2',
          title: 'Security Alert',
          desc:
              'Multiple failed login attempts detected from IP 192.168.1.45',
          priority: _PriorityFilter.high,
          time: '2 min ago',
          icon: Icons.security,
        );
        add(
          id: 'sa-3',
          title: 'License Expiration',
          desc: 'Enterprise license expires in 30 days - renewal required',
          priority: _PriorityFilter.high,
          time: '1 hour ago',
          icon: Icons.error_outline,
        );
        add(
          id: 'sa-4',
          title: 'Backup Completed',
          desc: 'Automated system backup completed successfully',
          priority: _PriorityFilter.low,
          time: '2 hours ago',
          icon: Icons.check_circle,
        );
        add(
          id: 'sa-5',
          title: 'User Activity Report',
          desc: 'Weekly user activity report generated',
          priority: _PriorityFilter.medium,
          time: '5 hours ago',
          icon: Icons.people,
        );
        add(
          id: 'sa-6',
          title: 'System Maintenance',
          desc: 'Scheduled maintenance window this Sunday 2-4 AM',
          priority: _PriorityFilter.medium,
          time: '1 day ago',
          icon: Icons.dns_outlined,
        );
        break;
      case UserRole.client:
      case UserRole.vendor:
      case UserRole.viewer:
        add(
          id: 'v-1',
          title: 'Updates Available',
          desc: 'New updates are available for your projects',
          priority: _PriorityFilter.low,
          time: '1 day ago',
          icon: Icons.update,
        );
        break;
    }

    return items;
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.colors,
    required this.roleLabel,
    required this.total,
    required this.onClearAll,
  });

  final _NotificationColors colors;
  final String roleLabel;
  final int total;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notifications',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.title,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '$total ${total == 1 ? 'notification' : 'notifications'} for $roleLabel',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colors.muted),
        ),
      ],
    );

    final button = onClearAll == null
        ? const SizedBox.shrink()
        : OutlinedButton(
            onPressed: onClearAll,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.body,
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear All'),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final headerRow = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(Icons.notifications, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(child: title),
          ],
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: headerRow),
              if (onClearAll != null) button,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headerRow,
            if (onClearAll != null) ...[
              const SizedBox(height: 12),
              button,
            ],
          ],
        );
      },
    );
  }
}

class _PriorityFilterCard extends StatelessWidget {
  const _PriorityFilterCard({
    required this.colors,
    required this.active,
    required this.counts,
    required this.onSelected,
  });

  final _NotificationColors colors;
  final _PriorityFilter active;
  final Map<_PriorityFilter, int> counts;
  final ValueChanged<_PriorityFilter> onSelected;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, color: colors.muted),
              const SizedBox(width: 8),
              Text(
                'Filter by Priority',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.title,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _PriorityFilter.values.map((filter) {
              final selected = filter == active;
              final count = counts[filter] ?? 0;
              final background =
                  selected ? colors.primary : colors.filterSurface;
              final foreground = selected ? Colors.white : colors.body;
              final badgeBackground = selected
                  ? Colors.white.withValues(alpha: 0.2)
                  : colors.surface;
              final badgeForeground = selected ? Colors.white : colors.body;
              return TextButton(
                onPressed: () => onSelected(filter),
                style: TextButton.styleFrom(
                  backgroundColor: background,
                  foregroundColor: foreground,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(filter.label),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: badgeForeground,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.colors,
    required this.notification,
    required this.onDismiss,
  });

  final _NotificationColors colors;
  final _NotificationDisplay notification;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final style = _priorityStyle(notification.priority, colors);
    final isDark = colors.isDark;
    final dismissBackground =
        isDark ? const Color(0xFF374151) : Colors.white;
    final dismissBorder =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB);
    final dismissForeground =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: style.border),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: style.accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: style.iconBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(notification.icon, color: style.iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: style.title,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _PriorityChip(
                              style: style,
                              label: notification.priority,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: style.description),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              notification.timeLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: style.time),
                            ),
                            TextButton.icon(
                              onPressed: onDismiss,
                              icon: Icon(
                                Icons.check_circle,
                                size: 14,
                                color: dismissForeground,
                              ),
                              label: Text(
                                'Dismiss',
                                style:
                                    TextStyle(color: dismissForeground, fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: dismissBackground,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: dismissBorder),
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
          ],
        ),
      ),
    );
    if (notification.priority == _PriorityFilter.urgent) {
      return _Pulse(child: card);
    }
    return card;
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.style,
    required this.label,
  });

  final _NotificationPriorityStyle style;
  final _PriorityFilter label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.chipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.label.toUpperCase(),
        style: TextStyle(
          color: style.chipText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.colors,
    required this.filter,
  });

  final _NotificationColors colors;
  final _PriorityFilter filter;

  @override
  Widget build(BuildContext context) {
    final message = filter == _PriorityFilter.all
        ? "You're all caught up!"
        : 'No ${filter.label.toLowerCase()} priority notifications';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.notifications_none, size: 48, color: colors.muted),
          const SizedBox(height: 12),
          Text(
            'No notifications',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.muted),
            textAlign: TextAlign.center,
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

  final _NotificationColors colors;
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

class _NotificationDisplay {
  const _NotificationDisplay({
    required this.id,
    required this.title,
    required this.description,
    required this.timeLabel,
    required this.priority,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final String timeLabel;
  final _PriorityFilter priority;
  final IconData icon;
}

enum _PriorityFilter { all, urgent, high, medium, low }

extension _PriorityFilterLabel on _PriorityFilter {
  String get label {
    switch (this) {
      case _PriorityFilter.all:
        return 'All';
      case _PriorityFilter.urgent:
        return 'Urgent';
      case _PriorityFilter.high:
        return 'High';
      case _PriorityFilter.medium:
        return 'Medium';
      case _PriorityFilter.low:
        return 'Low';
    }
  }
}

class _NotificationColors {
  const _NotificationColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.border,
    required this.muted,
    required this.body,
    required this.title,
    required this.primary,
    required this.primaryContainer,
    required this.filterSurface,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color border;
  final Color muted;
  final Color body;
  final Color title;
  final Color primary;
  final Color primaryContainer;
  final Color filterSurface;

  factory _NotificationColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    return _NotificationColors(
      isDark: isDark,
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      body: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      title: isDark ? Colors.white : const Color(0xFF111827),
      primary: primary,
      primaryContainer:
          isDark ? primary.withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
      filterSurface:
          isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}

class _NotificationPriorityStyle {
  const _NotificationPriorityStyle({
    required this.background,
    required this.border,
    required this.accent,
    required this.title,
    required this.description,
    required this.time,
    required this.chipBackground,
    required this.chipText,
    required this.iconColor,
    required this.iconBackground,
  });

  final Color background;
  final Color border;
  final Color accent;
  final Color title;
  final Color description;
  final Color time;
  final Color chipBackground;
  final Color chipText;
  final Color iconColor;
  final Color iconBackground;
}

_NotificationPriorityStyle _priorityStyle(
  _PriorityFilter priority,
  _NotificationColors colors,
) {
  final isDark = colors.isDark;
  const red50 = Color(0xFFFEF2F2);
  const red100 = Color(0xFFFEE2E2);
  const red200 = Color(0xFFFECACA);
  const red300 = Color(0xFFFCA5A5);
  const red400 = Color(0xFFF87171);
  const red500 = Color(0xFFEF4444);
  const red600 = Color(0xFFDC2626);
  const red700 = Color(0xFFB91C1C);
  const red800 = Color(0xFF991B1B);
  const red900 = Color(0xFF7F1D1D);
  const yellow50 = Color(0xFFFFFBEB);
  const yellow300 = Color(0xFFFCD34D);
  const yellow400 = Color(0xFFFBBF24);
  const yellow500 = Color(0xFFF59E0B);
  const yellow600 = Color(0xFFD97706);
  const yellow700 = Color(0xFFB45309);
  const yellow900 = Color(0xFF78350F);
  const green50 = Color(0xFFF0FDF4);
  const green300 = Color(0xFF86EFAC);
  const green400 = Color(0xFF4ADE80);
  const green500 = Color(0xFF22C55E);
  const green600 = Color(0xFF16A34A);
  const green700 = Color(0xFF15803D);
  const green900 = Color(0xFF14532D);
  final iconSurface = isDark
      ? const Color(0xFF1F2937).withValues(alpha: 0.5)
      : Colors.white.withValues(alpha: 0.5);
  switch (priority) {
    case _PriorityFilter.urgent:
      return _NotificationPriorityStyle(
        background: isDark
            ? red900.withValues(alpha: 0.4)
            : red100,
        border: Colors.transparent,
        accent: red500,
        title: isDark ? red200 : red900,
        description: isDark ? red300 : red800,
        time: isDark ? red400 : red700,
        chipBackground: red600,
        chipText: Colors.white,
        iconColor: isDark ? red400 : red600,
        iconBackground: iconSurface,
      );
    case _PriorityFilter.high:
      return _NotificationPriorityStyle(
        background: isDark
            ? red900.withValues(alpha: 0.2)
            : red50,
        border: Colors.transparent,
        accent: red500,
        title: isDark ? red300 : red900,
        description: isDark ? red400 : red700,
        time: isDark ? red500 : red600,
        chipBackground: red500,
        chipText: Colors.white,
        iconColor: isDark ? red400 : red600,
        iconBackground: iconSurface,
      );
    case _PriorityFilter.medium:
      return _NotificationPriorityStyle(
        background: isDark
            ? yellow900.withValues(alpha: 0.2)
            : yellow50,
        border: Colors.transparent,
        accent: yellow500,
        title: isDark ? yellow300 : yellow900,
        description: isDark ? yellow400 : yellow700,
        time: isDark ? yellow500 : yellow600,
        chipBackground: yellow500,
        chipText: Colors.white,
        iconColor: isDark ? yellow400 : yellow600,
        iconBackground: iconSurface,
      );
    case _PriorityFilter.low:
      return _NotificationPriorityStyle(
        background: isDark
            ? green900.withValues(alpha: 0.2)
            : green50,
        border: Colors.transparent,
        accent: green500,
        title: isDark ? green300 : green900,
        description: isDark ? green400 : green700,
        time: isDark ? green500 : green600,
        chipBackground: green500,
        chipText: Colors.white,
        iconColor: isDark ? green400 : green600,
        iconBackground: iconSurface,
      );
    case _PriorityFilter.all:
      return _NotificationPriorityStyle(
        background: colors.surface,
        border: colors.border,
        accent: colors.primary,
        title: colors.title,
        description: colors.body,
        time: colors.muted,
        chipBackground: colors.primary,
        chipText: Colors.white,
        iconColor: colors.primary,
        iconBackground:
            (isDark ? const Color(0xFF111827) : Colors.white).withValues(
          alpha: 0.6,
        ),
      );
  }
}

String _roleDisplayName(UserRole role) {
  switch (role) {
    case UserRole.employee:
      return 'Employee';
    case UserRole.supervisor:
      return 'Supervisor';
    case UserRole.manager:
      return 'Manager';
    case UserRole.maintenance:
      return 'Maintenance';
    case UserRole.admin:
      return 'Admin';
    case UserRole.superAdmin:
      return 'Super Admin';
    case UserRole.techSupport:
      return 'Tech Support';
    case UserRole.client:
      return 'Client';
    case UserRole.vendor:
      return 'Vendor';
    case UserRole.viewer:
      return 'Viewer';
  }
}
