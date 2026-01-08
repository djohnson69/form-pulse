// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../assets/presentation/pages/assets_page.dart';
import '../../../dashboard/presentation/pages/reports_page.dart';
import '../../../dashboard/presentation/pages/submission_detail_page.dart';
import '../../../documents/presentation/pages/documents_page.dart';
import '../../../ops/presentation/pages/ai_tools_page.dart';
import '../../../ops/presentation/pages/export_jobs_page.dart';
import '../../../ops/presentation/pages/guest_invites_page.dart';
import '../../../ops/presentation/pages/integrations_page.dart';
import '../../../ops/presentation/pages/news_posts_page.dart';
import '../../../ops/presentation/pages/notebook_pages_page.dart';
import '../../../ops/presentation/pages/notebook_reports_page.dart';
import '../../../ops/presentation/pages/notification_rules_page.dart';
import '../../../ops/presentation/pages/ops_hub_page.dart';
import '../../../ops/presentation/pages/payment_requests_page.dart';
import '../../../ops/presentation/pages/portfolio_items_page.dart';
import '../../../ops/presentation/pages/reviews_page.dart';
import '../../../ops/presentation/pages/signature_requests_page.dart';
import '../../../ops/presentation/widgets/ai_chat_panel.dart';
import '../../../dashboard/presentation/widgets/top_bar.dart';
import '../../../navigation/presentation/pages/audit_logs_page.dart';
import '../../../navigation/presentation/pages/before_after_photos_page.dart';
import '../../../navigation/presentation/pages/incidents_page.dart';
import '../../../navigation/presentation/pages/notifications_page.dart';
import '../../../navigation/presentation/pages/organization_chart_page.dart';
import '../../../navigation/presentation/pages/payroll_page.dart';
import '../../../navigation/presentation/pages/photos_page.dart';
import '../../../navigation/presentation/pages/qr_scanner_page.dart';
import '../../../navigation/presentation/pages/roles_page.dart';
import '../../../navigation/presentation/pages/roles_permissions_page.dart';
import '../../../navigation/presentation/pages/support_tickets_page.dart';
import '../../../navigation/presentation/pages/system_logs_page.dart';
import '../../../navigation/presentation/pages/timecards_page.dart';
import '../../../navigation/presentation/pages/user_directory_page.dart';
import '../../../navigation/presentation/pages/work_orders_page.dart';
import '../../../navigation/presentation/widgets/side_menu.dart';
import '../../../ops/data/ops_provider.dart';
import '../../../ops/data/ops_repository.dart';
import '../../../partners/presentation/pages/clients_page.dart';
import '../../../partners/presentation/pages/messages_page.dart';
import '../../../partners/presentation/pages/vendors_page.dart';
import '../../../projects/presentation/pages/projects_page.dart';
import '../../../sop/presentation/pages/sop_library_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../tasks/presentation/pages/tasks_page.dart';
import '../../../teams/presentation/pages/teams_page.dart';
import '../../../templates/presentation/pages/templates_page.dart';
import '../../../training/presentation/pages/training_hub_page.dart';
import '../../../../core/utils/automation_scheduler.dart';
import '../../../../core/utils/ai_job_scheduler.dart';
import '../../../../core/utils/submission_utils.dart';
import '../../data/admin_models.dart';
import '../../data/admin_providers.dart';

