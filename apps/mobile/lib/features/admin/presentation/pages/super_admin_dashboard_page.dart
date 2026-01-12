import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../dashboard/presentation/widgets/notification_panel.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../../assets/presentation/pages/assets_page.dart';
import '../../../documents/presentation/pages/documents_page.dart';
import '../../../dashboard/presentation/pages/reports_page.dart';
import '../../../ops/presentation/pages/ai_tools_page.dart';
import '../../../ops/presentation/pages/news_posts_page.dart';
import '../../../ops/presentation/pages/payment_requests_page.dart';
import '../../data/admin_providers.dart';
import '../../data/admin_models.dart';
import '../../../projects/presentation/pages/projects_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
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
import '../../../navigation/data/quick_action_provider.dart';
import '../../../navigation/presentation/widgets/side_menu.dart';
import '../../../partners/presentation/pages/messages_page.dart';
import '../../../sop/presentation/pages/sop_library_page.dart';
import '../../../tasks/presentation/pages/tasks_page.dart';
import '../../../templates/presentation/pages/templates_page.dart';
import '../../../training/presentation/pages/training_hub_page.dart';

final _superAdminDayStartedProvider = legacy.StateProvider<bool>((ref) => false);

class SuperAdminDashboardPage extends ConsumerStatefulWidget {
  const SuperAdminDashboardPage({
    super.key,
    this.initialRoute = SideMenuRoute.dashboard,
    this.role = UserRole.superAdmin,
  });

  final SideMenuRoute initialRoute;
  final UserRole role;

  @override
  ConsumerState<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState
    extends ConsumerState<SuperAdminDashboardPage> {
  late SideMenuRoute _activeRoute;

  @override
  void initState() {
    super.initState();
    _activeRoute = widget.initialRoute;
  }

  void _setRoute(SideMenuRoute route) {
    setState(() => _activeRoute = route);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      role: widget.role,
      activeRoute: _activeRoute,
      onNavigate: _setRoute,
      showRightSidebar: false,
      maxContentWidth: 1400,
      child: _superAdminPageForRoute(
        _activeRoute,
        onNavigate: _setRoute,
        role: widget.role,
      ),
    );
  }
}

Widget _superAdminPageForRoute(
  SideMenuRoute route, {
  required ValueChanged<SideMenuRoute> onNavigate,
  required UserRole role,
}) {
  if (route == SideMenuRoute.dashboard) {
    return _SuperAdminDashboardBody(onNavigate: onNavigate);
  }
  return switch (route) {
    SideMenuRoute.notifications => const NotificationsPage(),
    SideMenuRoute.messages => const MessagesPage(),
    SideMenuRoute.companyNews => const NewsPostsPage(),
    SideMenuRoute.organizationChart =>
        OrganizationChartPage(role: role),
    SideMenuRoute.systemOverview => const SystemOverviewPage(),
    SideMenuRoute.users => const UserDirectoryPage(),
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
    SideMenuRoute.reports => const ReportsPage(),
    SideMenuRoute.auditLogs => const AuditLogsPage(),
    SideMenuRoute.roleCustomization => const RoleCustomizationPage(),
    SideMenuRoute.settings => const SettingsPage(),
    SideMenuRoute.supportTickets => const SupportTicketsPage(),
    SideMenuRoute.knowledgeBase => const SopLibraryPage(),
    SideMenuRoute.systemLogs => const SystemLogsPage(),
    SideMenuRoute.dashboard => _SuperAdminDashboardBody(onNavigate: onNavigate),
    _ => _SuperAdminDashboardBody(onNavigate: onNavigate),
  };
}

class _SuperAdminDashboardBody extends ConsumerStatefulWidget {
  const _SuperAdminDashboardBody({required this.onNavigate});

  final ValueChanged<SideMenuRoute> onNavigate;

  @override
  ConsumerState<_SuperAdminDashboardBody> createState() =>
      _SuperAdminDashboardBodyState();
}

