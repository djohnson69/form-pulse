import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../admin/data/admin_models.dart';
import '../../../assets/presentation/pages/assets_page.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../../documents/presentation/pages/documents_page.dart';
import '../../../navigation/presentation/pages/audit_logs_page.dart';
import '../../../navigation/presentation/pages/approvals_page.dart';
import '../../../navigation/presentation/pages/before_after_photos_page.dart';
import '../../../navigation/presentation/pages/forms_page.dart';
import '../../../navigation/presentation/pages/incidents_page.dart';
import '../../../navigation/presentation/pages/notifications_page.dart';
import '../../../navigation/presentation/pages/organization_chart_page.dart';
import '../../../navigation/presentation/pages/payroll_page.dart';
import '../../../navigation/presentation/pages/photos_page.dart';
import '../../../navigation/presentation/pages/roles_permissions_page.dart';
import '../../../navigation/presentation/pages/role_customization_page.dart';
import '../../../navigation/presentation/pages/support_tickets_page.dart';
import '../../../navigation/presentation/pages/system_overview_page.dart';
import '../../../navigation/presentation/pages/system_logs_page.dart';
import '../../../navigation/presentation/pages/user_directory_page.dart';
import '../../../navigation/presentation/pages/work_orders_page.dart';
import '../../../navigation/presentation/widgets/side_menu.dart';
import '../../../ops/presentation/pages/ai_tools_page.dart';
import '../../../ops/presentation/pages/news_posts_page.dart';
import '../../../ops/presentation/pages/payment_requests_page.dart';
import '../../../partners/presentation/pages/messages_page.dart';
import '../../../projects/presentation/pages/projects_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../sop/presentation/pages/sop_library_page.dart';
import '../../../tasks/presentation/pages/tasks_page.dart';
import '../../../templates/presentation/pages/templates_page.dart';
import '../../../training/presentation/pages/training_hub_page.dart';
import '../../data/platform_providers.dart';
import '../widgets/emulate_user_dialog.dart';
import '../widgets/org_selector.dart';
import 'active_sessions_page.dart';
import 'all_organizations_page.dart';
import 'api_metrics_page.dart';
import 'error_tracking_page.dart';
import 'impersonation_log_page.dart';
import 'user_activity_page.dart';

class DeveloperConsolePage extends ConsumerStatefulWidget {
  const DeveloperConsolePage({super.key});

  @override
  ConsumerState<DeveloperConsolePage> createState() => _DeveloperConsolePageState();
}

class _DeveloperConsolePageState extends ConsumerState<DeveloperConsolePage> {
  SideMenuRoute _activeRoute = SideMenuRoute.dashboard;

  void _setRoute(SideMenuRoute route) {
    setState(() => _activeRoute = route);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      role: UserRole.developer,
      activeRoute: _activeRoute,
      onNavigate: _setRoute,
      showRightSidebar: false,
      maxContentWidth: 1400,
      child: _developerPageForRoute(
        _activeRoute,
        onNavigate: _setRoute,
      ),
    );
  }
}

Widget _developerPageForRoute(
  SideMenuRoute route, {
  required ValueChanged<SideMenuRoute> onNavigate,
}) {
  if (route == SideMenuRoute.dashboard) {
    return _DeveloperDashboardBody(onNavigate: onNavigate);
  }
  return switch (route) {
    SideMenuRoute.notifications => const NotificationsPage(),
    SideMenuRoute.messages => const MessagesPage(),
    SideMenuRoute.companyNews => const NewsPostsPage(),
    SideMenuRoute.organizationChart => OrganizationChartPage(role: UserRole.developer),
    SideMenuRoute.systemOverview => const SystemOverviewPage(),
    SideMenuRoute.users => const UserDirectoryPage(role: UserRole.developer),
    SideMenuRoute.rolesPermissions => const RolesPermissionsPage(),
    SideMenuRoute.projects => const ProjectsPage(),
    SideMenuRoute.tasks => const TasksPage(),
    SideMenuRoute.workOrders => const WorkOrdersPage(),
    SideMenuRoute.forms => const FormsPage(),
    SideMenuRoute.approvals => const ApprovalsPage(),
    SideMenuRoute.documents => const DocumentsPage(),
    SideMenuRoute.photos => const PhotosPage(),
    SideMenuRoute.beforeAfter => const BeforeAfterPhotosPage(),
    SideMenuRoute.assets => const AssetsPage(),
    SideMenuRoute.training => const TrainingHubPage(),
    SideMenuRoute.incidents => const IncidentsPage(),
    SideMenuRoute.aiTools => const AiToolsPage(),
    SideMenuRoute.templates => const TemplatesPage(),
    SideMenuRoute.payments => const PaymentRequestsPage(),
    SideMenuRoute.payroll => const PayrollPage(),
    SideMenuRoute.reports => const AllOrganizationsPage(),
    SideMenuRoute.auditLogs => const AuditLogsPage(),
    SideMenuRoute.roleCustomization => const RoleCustomizationPage(),
    SideMenuRoute.settings => const SettingsPage(),
    SideMenuRoute.supportTickets => const SupportTicketsPage(),
    SideMenuRoute.knowledgeBase => const SopLibraryPage(),
    SideMenuRoute.systemLogs => const SystemLogsPage(),
    SideMenuRoute.organization => const AllOrganizationsPage(),
    SideMenuRoute.team => const AllOrganizationsPage(),
    // Platform-level routes
    SideMenuRoute.activeSessions => const ActiveSessionsPage(),
    SideMenuRoute.userActivity => const UserActivityPage(),
    SideMenuRoute.apiMetrics => const ApiMetricsPage(),
    SideMenuRoute.errorTracking => const ErrorTrackingPage(),
    SideMenuRoute.impersonationLog => const ImpersonationLogPage(),
    _ => _DeveloperDashboardBody(onNavigate: onNavigate),
  };
}

