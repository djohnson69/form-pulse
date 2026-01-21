import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../admin/data/admin_models.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../../documents/presentation/pages/documents_page.dart';
import '../../../navigation/presentation/pages/notifications_page.dart';
import '../../../navigation/presentation/pages/support_tickets_page.dart';
import '../../../navigation/presentation/pages/system_logs_page.dart';
import '../../../navigation/presentation/pages/user_directory_page.dart';
import '../../../navigation/presentation/widgets/side_menu.dart';
import '../../../ops/presentation/pages/news_posts_page.dart';
import '../../../partners/presentation/pages/messages_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../sop/presentation/pages/sop_library_page.dart';
import '../../data/platform_providers.dart';
import '../widgets/emulate_user_dialog.dart';
import '../widgets/org_selector.dart';
import 'active_sessions_page.dart';
import 'all_organizations_page.dart';
import 'impersonation_log_page.dart';
import 'user_activity_page.dart';

class TechSupportConsolePage extends ConsumerStatefulWidget {
  const TechSupportConsolePage({super.key});

  @override
  ConsumerState<TechSupportConsolePage> createState() => _TechSupportConsolePageState();
}

class _TechSupportConsolePageState extends ConsumerState<TechSupportConsolePage> {
  SideMenuRoute _activeRoute = SideMenuRoute.dashboard;

  void _setRoute(SideMenuRoute route) {
    setState(() => _activeRoute = route);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      role: UserRole.techSupport,
      activeRoute: _activeRoute,
      onNavigate: _setRoute,
      showRightSidebar: false,
      maxContentWidth: 1400,
      child: _techSupportPageForRoute(
        _activeRoute,
        onNavigate: _setRoute,
      ),
    );
  }
}

Widget _techSupportPageForRoute(
  SideMenuRoute route, {
  required ValueChanged<SideMenuRoute> onNavigate,
}) {
  if (route == SideMenuRoute.dashboard) {
    return _TechSupportDashboardBody(onNavigate: onNavigate);
  }
  return switch (route) {
    SideMenuRoute.notifications => const NotificationsPage(),
    SideMenuRoute.messages => const MessagesPage(),
    SideMenuRoute.companyNews => const NewsPostsPage(),
    SideMenuRoute.organization => const AllOrganizationsPage(),
    SideMenuRoute.supportTickets => const SupportTicketsPage(),
    SideMenuRoute.users => const UserDirectoryPage(),
    SideMenuRoute.documents => const DocumentsPage(),
    SideMenuRoute.knowledgeBase => const SopLibraryPage(),
    SideMenuRoute.systemLogs => const SystemLogsPage(),
    SideMenuRoute.settings => const SettingsPage(),
    // Platform-level routes
    SideMenuRoute.activeSessions => const ActiveSessionsPage(),
    SideMenuRoute.userActivity => const UserActivityPage(),
    SideMenuRoute.impersonationLog => const ImpersonationLogPage(),
    _ => _TechSupportDashboardBody(onNavigate: onNavigate),
  };
}

class _TechSupportDashboardBody extends ConsumerWidget {
  const _TechSupportDashboardBody({required this.onNavigate});