class _SuperAdminDashboardBodyState
    extends ConsumerState<_SuperAdminDashboardBody> {
  late List<NotificationItem> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _superAdminNotifications();
  }

  void _dismissNotification(NotificationItem item) {
    setState(() {
      _notifications = _notifications
          .where((notification) => notification.id != item.id)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(adminStatsProvider);
    final users = ref.watch(adminUsersProvider);
    final totalUsers = users.asData?.value.length ?? 0;
    final totalUsersLabel = NumberFormat.decimalPattern().format(totalUsers);
    final dayStarted = ref.watch(_superAdminDayStartedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Future<void> handleStartDay() async {
      if (dayStarted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start the workday?'),
          content: const Text(
            'This will:\n\n'
            '• Open timecard submissions for all employees\n'
            '• Activate daily schedules and assignments\n'
            '• Send notifications to all active users\n'
            '• Initialize all operational systems\n\n'
            'Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start Day'),
            ),
          ],
        ),
      );
      if (approved == true) {
        ref.read(_superAdminDayStartedProvider.notifier).state = true;
      }
    }
    void handleCreateForm() {
      ref.read(createFormTriggerProvider.notifier).state++;
      widget.onNavigate(SideMenuRoute.forms);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        final horizontalPadding = constraints.maxWidth > 1100 ? 24.0 : 16.0;
        final sectionSpacing = isCompact ? 20.0 : 16.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            24,
          ),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final compact = constraints.maxWidth < 640;
                final startedBackground = isDark
                    ? const Color(0xFF14532D).withValues(alpha: 0.35)
                    : const Color(0xFFDCFCE7);
                final startedForeground = isDark
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFF15803D);
                final header = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Super Admin Dashboard',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Complete system control and monitoring',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
                final startDayButton = ElevatedButton.icon(
                  onPressed: dayStarted ? null : handleStartDay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dayStarted
                        ? startedBackground
                        : const Color(0xFF16A34A),
                    foregroundColor:
                        dayStarted ? startedForeground : Colors.white,
                    disabledBackgroundColor: startedBackground,
                    disabledForegroundColor: startedForeground,
                    elevation: dayStarted ? 0 : 6,
                    shadowColor:
                        const Color(0xFF16A34A).withValues(alpha: 0.25),
                    textStyle: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: dayStarted
                          ? BorderSide(
                              color: startedForeground.withValues(alpha: 0.6),
                            )
                          : BorderSide.none,
                    ),
                  ),
                  icon: dayStarted
                      ? Icon(
                          Icons.play_arrow,
                          size: 18,
                          color: startedForeground,
                        )
                      : _PulseIcon(
                          child: const Icon(
                            Icons.play_arrow,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                  label: Text(
                    dayStarted ? 'Day Started ✓' : 'Start Day',
                  ),
                );
                final addUserButton = FilledButton.icon(
                  onPressed: () => widget.onNavigate(SideMenuRoute.users),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    textStyle: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.person_add_alt_1,
                    size: 18,
                  ),
                  label: const Text('Add User'),
                );
                final actions = compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: double.infinity, child: startDayButton),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: addUserButton),
                        ],
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          startDayButton,
                          addUserButton,
                        ],
                      );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: header),
                      const SizedBox(width: 16),
                      actions,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 12),
                    actions,
                  ],
                );
              },
            ),
            SizedBox(height: sectionSpacing),
            NotificationsPanel(
              notifications: _notifications,
              onDismiss: _dismissNotification,
              initialLimit: 2,
            ),
            SizedBox(height: sectionSpacing),
            _SystemHealthBanner(),
            SizedBox(height: sectionSpacing),
            _StatsGrid(items: [
              _StatTile(
                label: 'Total Users',
                value: totalUsersLabel,
                icon: Icons.people_outline,
                color: Colors.blue,
                trend: '+12% this month',
              ),
              const _StatTile(
                label: 'System Health',
                value: '98.5%',
                icon: Icons.monitor_heart_outlined,
                color: Colors.green,
                trend: 'Optimal',
              ),
              const _StatTile(
                label: 'Servers Online',
                value: '24/24',
                icon: Icons.storage_outlined,
                color: Colors.purple,
                trend: 'All operational',
              ),
              const _StatTile(
                label: 'Storage Used',
                value: '847GB',
                icon: Icons.cloud_outlined,
                color: Colors.orange,
                trend: '32% of total',
              ),
              const _StatTile(
                label: 'API Calls',
                value: '15.2K',
                icon: Icons.trending_up,
                color: Colors.pink,
                trend: '+8% from yesterday',
              ),
            ]),
            SizedBox(height: sectionSpacing),
            _QuickActions(
              onNavigate: widget.onNavigate,
              onCreateForm: handleCreateForm,
            ),
            SizedBox(height: sectionSpacing),
            stats.when(
              data: (data) => _ServerOverview(stats: data),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const _ServerOverview(stats: null),
            ),
            SizedBox(height: sectionSpacing),
            const _MainGrid(),
          ],
        );
      },
    );
  }
}