final _dateFmt = DateFormat('MMM d, h:mm a');
final _shortDateFmt = DateFormat('MMM d, yyyy');
final _adminDayStartedProvider = legacy.StateProvider<bool>((ref) => false);

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.userRole,
    this.initialSectionId,
    this.embedInShell = false,
  });

  final UserRole userRole;
  final String? initialSectionId;
  final bool embedInShell;

  @override
  ConsumerState<AdminDashboardPage> createState() =>
      _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _sectionIndex = 0;
  bool _didInitSection = false;
  late final ProviderSubscription<AsyncValue<List<AdminOrgSummary>>> _orgListener;
  late final OpsRepositoryBase _opsRepository;
  Timer? _automationTimer;

  @override
  void initState() {
    super.initState();
    _opsRepository = ref.read(opsRepositoryProvider);
    Future.microtask(() async {
      if (!mounted) return;
      await AutomationScheduler.runIfDue(ops: _opsRepository);
      await AiJobScheduler.runIfDue(ops: _opsRepository);
    });
    _automationTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      if (!mounted) return;
      await AutomationScheduler.runIfDue(ops: _opsRepository);
      await AiJobScheduler.runIfDue(ops: _opsRepository);
    });
    _orgListener = ref.listenManual<AsyncValue<List<AdminOrgSummary>>>(
      adminOrganizationsProvider,
      (previous, next) {
        next.whenData((orgs) {
          if (orgs.isEmpty) return;
          final selected = ref.read(adminSelectedOrgIdProvider);
          final valid = selected != null &&
              orgs.any((org) => org.id == selected);
          if (!valid) {
            ref.read(adminSelectedOrgIdProvider.notifier).state = orgs.first.id;
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _orgListener.close();
    _automationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.userRole.canAccessAdminConsole) {
      return const Scaffold(
        body: Center(child: Text('Access denied: Admins only.')),
      );
    }

    final permissions = _AdminPermissions(widget.userRole);
    final orgCount =
        ref.watch(adminOrganizationsProvider).asData?.value.length ?? 0;
    final showOrgSwitcher =
        permissions.canSwitchOrg || (orgCount > 1 && permissions.canViewOrgs);

    final sectionIndexById = <String, int>{};
    final sections = <_AdminSection>[
      if (permissions.canViewOverview)
        _AdminSection(
          id: 'overview',
          label: 'Overview',
          icon: Icons.dashboard,
          builder: (context, ref) => _OverviewSection(
            permissions: permissions,
            showOrgSwitcher: showOrgSwitcher,
            userRoleLabel: widget.userRole.displayName,
            onNavigate: (id) {
              final index = sectionIndexById[id];
              if (index == null) return;
              setState(() => _sectionIndex = index);
            },
          ),
        ),
      if (permissions.canViewOrgs)
        _AdminSection(
          id: 'orgs',
          label: 'Organizations',
          icon: Icons.apartment,
          builder: (context, ref) =>
              _OrganizationsSection(permissions: permissions),
        ),
      if (permissions.canViewUsers)
        _AdminSection(
          id: 'users',
          label: 'Users',
          icon: Icons.people,
          builder: (context, ref) => _UsersSection(permissions: permissions),
        ),
      if (permissions.canViewForms)
        _AdminSection(
          id: 'forms',
          label: 'Forms',
          icon: Icons.description,
          builder: (context, ref) => _FormsSection(permissions: permissions),
        ),
      if (permissions.canViewSubmissions)
        _AdminSection(
          id: 'submissions',
          label: 'Submissions',
          icon: Icons.assignment_turned_in,
          builder: (context, ref) =>
              _SubmissionsSection(permissions: permissions),
        ),
      if (permissions.canViewOps)
        _AdminSection(
          id: 'ops',
          label: 'Operations',
          icon: Icons.hub,
          builder: (context, ref) => _OpsSection(permissions: permissions),
        ),
      if (permissions.canViewAudit)
        _AdminSection(
          id: 'audit',
          label: 'Audit',
          icon: Icons.security,
          builder: (context, ref) => _AuditSection(permissions: permissions),
        ),
      if (permissions.canViewSystem)
        _AdminSection(
          id: 'system',
          label: 'System',
          icon: Icons.settings,
          builder: (context, ref) => _SystemSection(permissions: permissions),
        ),
    ];
    for (var i = 0; i < sections.length; i++) {
      sectionIndexById[sections[i].id] = i;
    }

    void navigateToSection(String id) {
      final index = sectionIndexById[id];
      if (index == null) return;
      setState(() => _sectionIndex = index);
    }

    if (!_didInitSection && widget.initialSectionId != null) {
      final target = sectionIndexById[widget.initialSectionId!];
      if (target != null) {
        _sectionIndex = target;
      }
      _didInitSection = true;
    }

    if (_sectionIndex >= sections.length) {
      _sectionIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 1024;
        final showSidebar =
            !widget.embedInShell && (kIsWeb || constraints.maxWidth >= 1200);
        final contentRow = Row(
          children: [
            if (showSidebar)
              SideMenu(
                role: widget.userRole,
                activeRoute: SideMenuRoute.dashboard,
                onNavigate: (route) => _handleSideMenuRoute(
                  context,
                  route,
                  navigateToSection,
                ),
              ),
            if (useRail)
              NavigationRail(
                selectedIndex: _sectionIndex,
                onDestinationSelected: (index) {
                  setState(() => _sectionIndex = index);
                },
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final section in sections)
                    NavigationRailDestination(
                      icon: Icon(section.icon),
                      label: Text(section.label),
                    )
                ],
              ),
            Expanded(
              child: sections[_sectionIndex].builder(context, ref),
            ),
          ],
        );

        if (widget.embedInShell) {
          return Column(
            children: [
              Expanded(child: contentRow),
              if (!useRail)
                NavigationBar(
                  selectedIndex: _sectionIndex,
                  onDestinationSelected: (index) {
                    setState(() => _sectionIndex = index);
                  },
                  destinations: [
                    for (final section in sections)
                      NavigationDestination(
                        icon: Icon(section.icon),
                        label: section.label,
                      )
                  ],
                ),
            ],
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          drawer: showSidebar
              ? null
              : Drawer(
                  child: SideMenu(
                    role: widget.userRole,
                    activeRoute: SideMenuRoute.dashboard,
                    isMobile: true,
                    onNavigate: (route) => _handleSideMenuRoute(
                      context,
                      route,
                      navigateToSection,
                    ),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
          body: Column(
            children: [
              Builder(
                builder: (context) => TopBar(
                  role: widget.userRole,
                  isMobile: !showSidebar,
                  onMenuPressed: showSidebar
                      ? null
                      : () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Expanded(child: contentRow),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _sectionIndex,
                  onDestinationSelected: (index) {
                    setState(() => _sectionIndex = index);
                  },
                  destinations: [
                    for (final section in sections)
                      NavigationDestination(
                        icon: Icon(section.icon),
                        label: section.label,
                      )
                  ],
                ),
        );
      },
    );
  }

  void _handleSideMenuRoute(
    BuildContext context,
    SideMenuRoute route,
    void Function(String) navigateToSection,
  ) {
    switch (route) {
      case SideMenuRoute.dashboard:
        navigateToSection('overview');
        return;
      case SideMenuRoute.organization:
        navigateToSection('orgs');
        return;
      case SideMenuRoute.users:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UserDirectoryPage()),
        );
        return;
      case SideMenuRoute.forms:
        navigateToSection('forms');
        return;
      case SideMenuRoute.approvals:
        navigateToSection('submissions');
        return;
      case SideMenuRoute.auditLogs:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AuditLogsPage()),
        );
        return;
      case SideMenuRoute.systemOverview:
        navigateToSection('system');
        return;
      default:
        break;
    }

    final page = switch (route) {
      SideMenuRoute.notifications => const NotificationsPage(),
      SideMenuRoute.messages => const MessagesPage(),
      SideMenuRoute.companyNews => const NewsPostsPage(),
      SideMenuRoute.organizationChart =>
          OrganizationChartPage(role: widget.userRole),
      SideMenuRoute.team => const TeamsPage(),
      SideMenuRoute.tasks => const TasksPage(),
      SideMenuRoute.documents => const DocumentsPage(),
      SideMenuRoute.photos => const PhotosPage(),
      SideMenuRoute.beforeAfter => const BeforeAfterPhotosPage(),
      SideMenuRoute.assets => const AssetsPage(),
      SideMenuRoute.qrScanner => const QrScannerPage(),
      SideMenuRoute.training => const TrainingHubPage(),
      SideMenuRoute.incidents => const IncidentsPage(),
      SideMenuRoute.aiTools => const AiToolsPage(),
      SideMenuRoute.reports => const ReportsPage(),
      SideMenuRoute.settings => const SettingsPage(),
      SideMenuRoute.projects => const ProjectsPage(),
      SideMenuRoute.workOrders => const WorkOrdersPage(),
      SideMenuRoute.templates => const TemplatesPage(),
      SideMenuRoute.payments => const PaymentRequestsPage(),
      SideMenuRoute.payroll => const PayrollPage(),
      SideMenuRoute.rolesPermissions => widget.userRole == UserRole.admin
          ? const RolesPage()
          : const RolesPermissionsPage(),
      SideMenuRoute.supportTickets => const SupportTicketsPage(),
      SideMenuRoute.knowledgeBase => const SopLibraryPage(),
      SideMenuRoute.systemLogs => const SystemLogsPage(),
      SideMenuRoute.timecards => TimecardsPage(role: widget.userRole),
      _ => null,
    };

    if (page == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _AdminPermissions {
  const _AdminPermissions(this.role);

  final UserRole role;

  bool get canViewOverview => true;
  bool get canViewOrgs => role.canAccessAdminConsole;
  bool get canSwitchOrg => role == UserRole.superAdmin;
  bool get canViewUsers => role.isAdmin || role == UserRole.manager || role == UserRole.supervisor;
  bool get canManageUsers => role.isAdmin;
  bool get canViewForms => role.canAccessAdminConsole;
  bool get canManageForms => role.isAdmin || role == UserRole.manager;
  bool get canViewSubmissions => role.canAccessAdminConsole;
  bool get canManageSubmissions => role.isAdmin || role == UserRole.manager;
  bool get canViewOps => role.canSupervise;
  bool get canViewAudit => role.isAdmin;
  bool get canViewSystem => role == UserRole.superAdmin;
}

class _AdminSection {
  const _AdminSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String label;
  final IconData icon;
  final Widget Function(BuildContext context, WidgetRef ref) builder;
}

class _OrgSwitcher extends ConsumerWidget {
  const _OrgSwitcher({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgs = ref.watch(adminOrganizationsProvider);
    final selectedId = ref.watch(adminSelectedOrgIdProvider);

    return orgs.when(
      data: (data) {
        if (data.isEmpty) {
          return const SizedBox.shrink();
        }
        final active = data.firstWhere(
          (org) => org.id == selectedId,
          orElse: () => data.first,
        );
        return DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: active.id,
            icon: const Icon(Icons.unfold_more),
            items: data
                .map(
                  (org) => DropdownMenuItem(
                    value: org.id,
                    child: Text(compact ? org.name : 'Org: ${org.name}'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              ref.read(adminSelectedOrgIdProvider.notifier).state = value;
            },
          ),
        );
      },
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 16),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }
}

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection({
    required this.permissions,
    required this.showOrgSwitcher,
    required this.userRoleLabel,
    this.onNavigate,
  });

  final _AdminPermissions permissions;
  final bool showOrgSwitcher;
  final String userRoleLabel;
  final void Function(String id)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final orgs = ref.watch(adminOrganizationsProvider);
    final users = ref.watch(adminUsersProvider);
    final userFilters = ref.watch(adminUsersFilterProvider);
    final dayStarted = ref.watch(_adminDayStartedProvider);
    final activeOrgId = ref.watch(adminActiveOrgIdProvider);
    final orgList = orgs.asData?.value ?? const <AdminOrgSummary>[];
    AdminOrgSummary? activeOrg;
    if (orgList.isNotEmpty) {
      activeOrg = orgList.firstWhere(
        (org) => org.id == activeOrgId,
        orElse: () => orgList.first,
      );
    }

    void updateUserSearch(String value) {
      ref.read(adminUsersFilterProvider.notifier).state = (
        search: value,
        role: userFilters.role,
      );
    }
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
            '• Send notifications to all active users\n\n'
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
        ref.read(_adminDayStartedProvider.notifier).state = true;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final cardTheme = theme.cardTheme.copyWith(
          color: scheme.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        );
        return Theme(
          data: theme.copyWith(cardTheme: cardTheme),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.surface,
                  scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 24 : 16,
                16,
                isWide ? 24 : 16,
                24,
              ),
              children: [
                _AdminOverviewHeader(
                  activeOrg: activeOrg,
                  canManageUsers: permissions.canManageUsers,
                  dayStarted: dayStarted,
                  showOrgSwitcher: showOrgSwitcher,
                  userRoleLabel: userRoleLabel,
                  onSearchChanged: updateUserSearch,
                  onStartDay: handleStartDay,
                  onNavigate: onNavigate,
                ),
                const SizedBox(height: 16),
                stats.when(
                  data: (data) {
                    final totalUsers = users.asData?.value.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AdminReactStatsGrid(
                          stats: _adminReactStats(
                            totalUsers: totalUsers ?? 0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _AdminOverviewPanels(
                          isWide: isWide,
                          permissions: permissions,
                          users: users,
                          onUserSearch: updateUserSearch,
                          onNavigate: onNavigate,
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorTile(
                    message: 'Failed to load overview stats',
                    onRetry: () => ref.invalidate(adminStatsProvider),
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

class _AdminOverviewHeader extends StatelessWidget {
  const _AdminOverviewHeader({
    required this.activeOrg,
    required this.canManageUsers,
    required this.dayStarted,
    required this.showOrgSwitcher,
    required this.userRoleLabel,
    required this.onSearchChanged,
    required this.onStartDay,
    this.onNavigate,
  });

  final AdminOrgSummary? activeOrg;
  final bool canManageUsers;
  final bool dayStarted;
  final bool showOrgSwitcher;
  final String userRoleLabel;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onStartDay;
  final void Function(String id)? onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final startedBackground = isDark
                ? const Color(0xFF14532D).withValues(alpha: 0.35)
                : const Color(0xFFDCFCE7);
            final startedForeground =
                isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
            final actionButtons = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: dayStarted ? null : onStartDay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dayStarted
                        ? startedBackground
                        : const Color(0xFF16A34A),
                    foregroundColor:
                        dayStarted ? startedForeground : Colors.white,
                    disabledBackgroundColor: startedBackground,
                    disabledForegroundColor: startedForeground,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: dayStarted
                          ? BorderSide(color: startedForeground.withValues(alpha: 0.6))
                          : BorderSide.none,
                    ),
                  ),
                  icon: Icon(
                    Icons.play_arrow,
                    size: 18,
                    color: dayStarted ? startedForeground : Colors.white,
                  ),
                  label: Text(dayStarted ? 'Day Started ✓' : 'Start Day'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('System Settings'),
                ),
                FilledButton.icon(
                  onPressed: canManageUsers
                      ? () => onNavigate?.call('users')
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add User'),
                ),
              ],
            );

            final header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Dashboard', style: titleStyle),
                const SizedBox(height: 4),
                Text(
                  'User management and system administration',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 16),
                  actionButtons,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 12),
                actionButtons,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdminCommandBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final navPills = [
      const _AdminNavPill(label: 'Dashboard', selected: true),
      _AdminNavPill(
        label: 'Forms',
        onTap: () => onNavigate?.call('forms'),
      ),
      _AdminNavPill(
        label: 'Account',
        onTap: () => onNavigate?.call('users'),
      ),
      _AdminNavPill(
        label: 'Audit Log',
        onTap: () => onNavigate?.call('audit'),
      ),
    ];
    final searchField = TextField(
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Search users, forms, or submissions',
        suffixIcon: const Icon(Icons.tune),
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
    final actions = [
      if (showOrgSwitcher)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _OrgSwitcher(compact: true),
        ),
      Chip(
        label: Text(userRoleLabel),
        backgroundColor: scheme.secondaryContainer,
      ),
      _AdminCommandIcon(
        icon: Icons.notifications_none,
        label: 'Alerts',
        onTap: () => onNavigate?.call('audit'),
      ),
      _AdminCommandIcon(
        icon: Icons.assignment_turned_in_outlined,
        label: 'Entries',
        onTap: () => onNavigate?.call('submissions'),
      ),
      const CircleAvatar(
        radius: 16,
        child: Icon(Icons.person, size: 18),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) {
              return Row(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          Icons.dashboard_customize_outlined,
                          color: scheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Form Bridge',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  Wrap(spacing: 8, children: navPills),
                  const SizedBox(width: 12),
                  Wrap(spacing: 8, children: actions),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.dashboard_customize_outlined,
                        color: scheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Form Bridge',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    ...actions,
                  ],
                ),
                const SizedBox(height: 12),
                searchField,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: navPills,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

List<_AdminReactStat> _adminReactStats({
  required int totalUsers,
}) {
  final totalUsersLabel = NumberFormat.decimalPattern().format(totalUsers);
  return [
    _AdminReactStat(
      label: 'Total Users',
      value: totalUsersLabel,
      icon: Icons.people_outline,
      tone: _AdminStatTone.blue,
      trend: '+12 this month',
    ),
    const _AdminReactStat(
      label: 'Active Sessions',
      value: '142',
      icon: Icons.show_chart,
      tone: _AdminStatTone.green,
    ),
    const _AdminReactStat(
      label: 'Pending Approvals',
      value: '8',
      icon: Icons.schedule,
      tone: _AdminStatTone.orange,
    ),
    const _AdminReactStat(
      label: 'Security Alerts',
      value: '2',
      icon: Icons.shield_outlined,
      tone: _AdminStatTone.red,
      trend: 'Low priority',
    ),
    const _AdminReactStat(
      label: 'System Health',
      value: '99%',
      icon: Icons.check_circle_outline,
      tone: _AdminStatTone.emerald,
    ),
  ];
}

enum _AdminStatTone { blue, green, orange, red, emerald }

class _AdminReactStat {
  const _AdminReactStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.trend,
  });

  final String label;
  final String value;
  final IconData icon;
  final _AdminStatTone tone;
  final String? trend;
}

class _AdminReactStatsGrid extends StatelessWidget {
  const _AdminReactStatsGrid({required this.stats});

  final List<_AdminReactStat> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1100 ? 5 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount > 2 ? 2.25 : 1.4,
          physics: const NeverScrollableScrollPhysics(),
          children: stats
              .map((stat) => _AdminReactStatCard(stat: stat))
              .toList(),
        );
      },
    );
  }
}

class _AdminReactStatCard extends StatelessWidget {
  const _AdminReactStatCard({required this.stat});

  final _AdminReactStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = _AdminStatPalette.fromTone(stat.tone, isDark);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(stat.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            stat.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (stat.trend != null) ...[
            const SizedBox(height: 6),
            Text(
              stat.trend!,
              style: theme.textTheme.labelSmall?.copyWith(
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminStatPalette {
  const _AdminStatPalette({
    required this.gradient,
    required this.border,
    required this.iconBackground,
  });

  final List<Color> gradient;
  final Color border;
  final Color iconBackground;

  factory _AdminStatPalette.fromTone(_AdminStatTone tone, bool isDark) {
    switch (tone) {
      case _AdminStatTone.blue:
        return _AdminStatPalette(
          gradient: isDark
              ? [
                  const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                  const Color(0xFF312E81).withValues(alpha: 0.4),
                ]
              : const [Color(0xFFEFF6FF), Color(0xFFE0E7FF)],
          border: isDark
              ? const Color(0xFF1D4ED8).withValues(alpha: 0.4)
              : const Color(0xFFBFDBFE),
          iconBackground: const Color(0xFF2563EB),
        );
      case _AdminStatTone.green:
        return _AdminStatPalette(
          gradient: isDark
              ? [
                  const Color(0xFF064E3B).withValues(alpha: 0.4),
                  const Color(0xFF065F46).withValues(alpha: 0.4),
                ]
              : const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
          border: isDark
              ? const Color(0xFF059669).withValues(alpha: 0.4)
              : const Color(0xFFBBF7D0),
          iconBackground: const Color(0xFF16A34A),
        );
      case _AdminStatTone.orange:
        return _AdminStatPalette(
          gradient: isDark
              ? [
                  const Color(0xFF7C2D12).withValues(alpha: 0.4),
                  const Color(0xFF9A3412).withValues(alpha: 0.4),
                ]
              : const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
          border: isDark
              ? const Color(0xFFEA580C).withValues(alpha: 0.4)
              : const Color(0xFFFED7AA),
          iconBackground: const Color(0xFFEA580C),
        );
      case _AdminStatTone.red:
        return _AdminStatPalette(
          gradient: isDark
              ? [
                  const Color(0xFF7F1D1D).withValues(alpha: 0.4),
                  const Color(0xFF991B1B).withValues(alpha: 0.4),
                ]
              : const [Color(0xFFFEF2F2), Color(0xFFFFE4E6)],
          border: isDark
              ? const Color(0xFFDC2626).withValues(alpha: 0.4)
              : const Color(0xFFFECACA),
          iconBackground: const Color(0xFFDC2626),
        );
      case _AdminStatTone.emerald:
        return _AdminStatPalette(
          gradient: isDark
              ? [
                  const Color(0xFF065F46).withValues(alpha: 0.4),
                  const Color(0xFF047857).withValues(alpha: 0.4),
                ]
              : const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          border: isDark
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFFA7F3D0),
          iconBackground: const Color(0xFF059669),
        );
    }
  }
}

class _AdminOverviewPanels extends StatelessWidget {
  const _AdminOverviewPanels({
    required this.isWide,
    required this.permissions,
    required this.users,
    required this.onUserSearch,
    required this.onNavigate,
  });

  final bool isWide;
  final _AdminPermissions permissions;
  final AsyncValue<List<AdminUserSummary>> users;
  final ValueChanged<String> onUserSearch;
  final void Function(String id)? onNavigate;

  @override
  Widget build(BuildContext context) {
    final userList = users.asData?.value ?? const <AdminUserSummary>[];
    final roleDistribution = _buildRoleDistribution(userList);
    final approvals = const [
      _AdminApprovalItem(
        type: 'New User Request',
        user: 'John Smith',
        time: '1 hour ago',
      ),
      _AdminApprovalItem(
        type: 'Role Change',
        user: 'Lisa White',
        time: '3 hours ago',
      ),
      _AdminApprovalItem(
        type: 'Access Request',
        user: 'David Kim',
        time: '5 hours ago',
      ),
    ];
    final securityAlerts = const [
      _AdminSecurityAlert(
        title: 'Multiple Login Attempts',
        detail: 'User: mike.chen@company.com',
        tone: _AdminAlertTone.warning,
      ),
      _AdminSecurityAlert(
        title: 'Unusual Activity Detected',
        detail: 'Location: New York',
        tone: _AdminAlertTone.info,
      ),
    ];

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminPanel(
          title: 'User Management',
          child: _AdminUsersPreview(
            users: users,
            onManageUsers:
                permissions.canViewUsers ? () => onNavigate?.call('users') : null,
            onSearch: onUserSearch,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 780;
            final roleCard = _AdminPanel(
              title: 'Role Distribution',
              child: _AdminRoleDistributionCard(items: roleDistribution),
            );
            final activityCard = const _AdminPanel(
              title: 'User Activity',
              child: _AdminUserActivityCard(),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: roleCard),
                  const SizedBox(width: 16),
                  Expanded(child: activityCard),
                ],
              );
            }
            return Column(
              children: [
                roleCard,
                const SizedBox(height: 16),
                activityCard,
              ],
            );
          },
        ),
      ],
    );

    final sideColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminPanel(
          title: 'Quick Actions',
          child: _AdminQuickActions(
            onNavigate: onNavigate,
            canManageUsers: permissions.canManageUsers,
            role: permissions.role,
          ),
        ),
        const SizedBox(height: 16),
        _AdminPanel(
          title: 'Pending Approvals',
          child: _AdminPendingApprovals(items: approvals, totalCount: 8),
        ),
        const SizedBox(height: 16),
        _AdminPanel(
          title: 'Security Alerts',
          child: _AdminSecurityAlerts(items: securityAlerts),
        ),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: mainColumn),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: sideColumn),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        mainColumn,
        const SizedBox(height: 16),
        sideColumn,
      ],
    );
  }
}