  final ValueChanged<SideMenuRoute> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(platformSupportTicketsProvider);
    final usersAsync = ref.watch(platformUsersProvider);
    final orgsAsync = ref.watch(platformOrganizationsProvider);
    final emulatedUser = ref.watch(emulatedUserProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        final horizontalPadding = constraints.maxWidth > 1100 ? 24.0 : 16.0;
        final sectionSpacing = isCompact ? 20.0 : 16.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 24),
          children: [
            // Header
            _buildHeader(context, isDark, isCompact, ref),
            SizedBox(height: sectionSpacing),

            // Emulation Banner
            if (emulatedUser != null) ...[
              _EmulationCard(user: emulatedUser, ref: ref),
              SizedBox(height: sectionSpacing),
            ],

            // Quick Stats
            _QuickStatsRow(
              orgsAsync: orgsAsync,
              usersAsync: usersAsync,
              ticketsAsync: ticketsAsync,
            ),
            SizedBox(height: sectionSpacing),

            // Quick Actions
            _TechSupportQuickActions(onNavigate: onNavigate, ref: ref),
            SizedBox(height: sectionSpacing),

            // Two column layout
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _SupportTicketsSection(
                          ticketsAsync: ticketsAsync,
                          onNavigate: onNavigate,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _RecentUsersSection(
                          usersAsync: usersAsync,
                          onNavigate: onNavigate,
                          ref: ref,
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _SupportTicketsSection(
                      ticketsAsync: ticketsAsync,
                      onNavigate: onNavigate,
                    ),
                    SizedBox(height: sectionSpacing),
                    _RecentUsersSection(
                      usersAsync: usersAsync,
                      onNavigate: onNavigate,
                      ref: ref,
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isCompact, WidgetRef ref) {
    final theme = Theme.of(context);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.support_agent,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support Console',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Help users across all organizations',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Org Selector
        Row(
          children: [
            Icon(
              Icons.filter_list,
              size: 16,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Text(
              'Viewing:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            const OrgSelector(),
          ],
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionButton(
          icon: Icons.supervisor_account,
          label: 'Emulate User',
          color: const Color(0xFF0EA5E9),
          onPressed: () async {
            final user = await EmulateUserDialog.show(context);
            if (user != null) {
              ref.read(emulatedUserProvider.notifier).state = user;
            }
          },
        ),
        _ActionButton(
          icon: Icons.search,
          label: 'Find User',
          color: const Color(0xFF8B5CF6),
          onPressed: () => onNavigate(SideMenuRoute.users),
        ),
      ],
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 16),
          actions,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: header),
        const SizedBox(width: 16),
        actions,
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: color.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _EmulationCard extends StatelessWidget {
  const _EmulationCard({required this.user, required this.ref});

  final EmulatedUser user;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0369A1).withValues(alpha: 0.3), const Color(0xFF0EA5E9).withValues(alpha: 0.2)]
              : [const Color(0xFFE0F2FE), const Color(0xFFF0F9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF0EA5E9) : const Color(0xFF7DD3FC),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.3 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.supervisor_account,
              color: Color(0xFF0EA5E9),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currently Emulating',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.displayName} (${user.role.displayName})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                if (user.orgName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.orgName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              ref.read(emulatedUserProvider.notifier).state = null;
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('End Session', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.orgsAsync,
    required this.usersAsync,
    required this.ticketsAsync,
  });

  final AsyncValue<List<AdminOrgSummary>> orgsAsync;
  final AsyncValue<List<AdminUserSummary>> usersAsync;
  final AsyncValue<List<SupportTicket>> ticketsAsync;

  @override
  Widget build(BuildContext context) {
    final openTickets = ticketsAsync.whenData(
      (tickets) => tickets.where((t) => t.status == 'open').length,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;
        final children = [
          Expanded(
            child: _QuickStatCard(
              label: 'Organizations',
              value: orgsAsync.when(
                data: (orgs) => '${orgs.length}',
                loading: () => '...',
                error: (_, __) => '0',
              ),
              icon: Icons.apartment,
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickStatCard(
              label: 'Total Users',
              value: usersAsync.when(
                data: (users) => '${users.length}',
                loading: () => '...',
                error: (_, __) => '0',
              ),
              icon: Icons.people,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickStatCard(
              label: 'Open Tickets',
              value: openTickets.when(
                data: (count) => '$count',
                loading: () => '...',
                error: (_, __) => '0',
              ),
              icon: Icons.confirmation_number,
              color: const Color(0xFFF59E0B),
            ),
          ),
        ];

        if (isCompact) {
          return Column(
            children: children.where((w) => w is! SizedBox).map((w) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(width: double.infinity, child: w),
              );
            }).toList(),
          );
        }

        return Row(children: children);
      },
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TechSupportQuickActions extends StatelessWidget {
  const _TechSupportQuickActions({required this.onNavigate, required this.ref});

  final ValueChanged<SideMenuRoute> onNavigate;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickActionChip(
                icon: Icons.confirmation_number,
                label: 'Support Tickets',
                onTap: () => onNavigate(SideMenuRoute.supportTickets),
              ),
              _QuickActionChip(
                icon: Icons.people,
                label: 'Find User',
                onTap: () => onNavigate(SideMenuRoute.users),
              ),
              _QuickActionChip(
                icon: Icons.apartment,
                label: 'All Organizations',
                onTap: () => onNavigate(SideMenuRoute.organization),
              ),
              _QuickActionChip(
                icon: Icons.supervisor_account,
                label: 'Emulate User',
                onTap: () async {
                  final user = await EmulateUserDialog.show(context);
                  if (user != null) {
                    ref.read(emulatedUserProvider.notifier).state = user;
                  }
                },
              ),
              _QuickActionChip(
                icon: Icons.menu_book,
                label: 'Knowledge Base',
                onTap: () => onNavigate(SideMenuRoute.knowledgeBase),
              ),
              _QuickActionChip(
                icon: Icons.storage,
                label: 'System Logs',
                onTap: () => onNavigate(SideMenuRoute.systemLogs),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportTicketsSection extends StatelessWidget {
  const _SupportTicketsSection({
    required this.ticketsAsync,
    required this.onNavigate,
  });

  final AsyncValue<List<SupportTicket>> ticketsAsync;
  final ValueChanged<SideMenuRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.confirmation_number,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Recent Support Tickets',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => onNavigate(SideMenuRoute.supportTickets),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ticketsAsync.when(
            data: (tickets) {
              if (tickets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 48,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No open tickets',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tickets.take(5).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  return _TicketTile(ticket: ticket);
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load tickets',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');

    final priorityColor = switch (ticket.priority) {
      'high' => const Color(0xFFEF4444),
      'medium' => const Color(0xFFF59E0B),
      'low' => const Color(0xFF10B981),
      _ => const Color(0xFF6B7280),
    };

    final statusColor = switch (ticket.status) {
      'open' => const Color(0xFFF59E0B),
      'in-progress' || 'in_progress' => const Color(0xFF3B82F6),
      'resolved' || 'closed' => const Color(0xFF10B981),
      _ => const Color(0xFF6B7280),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151).withValues(alpha: 0.5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          // Priority indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      ticket.userName ?? 'Unknown user',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    if (ticket.orgName != null) ...[
                      Text(
                        ' • ',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                      ),
                      Text(
                        ticket.orgName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ticket.status,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Time
          Text(
            ticket.createdAt != null ? timeFormat.format(ticket.createdAt!) : '',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentUsersSection extends StatelessWidget {
  const _RecentUsersSection({
    required this.usersAsync,
    required this.onNavigate,
    required this.ref,
  });

  final AsyncValue<List<AdminUserSummary>> usersAsync;
  final ValueChanged<SideMenuRoute> onNavigate;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people,
                color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Recent Users',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => onNavigate(SideMenuRoute.users),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          usersAsync.when(
            data: (users) {
              if (users.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No users found',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: users.take(6).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _UserTile(
                    user: user,
                    onEmulate: () {
                      ref.read(emulatedUserProvider.notifier).state = EmulatedUser(
                        id: user.id,
                        email: user.email,
                        role: user.role,
                        orgId: user.orgId,
                        firstName: user.firstName,
                        lastName: user.lastName,
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load users',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onEmulate,
  });

  final AdminUserSummary user;
  final VoidCallback onEmulate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayName = _formatDisplayName();
    final initials = _getInitials(displayName);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.1),
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: Color(0xFF8B5CF6),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              Text(
                user.role.displayName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onEmulate,
          icon: const Icon(Icons.supervisor_account, size: 18),
          tooltip: 'Emulate user',
          style: IconButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          ),
        ),
      ],
    );
  }

  String _formatDisplayName() {
    if (user.firstName.isNotEmpty) {
      if (user.lastName.isNotEmpty) {
        return '${user.firstName} ${user.lastName}';
      }
      return user.firstName;
    }
    return user.email.split('@').first;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      final first = parts.first;
      if (first.isEmpty) return 'U';
      return first.length == 1 ? first.toUpperCase() : first.substring(0, 2).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