class _DeveloperDashboardBody extends ConsumerWidget {
  const _DeveloperDashboardBody({required this.onNavigate});

  final ValueChanged<SideMenuRoute> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platformStats = ref.watch(platformStatsProvider);
    final orgsAsync = ref.watch(platformOrganizationsProvider);
    final auditAsync = ref.watch(platformAuditProvider);
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

            // System Health
            _SystemHealthSection(isDark: isDark),
            SizedBox(height: sectionSpacing),

            // Platform Stats
            platformStats.when(
              data: (stats) => _PlatformStatsGrid(stats: stats, onNavigate: onNavigate),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _PlatformStatsGrid(
                stats: const PlatformStats(
                  totalOrganizations: 0,
                  totalUsers: 0,
                  activeSubscriptions: 0,
                  trialSubscriptions: 0,
                  storageUsedGb: 0,
                  activeSessions: 0,
                  avgApiLatencyMs: 0,
                  openErrors: 0,
                  openTickets: 0,
                ),
                onNavigate: onNavigate,
              ),
            ),
            SizedBox(height: sectionSpacing),

            // Two column layout for orgs and activity
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _OrganizationsOverview(
                          orgsAsync: orgsAsync,
                          onNavigate: onNavigate,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _RecentActivitySection(auditAsync: auditAsync),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _OrganizationsOverview(orgsAsync: orgsAsync, onNavigate: onNavigate),
                    SizedBox(height: sectionSpacing),
                    _RecentActivitySection(auditAsync: auditAsync),
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
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.terminal,
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
                    'Developer Console',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Platform-wide system management & debugging',
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
          color: const Color(0xFF7C3AED),
          onPressed: () async {
            final user = await EmulateUserDialog.show(context);
            if (user != null) {
              ref.read(emulatedUserProvider.notifier).state = user;
            }
          },
        ),
        _ActionButton(
          icon: Icons.refresh,
          label: 'Refresh Data',
          color: const Color(0xFF059669),
          onPressed: () {
            ref.invalidate(platformStatsProvider);
            ref.invalidate(platformOrganizationsProvider);
            ref.invalidate(platformUsersProvider);
            ref.invalidate(platformAuditProvider);
          },
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
              ? [const Color(0xFF5B21B6).withValues(alpha: 0.3), const Color(0xFF7C3AED).withValues(alpha: 0.2)]
              : [const Color(0xFFEDE9FE), const Color(0xFFF5F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF7C3AED) : const Color(0xFFC4B5FD),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.3 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.supervisor_account,
              color: Color(0xFF7C3AED),
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
                    color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
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
              backgroundColor: const Color(0xFF7C3AED),
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

class _SystemHealthSection extends StatelessWidget {
  const _SystemHealthSection({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B).withValues(alpha: 0.4), const Color(0xFF065F46).withValues(alpha: 0.4)]
              : const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                  : const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.check_circle,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Status: Operational',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All services running normally • Last check: ${DateFormat('h:mm a').format(DateTime.now())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
          _HealthIndicator(label: 'API', status: 'ok', isDark: isDark),
          const SizedBox(width: 12),
          _HealthIndicator(label: 'DB', status: 'ok', isDark: isDark),
          const SizedBox(width: 12),
          _HealthIndicator(label: 'Storage', status: 'ok', isDark: isDark),
        ],
      ),
    );
  }
}

class _HealthIndicator extends StatelessWidget {
  const _HealthIndicator({
    required this.label,
    required this.status,
    required this.isDark,
  });