List<_RoleDistributionItem> _buildRoleDistribution(
  List<AdminUserSummary> users,
) {
  final total = users.length;
  final roleOrder = <_RoleDistributionItem>[
    const _RoleDistributionItem(
      label: 'Employees',
      role: UserRole.employee,
      color: Color(0xFF3B82F6),
    ),
    const _RoleDistributionItem(
      label: 'Supervisors',
      role: UserRole.supervisor,
      color: Color(0xFF8B5CF6),
    ),
    const _RoleDistributionItem(
      label: 'Managers',
      role: UserRole.manager,
      color: Color(0xFF22C55E),
    ),
    const _RoleDistributionItem(
      label: 'Admins',
      role: UserRole.admin,
      color: Color(0xFFF97316),
    ),
    const _RoleDistributionItem(
      label: 'Tech Support',
      role: UserRole.techSupport,
      color: Color(0xFFEF4444),
    ),
  ];
  return roleOrder.map((item) {
    final count = users.where((user) => user.role == item.role).length;
    final percent = total == 0 ? 0 : ((count / total) * 100).round();
    return item.copyWith(count: count, percent: percent);
  }).toList();
}

class _RoleDistributionItem {
  const _RoleDistributionItem({
    required this.label,
    required this.role,
    required this.color,
    this.count = 0,
    this.percent = 0,
  });