class _SystemHealthBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundGradient = LinearGradient(
      colors: isDark
          ? [
              const Color(0xFF064E3B).withValues(alpha: 0.4),
              const Color(0xFF065F46).withValues(alpha: 0.4),
            ]
          : const [
              Color(0xFFF0FDF4),
              Color(0xFFDCFCE7),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final border = isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0);
    final titleColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF14532D);
    final bodyColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: backgroundGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Systems Operational',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'All services running smoothly with optimal performance',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: bodyColor,
                      ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth < 640 ? 2 : 4;
                    final stats = const [
                      _MiniHealthStat(label: 'Uptime', value: '99.9%'),
                      _MiniHealthStat(label: 'Response', value: '45ms'),
                      _MiniHealthStat(label: 'Security', value: '100%'),
                      _MiniHealthStat(label: 'Monitoring', value: '24/7'),
                    ];
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: crossAxisCount == 2 ? 1.8 : 2.2,
                      children: stats,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniHealthStat extends StatelessWidget {
  const _MiniHealthStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF064E3B).withValues(alpha: 0.35)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.6);
    final border = isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0);
    final textColor = isDark ? const Color(0xFFF0FDF4) : const Color(0xFF14532D);
    final labelColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 140;
        return Container(
          padding: EdgeInsets.all(compact ? 8 : 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  fontSize: compact ? 14 : null,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: labelColor,
                  fontSize: compact ? 10 : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});

  final List<_StatTile> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        final isWide = constraints.maxWidth >= 1024;
        final crossAxisCount = isWide ? 5 : 2;
        final ratio = isWide ? 1.2 : (isCompact ? 1.05 : 1.15);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: ratio,
          children: items,
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 220;
        final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
        final background = isDark ? const Color(0xFF1F2937) : Colors.white;
        final gradient = LinearGradient(
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.2) ?? color,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        return Container(
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 40 : 48,
                height: compact ? 40 : 48,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: compact ? 20 : 24),
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 22 : 26,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 11 : 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (trend != null) ...[
                SizedBox(height: compact ? 2 : 4),
                Text(
                  trend!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF16A34A),
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 10 : 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onNavigate,
    required this.onCreateForm,
  });

  final ValueChanged<SideMenuRoute> onNavigate;
  final VoidCallback onCreateForm;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Quick Actions',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;
          final crossAxisCount = constraints.maxWidth >= 1024 ? 4 : 2;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isCompact ? 1.3 : 1.6,
            children: [
              _QuickActionCard(
                label: 'Add User',
                icon: Icons.person_add_alt_1,
                tone: _QuickActionTone.blue,
                onTap: () => onNavigate(SideMenuRoute.users),
              ),
              _QuickActionCard(
                label: 'Create Form',
                icon: Icons.description_outlined,
                tone: _QuickActionTone.purple,
                onTap: onCreateForm,
              ),
              _QuickActionCard(
                label: 'New Project',
                icon: Icons.folder_open_outlined,
                tone: _QuickActionTone.green,
                onTap: () => onNavigate(SideMenuRoute.projects),
              ),
              _QuickActionCard(
                label: 'Settings',
                icon: Icons.settings_outlined,
                tone: _QuickActionTone.gray,
                onTap: () => onNavigate(SideMenuRoute.settings),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final _QuickActionTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = _QuickActionPalette.fromTone(tone, isDark);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 170;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(compact ? 12 : 16),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: palette.icon, size: compact ? 20 : 24),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.label,
                        fontSize: compact ? 12 : null,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _QuickActionTone { blue, purple, green, gray }

class _QuickActionPalette {
  const _QuickActionPalette({
    required this.background,
    required this.border,
    required this.icon,
    required this.label,
  });

  final Color background;
  final Color border;
  final Color icon;
  final Color label;

  factory _QuickActionPalette.fromTone(_QuickActionTone tone, bool isDark) {
    switch (tone) {
      case _QuickActionTone.blue:
        return _QuickActionPalette(
          background: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
              : const Color(0xFFEFF6FF),
          border: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
              : const Color(0xFFDBEAFE),
          icon: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
          label: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
        );
      case _QuickActionTone.purple:
        return _QuickActionPalette(
          background: isDark
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
              : const Color(0xFFF5F3FF),
          border: isDark
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
              : const Color(0xFFEDE9FE),
          icon: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
          label: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
        );
      case _QuickActionTone.green:
        return _QuickActionPalette(
          background: isDark
              ? const Color(0xFF22C55E).withValues(alpha: 0.1)
              : const Color(0xFFF0FDF4),
          border: isDark
              ? const Color(0xFF22C55E).withValues(alpha: 0.2)
              : const Color(0xFFDCFCE7),
          icon: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
          label: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
        );
      case _QuickActionTone.gray:
        return _QuickActionPalette(
          background: isDark
              ? const Color(0xFF6B7280).withValues(alpha: 0.1)
              : const Color(0xFFF9FAFB),
          border: isDark
              ? const Color(0xFF6B7280).withValues(alpha: 0.2)
              : const Color(0xFFF3F4F6),
          icon: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
          label: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
        );
    }
  }
}

class _ServerOverview extends StatefulWidget {
  const _ServerOverview({required this.stats});

  final AdminStats? stats;

  @override
  State<_ServerOverview> createState() => _ServerOverviewState();
}

class _ServerOverviewState extends State<_ServerOverview> {
  String _timeRange = 'daily';
  int? _hoveredChartIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final chartData = const [
      _ApiChartPoint(value: 45, label: 'M', day: 'Mon', requests: 12450),
      _ApiChartPoint(value: 38, label: 'T', day: 'Tue', requests: 10230),
      _ApiChartPoint(value: 52, label: 'W', day: 'Wed', requests: 15670),
      _ApiChartPoint(value: 41, label: 'T', day: 'Thu', requests: 11890),
      _ApiChartPoint(value: 48, label: 'F', day: 'Fri', requests: 14320),
      _ApiChartPoint(value: 35, label: 'S', day: 'Sat', requests: 9450),
      _ApiChartPoint(value: 28, label: 'S', day: 'Sun', requests: 7820),
    ];
    final maxValue = chartData
        .map((entry) => entry.value)
        .reduce((value, element) => value > element ? value : element);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              final titleRow = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.dns_outlined,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Server & System Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ],
              );
              final isCompact = constraints.maxWidth < 640;
              final dropdown = _TimeRangeDropdown(
                value: _timeRange,
                onChanged: (value) => setState(() => _timeRange = value),
                isExpanded: isCompact,
              );
              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    titleRow,
                    dropdown,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleRow,
                  const SizedBox(height: 12),
                  if (isCompact)
                    SizedBox(width: double.infinity, child: dropdown)
                  else
                    dropdown,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 640;
              final crossAxisCount = constraints.maxWidth >= 1024 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: isCompact ? 10 : 12,
                mainAxisSpacing: isCompact ? 10 : 12,
                childAspectRatio: crossAxisCount > 2
                    ? 2.1
                    : isCompact
                        ? 1.3
                        : 1.7,
                children: const [
                  _ServerStatusCard(
                    title: 'Server Status',
                    value: '99.9%',
                    subtitle: 'Uptime',
                    icon: Icons.show_chart,
                    tone: _StatusTone.green,
                    chip: 'Online',
                    progress: 0.0,
                  ),
                  _ServerStatusCard(
                    title: 'CPU Usage',
                    value: '45%',
                    subtitle: '',
                    icon: Icons.memory,
                    tone: _StatusTone.blue,
                    chip: '',
                    progress: 0.45,
                    trendIcon: Icons.trending_down,
                  ),
                  _ServerStatusCard(
                    title: 'Memory',
                    value: '6.2 GB',
                    subtitle: 'of 16 GB used',
                    icon: Icons.sd_storage,
                    tone: _StatusTone.purple,
                    chip: '',
                    progress: 0.0,
                    trendIcon: Icons.trending_up,
                  ),
                  _ServerStatusCard(
                    title: 'Database',
                    value: '847 MB',
                    subtitle: 'Total size',
                    icon: Icons.storage_outlined,
                    tone: _StatusTone.orange,
                    chip: '',
                    progress: 0.0,
                    trendIcon: Icons.trending_up,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 640;
              final titleRow = Row(
                children: [
                  const Icon(Icons.public, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'API Usage & Performance',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
              final metrics = Wrap(
                spacing: 12,
                runSpacing: 6,
                children: const [
                  _InlineMetric(label: 'Avg Response:', value: '45ms'),
                  _InlineMetric(label: 'Success Rate:', value: '99.7%'),
                ],
              );
              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleRow,
                    const SizedBox(height: 8),
                    metrics,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleRow,
                  metrics,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 640;
              final crossAxisCount = constraints.maxWidth >= 1200
                  ? 5
                  : constraints.maxWidth >= 800
                      ? 3
                      : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: isCompact ? 8 : 10,
                mainAxisSpacing: isCompact ? 8 : 10,
                childAspectRatio: crossAxisCount >= 5
                    ? 1.6
                    : isCompact
                        ? 1.1
                        : 1.4,
                children: const [
                  _ApiMetricTile(
                    label: 'Total Requests',
                    value: '82.1K',
                    note: '+12.3%',
                    noteIcon: Icons.trending_up,
                    highlight: Color(0xFF16A34A),
                  ),
                  _ApiMetricTile(
                    label: 'GET Requests',
                    value: '54.2K',
                    note: '66% of total',
                  ),
                  _ApiMetricTile(
                    label: 'POST Requests',
                    value: '23.8K',
                    note: '29% of total',
                  ),
                  _ApiMetricTile(
                    label: 'Failed Requests',
                    value: '243',
                    note: '0.3% failure',
                    highlight: Color(0xFFDC2626),
                  ),
                  _ApiMetricTile(
                    label: 'Bandwidth',
                    value: '2.4 GB',
                    note: 'Used',
                    noteIcon: Icons.wifi,
                    highlight: Color(0xFF2563EB),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 640;
                    final peakRow = Row(
                      children: [
                        Text(
                          'Peak:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '15.6K requests',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(Wed)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'API Requests Over Time',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          peakRow,
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'API Requests Over Time',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        peakRow,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < chartData.length; i++)
                        Expanded(
                          child: _ApiChartBar(
                            label: chartData[i].label,
                            heightRatio: chartData[i].value / maxValue,
                            requests: chartData[i].requests,
                            isHovered: _hoveredChartIndex == i,
                            onHover: (hovered) {
                              setState(
                                () => _hoveredChartIndex = hovered ? i : null,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final responseCard = _PerformanceCard(
                title: 'Response Times',
                icon: Icons.bolt,
                color: const Color(0xFFF59E0B),
                rows: const [
                  _PerformanceRow(
                    label: '/api/tasks',
                    value: '32ms',
                    status: _PerformanceStatus.excellent,
                  ),
                  _PerformanceRow(
                    label: '/api/forms',
                    value: '45ms',
                    status: _PerformanceStatus.good,
                  ),
                  _PerformanceRow(
                    label: '/api/projects',
                    value: '58ms',
                    status: _PerformanceStatus.good,
                  ),
                  _PerformanceRow(
                    label: '/api/analytics',
                    value: '124ms',
                    status: _PerformanceStatus.fair,
                  ),
                ],
              );
              final databaseCard = const _DatabasePerformanceCard();
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: responseCard),
                    const SizedBox(width: 12),
                    Expanded(child: databaseCard),
                  ],
                );
              }
              return Column(
                children: [
                  responseCard,
                  const SizedBox(height: 12),
                  databaseCard,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _ServiceHealthStatusSection(borderColor: border),
        ],
      ),
    );
  }
}

class _ApiChartPoint {
  const _ApiChartPoint({
    required this.value,
    required this.label,
    required this.day,
    required this.requests,
  });

  final int value;
  final String label;
  final String day;
  final int requests;
}

enum _StatusTone { green, blue, purple, orange }

class _ServerStatusCard extends StatelessWidget {
  const _ServerStatusCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.chip,
    required this.progress,
    this.trendIcon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final _StatusTone tone;
  final String chip;
  final double progress;
  final IconData? trendIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = _StatusPalette.fromTone(tone, isDark);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 170;
        return Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: compact ? 32 : 36,
                    height: compact ? 32 : 36,
                    decoration: BoxDecoration(
                      color: palette.iconBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: compact ? 18 : 20,
                    ),
                  ),
                  if (chip.isNotEmpty)
                    Row(
                      children: [
                        const _PulseDot(color: Color(0xFF22C55E)),
                        const SizedBox(width: 4),
                        Text(
                          chip,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: compact ? 10 : null,
                          ),
                        ),
                      ],
                    )
                  else if (trendIcon != null)
                    Icon(
                      trendIcon,
                      size: compact ? 14 : 16,
                      color: palette.accent,
                    ),
                ],
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                  fontSize: compact ? 11 : null,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 20 : 24,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                SizedBox(height: compact ? 2 : 4),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.accent,
                    fontSize: compact ? 10 : null,
                  ),
                ),
              ],
              if (progress > 0) ...[
                SizedBox(height: compact ? 6 : 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: compact ? 5 : 6,
                    backgroundColor: palette.progressBackground,
                    valueColor: AlwaysStoppedAnimation(palette.progressFill),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusPalette {
  const _StatusPalette({
    required this.gradient,
    required this.border,
    required this.iconBackground,
    required this.accent,
    required this.progressBackground,
    required this.progressFill,
  });

  final List<Color> gradient;
  final Color border;
  final Color iconBackground;
  final Color accent;
  final Color progressBackground;
  final Color progressFill;

  factory _StatusPalette.fromTone(_StatusTone tone, bool isDark) {
    switch (tone) {
      case _StatusTone.green:
        return _StatusPalette(
          gradient: isDark
              ? [
                  const Color(0xFF064E3B).withValues(alpha: 0.4),
                  const Color(0xFF065F46).withValues(alpha: 0.4),
                ]
              : const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
          border: isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0),
          iconBackground: const Color(0xFF22C55E),
          accent: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
          progressBackground: isDark
              ? const Color(0xFF064E3B)
              : const Color(0xFFBBF7D0),
          progressFill: const Color(0xFF22C55E),
        );
      case _StatusTone.blue:
        return _StatusPalette(
          gradient: isDark
              ? [
                  const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                  const Color(0xFF312E81).withValues(alpha: 0.4),
                ]
              : const [Color(0xFFEFF6FF), Color(0xFFE0E7FF)],
          border: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE),
          iconBackground: const Color(0xFF3B82F6),
          accent: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
          progressBackground: isDark
              ? const Color(0xFF1E3A8A)
              : const Color(0xFFBFDBFE),
          progressFill: const Color(0xFF2563EB),
        );
      case _StatusTone.purple:
        return _StatusPalette(
          gradient: isDark
              ? [
                  const Color(0xFF4C1D95).withValues(alpha: 0.4),
                  const Color(0xFF6D28D9).withValues(alpha: 0.4),
                ]
              : const [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
          border: isDark ? const Color(0xFF7C3AED) : const Color(0xFFC4B5FD),
          iconBackground: const Color(0xFF8B5CF6),
          accent: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
          progressBackground: isDark
              ? const Color(0xFF4C1D95)
              : const Color(0xFFC4B5FD),
          progressFill: const Color(0xFF7C3AED),
        );
      case _StatusTone.orange:
        return _StatusPalette(
          gradient: isDark
              ? [
                  const Color(0xFF7C2D12).withValues(alpha: 0.4),
                  const Color(0xFF9A3412).withValues(alpha: 0.4),
                ]
              : const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
          border: isDark ? const Color(0xFFEA580C) : const Color(0xFFFED7AA),
          iconBackground: const Color(0xFFF97316),
          accent: isDark ? const Color(0xFFFED7AA) : const Color(0xFFEA580C),
          progressBackground: isDark
              ? const Color(0xFF7C2D12)
              : const Color(0xFFFED7AA),
          progressFill: const Color(0xFFF97316),
        );
    }
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF16A34A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ApiMetricTile extends StatelessWidget {
  const _ApiMetricTile({
    required this.label,
    required this.value,
    required this.note,
    this.noteIcon,
    this.highlight,
  });

  final String label;
  final String value;
  final String note;
  final IconData? noteIcon;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 170;
        return Container(
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: compact ? 10 : null,
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 16 : null,
                  color: highlight ??
                      (isDark ? Colors.white : const Color(0xFF111827)),
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Row(
                children: [
                  if (noteIcon != null) ...[
                    Icon(
                      noteIcon,
                      size: compact ? 10 : 12,
                      color: highlight ?? const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      note,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: highlight ?? theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 10 : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApiChartBar extends StatelessWidget {
  const _ApiChartBar({
    required this.label,
    required this.heightRatio,
    required this.requests,
    required this.isHovered,
    required this.onHover,
  });

  final String label;
  final double heightRatio;
  final int requests;
  final bool isHovered;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueLabel = '${(requests / 1000).toStringAsFixed(1)}K';
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      cursor: SystemMouseCursors.click,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightRatio,
                widthFactor: 0.7,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isHovered
                          ? const [Color(0xFF1D4ED8), Color(0xFF3B82F6)]
                          : const [Color(0xFF2563EB), Color(0xFF60A5FA)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AnimatedOpacity(
            opacity: isHovered ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Text(
              valueLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRangeDropdown extends StatelessWidget {
  const _TimeRangeDropdown({
    required this.value,
    required this.onChanged,
    this.isExpanded = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
    final textColor =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.expand_more, color: textColor, size: 18),
          dropdownColor: background,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          isExpanded: isExpanded,
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
          items: const [
            DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
          ],
        ),
      ),
    );
  }
}

class _DatabasePerformanceCard extends StatelessWidget {
  const _DatabasePerformanceCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage, size: 16, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(
                'Database Performance',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DatabasePerformanceRow(
            label: 'Query Time (Avg)',
            value: '18ms',
            valueColor: textColor,
            labelColor: muted,
          ),
          const SizedBox(height: 10),
          _DatabasePerformanceRow(
            label: 'Active Connections',
            value: '24',
            valueColor: textColor,
            labelColor: muted,
          ),
          const SizedBox(height: 10),
          _DatabasePerformanceRow(
            label: 'Slow Queries',
            value: '3',
            valueColor:
                isDark ? const Color(0xFFFBBF24) : const Color(0xFFEA580C),
            labelColor: muted,
          ),
          const SizedBox(height: 10),
          _DatabasePerformanceRow(
            label: 'Cache Hit Rate',
            value: '94.2%',
            valueColor: const Color(0xFF16A34A),
            labelColor: muted,
          ),
        ],
      ),
    );
  }
}

class _DatabasePerformanceRow extends StatelessWidget {
  const _DatabasePerformanceRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: labelColor,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _ServiceHealthStatusSection extends StatelessWidget {
  const _ServiceHealthStatusSection({required this.borderColor});

  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Health Status',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 640;
              final crossAxisCount = constraints.maxWidth >= 1024 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: isCompact ? 8 : 12,
                mainAxisSpacing: isCompact ? 8 : 12,
                childAspectRatio: isCompact ? 1.9 : 2.3,
                children: const [
                  _ServiceHealthCard(
                    name: 'Web Server',
                    status: 'operational',
                    response: '12ms',
                  ),
                  _ServiceHealthCard(
                    name: 'API Gateway',
                    status: 'operational',
                    response: '8ms',
                  ),
                  _ServiceHealthCard(
                    name: 'Database',
                    status: 'operational',
                    response: '5ms',
                  ),
                  _ServiceHealthCard(
                    name: 'File Storage',
                    status: 'operational',
                    response: '23ms',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceHealthCard extends StatelessWidget {
  const _ServiceHealthCard({
    required this.name,
    required this.status,
    required this.response,
  });

  final String name;
  final String status;
  final String response;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 150;
        return Container(
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      fontSize: compact ? 10 : null,
                    ),
                  ),
                  const _PulseDot(color: Color(0xFF22C55E)),
                ],
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                'Response: $response',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF6B7280),
                  fontSize: compact ? 10 : null,
                ),
              ),
              Text(
                status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF16A34A),
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 10 : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: 0.5).animate(
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
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  const _PulseIcon({required this.child});

  final Widget child;

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1, end: 1.15).animate(
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
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<_PerformanceRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PerformanceRowTile(row: row),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceRowTile extends StatelessWidget {
  const _PerformanceRowTile({required this.row});

  final _PerformanceRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = row.status.color;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          row.label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color:
                isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        Row(
          children: [
            Text(
              row.value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PerformanceRow {
  const _PerformanceRow({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final _PerformanceStatus status;
}

enum _PerformanceStatus {
  excellent(Color(0xFF22C55E)),
  good(Color(0xFF3B82F6)),
  fair(Color(0xFFF59E0B));

  const _PerformanceStatus(this.color);

  final Color color;
}

class _MainGrid extends StatelessWidget {
  const _MainGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelBorder = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final panelBackground = isDark ? const Color(0xFF1F2937) : Colors.white;
    final activities = const [
      _ActivityItem(
        user: 'John Smith',
        action: 'submitted a form',
        item: 'Safety Inspection Report',
        time: '2 min ago',
        tone: _ActivityTone.success,
      ),
      _ActivityItem(
        user: 'Sarah Chen',
        action: 'uploaded document',
        item: 'Equipment_Manual.pdf',
        time: '5 min ago',
        tone: _ActivityTone.info,
      ),
      _ActivityItem(
        user: 'Mike Davis',
        action: 'reported an incident',
        item: 'Equipment Malfunction',
        time: '12 min ago',
        tone: _ActivityTone.warning,
      ),
      _ActivityItem(
        user: 'Emma Wilson',
        action: 'completed training',
        item: 'Safety Certification',
        time: '25 min ago',
        tone: _ActivityTone.success,
      ),
      _ActivityItem(
        user: 'Tom Brown',
        action: 'created project',
        item: 'Building A Renovation',
        time: '1 hour ago',
        tone: _ActivityTone.info,
      ),
    ];
    final alerts = const [
      _SystemAlert(
        title: 'High CPU Usage',
        detail: 'Server 3 at 87%',
        severity: _AlertSeverity.high,
        time: '5 min ago',
      ),
      _SystemAlert(
        title: 'Disk Space Low',
        detail: 'Database server 92%',
        severity: _AlertSeverity.medium,
        time: '12 min ago',
      ),
      _SystemAlert(
        title: 'Failed Login Attempts',
        detail: '5 attempts detected',
        severity: _AlertSeverity.low,
        time: '30 min ago',
      ),
    ];
    final recentUsers = const [
      _RecentUser(
        name: 'John Smith',
        role: 'Employee',
        status: _PresenceStatus.online,
        joined: '2 days ago',
      ),
      _RecentUser(
        name: 'Sarah Chen',
        role: 'Supervisor',
        status: _PresenceStatus.online,
        joined: '5 days ago',
      ),
      _RecentUser(
        name: 'Mike Davis',
        role: 'Manager',
        status: _PresenceStatus.away,
        joined: '1 week ago',
      ),
      _RecentUser(
        name: 'Emma Wilson',
        role: 'Employee',
        status: _PresenceStatus.offline,
        joined: '2 weeks ago',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 640 ? 12.0 : 16.0;
        final isWide = constraints.maxWidth > 1000;
        final activityCard = Container(
          decoration: BoxDecoration(
            color: panelBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: panelBorder),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: panelBorder),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Real-Time Activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: activities
                      .map((activity) => _ActivityTile(activity: activity))
                      .toList(),
                ),
              ),
            ],
          ),
        );
        final sideColumn = Column(
          children: [
            _PanelCard(
              title: 'Alerts',
              trailing: _AlertCountPill(
                count: alerts.length,
              ),
              child: Column(
                children: [
                  ...alerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AlertCard(alert: alert),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),
            _PanelCard(
              title: 'Recent Users',
              child: Column(
                children:
                    recentUsers.map((user) => _RecentUserTile(user: user)).toList(),
              ),
            ),
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: activityCard),
              SizedBox(width: spacing),
              Expanded(flex: 2, child: sideColumn),
            ],
          );
        }
        return Column(
          children: [
            activityCard,
            SizedBox(height: spacing),
            sideColumn,
          ],
        );
      },
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.user,
    required this.action,
    required this.item,
    required this.time,
    required this.tone,
  });

  final String user;
  final String action;
  final String item;
  final String time;
  final _ActivityTone tone;
}

enum _ActivityTone { success, warning, info }

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final _ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final dotColor = switch (activity.tone) {
      _ActivityTone.success => const Color(0xFF22C55E),
      _ActivityTone.warning => const Color(0xFFF59E0B),
      _ActivityTone.info => const Color(0xFF3B82F6),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 8 : 10),
          child: Container(
            padding: EdgeInsets.all(compact ? 12 : 16),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(top: compact ? 4 : 6),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${activity.user} ${activity.action}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.item,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 6),
                      Text(
                        activity.time,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SystemAlert {
  const _SystemAlert({
    required this.title,
    required this.detail,
    required this.severity,
    required this.time,
  });

  final String title;
  final String detail;
  final _AlertSeverity severity;
  final String time;
}

enum _AlertSeverity { high, medium, low }

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final _SystemAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = _alertPalette(alert.severity, isDark);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_outlined, color: palette.icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.title,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.detail,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      alert.time,
                      style:
                          theme.textTheme.labelSmall?.copyWith(color: palette.time),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlertCountPill extends StatelessWidget {
  const _AlertCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count.toString(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _AlertPalette {
  const _AlertPalette({
    required this.background,
    required this.border,
    required this.icon,
    required this.title,
    required this.detail,
    required this.time,
  });

  final Color background;
  final Color border;
  final Color icon;
  final Color title;
  final Color detail;
  final Color time;
}

_AlertPalette _alertPalette(_AlertSeverity severity, bool isDark) {
  switch (severity) {
    case _AlertSeverity.high:
      return _AlertPalette(
        background: isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.2)
            : const Color(0xFFFEF2F2),
        border:
            isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA),
        icon: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
        title: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D),
        detail: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
        time: isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
      );
    case _AlertSeverity.medium:
      return _AlertPalette(
        background: isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.2)
            : const Color(0xFFFFFBEB),
        border:
            isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
        icon: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        title: isDark ? const Color(0xFFFCD34D) : const Color(0xFF78350F),
        detail: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        time: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
      );
    case _AlertSeverity.low:
      return _AlertPalette(
        background: isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
            : const Color(0xFFEFF6FF),
        border:
            isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE),
        icon: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
        title: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
        detail: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
        time: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
      );
  }
}

class _RecentUser {
  const _RecentUser({
    required this.name,
    required this.role,
    required this.status,
    required this.joined,
  });

  final String name;
  final String role;
  final _PresenceStatus status;
  final String joined;
}

enum _PresenceStatus { online, away, offline }

class _RecentUserTile extends StatelessWidget {
  const _RecentUserTile({required this.user});

  final _RecentUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final statusColor = switch (user.status) {
      _PresenceStatus.online => const Color(0xFF22C55E),
      _PresenceStatus.away => const Color(0xFFF59E0B),
      _PresenceStatus.offline => const Color(0xFF9CA3AF),
    };
    final initials = user.name
        .split(' ')
        .map((part) => part.isNotEmpty ? part[0] : '')
        .take(2)
        .join();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 8 : 10),
          child: Container(
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: compact ? 40 : 44,
                      height: compact ? 40 : 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isDark ? const Color(0xFF1F2937) : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user.role} • ${user.joined}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return Container(
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              SizedBox(height: compact ? 12 : 16),
              child,
            ],
          ),
        );
      },
    );
  }
}