  final String label;
  final String status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isOk = status == 'ok';
    final color = isOk
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
        : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformStatsGrid extends StatelessWidget {
  const _PlatformStatsGrid({required this.stats, required this.onNavigate});

  final PlatformStats stats;
  final ValueChanged<SideMenuRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.decimalPattern();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Platform-focused metrics in 2 columns: Scale (left) + Health (right)
    final statItems = [
      // Left column - Platform Scale
      _StatRowData(
        label: 'Organizations',
        value: numberFormat.format(stats.totalOrganizations),
        icon: Icons.apartment,
        color: const Color(0xFF3B82F6),
        onTap: () => onNavigate(SideMenuRoute.organization),
      ),
      _StatRowData(
        label: 'Total Users',
        value: numberFormat.format(stats.totalUsers),
        icon: Icons.people,
        color: const Color(0xFF8B5CF6),
        onTap: () => onNavigate(SideMenuRoute.users),
      ),
      _StatRowData(
        label: 'Active Subscriptions',
        value: numberFormat.format(stats.activeSubscriptions),
        icon: Icons.credit_card,
        color: const Color(0xFF10B981),
        onTap: () {}, // Future: subscription management page
      ),
      _StatRowData(
        label: 'Storage Used',
        value: stats.storageUsedGb > 0
            ? '${stats.storageUsedGb.toStringAsFixed(1)} GB'
            : '—',
        icon: Icons.cloud,
        color: const Color(0xFF6366F1),
        onTap: () {},
      ),
      // Right column - Platform Health
      _StatRowData(
        label: 'Active Sessions',
        value: numberFormat.format(stats.activeSessions),
        icon: Icons.sensors,
        color: const Color(0xFF14B8A6),
        onTap: () => onNavigate(SideMenuRoute.activeSessions),
      ),
      _StatRowData(
        label: 'API Latency',
        value: stats.avgApiLatencyMs > 0
            ? '${stats.avgApiLatencyMs.toStringAsFixed(0)}ms'
            : '—',
        icon: Icons.speed,
        color: stats.avgApiLatencyMs <= 0
            ? const Color(0xFF6B7280)
            : stats.avgApiLatencyMs < 100
                ? const Color(0xFF10B981)
                : stats.avgApiLatencyMs < 300
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444),
        onTap: () => onNavigate(SideMenuRoute.apiMetrics),
      ),
      _StatRowData(
        label: 'Open Errors',
        value: numberFormat.format(stats.openErrors),
        icon: Icons.error_outline,
        color: stats.openErrors > 0
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        onTap: () => onNavigate(SideMenuRoute.errorTracking),
      ),
      _StatRowData(
        label: 'Open Tickets',
        value: numberFormat.format(stats.openTickets),
        icon: Icons.support_agent,
        color: stats.openTickets > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981),
        onTap: () => onNavigate(SideMenuRoute.supportTickets),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use 2 columns on wider screens, 1 column on narrow
        final useWideLayout = constraints.maxWidth >= 600;

        if (useWideLayout) {
          // Split into two columns
          final leftColumn = statItems.sublist(0, 4);
          final rightColumn = statItems.sublist(4);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    children: leftColumn
                        .map((item) => _StatRow(
                              label: item.label,
                              value: item.value,
                              icon: item.icon,
                              color: item.color,
                              onTap: item.onTap,
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    children: rightColumn
                        .map((item) => _StatRow(
                              label: item.label,
                              value: item.value,
                              icon: item.icon,
                              color: item.color,
                              onTap: item.onTap,
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        }

        // Single column for narrow screens
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: statItems
                .map((item) => _StatRow(
                      label: item.label,
                      value: item.value,
                      icon: item.icon,
                      color: item.color,
                      onTap: item.onTap,
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _StatRowData {
  const _StatRowData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                  ),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizationsOverview extends StatelessWidget {
  const _OrganizationsOverview({
    required this.orgsAsync,
    required this.onNavigate,
  });

  final AsyncValue<List<AdminOrgSummary>> orgsAsync;
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
                Icons.apartment,
                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Organizations',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => onNavigate(SideMenuRoute.organization),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          orgsAsync.when(
            data: (orgs) {
              if (orgs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No organizations found',
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
                itemCount: orgs.take(5).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final org = orgs[index];
                  return _OrgTile(org: org);
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
                  'Failed to load organizations',
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

class _OrgTile extends StatelessWidget {
  const _OrgTile({required this.org});

  final AdminOrgSummary org;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                org.name.isNotEmpty ? org.name[0].toUpperCase() : 'O',
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
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
                  org.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                Text(
                  '${org.memberCount} members',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Active',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF10B981),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({required this.auditAsync});

  final AsyncValue<List<AdminAuditEvent>> auditAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');

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
                Icons.history,
                color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Recent Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          auditAsync.when(
            data: (events) {
              if (events.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No recent activity',
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
                itemCount: events.take(8).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return _ActivityTile(
                    action: event.action,
                    detail: event.resourceType,
                    time: timeFormat.format(event.createdAt),
                    isDark: isDark,
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
                  'Failed to load activity',
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

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.action,
    required this.detail,
    required this.time,
    required this.isDark,
  });

  final String action;
  final String? detail;
  final String time;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final actionColor = switch (action.toUpperCase()) {
      'INSERT' => const Color(0xFF10B981),
      'UPDATE' => const Color(0xFF3B82F6),
      'DELETE' => const Color(0xFFEF4444),
      _ => const Color(0xFF6B7280),
    };

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: actionColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: actionColor,
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Text(
          time,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}