  final String label;
  final UserRole role;
  final Color color;
  final int count;
  final int percent;

  _RoleDistributionItem copyWith({int? count, int? percent}) {
    return _RoleDistributionItem(
      label: label,
      role: role,
      color: color,
      count: count ?? this.count,
      percent: percent ?? this.percent,
    );
  }
}

class _AdminRoleDistributionCard extends StatelessWidget {
  const _AdminRoleDistributionCard({required this.items});

  final List<_RoleDistributionItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF374151),
                        ),
                      ),
                      Text(
                        item.count.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: item.percent / 100,
                      minHeight: 8,
                      backgroundColor:
                          isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation(item.color),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AdminUserActivityCard extends StatelessWidget {
  const _AdminUserActivityCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        _AdminActivityTile(
          label: 'Active Users',
          value: '142',
          detail: 'Currently online',
          color: const Color(0xFF22C55E),
          background: isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.2)
              : const Color(0xFFECFDF5),
          border: isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0),
          icon: Icons.bar_chart,
        ),
        const SizedBox(height: 12),
        _AdminActivityTile(
          label: 'New This Month',
          value: '12',
          detail: '+15% from last month',
          color: const Color(0xFF3B82F6),
          background: isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
              : const Color(0xFFEFF6FF),
          border: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE),
          icon: Icons.trending_up,
        ),
      ],
    );
  }
}

class _AdminActivityTile extends StatelessWidget {
  const _AdminActivityTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    required this.background,
    required this.border,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;
  final Color background;
  final Color border;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
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
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _AdminQuickActions extends StatelessWidget {
  const _AdminQuickActions({
    required this.onNavigate,
    required this.canManageUsers,
    required this.role,
  });

  final void Function(String id)? onNavigate;
  final bool canManageUsers;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AdminQuickActionTile(
          label: 'Add New User',
          icon: Icons.person_add_alt_1,
          color: const Color(0xFF2563EB),
          onTap: canManageUsers ? () => onNavigate?.call('users') : null,
        ),
        const SizedBox(height: 10),
        _AdminQuickActionTile(
          label: 'Manage Roles',
          icon: Icons.key,
          color: const Color(0xFF8B5CF6),
          onTap: () {
            final page = role == UserRole.admin
                ? const RolesPage()
                : const RolesPermissionsPage();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => page),
            );
          },
        ),
        const SizedBox(height: 10),
        _AdminQuickActionTile(
          label: 'System Settings',
          icon: Icons.settings_outlined,
          color: const Color(0xFF22C55E),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
        ),
        const SizedBox(height: 10),
        _AdminQuickActionTile(
          label: 'Audit Logs',
          icon: Icons.description_outlined,
          color: const Color(0xFFF97316),
          onTap: () => onNavigate?.call('audit'),
        ),
      ],
    );
  }
}

class _AdminQuickActionTile extends StatelessWidget {
  const _AdminQuickActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = color.withValues(alpha: isDark ? 0.2 : 0.12);
    final border = color.withValues(alpha: isDark ? 0.4 : 0.2);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminPendingApprovals extends StatelessWidget {
  const _AdminPendingApprovals({
    required this.items,
    required this.totalCount,
  });

  final List<_AdminApprovalItem> items;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _AdminCountPill(
            label: totalCount.toString(),
            color: const Color(0xFFF97316),
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.type,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.time,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.user,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          child: const Text('Review'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text('View All Approvals'),
        ),
      ],
    );
  }
}

class _AdminSecurityAlerts extends StatelessWidget {
  const _AdminSecurityAlerts({required this.items});

  final List<_AdminSecurityAlert> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AdminAlertTile(alert: alert),
            ),
          )
          .toList(),
    );
  }
}

class _AdminAlertTile extends StatelessWidget {
  const _AdminAlertTile({required this.alert});