List<NotificationItem> _superAdminNotifications() {
  return [
    NotificationItem(
      id: 'critical',
      title: 'CRITICAL: System Outage',
      description: 'Database server is down - immediate action required',
      timeLabel: 'Just now',
      icon: Icons.warning_amber_outlined,
      priority: NotificationPriority.urgent,
    ),
    NotificationItem(
      id: 'security',
      title: 'Security Alert',
      description: 'Multiple failed login attempts detected from IP 192.168.1.45',
      timeLabel: '2 min ago',
      icon: Icons.security_outlined,
      priority: NotificationPriority.high,
    ),
    NotificationItem(
      id: 'approvals',
      title: 'Pending User Approvals',
      description: '15 new user registrations waiting for approval',
      timeLabel: '1 hour ago',
      icon: Icons.people_outline,
      priority: NotificationPriority.medium,
    ),
    NotificationItem(
      id: 'backup',
      title: 'Backup Complete',
      description: 'Daily system backup completed successfully',
      timeLabel: '3 hours ago',
      icon: Icons.check_circle_outline,
      priority: NotificationPriority.low,
    ),
    NotificationItem(
      id: 'license',
      title: 'License Renewal',
      description: 'Premium license expires in 7 days',
      timeLabel: '5 hours ago',
      icon: Icons.description_outlined,
      priority: NotificationPriority.medium,
    ),
  ];
}