  final _AdminSecurityAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = alert.tone == _AdminAlertTone.warning
        ? const Color(0xFFF59E0B)
        : const Color(0xFF3B82F6);
    final background = color.withValues(alpha: isDark ? 0.2 : 0.15);
    final border = color.withValues(alpha: isDark ? 0.35 : 0.25);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            alert.tone == _AdminAlertTone.warning
                ? Icons.warning_amber_outlined
                : Icons.monitor_heart_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.detail,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCountPill extends StatelessWidget {
  const _AdminCountPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.15),
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

class _AdminApprovalItem {
  const _AdminApprovalItem({
    required this.type,
    required this.user,
    required this.time,
  });

  final String type;
  final String user;
  final String time;
}

class _AdminSecurityAlert {
  const _AdminSecurityAlert({
    required this.title,
    required this.detail,
    required this.tone,
  });

  final String title;
  final String detail;
  final _AdminAlertTone tone;
}

enum _AdminAlertTone { warning, info }

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _AdminUsersPreview extends StatelessWidget {
  const _AdminUsersPreview({
    required this.users,
    this.onManageUsers,
    this.onSearch,
  });

  final AsyncValue<List<AdminUserSummary>> users;
  final VoidCallback? onManageUsers;
  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    return users.when(
      data: (data) {
        if (data.isEmpty) {
          return const Text('No users found for this organization.');
        }
        final preview = data.take(6).toList();
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;
            final toolbar = Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search user, role, or email',
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('Filter'),
                ),
              ],
            );
            if (isCompact) {
              return Column(
                children: [
                  toolbar,
                  const SizedBox(height: 12),
                  ...preview.map((user) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(user.displayName),
                      subtitle: Text('${user.email} • ${user.role.displayName}'),
                      trailing: _AdminStatusPill(
                        label: user.isActive ? 'active' : 'pending',
                        color: user.isActive ? Colors.green : Colors.orange,
                      ),
                    );
                  }).toList(),
                  if (onManageUsers != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onManageUsers,
                        child: const Text('View All Users'),
                      ),
                    ),
                ],
              );
            }
            return Column(
              children: [
                toolbar,
                const SizedBox(height: 12),
                _buildUserTableHeader(context),
                const SizedBox(height: 8),
                ...preview.map(
                  (user) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildUserTableRow(context, user),
                  ),
                ),
                if (onManageUsers != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onManageUsers,
                      child: const Text('View All Users'),
                    ),
                  ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Failed to load users: $e'),
    );
  }

  Widget _buildUserTableHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('User', style: headerStyle)),
          Expanded(flex: 2, child: Text('Role', style: headerStyle)),
          Expanded(flex: 2, child: Text('Status', style: headerStyle)),
          Expanded(flex: 2, child: Text('Joined', style: headerStyle)),
          const SizedBox(width: 110),
        ],
      ),
    );
  }

  Widget _buildUserTableRow(BuildContext context, AdminUserSummary user) {
    final joined = _shortDateFmt.format(user.createdAt);
    final scheme = Theme.of(context).colorScheme;
    final statusLabel = user.isActive ? 'active' : 'pending';
    final statusColor = user.isActive ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(user.role.displayName),
          ),
          Expanded(
            flex: 2,
            child: _AdminStatusPill(
              label: statusLabel,
              color: statusColor,
            ),
          ),
          Expanded(flex: 2, child: Text(joined)),
          SizedBox(
            width: 110,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: onManageUsers,
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: onManageUsers,
                  child: const Text('View'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSubmissionsPreview extends StatelessWidget {
  const _AdminSubmissionsPreview({
    required this.submissions,
    this.onViewSubmissions,
  });

  final AsyncValue<List<AdminSubmissionSummary>> submissions;
  final VoidCallback? onViewSubmissions;

  @override
  Widget build(BuildContext context) {
    return submissions.when(
      data: (data) {
        if (data.isEmpty) {
          return const Text('No submissions yet.');
        }
        final preview = data.take(6).toList();
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 640;
            if (isCompact) {
              return Column(
                children: preview.map((summary) {
                  final submitter =
                      summary.submittedByName ?? summary.submittedBy ?? 'Unknown';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_turned_in_outlined),
                    title: Text(summary.formTitle ?? 'Submission'),
                    subtitle:
                        Text('$submitter • ${_dateFmt.format(summary.submittedAt)}'),
                    trailing: _AdminStatusPill(
                      label: _formatStatusLabel(summary.status),
                      color: _adminStatusColor(summary.status),
                    ),
                    onTap: onViewSubmissions,
                  );
                }).toList(),
              );
            }
            return Column(
              children: [
                _buildSubmissionTableHeader(context),
                const SizedBox(height: 8),
                ...preview.map(
                  (summary) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildSubmissionTableRow(context, summary),
                  ),
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Failed to load submissions: $e'),
    );
  }

  Widget _buildSubmissionTableHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Form', style: headerStyle)),
          Expanded(flex: 2, child: Text('Submitted by', style: headerStyle)),
          Expanded(flex: 2, child: Text('Status', style: headerStyle)),
          Expanded(flex: 2, child: Text('Submitted', style: headerStyle)),
          const SizedBox(width: 72),
        ],
      ),
    );
  }

  Widget _buildSubmissionTableRow(
    BuildContext context,
    AdminSubmissionSummary summary,
  ) {
    final submitter = summary.submittedByName ?? summary.submittedBy ?? 'Unknown';
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(summary.formTitle ?? 'Submission'),
          ),
          Expanded(flex: 2, child: Text(submitter)),
          Expanded(
            flex: 2,
            child: _AdminStatusPill(
              label: _formatStatusLabel(summary.status),
              color: _adminStatusColor(summary.status),
            ),
          ),
          Expanded(flex: 2, child: Text(_dateFmt.format(summary.submittedAt))),
          SizedBox(
            width: 72,
            child: TextButton(
              onPressed: onViewSubmissions,
              child: const Text('View'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAuditPreview extends StatelessWidget {
  const _AdminAuditPreview({required this.audit});

  final AsyncValue<List<AdminAuditEvent>> audit;

  @override
  Widget build(BuildContext context) {
    return audit.when(
      data: (data) {
        if (data.isEmpty) {
          return const Text('No audit events yet.');
        }
        final preview = data.take(4).toList();
        return Column(
          children: preview.map((event) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text('${event.action} ${event.resourceType}'),
              subtitle: Text(_dateFmt.format(event.createdAt)),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Failed to load audit log: $e'),
    );
  }
}

class _AdminAiAssistantCard extends StatelessWidget {
  const _AdminAiAssistantCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ask questions, draft policy responses, and automate workflows.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        const AiChatPanel(
          suggestions: [
            'Summarize incident trends from the last week.',
            'Draft a compliance update for project managers.',
            'Create an audit checklist for site inspections.',
          ],
          placeholder: 'Ask AI about audits, compliance, or operations...',
          initialMessage: 'Hi! Ask me about audits, submissions, or workflows.',
          maxHeight: 220,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiToolsPage()),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Open AI tools'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OpsHubPage()),
              ),
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Automation hub'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminOpsSnapshot extends StatelessWidget {
  const _AdminOpsSnapshot({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = [
      _OpsMetricData(
        label: 'Automation jobs',
        value: stats.aiJobs,
        icon: Icons.auto_awesome_outlined,
        color: scheme.primary,
      ),
      _OpsMetricData(
        label: 'Export jobs',
        value: stats.exportJobs,
        icon: Icons.cloud_upload_outlined,
        color: scheme.secondary,
      ),
      _OpsMetricData(
        label: 'Webhooks',
        value: stats.webhooks,
        icon: Icons.hub_outlined,
        color: scheme.tertiary,
      ),
      _OpsMetricData(
        label: 'Documents',
        value: stats.documents,
        icon: Icons.folder_open_outlined,
        color: scheme.primary,
      ),
      _OpsMetricData(
        label: 'Assets',
        value: stats.assets,
        icon: Icons.inventory_2_outlined,
        color: scheme.secondary,
      ),
      _OpsMetricData(
        label: 'Reviews',
        value: stats.reviews,
        icon: Icons.rate_review_outlined,
        color: scheme.tertiary,
      ),
    ];
    var maxValue = 0;
    for (final metric in metrics) {
      if (metric.value > maxValue) {
        maxValue = metric.value;
      }
    }
    return Column(
      children: metrics
          .map(
            (metric) => _OpsMetricRow(
              label: metric.label,
              value: metric.value,
              max: maxValue,
              icon: metric.icon,
              color: metric.color,
            ),
          )
          .toList(),
    );
  }
}

class _OpsMetricRow extends StatelessWidget {
  const _OpsMetricRow({
    required this.label,
    required this.value,
    required this.max,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final int max;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
              Text(
                value.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpsMetricData {
  const _OpsMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _AdminStatusPill extends StatelessWidget {
  const _AdminStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
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

class _AdminCommandIcon extends StatelessWidget {
  const _AdminCommandIcon({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavPill extends StatelessWidget {
  const _AdminNavPill({
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = selected ? scheme.primary : scheme.surface;
    final foreground =
        selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

Color _adminStatusColor(String status) {
  final normalized = status.replaceAll('_', '').toLowerCase();
  switch (normalized) {
    case 'approved':
      return Colors.green.shade600;
    case 'rejected':
      return Colors.red.shade400;
    case 'underreview':
      return Colors.orange.shade600;
    case 'requireschanges':
      return Colors.deepOrange.shade400;
    case 'pendingsync':
      return Colors.blueGrey.shade400;
    case 'archived':
      return Colors.grey.shade500;
    case 'draft':
      return Colors.blueGrey.shade300;
    case 'submitted':
    default:
      return Colors.indigo.shade400;
  }
}

String _formatStatusLabel(String status) {
  if (status.isEmpty) return 'Unknown';
  final cleaned = status.replaceAll('_', ' ');
  final buffer = StringBuffer();
  for (var i = 0; i < cleaned.length; i++) {
    final char = cleaned[i];
    if (i == 0) {
      buffer.write(char.toUpperCase());
      continue;
    }
    if (char == ' ') {
      buffer.write(char);
      continue;
    }
    if (char.toUpperCase() == char && char.toLowerCase() != char) {
      buffer.write(' ');
    }
    buffer.write(char);
  }
  return buffer.toString();
}

String _formatCompact(int value) {
  return NumberFormat.compact().format(value);
}

class _OrganizationsSection extends ConsumerWidget {
  const _OrganizationsSection({required this.permissions});

  final _AdminPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgs = ref.watch(adminOrganizationsProvider);
    final activeOrgId = ref.watch(adminActiveOrgIdProvider);

    return _SectionShell(
      title: 'Organizations',
      subtitle: permissions.canSwitchOrg
          ? 'Switch and monitor organizations across the platform.'
          : 'Your organization overview and membership counts.',
      children: [
        if (permissions.canSwitchOrg) const _OrgSwitcher(),
        if (permissions.canSwitchOrg) const SizedBox(height: 12),
        orgs.when(
          data: (data) {
            if (data.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No organizations available.'),
                ),
              );
            }
            return Column(
              children: data
                  .map(
                    (org) => Card(
                      child: ListTile(
                        title: Text(org.name),
                        subtitle: Text(
                          'Members: ${org.memberCount} • Created ${_shortDateFmt.format(org.createdAt)}',
                        ),
                        trailing: permissions.canSwitchOrg
                            ? FilledButton(
                                onPressed: org.id == activeOrgId
                                    ? null
                                    : () {
                                        ref
                                            .read(
                                              adminSelectedOrgIdProvider.notifier,
                                            )
                                            .state = org.id;
                                      },
                                child: Text(
                                  org.id == activeOrgId
                                      ? 'Active'
                                      : 'Switch',
                                ),
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorTile(
            message: 'Failed to load organizations',
            onRetry: () => ref.invalidate(adminOrganizationsProvider),
          ),
        ),
      ],
    );
  }
}

class _UsersSection extends ConsumerWidget {
  const _UsersSection({required this.permissions});

  final _AdminPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    final filters = ref.watch(adminUsersFilterProvider);
    final roleOptions = _assignableRoles(permissions.role);

    return _SectionShell(
      title: 'Users',
      subtitle: permissions.canManageUsers
          ? 'Manage roles and view user access in the active organization.'
          : 'View team members in the active organization.',
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name or email',
                ),
                onChanged: (value) {
                  ref.read(adminUsersFilterProvider.notifier).state = (
                    search: value,
                    role: filters.role,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<UserRole?>(
              value: filters.role,
              hint: const Text('Role'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All roles')),
                ...UserRole.values.map(
                  (role) => DropdownMenuItem(
                    value: role,
                    child: Text(role.displayName),
                  ),
                ),
              ],
              onChanged: (value) {
                ref.read(adminUsersFilterProvider.notifier).state = (
                  search: filters.search,
                  role: value,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        users.when(
          data: (data) {
            if (data.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No users found for this organization.'),
                ),
              );
            }
            return Column(
              children: data
                  .map(
                    (user) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(user.displayName),
                        subtitle: Text(
                          '${user.email} • Joined ${_shortDateFmt.format(user.createdAt)}',
                        ),
                        trailing: permissions.canManageUsers
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: user.isActive,
                                    onChanged: (value) async {
                                      await ref
                                          .read(adminRepositoryProvider)
                                          .updateUserActive(
                                            userId: user.id,
                                            isActive: value,
                                          );
                                      if (!context.mounted) return;
                                      ref.invalidate(adminUsersProvider);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            value
                                                ? 'Activated ${user.displayName}'
                                                : 'Deactivated ${user.displayName}',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (roleOptions.contains(user.role))
                                    DropdownButton<UserRole>(
                                      value: user.role,
                                      items: roleOptions
                                          .map(
                                            (role) => DropdownMenuItem(
                                              value: role,
                                              child: Text(role.displayName),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) async {
                                        if (value == null || value == user.role) {
                                          return;
                                        }
                                        await ref
                                            .read(adminRepositoryProvider)
                                            .updateUserRole(
                                              userId: user.id,
                                              role: value,
                                            );
                                        if (!context.mounted) return;
                                        ref.invalidate(adminUsersProvider);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Updated ${user.displayName} to ${value.displayName}',
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  else
                                    Chip(label: Text(user.role.displayName)),
                                ],
                              )
                            : Chip(label: Text(user.role.displayName)),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorTile(
            message: 'Failed to load users',
            onRetry: () => ref.invalidate(adminUsersProvider),
          ),
        ),
      ],
    );
  }
}

class _FormsSection extends ConsumerWidget {
  const _FormsSection({required this.permissions});

  final _AdminPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final forms = ref.watch(adminFormsProvider);
    final filters = ref.watch(adminFormsFilterProvider);

    return _SectionShell(
      title: 'Forms',
      subtitle: permissions.canManageForms
          ? 'Publish, filter, and monitor templates.'
          : 'View templates in the active organization.',
      children: [
        stats.when(
          data: (data) => _InlineStatRow(
            items: [
              _StatItem(label: 'Forms', value: data.forms),
              _StatItem(label: 'Submissions', value: data.submissions),
              _StatItem(label: 'Attachments', value: data.attachments),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        _FiltersBar(
          search: filters.search,
          category: filters.category,
          published: filters.published,
          onChanged: (search, category, published) {
            ref.read(adminFormsFilterProvider.notifier).state = (
              search: search,
              category: category,
              published: published,
            );
          },
          forms: forms,
        ),
        const SizedBox(height: 12),
        stats.when(
          data: (data) => _FormsByCategoryCard(stats: data),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        forms.when(
          data: (data) => _FormsList(
            forms: data,
            canManage: permissions.canManageForms,
            onPublishToggle: (id, value) async {
              await ref
                  .read(adminRepositoryProvider)
                  .togglePublish(formId: id, isPublished: value);
              ref.invalidate(adminFormsProvider);
              ref.invalidate(adminStatsProvider);
            },
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ErrorTile(
            message: 'Failed to load forms',
            onRetry: () => ref.invalidate(adminFormsProvider),
          ),
        ),
      ],
    );
  }
}

class _SubmissionsSection extends ConsumerWidget {
  const _SubmissionsSection({required this.permissions});

  final _AdminPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissions = ref.watch(adminSubmissionsProvider);
    final status = ref.watch(adminSubmissionsStatusProvider);
    final roleFilter = ref.watch(adminSubmissionsRoleProvider);

    return _SectionShell(
      title: 'Submissions',
      subtitle: permissions.canManageSubmissions
          ? 'Review recent submissions and drill into details.'
          : 'View recent submissions for the active organization.',
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: ValueKey(status),
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'underReview', child: Text('Under review')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (val) {
                  ref.read(adminSubmissionsStatusProvider.notifier).state = val;
                  ref.invalidate(adminSubmissionsProvider);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<UserRole?>(
                key: ValueKey(roleFilter),
                initialValue: roleFilter,
                decoration: const InputDecoration(labelText: 'Submitter role'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All roles')),
                  ...UserRole.values.map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.displayName),
                    ),
                  ),
                ],
                onChanged: (val) {
                  ref.read(adminSubmissionsRoleProvider.notifier).state = val;
                },
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () => ref.invalidate(adminSubmissionsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        submissions.when(
          data: (data) {
            final filtered = roleFilter == null
                ? data
                : data
                    .where((item) => item.submittedByRole == roleFilter)
                    .toList();
            return _SubmissionsList(
              submissions: filtered,
              onTap: (summary) async {
                final full = await ref
                    .read(adminRepositoryProvider)
                    .fetchSubmissionDetail(summary.id);
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubmissionDetailPage(submission: full),
                  ),
                );
                if (!context.mounted) return;
                ref.invalidate(adminSubmissionsProvider);
              },
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ErrorTile(
            message: 'Failed to load submissions',
            onRetry: () => ref.invalidate(adminSubmissionsProvider),
          ),
        ),
      ],
    );
  }
}

class _OpsSection extends ConsumerWidget {
  const _OpsSection({required this.permissions});

  final _AdminPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);

    return _SectionShell(
      title: 'Operations',
      subtitle: 'Quick access to operational modules and live counts.',
      children: [
        stats.when(
          data: (data) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _AdminActionCard(
                label: 'Projects',
                value: data.projects,
                icon: Icons.folder_open,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProjectsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Tasks',
                value: data.tasks,
                icon: Icons.checklist,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TasksPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Assets',
                value: data.assets,
                icon: Icons.inventory_2,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AssetsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Photo Galleries',
                value: data.projectPhotos,
                icon: Icons.photo_library,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PhotosPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Documents',
                value: data.documents,
                icon: Icons.folder_copy,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DocumentsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Signatures',
                value: data.signatureRequests,
                icon: Icons.border_color,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignatureRequestsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Training',
                value: data.trainingRecords,
                icon: Icons.school,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TrainingHubPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Reports',
                value: data.submissions,
                icon: Icons.insights,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Ops Hub',
                value: data.notifications,
                icon: Icons.hub,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OpsHubPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Notebook Pages',
                value: data.notebookPages,
                icon: Icons.note_alt,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotebookPagesPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Notebook Reports',
                value: data.notebookReports,
                icon: Icons.picture_as_pdf,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotebookReportsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'News Posts',
                value: data.newsPosts,
                icon: Icons.campaign,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewsPostsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Notification Rules',
                value: data.notificationRules,
                icon: Icons.notifications_active,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationRulesPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Messages',
                value: data.messageThreads,
                icon: Icons.chat_bubble_outline,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MessagesPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Clients',
                value: data.clients,
                icon: Icons.business,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClientsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Vendors',
                value: data.vendors,
                icon: Icons.handshake,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VendorsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Guest Access',
                value: data.guestInvites,
                icon: Icons.person_add_alt_1,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GuestInvitesPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Payments',
                value: data.paymentRequests,
                icon: Icons.payments,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaymentRequestsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Reviews',
                value: data.reviews,
                icon: Icons.star_rate,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReviewsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Portfolio',
                value: data.portfolioItems,
                icon: Icons.auto_stories,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PortfolioItemsPage()),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorTile(
            message: 'Failed to load ops data',
            onRetry: () => ref.invalidate(adminStatsProvider),
          ),
        ),
      ],
    );
  }
}

class _AuditSection extends ConsumerWidget {
  const _AuditSection({required this.permissions});

  final _AdminPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(adminAuditProvider);

    return _SectionShell(
      title: 'Audit Log',
      subtitle: 'Latest administrative actions for this organization.',
      children: [
        audit.when(
          data: (data) {
            if (data.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No audit events yet.'),
                ),
              );
            }
            return Column(
              children: data
                  .map(
                    (event) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(
                          '${event.action} ${event.resourceType}',
                        ),
                        subtitle: Text(
                          'Actor: ${event.actorId ?? 'System'} • ${_dateFmt.format(event.createdAt)}',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorTile(
            message: 'Failed to load audit log',
            onRetry: () => ref.invalidate(adminAuditProvider),
          ),
        ),
      ],
    );
  }
}

class _SystemSection extends ConsumerWidget {
  const _SystemSection({required this.permissions});

  final _AdminPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);

    return _SectionShell(
      title: 'System',
      subtitle: 'Platform-wide integrations and automation controls.',
      children: [
        stats.when(
          data: (data) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _AdminActionCard(
                label: 'Webhooks',
                value: data.webhooks,
                icon: Icons.link,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IntegrationsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'Export Jobs',
                value: data.exportJobs,
                icon: Icons.file_download,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExportJobsPage()),
                ),
              ),
              _AdminActionCard(
                label: 'AI Jobs',
                value: data.aiJobs,
                icon: Icons.auto_awesome,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiToolsPage()),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorTile(
            message: 'Failed to load system data',
            onRetry: () => ref.invalidate(adminStatsProvider),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      _MetricCardData(
        title: 'Forms',
        value: stats.forms,
        icon: Icons.description,
        color: theme.colorScheme.primaryContainer,
      ),
      _MetricCardData(
        title: 'Submissions',
        value: stats.submissions,
        icon: Icons.assignment_turned_in,
        color: theme.colorScheme.secondaryContainer,
      ),
      _MetricCardData(
        title: 'Attachments',
        value: stats.attachments,
        icon: Icons.attach_file,
        color: theme.colorScheme.tertiaryContainer,
      ),
      _MetricCardData(
        title: 'Projects',
        value: stats.projects,
        icon: Icons.folder_open,
        color: theme.colorScheme.primaryContainer,
      ),
      _MetricCardData(
        title: 'Tasks',
        value: stats.tasks,
        icon: Icons.checklist,
        color: theme.colorScheme.secondaryContainer,
      ),
      _MetricCardData(
        title: 'Assets',
        value: stats.assets,
        icon: Icons.inventory_2,
        color: theme.colorScheme.tertiaryContainer,
      ),
      _MetricCardData(
        title: 'Documents',
        value: stats.documents,
        icon: Icons.folder_copy,
        color: theme.colorScheme.primaryContainer,
      ),
      _MetricCardData(
        title: 'Training',
        value: stats.trainingRecords,
        icon: Icons.school,
        color: theme.colorScheme.secondaryContainer,
      ),
      _MetricCardData(
        title: 'Incidents',
        value: stats.incidents,
        icon: Icons.report_problem,
        color: theme.colorScheme.tertiaryContainer,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 720;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((card) => SizedBox(
                      width: isWide
                          ? (constraints.maxWidth / 3) - 10
                          : constraints.maxWidth,
                      child: _StatCard(card: card),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }
}

class _OverviewHighlights extends StatelessWidget {
  const _OverviewHighlights({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Highlights',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Inspections logged: ${stats.inspections}'),
            Text('Active notifications: ${stats.notifications}'),
            Text('Automation jobs: ${stats.exportJobs + stats.aiJobs}'),
          ],
        ),
      ),
    );
  }
}

class _AiUsageSection extends ConsumerWidget {
  const _AiUsageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(adminAiUsageProvider);
    return usage.when(
      data: (data) {
        const heavyThreshold = 50;
        final sortedTypes = data.byType.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topTypes = sortedTypes.take(6).toList();
        final avgPerDay = (data.totalJobs / 30).toStringAsFixed(1);
        final heavyUsers =
            data.topUsers.where((user) => user.jobs >= heavyThreshold).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'AI Usage',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(data.windowLabel,
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(adminAiUsageProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Total jobs: ${data.totalJobs}'),
                Text('Avg per day: $avgPerDay'),
                const SizedBox(height: 12),
                if (topTypes.isNotEmpty) ...[
                  const Text('Top AI tasks'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in topTypes)
                        Chip(
                          label: Text(
                            '${_labelForAiType(entry.key)} (${entry.value})',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Heavy users'),
                const SizedBox(height: 6),
                if (data.topUsers.isEmpty)
                  const Text('No AI usage recorded yet.'),
                if (data.topUsers.isNotEmpty)
                  Column(
                    children: data.topUsers
                        .map(
                          (user) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person),
                            title: Text(user.displayName),
                            subtitle: Text(user.email),
                            trailing: Text('${user.jobs} jobs'),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),
                const Text('AI Alerts'),
                const SizedBox(height: 6),
                if (heavyUsers.isEmpty)
                  const Text('No AI alerts.'),
                if (heavyUsers.isNotEmpty)
                  Column(
                    children: heavyUsers
                        .map(
                          (user) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.warning_amber),
                            title: Text(user.displayName),
                            subtitle: Text(
                              'High usage (${user.jobs} jobs in ${data.windowLabel})',
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorTile(
        message: 'Failed to load AI usage',
        onRetry: () => ref.invalidate(adminAiUsageProvider),
      ),
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final String? subtitle;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.card});

  final _MetricCardData card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: card.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(card.icon, color: card.color),
                ),
                const Spacer(),
                Icon(
                  Icons.trending_up,
                  size: 18,
                  color: scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _formatCompact(card.value),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              card.title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (card.subtitle != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  card.subtitle!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.label,
    required this.value,
    required this.max,
  });

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final pct = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(value.toString()),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormsByCategoryCard extends StatelessWidget {
  const _FormsByCategoryCard({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.formsByCategory.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forms by category',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...stats.formsByCategory.entries.map(
              (e) => _CategoryBar(
                label: e.key.isEmpty ? 'Uncategorized' : e.key,
                value: e.value,
                max: stats.forms,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.search,
    required this.category,
    required this.published,
    required this.onChanged,
    required this.forms,
  });

  final String search;
  final String category;
  final bool? published;
  final void Function(String search, String category, bool? published) onChanged;
  final AsyncValue<List<AdminFormSummary>> forms;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search forms',
            ),
            onChanged: (value) => onChanged(value, category, published),
          ),
        ),
        const SizedBox(width: 12),
        forms.when(
          data: (data) {
            final set = <String>{};
            for (final f in data) {
              if (f.category != null && f.category!.isNotEmpty) {
                set.add(f.category!);
              }
            }
            final list = set.toList()..sort();
            final hasCategory = category.isNotEmpty && list.contains(category);
            final selected = hasCategory ? category : '';
            final items = [
              const DropdownMenuItem(value: '', child: Text('All')),
              ...list.map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ];
            return DropdownButton<String>(
              hint: const Text('Category'),
              value: selected.isEmpty ? null : selected,
              items: items,
              onChanged: (val) => onChanged(search, val ?? '', published),
            );
          },
          loading: () => DropdownButton<String>(
            hint: const Text('Category'),
            value: null,
            items: const [
              DropdownMenuItem(value: '', child: Text('Loading...')),
            ],
            onChanged: null,
          ),
          error: (_, _) => DropdownButton<String>(
            hint: const Text('Category'),
            value: null,
            items: const [
              DropdownMenuItem(value: '', child: Text('Error')),
            ],
            onChanged: null,
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<bool?>(
          hint: const Text('Published'),
          value: published,
          items: const [
            DropdownMenuItem(value: null, child: Text('All')),
            DropdownMenuItem(value: true, child: Text('Published')),
            DropdownMenuItem(value: false, child: Text('Draft')),
          ],
          onChanged: (val) => onChanged(search, category, val),
        ),
      ],
    );
  }
}

class _FormsList extends StatelessWidget {
  const _FormsList({
    required this.forms,
    required this.onPublishToggle,
    required this.canManage,
  });

  final List<AdminFormSummary> forms;
  final Future<void> Function(String id, bool value) onPublishToggle;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No forms yet.')),
        ),
      );
    }
    return Card(
      child: Column(
        children: forms
            .map(
              (f) => ListTile(
                leading: Icon(
                  f.isPublished ? Icons.check_circle : Icons.circle_outlined,
                  color: f.isPublished
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(f.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${f.category ?? 'Uncategorized'} • v${f.version ?? '1.0.0'} • ${_dateFmt.format(f.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (f.tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: f.tags
                            .take(5)
                            .map(
                              (t) => Chip(
                                label: Text(t),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
                trailing: Switch(
                  value: f.isPublished,
                  onChanged: canManage ? (val) => onPublishToggle(f.id, val) : null,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SubmissionsList extends StatelessWidget {
  const _SubmissionsList({
    required this.submissions,
    required this.onTap,
  });

  final List<AdminSubmissionSummary> submissions;
  final void Function(AdminSubmissionSummary submission) onTap;

  Color _statusColor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'underreview':
      case 'under_review':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No submissions yet.')),
        ),
      );
    }
    return Card(
      child: Column(
        children: submissions
            .map(
              (s) {
                final inputTypes = _inputTypesFromMeta(s.metadata)
                    .map((type) => submissionInputTypeLabels[type] ?? type)
                    .toList();
                final visibility = _visibilityFromMeta(s.metadata);
                final submitter = _buildSubmitterLabel(s);
                final showMeta = inputTypes.isNotEmpty || visibility.isNotEmpty;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _statusColor(context, s.status).withValues(alpha: 0.1),
                    child: Icon(Icons.description,
                        color: _statusColor(context, s.status)),
                  ),
                  title: Text(s.formTitle ?? s.formId),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.status.toUpperCase()} • ${_dateFmt.format(s.submittedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (submitter.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          submitter,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (showMeta) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            ...inputTypes.map(
                              (label) => Chip(
                                label: Text(label),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            if (visibility.isNotEmpty)
                              Chip(
                                avatar:
                                    const Icon(Icons.lock_outline, size: 16),
                                label: Text(
                                  submissionAccessLevelLabels[visibility] ??
                                      visibility,
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Attachments'),
                      Text(
                        s.attachmentsCount.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                  isThreeLine: submitter.isNotEmpty || showMeta,
                  onTap: () => onTap(s),
                );
              },
            )
            .toList(),
      ),
    );
  }

  List<String> _inputTypesFromMeta(Map<String, dynamic>? metadata) {
    final raw = metadata?['inputTypes'];
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .map((item) => item == 'file' ? 'document' : item)
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    }
    return const [];
  }

  String _visibilityFromMeta(Map<String, dynamic>? metadata) {
    final raw = metadata?['visibility'] ?? metadata?['accessLevel'];
    if (raw == null) return '';
    final value = raw.toString().trim();
    return value;
  }

  String _buildSubmitterLabel(AdminSubmissionSummary summary) {
    final name = summary.submittedByName ?? summary.submittedBy ?? '';
    final role = summary.submittedByRole?.displayName;
    if (name.isEmpty && role == null) return '';
    if (role == null || role.isEmpty) return 'By $name';
    if (name.isEmpty) return 'By $role';
    return 'By $name ($role)';
  }
}

class _InlineStatRow extends StatelessWidget {
  const _InlineStatRow({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items
          .map(
            (item) => Chip(
              label: Text('${item.label}: ${item.value}'),
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          )
          .toList(),
    );
  }
}

class _StatItem {
  const _StatItem({required this.label, required this.value});

  final String label;
  final int value;
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('Count: $value'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _labelForAiType(String type) {
  switch (type) {
    case 'photo_caption':
      return 'Photo caption';
    case 'progress_recap':
      return 'Progress recap';
    case 'translation':
      return 'Translation';
    case 'checklist_builder':
      return 'Checklist builder';
    case 'field_report':
      return 'Field report';
    case 'walkthrough_notes':
      return 'Walkthrough notes';
    case 'daily_log':
      return 'Daily log';
    case 'summary':
      return 'Summary';
    default:
      return type.replaceAll('_', ' ');
  }
}

List<UserRole> _assignableRoles(UserRole actor) {
  switch (actor) {
    case UserRole.superAdmin:
      return UserRole.values;
    case UserRole.admin:
      return const [
        UserRole.admin,
        UserRole.manager,
        UserRole.supervisor,
        UserRole.employee,
        UserRole.maintenance,
        UserRole.techSupport,
        UserRole.client,
        UserRole.vendor,
        UserRole.viewer,
      ];
    case UserRole.manager:
      return const [
        UserRole.manager,
        UserRole.supervisor,
        UserRole.employee,
        UserRole.maintenance,
        UserRole.client,
        UserRole.vendor,
        UserRole.viewer,
      ];
    case UserRole.supervisor:
      return const [
        UserRole.supervisor,
        UserRole.employee,
        UserRole.maintenance,
        UserRole.viewer,
      ];
    case UserRole.employee:
    case UserRole.maintenance:
    case UserRole.techSupport:
    case UserRole.client:
    case UserRole.vendor:
    case UserRole.viewer:
      return const [];
  }
}
