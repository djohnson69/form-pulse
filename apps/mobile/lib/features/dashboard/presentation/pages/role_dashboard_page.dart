// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../../admin/presentation/pages/admin_shell_page.dart';
import '../../../admin/presentation/pages/super_admin_dashboard_page.dart';
import '../../../analytics/presentation/pages/analytics_page.dart';
import '../../../assets/presentation/pages/assets_page.dart';
import '../../../documents/presentation/pages/documents_page.dart';
import '../../../documents/data/documents_provider.dart';
import '../../../navigation/presentation/pages/approvals_page.dart';
import '../../../navigation/presentation/pages/audit_logs_page.dart';
import '../../../navigation/presentation/pages/before_after_photos_page.dart';
import '../../../navigation/presentation/pages/forms_page.dart';
import '../../../navigation/presentation/pages/incidents_page.dart';
import '../../../navigation/presentation/pages/notifications_page.dart';
import '../../../navigation/presentation/pages/organization_chart_page.dart';
import '../../../navigation/presentation/pages/payroll_page.dart';
import '../../../navigation/presentation/pages/photos_page.dart';
import '../../../navigation/presentation/pages/qr_scanner_page.dart';
import '../../../navigation/presentation/pages/roles_page.dart';
import '../../../navigation/presentation/pages/roles_permissions_page.dart';
import '../../../navigation/presentation/pages/role_customization_page.dart';
import '../../../navigation/presentation/pages/support_tickets_page.dart';
import '../../../navigation/presentation/pages/system_overview_page.dart';
import '../../../navigation/presentation/pages/system_logs_page.dart';
import '../../../navigation/presentation/pages/timecards_page.dart';
import '../../../navigation/presentation/pages/user_directory_page.dart';
import '../../../navigation/presentation/pages/work_orders_page.dart';
import '../../../ops/presentation/pages/ai_tools_page.dart';
import '../../../ops/presentation/pages/news_posts_page.dart';
import '../../../ops/presentation/pages/payment_requests_page.dart';
import '../../../partners/presentation/pages/messages_page.dart';
import '../../../projects/presentation/pages/projects_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../sop/presentation/pages/sop_library_page.dart';
import '../../../tasks/presentation/pages/tasks_page.dart';
import '../../../tasks/presentation/pages/task_detail_page.dart';
import '../../../teams/presentation/pages/teams_page.dart';
import '../../../templates/presentation/pages/templates_page.dart';
import '../../../training/data/training_provider.dart';
import '../../../training/presentation/pages/training_hub_page.dart';
import '../../../navigation/presentation/widgets/side_menu.dart';
import '../widgets/dashboard_shell.dart';
import '../../data/user_profile_provider.dart';
import '../../data/role_override_provider.dart';
import '../../data/dashboard_provider.dart';
import '../../data/dashboard_layout_provider.dart';
import '../../../tasks/data/tasks_provider.dart';
import '../widgets/notification_panel.dart';
import 'dashboard_page.dart';

class RoleDashboardPage extends ConsumerWidget {
  const RoleDashboardPage({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(roleOverrideProvider);
    final activeRole = override ?? role;
    switch (activeRole) {
      case UserRole.developer:
        return const SuperAdminDashboardPage(role: UserRole.developer);
      case UserRole.superAdmin:
        return const SuperAdminDashboardPage();
      case UserRole.admin:
        return AdminShellPage(role: activeRole);
      case UserRole.manager:
        return RoleShellPage(role: activeRole);
      case UserRole.supervisor:
        return RoleShellPage(role: activeRole);
      case UserRole.employee:
        return RoleShellPage(role: activeRole);
      case UserRole.maintenance:
        return RoleShellPage(role: activeRole);
      case UserRole.techSupport:
        return RoleShellPage(role: activeRole);
      case UserRole.client:
      case UserRole.vendor:
      case UserRole.viewer:
        return const DashboardPage();
    }
  }
}

class RoleShellPage extends ConsumerStatefulWidget {
  const RoleShellPage({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<RoleShellPage> createState() => _RoleShellPageState();
}

class _RoleShellPageState extends ConsumerState<RoleShellPage> {
  SideMenuRoute _activeRoute = SideMenuRoute.dashboard;

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      role: widget.role,
      activeRoute: _activeRoute,
      showRightSidebar: false,
      onNavigate: (route) => setState(() => _activeRoute = route),
      child: _pageForRoute(widget.role, _activeRoute),
    );
  }
}

Widget _pageForRoute(UserRole role, SideMenuRoute route) {
  if (route == SideMenuRoute.dashboard) {
    return _roleDashboardBody(role);
  }
  return switch (route) {
    SideMenuRoute.notifications => const NotificationsPage(),
    SideMenuRoute.messages => const MessagesPage(),
    SideMenuRoute.companyNews => const NewsPostsPage(),
    SideMenuRoute.organizationChart => OrganizationChartPage(role: role),
    SideMenuRoute.team => const TeamsPage(),
    SideMenuRoute.organization => role.canAccessAdminConsole
        ? AdminDashboardPage(
            userRole: role,
            initialSectionId: 'orgs',
            embedInShell: true,
          )
        : OrganizationChartPage(role: role),
    SideMenuRoute.tasks => const TasksPage(),
    SideMenuRoute.forms => const FormsPage(),
    SideMenuRoute.approvals => const ApprovalsPage(),
    SideMenuRoute.documents => const DocumentsPage(),
    SideMenuRoute.photos => const PhotosPage(),
    SideMenuRoute.beforeAfter => const BeforeAfterPhotosPage(),
    SideMenuRoute.assets => const AssetsPage(),
    SideMenuRoute.qrScanner => const QrScannerPage(),
    SideMenuRoute.training => const TrainingHubPage(),
    SideMenuRoute.incidents => const IncidentsPage(),
    SideMenuRoute.aiTools => const AiToolsPage(),
    SideMenuRoute.timecards => TimecardsPage(role: role),
    SideMenuRoute.reports => const AnalyticsPage(),
    SideMenuRoute.settings => const SettingsPage(),
    SideMenuRoute.projects => const ProjectsPage(),
    SideMenuRoute.workOrders => const WorkOrdersPage(),
    SideMenuRoute.templates => const TemplatesPage(),
    SideMenuRoute.payments => const PaymentRequestsPage(),
    SideMenuRoute.payroll => const PayrollPage(),
    SideMenuRoute.auditLogs => role.canAccessAdminConsole
        ? const AuditLogsPage()
        : const SystemLogsPage(),
    SideMenuRoute.rolesPermissions => role == UserRole.admin
        ? const RolesPage()
        : const RolesPermissionsPage(),
    SideMenuRoute.roleCustomization => const RoleCustomizationPage(),
    SideMenuRoute.systemOverview => const SystemOverviewPage(),
    SideMenuRoute.supportTickets => const SupportTicketsPage(),
    SideMenuRoute.knowledgeBase => const SopLibraryPage(),
    SideMenuRoute.systemLogs => const SystemLogsPage(),
    SideMenuRoute.users => const UserDirectoryPage(),
    SideMenuRoute.dashboard => _roleDashboardBody(role),
  };
}

Widget _roleDashboardBody(UserRole role) {
  switch (role) {
    case UserRole.employee:
      return const EmployeeDashboardPage(embedInShell: false);
    case UserRole.supervisor:
      return const SupervisorDashboardPage(embedInShell: false);
    case UserRole.manager:
      return const ManagerDashboardPage(embedInShell: false);
    case UserRole.maintenance:
      return const MaintenanceDashboardPage(embedInShell: false);
    case UserRole.techSupport:
      return const TechSupportDashboardPage(embedInShell: false);
    case UserRole.developer:
    case UserRole.admin:
    case UserRole.superAdmin:
    case UserRole.client:
    case UserRole.vendor:
    case UserRole.viewer:
      return const DashboardPage();
  }
}

class EmployeeDashboardPage extends ConsumerStatefulWidget {
  const EmployeeDashboardPage({super.key, this.embedInShell = true});

  final bool embedInShell;

  @override
  ConsumerState<EmployeeDashboardPage> createState() =>
      _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends ConsumerState<EmployeeDashboardPage> {
  bool _clockedIn = false;
  String? _clockInTime;
  String _locationLabel = 'Getting location...';
  final Set<String> _dismissedNotificationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    final location = await _resolveLocation();
    if (!mounted) return;
    setState(() => _locationLabel = location);
  }

  Future<String> _resolveLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Location unavailable';
      }
      final position = await Geolocator.getCurrentPosition();
      return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    } catch (_) {
      return 'Location unavailable';
    }
  }

  Future<void> _clockIn() async {
    final time = DateFormat('h:mm a').format(DateTime.now());
    final location = await _resolveLocation();
    if (!mounted) return;
    if (location == 'Location unavailable') {
      setState(() => _locationLabel = location);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Unable to get location. Please enable location services.'),
        ),
      );
      return;
    }
    setState(() {
      _clockedIn = true;
      _clockInTime = time;
      _locationLabel = location;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Clocked in at $time\nLocation: $location')),
    );
  }

  void _clockOut() {
    final time = DateFormat('h:mm a').format(DateTime.now());
    final startTime = _clockInTime;
    setState(() {
      _clockedIn = false;
      _clockInTime = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          startTime == null
              ? 'Clocked out at $time'
              : 'Clocked out at $time\nStarted at $startTime',
        ),
      ),
    );
  }

  Future<void> _dismissNotification(NotificationItem item) async {
    if (_dismissedNotificationIds.contains(item.id)) return;
    setState(() => _dismissedNotificationIds.add(item.id));
    try {
      final repo = ref.read(dashboardRepositoryProvider);
      await repo.markNotificationRead(item.id);
      if (!mounted) return;
      ref.invalidate(dashboardDataProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _dismissedNotificationIds.remove(item.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to dismiss notification.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 768;
    final pagePadding = EdgeInsets.all(isWide ? 24 : 16);
    final double sectionSpacing = isWide ? 24.0 : 20.0;
    final double cardSpacing = isWide ? 24.0 : 20.0;
    final sectionTitleStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : const Color(0xFF111827),
    );
    final tasksAsync = ref.watch(tasksProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.asData?.value;
    final fallbackName = profile?.email ??
        Supabase.instance.client.auth.currentUser?.email;
    final userName = (profile?.firstName?.trim().isNotEmpty == true)
        ? profile!.firstName!.trim()
        : (fallbackName?.split('@').first ?? 'there');

    final layout = ref.watch(dashboardLayoutProvider)[UserRole.employee] ??
        DashboardLayoutConfig.defaultsFor(UserRole.employee);
    final tasks = tasksAsync.asData?.value ?? const <Task>[];
    final taskCount = tasks.length;
    final completedTasks = tasks.where((task) => task.isComplete).length;
    final documentsAsync = ref.watch(documentsProvider(null));
    final documentsCount = documentsAsync.asData?.value.length ?? 0;
    final employeeIdAsync = ref.watch(currentEmployeeIdProvider);
    final employeeId = employeeIdAsync.asData?.value;
    final trainingRecordsAsync = employeeId == null
        ? const AsyncValue.data(<Training>[])
        : ref.watch(trainingRecordsProvider(employeeId));
    final dashboardData = dashboardAsync.asData?.value;
    final photoCount = dashboardData == null
        ? 0
        : dashboardData.submissions.fold<int>(
            0,
            (sum, submission) =>
                sum + (submission.attachments?.length ?? 0),
          );
    final openTaskList = tasks
        .where((task) => !task.isComplete)
        .toList()
      ..sort((a, b) {
        final aDue = a.dueDate;
        final bDue = b.dueDate;
        if (aDue == null && bDue == null) return 0;
        if (aDue == null) return 1;
        if (bDue == null) return -1;
        return aDue.compareTo(bDue);
      });
    final dueTodayTasks = openTaskList
        .where((task) => _isSameDay(task.dueDate, DateTime.now()))
        .toList();
    final dueTodayCount = dueTodayTasks.length;
    final tasksForToday = dueTodayTasks.take(3).toList();
    final employeeNotifications = _buildEmployeeNotifications(
      dashboardAsync.asData?.value.notifications ?? const [],
      dismissedIds: _dismissedNotificationIds,
    );
    final showNotifications =
        layout.showNotifications && employeeNotifications.isNotEmpty;
    final trainingRecords = trainingRecordsAsync.asData?.value ?? const <Training>[];
    final trainingItems = _buildTrainingItems(trainingRecords);
    final upcomingEvents = _buildUpcomingEvents(openTaskList, trainingRecords);
    final completionPercent =
        taskCount == 0 ? 0 : ((completedTasks / taskCount) * 100).round();
    final qualityPercent = taskCount == 0
        ? 0
        : (tasks.fold<int>(0, (sum, task) => sum + task.progress) /
                taskCount)
            .round();
    final responsePercent = _onTimeCompletionPercent(tasks);
    final performanceMetrics = [
      _ProgressMetric(
        label: 'Task Completion',
        value: completionPercent,
        color: const Color(0xFF22C55E),
        textColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
      ),
      _ProgressMetric(
        label: 'Quality Score',
        value: qualityPercent,
        color: const Color(0xFF3B82F6),
        textColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      ),
      _ProgressMetric(
        label: 'Response Time',
        value: responsePercent,
        color: const Color(0xFFA855F7),
        textColor: isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED),
      ),
    ];
    final quickActions = [
      _QuickActionTile(
        icon: Icons.description_outlined,
        label: 'Submit Form',
        color: const Color(0xFF2563EB),
        lightBackground: const Color(0xFFEFF6FF),
        darkBackground: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        lightHoverBackground: const Color(0xFFDBEAFE),
        darkHoverBackground: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        lightBorder: const Color(0xFFDBEAFE),
        darkBorder: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        lightIcon: const Color(0xFF2563EB),
        darkIcon: const Color(0xFF60A5FA),
        lightText: const Color(0xFF1D4ED8),
        darkText: const Color(0xFF93C5FD),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FormsPage()),
        ),
      ),
      _QuickActionTile(
        icon: Icons.warning_amber_outlined,
        label: 'Report Issue',
        color: const Color(0xFFDC2626),
        lightBackground: const Color(0xFFFEF2F2),
        darkBackground: const Color(0xFFEF4444).withValues(alpha: 0.1),
        lightHoverBackground: const Color(0xFFFEE2E2),
        darkHoverBackground: const Color(0xFFEF4444).withValues(alpha: 0.2),
        lightBorder: const Color(0xFFFEE2E2),
        darkBorder: const Color(0xFFEF4444).withValues(alpha: 0.2),
        lightIcon: const Color(0xFFDC2626),
        darkIcon: const Color(0xFFF87171),
        lightText: const Color(0xFFB91C1C),
        darkText: const Color(0xFFFCA5A5),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const IncidentsPage()),
        ),
      ),
      _QuickActionTile(
        icon: Icons.description_outlined,
        label: 'Upload Doc',
        color: const Color(0xFF7C3AED),
        lightBackground: const Color(0xFFF5F3FF),
        darkBackground: const Color(0xFFA855F7).withValues(alpha: 0.1),
        lightHoverBackground: const Color(0xFFEDE9FE),
        darkHoverBackground: const Color(0xFFA855F7).withValues(alpha: 0.2),
        lightBorder: const Color(0xFFEDE9FE),
        darkBorder: const Color(0xFFA855F7).withValues(alpha: 0.2),
        lightIcon: const Color(0xFF7C3AED),
        darkIcon: const Color(0xFFC084FC),
        lightText: const Color(0xFF6D28D9),
        darkText: const Color(0xFFD8B4FE),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DocumentsPage()),
        ),
      ),
      _QuickActionTile(
        icon: Icons.inventory_2_outlined,
        label: 'My Assets',
        color: const Color(0xFF16A34A),
        lightBackground: const Color(0xFFF0FDF4),
        darkBackground: const Color(0xFF22C55E).withValues(alpha: 0.1),
        lightHoverBackground: const Color(0xFFDCFCE7),
        darkHoverBackground: const Color(0xFF22C55E).withValues(alpha: 0.2),
        lightBorder: const Color(0xFFDCFCE7),
        darkBorder: const Color(0xFF22C55E).withValues(alpha: 0.2),
        lightIcon: const Color(0xFF16A34A),
        darkIcon: const Color(0xFF4ADE80),
        lightText: const Color(0xFF15803D),
        darkText: const Color(0xFF86EFAC),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AssetsPage()),
        ),
      ),
    ];

    final content = ListView(
        padding: pagePadding,
        children: [
          Text(
            'Welcome back, ${_capitalize(userName)}!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: isWide ? 30 : 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have $dueTodayCount tasks due today',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          if (layout.showActionBar) ...[
            _ActionBar(
              primaryLabel: _clockedIn ? 'Clock Out' : 'Clock In',
              primaryIcon: _clockedIn ? Icons.logout : Icons.login,
              primaryColor:
                  _clockedIn ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              primaryHoverColor:
                  _clockedIn ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
              onPrimaryTap: _clockedIn ? _clockOut : _clockIn,
              secondaryLabel: 'Start My Day',
              secondaryIcon: Icons.play_arrow,
              onSecondaryTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TasksPage()),
                );
              },
              secondaryHoverColor: const Color(0xFF1D4ED8),
              stats: [
                _InlineStat(
                  icon: Icons.schedule,
                  label: 'Tasks',
                  value: '$taskCount',
                  color: Colors.blue,
                  backgroundLight: const Color(0xFFDBEAFE),
                  backgroundDark: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                  iconColorLight: const Color(0xFF2563EB),
                  iconColorDark: const Color(0xFF60A5FA),
                ),
                _InlineStat(
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  value: '$completedTasks',
                  color: Colors.green,
                  backgroundLight: const Color(0xFFDCFCE7),
                  backgroundDark: const Color(0xFF14532D).withValues(alpha: 0.3),
                  iconColorLight: const Color(0xFF16A34A),
                  iconColorDark: const Color(0xFF4ADE80),
                ),
                _InlineStat(
                  icon: Icons.description_outlined,
                  label: 'Documents',
                  value: '$documentsCount',
                  color: Colors.purple,
                  backgroundLight: const Color(0xFFF3E8FF),
                  backgroundDark: const Color(0xFF581C87).withValues(alpha: 0.3),
                  iconColorLight: const Color(0xFF7C3AED),
                  iconColorDark: const Color(0xFFC084FC),
                ),
                _InlineStat(
                  icon: Icons.photo_camera_outlined,
                  label: 'Photos',
                  value: '$photoCount',
                  color: Colors.orange,
                  backgroundLight: const Color(0xFFFFEDD5),
                  backgroundDark: const Color(0xFF7C2D12).withValues(alpha: 0.3),
                  iconColorLight: const Color(0xFFEA580C),
                  iconColorDark: const Color(0xFFFB923C),
                ),
              ],
            ),
            if (_clockedIn)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ClockStatusBanner(
                  timeLabel: _clockInTime ?? 'Now',
                  locationLabel: _locationLabel,
                ),
              ),
            SizedBox(height: sectionSpacing),
          ],
          if (showNotifications) ...[
            NotificationsPanel(
              notifications: employeeNotifications,
              onDismiss: _dismissNotification,
              initialLimit: 2,
            ),
            SizedBox(height: sectionSpacing),
          ],
          if (layout.showQuickActions) ...[
            _SectionCard(
              title: 'Quick Actions',
              titleStyle: sectionTitleStyle,
              backgroundLight: Colors.white,
              backgroundDark: const Color(0xFF1F2937),
              headerPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              bodyPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              showShadow: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 1024 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.35,
                    children: quickActions,
                  );
                },
              ),
            ),
            SizedBox(height: sectionSpacing),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1024;
              final leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: "Today's Tasks",
                    titleStyle: sectionTitleStyle,
                    backgroundLight: Colors.white,
                    backgroundDark: const Color(0xFF1F2937),
                    headerPadding: const EdgeInsets.all(20),
                    bodyPadding: EdgeInsets.zero,
                    showDivider: true,
                    showShadow: true,
                    clipBehavior: Clip.antiAlias,
                    trailing: _HeaderIconButton(onTap: () {}),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (tasksForToday.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'No tasks due today',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontSize: 14,
                                          color: isDark
                                              ? const Color(0xFF9CA3AF)
                                              : const Color(0xFF6B7280),
                                        ),
                                  ),
                                )
                              else
                                ...tasksForToday.asMap().entries.map((entry) {
                                  final task = entry.value;
                                  final isLast =
                                      entry.key == tasksForToday.length - 1;
                                  return Padding(
                                    padding:
                                        EdgeInsets.only(bottom: isLast ? 0 : 12),
                                    child: _EmployeeTaskCard(
                                      task: _EmployeeTask(
                                        title: task.title,
                                        location: _taskLocationLabel(task),
                                        priority: _taskPriorityLabel(task),
                                        dueTime: _taskDueLabel(task),
                                      ),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                TaskDetailPage(task: task),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? const Color(0xFF374151)
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                          ),
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const TasksPage()),
                                );
                              },
                              style: ButtonStyle(
                                foregroundColor:
                                    MaterialStateProperty.resolveWith((states) {
                                  if (states.contains(MaterialState.hovered)) {
                                    return const Color(0xFF1D4ED8);
                                  }
                                  return const Color(0xFF2563EB);
                                }),
                                textStyle: MaterialStateProperty.all(
                                  theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                overlayColor: MaterialStateProperty.all(
                                  Colors.transparent,
                                ),
                                padding:
                                    MaterialStateProperty.all(EdgeInsets.zero),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('View All Tasks'),
                                  SizedBox(width: 6),
                                  Icon(Icons.chevron_right, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (layout.showPerformance) ...[
                    SizedBox(height: cardSpacing),
                    _SectionCard(
                      title: 'Performance',
                      titleStyle: sectionTitleStyle,
                      backgroundLight: Colors.white,
                      backgroundDark: const Color(0xFF1F2937),
                      headerPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      bodyPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      showShadow: true,
                      leading: const Icon(
                        Icons.track_changes_outlined,
                        color: Color(0xFF2563EB),
                      ),
                      leadingIconSize: 20,
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AnalyticsPage(),
                            ),
                          );
                        },
                        style: ButtonStyle(
                          foregroundColor:
                              MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.hovered)) {
                              return const Color(0xFF1D4ED8);
                            }
                            return const Color(0xFF2563EB);
                          }),
                          textStyle: MaterialStateProperty.all(
                            theme.textTheme.bodySmall?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          overlayColor:
                              MaterialStateProperty.all(Colors.transparent),
                        ),
                        child: const Text('View Details'),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...performanceMetrics
                              .map((metric) =>
                                  _ProgressMetricRow(
                                    metric: metric,
                                    bottomSpacing: 20,
                                  ))
                              .toList(),
                        ],
                      ),
                    ),
                  ],
                ],
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (layout.showTraining) ...[
                    _SectionCard(
                      title: 'Training',
                      titleStyle: sectionTitleStyle,
                      backgroundLight: Colors.white,
                      backgroundDark: const Color(0xFF1F2937),
                      headerPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      bodyPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      showShadow: true,
                      leading: const Icon(
                        Icons.school_outlined,
                        color: Color(0xFF7C3AED),
                      ),
                      leadingIconSize: 20,
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TrainingHubPage(),
                            ),
                          );
                        },
                        style: ButtonStyle(
                          foregroundColor:
                              MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.hovered)) {
                              return const Color(0xFF1D4ED8);
                            }
                            return const Color(0xFF2563EB);
                          }),
                          textStyle: MaterialStateProperty.all(
                            theme.textTheme.bodySmall?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          overlayColor:
                              MaterialStateProperty.all(Colors.transparent),
                        ),
                        child: const Text('View All'),
                      ),
                      child: Builder(
                        builder: (context) {
                          if (trainingRecordsAsync.isLoading) {
                            return const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          if (trainingRecordsAsync.hasError) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Unable to load training progress',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 14,
                                      color: isDark
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF6B7280),
                                    ),
                              ),
                            );
                          }
                          if (trainingItems.isEmpty) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No training progress yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 14,
                                      color: isDark
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF6B7280),
                                    ),
                              ),
                            );
                          }
                          return Column(
                            children: trainingItems
                                .map((item) => _TrainingProgressRow(item: item))
                                .toList(),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: cardSpacing),
                    _SectionCard(
                      title: 'Upcoming',
                      titleStyle: sectionTitleStyle,
                      backgroundLight: Colors.white,
                      backgroundDark: const Color(0xFF1F2937),
                      headerPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      bodyPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      showShadow: true,
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF2563EB),
                      ),
                      leadingIconSize: 20,
                      child: Column(
                        children: upcomingEvents.isEmpty
                            ? [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'No upcoming items scheduled',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontSize: 14,
                                          color: isDark
                                              ? const Color(0xFF9CA3AF)
                                              : const Color(0xFF6B7280),
                                        ),
                                  ),
                                ),
                              ]
                            : upcomingEvents
                                .take(3)
                                .map(
                                  (event) => _UpcomingEventCard(event: event),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: leftColumn),
                    const SizedBox(width: 24),
                    Expanded(child: rightColumn),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftColumn,
                  SizedBox(height: cardSpacing),
                  rightColumn,
                ],
              );
            },
          ),
        ],
      );
    if (!widget.embedInShell) {
      return content;
    }
    return DashboardShell(
      role: UserRole.employee,
      onNavigate: (route) =>
          _navigateFromSideMenu(context, UserRole.employee, route),
      child: content,
    );
  }
}

class SupervisorDashboardPage extends ConsumerStatefulWidget {
  const SupervisorDashboardPage({super.key, this.embedInShell = true});

  final bool embedInShell;

  @override
  ConsumerState<SupervisorDashboardPage> createState() =>
      _SupervisorDashboardPageState();
}

class _SupervisorDashboardPageState
    extends ConsumerState<SupervisorDashboardPage> {
  bool _clockedIn = false;
  String? _clockInTime;
  String _locationLabel = 'Loading...';

  @override
  void initState() {
    super.initState();
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    final location = await _resolveLocation();
    if (!mounted) return;
    setState(() => _locationLabel = location);
  }

  Future<String> _resolveLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition();
      return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    } catch (_) {
      return 'Location unavailable';
    }
  }

  Future<void> _clockIn() async {
    final time = DateFormat('h:mm a').format(DateTime.now());
    final location = await _resolveLocation();
    if (!mounted) return;
    setState(() {
      _clockedIn = true;
      _clockInTime = time;
      _locationLabel = location;
    });
  }

  void _clockOut() {
    setState(() {
      _clockedIn = false;
      _clockInTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(dashboardLayoutProvider)[UserRole.supervisor] ??
        DashboardLayoutConfig.defaultsFor(UserRole.supervisor);
    final teamMembers = [
      const _SupervisorMember(
        name: 'Sarah Johnson',
        avatar: 'SJ',
        status: 'active',
        tasksCompleted: 12,
        tasksTotal: 15,
        performance: 95,
      ),
      const _SupervisorMember(
        name: 'Mike Chen',
        avatar: 'MC',
        status: 'active',
        tasksCompleted: 10,
        tasksTotal: 12,
        performance: 88,
      ),
      const _SupervisorMember(
        name: 'Emily Davis',
        avatar: 'ED',
        status: 'away',
        tasksCompleted: 8,
        tasksTotal: 14,
        performance: 78,
      ),
      const _SupervisorMember(
        name: 'Tom Brown',
        avatar: 'TB',
        status: 'active',
        tasksCompleted: 15,
        tasksTotal: 15,
        performance: 100,
      ),
    ];
    final teamTasks = [
      const _TeamTask(
        title: 'Safety Inspection - Building A',
        assignee: 'Sarah Johnson',
        priority: 'high',
        dueDate: 'Today',
      ),
      const _TeamTask(
        title: 'Equipment Maintenance',
        assignee: 'Mike Chen',
        priority: 'medium',
        dueDate: 'Tomorrow',
      ),
      const _TeamTask(
        title: 'Site Cleanup',
        assignee: 'Emily Davis',
        priority: 'low',
        dueDate: 'Dec 25',
      ),
    ];
    final performanceMetrics = [
      const _ProgressMetric(label: 'Completion', value: 87, color: Colors.green),
      const _ProgressMetric(label: 'On-Time', value: 92, color: Colors.blue),
      const _ProgressMetric(label: 'Quality', value: 95, color: Colors.purple),
    ];
    final approvals = [
      const _ApprovalItem(type: 'Timesheet', user: 'Sarah Johnson', time: '2h ago'),
      const _ApprovalItem(type: 'Expense', user: 'Mike Chen', time: '3h ago'),
      const _ApprovalItem(type: 'Leave Request', user: 'Emily Davis', time: '5h ago'),
    ];
    final quickActions = [
      _QuickActionTile(
        icon: Icons.playlist_add_check,
        label: 'Assign Tasks',
        color: Colors.blue,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TasksPage()),
          );
        },
      ),
      _QuickActionTile(
        icon: Icons.rule_folder_outlined,
        label: 'Review Approvals',
        color: Colors.red,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ApprovalsPage()),
        ),
      ),
      _QuickActionTile(
        icon: Icons.schedule,
        label: 'Team Schedule',
        color: Colors.orange,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TimecardsPage(role: UserRole.supervisor),
          ),
        ),
      ),
      _QuickActionTile(
        icon: Icons.trending_up,
        label: 'View Reports',
        color: Colors.purple,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AnalyticsPage()),
        ),
      ),
    ];
    final teamCompleted = 78;
    final teamTotalTasks = 172;
    final teamCompletionRate =
        teamTotalTasks == 0 ? 0.0 : teamCompleted / teamTotalTasks;

    final content = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Supervisor Dashboard',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Managing 4 team members',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (layout.showActionBar) ...[
            _ActionBar(
              primaryLabel: _clockedIn ? 'Clock Out' : 'Clock In',
              primaryIcon: _clockedIn ? Icons.logout : Icons.login,
              primaryColor: _clockedIn ? Colors.red : Colors.green,
              onPrimaryTap: _clockedIn ? _clockOut : _clockIn,
              secondaryLabel: 'Start My Day',
              secondaryIcon: Icons.play_arrow,
              onSecondaryTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TasksPage()),
                );
              },
              stats: const [
                _InlineStat(
                  icon: Icons.people_outline,
                  label: 'Team',
                  value: '4',
                  color: Colors.blue,
                ),
                _InlineStat(
                  icon: Icons.schedule,
                  label: 'Active',
                  value: '94',
                  color: Colors.orange,
                ),
                _InlineStat(
                  icon: Icons.warning_amber_outlined,
                  label: 'Approvals',
                  value: '5',
                  color: Colors.red,
                ),
                _InlineStat(
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  value: '78',
                  color: Colors.green,
                ),
              ],
            ),
            if (_clockedIn)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ClockStatusBanner(
                  timeLabel: _clockInTime ?? 'Now',
                  locationLabel: _locationLabel,
                ),
              ),
            const SizedBox(height: 16),
          ],
          if (layout.showNotifications) ...[
            NotificationsPanel(
              notifications: _sampleSupervisorNotifications(),
              onDismiss: (item) {},
              initialLimit: 2,
            ),
            const SizedBox(height: 16),
          ],
          if (layout.showQuickActions) ...[
            _SectionCard(
              title: 'Quick Actions',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.35,
                    children: quickActions,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              final leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Team Members',
                    trailing: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.filter_list),
                    ),
                    child: Column(
                      children: [
                        ...teamMembers
                            .map((member) => _SupervisorMemberCard(member: member)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TeamsPage()),
                            );
                          },
                          child: const Text('View All Team Members'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Team Tasks',
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TasksPage()),
                        );
                      },
                      child: const Text('View All'),
                    ),
                    child: Column(
                      children: teamTasks
                          .map((task) => _TeamTaskCard(task: task))
                          .toList(),
                    ),
                  ),
                ],
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (layout.showPerformance) ...[
                    _SectionCard(
                      title: 'Team Performance',
                      leading: const Icon(Icons.bolt),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PerformanceSummaryBar(
                            completionRate: teamCompletionRate,
                            completed: teamCompleted,
                            total: teamTotalTasks,
                          ),
                          const SizedBox(height: 12),
                          ...performanceMetrics
                              .map((metric) => _ProgressMetricRow(metric: metric))
                              .toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (layout.showApprovals) ...[
                    _SectionCard(
                      title: 'Approvals',
                      trailing: _CountPill(
                        label: '${approvals.length}',
                        color: Colors.red,
                      ),
                      child: Column(
                        children: approvals
                            .map((approval) => _ApprovalCard(item: approval))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftColumn),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: rightColumn),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftColumn,
                  const SizedBox(height: 16),
                  rightColumn,
                ],
              );
            },
          ),
        ],
      );
    if (!widget.embedInShell) {
      return content;
    }
    return DashboardShell(
      role: UserRole.supervisor,
      onNavigate: (route) =>
          _navigateFromSideMenu(context, UserRole.supervisor, route),
      child: content,
    );
  }
}

class ManagerDashboardPage extends ConsumerStatefulWidget {
  const ManagerDashboardPage({super.key, this.embedInShell = true});

  final bool embedInShell;

  @override
  ConsumerState<ManagerDashboardPage> createState() =>
      _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends ConsumerState<ManagerDashboardPage> {
  bool _clockedIn = false;
  String? _clockInTime;
  String _locationLabel = 'Loading...';
  final Set<int> _expandedSupervisors = {1};

  @override
  void initState() {
    super.initState();
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    final location = await _resolveLocation();
    if (!mounted) return;
    setState(() => _locationLabel = location);
  }

  Future<String> _resolveLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition();
      return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    } catch (_) {
      return 'Location unavailable';
    }
  }

  Future<void> _clockIn() async {
    final time = DateFormat('h:mm a').format(DateTime.now());
    final location = await _resolveLocation();
    if (!mounted) return;
    setState(() {
      _clockedIn = true;
      _clockInTime = time;
      _locationLabel = location;
    });
  }

  void _clockOut() {
    setState(() {
      _clockedIn = false;
      _clockInTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(dashboardLayoutProvider)[UserRole.manager] ??
        DashboardLayoutConfig.defaultsFor(UserRole.manager);
    final organizationData = [
      _SupervisorTeam(
        id: 1,
        name: 'John Smith',
        role: 'Site Supervisor',
        avatar: 'JS',
        teamSize: 8,
        projects: 3,
        performance: 94,
        employees: const [
          _SupervisorEmployee(
            name: 'Mike Johnson',
            avatar: 'MJ',
            status: 'active',
            tasksCompleted: 12,
            tasksTotal: 15,
          ),
          _SupervisorEmployee(
            name: 'Sarah Davis',
            avatar: 'SD',
            status: 'active',
            tasksCompleted: 10,
            tasksTotal: 12,
          ),
          _SupervisorEmployee(
            name: 'Tom Wilson',
            avatar: 'TW',
            status: 'away',
            tasksCompleted: 8,
            tasksTotal: 14,
          ),
          _SupervisorEmployee(
            name: 'Emma Brown',
            avatar: 'EB',
            status: 'active',
            tasksCompleted: 15,
            tasksTotal: 15,
          ),
        ],
      ),
      _SupervisorTeam(
        id: 2,
        name: 'Sarah Johnson',
        role: 'Operations Supervisor',
        avatar: 'SJ',
        teamSize: 6,
        projects: 2,
        performance: 96,
        employees: const [
          _SupervisorEmployee(
            name: 'Robert Taylor',
            avatar: 'RT',
            status: 'active',
            tasksCompleted: 11,
            tasksTotal: 12,
          ),
          _SupervisorEmployee(
            name: 'Jennifer White',
            avatar: 'JW',
            status: 'active',
            tasksCompleted: 9,
            tasksTotal: 11,
          ),
          _SupervisorEmployee(
            name: 'Michael Garcia',
            avatar: 'MG',
            status: 'active',
            tasksCompleted: 14,
            tasksTotal: 15,
          ),
          _SupervisorEmployee(
            name: 'Amanda Clark',
            avatar: 'AC',
            status: 'active',
            tasksCompleted: 12,
            tasksTotal: 13,
          ),
        ],
      ),
      _SupervisorTeam(
        id: 3,
        name: 'Mike Chen',
        role: 'Maintenance Supervisor',
        avatar: 'MC',
        teamSize: 5,
        projects: 4,
        performance: 91,
        employees: const [
          _SupervisorEmployee(
            name: 'Kevin Harris',
            avatar: 'KH',
            status: 'active',
            tasksCompleted: 9,
            tasksTotal: 12,
          ),
          _SupervisorEmployee(
            name: 'Laura Thompson',
            avatar: 'LT',
            status: 'active',
            tasksCompleted: 10,
            tasksTotal: 12,
          ),
          _SupervisorEmployee(
            name: 'Steven Jackson',
            avatar: 'SJ',
            status: 'active',
            tasksCompleted: 8,
            tasksTotal: 11,
          ),
        ],
      ),
    ];
    final totalEmployees =
        organizationData.fold<int>(0, (sum, team) => sum + team.teamSize);
    final totalProjects =
        organizationData.fold<int>(0, (sum, team) => sum + team.projects);
    final activeProjects = [
      const _ActiveProject(
        name: 'Building A Construction',
        supervisor: 'John Smith',
        progress: 75,
        deadline: 'Dec 31',
        budget: 85,
        status: 'on-track',
      ),
      const _ActiveProject(
        name: 'Site Renovation Phase 2',
        supervisor: 'Maria Garcia',
        progress: 45,
        deadline: 'Jan 15',
        budget: 60,
        status: 'on-track',
      ),
      const _ActiveProject(
        name: 'Equipment Upgrade',
        supervisor: 'Robert Anderson',
        progress: 90,
        deadline: 'Dec 28',
        budget: 95,
        status: 'at-risk',
      ),
    ];
    final departmentMetrics = [
      const _DepartmentMetric(
        title: 'Completion Rate',
        value: '91%',
        subtitle: '+5% from last month',
        color: Colors.green,
        icon: Icons.check_circle,
      ),
      const _DepartmentMetric(
        title: 'On-Time Delivery',
        value: '88%',
        subtitle: 'Within deadlines',
        color: Colors.blue,
        icon: Icons.schedule,
      ),
      const _DepartmentMetric(
        title: 'Quality Score',
        value: '94%',
        subtitle: 'Above target',
        color: Colors.purple,
        icon: Icons.emoji_events_outlined,
      ),
    ];
    final criticalIssues = [
      const _CriticalIssue(
        issue: 'Budget Overrun',
        project: 'Equipment Upgrade',
        severity: 'high',
      ),
      const _CriticalIssue(
        issue: 'Resource Shortage',
        project: 'Building A',
        severity: 'medium',
      ),
      const _CriticalIssue(
        issue: 'Delayed Approval',
        project: 'Site Renovation',
        severity: 'medium',
      ),
    ];
    final monthlySummary = const [
      _SummaryItem(label: 'Projects Completed', value: '7'),
      _SummaryItem(label: 'Tasks Completed', value: '342'),
      _SummaryItem(label: 'Budget Spent', value: '\$340K'),
      _SummaryItem(label: 'Team Growth', value: '+8%', accent: true),
    ];
    final resourceAllocation = const [
      _ResourceAllocationItem(
        label: 'Labor',
        allocation: 72,
        detail: 'On-site crews across projects',
      ),
      _ResourceAllocationItem(
        label: 'Equipment',
        allocation: 64,
        detail: 'Fleet & heavy machinery utilization',
      ),
      _ResourceAllocationItem(
        label: 'Budget Used',
        allocation: 58,
        detail: 'Spend vs plan across all departments',
      ),
      _ResourceAllocationItem(
        label: 'Subcontractors',
        allocation: 41,
        detail: 'Active contracts this month',
      ),
    ];
    final crossDepartmentAnalytics = const [
      _CrossDepartmentMetric(
        title: 'Efficiency Score',
        value: '91%',
        delta: '+5%',
      ),
      _CrossDepartmentMetric(
        title: 'Quality Score',
        value: '94%',
        delta: '+2%',
      ),
      _CrossDepartmentMetric(
        title: 'Safety Score',
        value: '97%',
        delta: '+1%',
      ),
      _CrossDepartmentMetric(
        title: 'Budget Utilization',
        value: '82%',
        delta: '-3%',
        isNegative: true,
      ),
    ];

    final content = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Manager Dashboard',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${organizationData.length} supervisors • $totalEmployees employees • $totalProjects projects',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (layout.showActionBar) ...[
            _ActionBar(
              primaryLabel: _clockedIn ? 'Clock Out' : 'Clock In',
              primaryIcon: _clockedIn ? Icons.logout : Icons.login,
              primaryColor: _clockedIn ? Colors.red : Colors.green,
              onPrimaryTap: _clockedIn ? _clockOut : _clockIn,
              secondaryLabel: 'Start My Day',
              secondaryIcon: Icons.play_arrow,
              onSecondaryTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TasksPage()),
                );
              },
              stats: const [
                _InlineStat(
                  icon: Icons.folder_outlined,
                  label: 'Projects',
                  value: '9',
                  color: Colors.blue,
                ),
                _InlineStat(
                  icon: Icons.people_outline,
                  label: 'Supervisors',
                  value: '3',
                  color: Colors.purple,
                ),
                _InlineStat(
                  icon: Icons.groups_outlined,
                  label: 'Employees',
                  value: '19',
                  color: Colors.green,
                ),
                _InlineStat(
                  icon: Icons.trending_up,
                  label: 'Performance',
                  value: '91%',
                  color: Colors.teal,
                ),
              ],
            ),
            if (_clockedIn)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ClockStatusBanner(
                  timeLabel: _clockInTime ?? 'Now',
                  locationLabel: _locationLabel,
                ),
              ),
            const SizedBox(height: 16),
          ],
          if (layout.showNotifications) ...[
            NotificationsPanel(
              notifications: _sampleManagerNotifications(),
              onDismiss: (item) {},
              initialLimit: 2,
            ),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              final leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Organization Structure',
                    trailing: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.filter_list),
                    ),
                    child: Column(
                      children: organizationData.map((supervisor) {
                        final expanded =
                            _expandedSupervisors.contains(supervisor.id);
                        return _SupervisorTeamCard(
                          team: supervisor,
                          expanded: expanded,
                          onToggle: () {
                            setState(() {
                              if (expanded) {
                                _expandedSupervisors.remove(supervisor.id);
                              } else {
                                _expandedSupervisors.add(supervisor.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Active Projects',
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProjectsPage()),
                        );
                      },
                      child: const Text('View All'),
                    ),
                    child: Column(
                      children: activeProjects
                          .map((project) => _ActiveProjectCard(project: project))
                          .toList(),
                    ),
                  ),
                ],
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Department Metrics',
                    child: Column(
                      children: departmentMetrics
                          .map((metric) => _DepartmentMetricCard(metric: metric))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Critical Issues',
                    trailing: _CountPill(label: '3', color: Colors.red),
                    child: Column(
                      children: criticalIssues
                          .map((issue) => _CriticalIssueCard(issue: issue))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (layout.showResourceAllocation) ...[
                    _SectionCard(
                      title: 'Resource Allocation',
                      child: _ResourceAllocationGrid(items: resourceAllocation),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _SectionCard(
                    title: 'Cross-Department Analytics',
                    child: Column(
                      children: crossDepartmentAnalytics
                          .map((metric) => _CrossDepartmentMetricCard(metric: metric))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'This Month',
                    isGradient: true,
                    child: Column(
                      children: monthlySummary
                          .map((item) => _SummaryRow(item: item))
                          .toList(),
                    ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftColumn),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: rightColumn),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftColumn,
                  const SizedBox(height: 16),
                  rightColumn,
                ],
              );
            },
          ),
        ],
      );
    if (!widget.embedInShell) {
      return content;
    }
    return DashboardShell(
      role: UserRole.manager,
      onNavigate: (route) =>
          _navigateFromSideMenu(context, UserRole.manager, route),
      child: content,
    );
  }
}

class MaintenanceDashboardPage extends ConsumerStatefulWidget {
  const MaintenanceDashboardPage({super.key, this.embedInShell = true});

  final bool embedInShell;

  @override
  ConsumerState<MaintenanceDashboardPage> createState() =>
      _MaintenanceDashboardPageState();
}

class _MaintenanceDashboardPageState
    extends ConsumerState<MaintenanceDashboardPage> {
  bool _clockedIn = false;
  String? _clockInTime;
  String _locationLabel = 'Getting location...';

  @override
  void initState() {
    super.initState();
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    final location = await _resolveLocation();
    if (!mounted) return;
    setState(() => _locationLabel = location);
  }

  Future<String> _resolveLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition();
      return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    } catch (_) {
      return 'Location unavailable';
    }
  }

  Future<void> _clockIn() async {
    final time = DateFormat('h:mm a').format(DateTime.now());
    final location = await _resolveLocation();
    if (!mounted) return;
    setState(() {
      _clockedIn = true;
      _clockInTime = time;
      _locationLabel = location;
    });
  }

  void _clockOut() {
    setState(() {
      _clockedIn = false;
      _clockInTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final workOrders = [
      const _MaintenanceWorkOrder(
        id: 'WO-2301',
        equipment: 'Excavator #245',
        issue: 'Hydraulic leak - urgent repair needed',
        priority: 'high',
        assignedTo: 'John Smith',
        dueDate: 'Dec 24',
        status: 'in-progress',
        location: 'Main Site - Zone A',
      ),
      const _MaintenanceWorkOrder(
        id: 'WO-2302',
        equipment: 'Generator #12',
        issue: 'Scheduled 500-hour maintenance',
        priority: 'medium',
        assignedTo: 'Mike Johnson',
        dueDate: 'Dec 26',
        status: 'scheduled',
        location: 'Building B',
      ),
      const _MaintenanceWorkOrder(
        id: 'WO-2303',
        equipment: 'Forklift #7',
        issue: 'Battery replacement required',
        priority: 'low',
        assignedTo: 'Sarah Williams',
        dueDate: 'Dec 28',
        status: 'pending',
        location: 'Warehouse',
      ),
      const _MaintenanceWorkOrder(
        id: 'WO-2304',
        equipment: 'Air Compressor #3',
        issue: 'Pressure gauge malfunction',
        priority: 'high',
        assignedTo: 'Tom Brown',
        dueDate: 'Dec 24',
        status: 'in-progress',
        location: 'Main Site - Zone C',
      ),
    ];
    final scheduledMaintenance = [
      const _MaintenanceScheduleItem(
        equipment: 'Crane #5',
        type: 'Annual Inspection',
        date: 'Dec 30',
        hours: '2000 hrs',
      ),
      const _MaintenanceScheduleItem(
        equipment: 'Scissor Lift #8',
        type: 'Monthly Check',
        date: 'Dec 27',
        hours: '500 hrs',
      ),
      const _MaintenanceScheduleItem(
        equipment: 'Welding Machine #2',
        type: 'Safety Inspection',
        date: 'Dec 29',
        hours: '750 hrs',
      ),
    ];
    final inventoryItems = [
      const _InventoryItem(
        part: 'Hydraulic Fluid (5gal)',
        quantity: 12,
        minStock: 8,
        status: 'good',
      ),
      const _InventoryItem(
        part: 'Air Filters - Heavy Duty',
        quantity: 3,
        minStock: 10,
        status: 'low',
      ),
      const _InventoryItem(
        part: 'Engine Oil (10W-30)',
        quantity: 24,
        minStock: 15,
        status: 'good',
      ),
      const _InventoryItem(
        part: 'Replacement Batteries',
        quantity: 2,
        minStock: 5,
        status: 'critical',
      ),
    ];

    final content = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Maintenance Dashboard',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Equipment maintenance, work orders, and inventory management',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _ActionBar(
            primaryLabel: _clockedIn ? 'Clock Out' : 'Clock In',
            primaryIcon: _clockedIn ? Icons.logout : Icons.login,
            primaryColor: _clockedIn ? Colors.red : Colors.green,
            onPrimaryTap: _clockedIn ? _clockOut : _clockIn,
            stats: const [
              _InlineStat(
                icon: Icons.build_outlined,
                label: 'Open WO',
                value: '12',
                color: Colors.blue,
              ),
              _InlineStat(
                icon: Icons.warning_amber_outlined,
                label: 'Urgent',
                value: '4',
                color: Colors.red,
              ),
              _InlineStat(
                icon: Icons.check_circle_outline,
                label: 'Completed',
                value: '8',
                color: Colors.green,
              ),
              _InlineStat(
                icon: Icons.schedule,
                label: 'Equipment Due',
                value: '6',
                color: Colors.amber,
              ),
            ],
          ),
          if (_clockedIn)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ClockStatusBanner(
                timeLabel: _clockInTime ?? 'Now',
                locationLabel: _locationLabel,
              ),
            ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              final leftColumn = _SectionCard(
                title: 'Active Work Orders',
                leading: const Icon(Icons.build_outlined),
                child: Column(
                  children: workOrders
                      .map((order) => _MaintenanceWorkOrderCard(order: order))
                      .toList(),
                ),
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Scheduled PM',
                    leading: const Icon(Icons.calendar_today_outlined),
                    child: Column(
                      children: scheduledMaintenance
                          .map((item) => _MaintenanceScheduleCard(item: item))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Parts Inventory',
                    leading: const Icon(Icons.inventory_2_outlined),
                    child: Column(
                      children: inventoryItems
                          .map((item) => _InventoryCard(item: item))
                          .toList(),
                    ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftColumn),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: rightColumn),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftColumn,
                  const SizedBox(height: 16),
                  rightColumn,
                ],
              );
            },
          ),
        ],
      );
    if (!widget.embedInShell) {
      return content;
    }
    return DashboardShell(
      role: UserRole.maintenance,
      onNavigate: (route) =>
          _navigateFromSideMenu(context, UserRole.maintenance, route),
      child: content,
    );
  }
}

class TechSupportDashboardPage extends ConsumerStatefulWidget {
  const TechSupportDashboardPage({super.key, this.embedInShell = true});

  final bool embedInShell;

  @override
  ConsumerState<TechSupportDashboardPage> createState() =>
      _TechSupportDashboardPageState();
}

class _TechSupportDashboardPageState
    extends ConsumerState<TechSupportDashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedPriority = 'all';

  final List<_SupportTicket> _tickets = const [
    _SupportTicket(
      title: 'Cannot access forms module',
      user: 'Sarah Johnson',
      priority: 'high',
      status: 'open',
      time: '5 min ago',
      category: 'Access',
    ),
    _SupportTicket(
      title: 'Dashboard loading slowly',
      user: 'Mike Chen',
      priority: 'medium',
      status: 'in-progress',
      time: '15 min ago',
      category: 'Performance',
    ),
    _SupportTicket(
      title: 'File upload error',
      user: 'Emily Davis',
      priority: 'high',
      status: 'open',
      time: '30 min ago',
      category: 'Bug',
    ),
    _SupportTicket(
      title: 'Password reset request',
      user: 'Tom Brown',
      priority: 'low',
      status: 'pending',
      time: '1 hour ago',
      category: 'Account',
    ),
    _SupportTicket(
      title: 'Asset QR code not scanning',
      user: 'Lisa White',
      priority: 'medium',
      status: 'in-progress',
      time: '2 hours ago',
      category: 'Feature',
    ),
    _SupportTicket(
      title: 'Export report not working',
      user: 'James Lee',
      priority: 'medium',
      status: 'open',
      time: '3 hours ago',
      category: 'Bug',
    ),
  ];
  final List<_TechActivity> _activities = const [
    _TechActivity(
      action: 'Resolved ticket',
      detail: 'Cannot access forms module - Sarah Johnson',
      time: '10 min ago',
      type: 'success',
    ),
    _TechActivity(
      action: 'System diagnostic',
      detail: 'Server health check completed',
      time: '30 min ago',
      type: 'info',
    ),
    _TechActivity(
      action: 'Updated ticket',
      detail: 'Dashboard loading slowly - Mike Chen',
      time: '1 hour ago',
      type: 'info',
    ),
    _TechActivity(
      action: 'User assistance',
      detail: 'Helped Tom Brown with password reset',
      time: '2 hours ago',
      type: 'success',
    ),
  ];
  final List<_SupportMetric> _supportMetrics = const [
    _SupportMetric(
      label: 'Avg Resolution Time',
      value: '2.5h',
      progress: 0.65,
      note: 'Target: 3h',
      color: Colors.blue,
    ),
    _SupportMetric(
      label: 'Customer Satisfaction',
      value: '96%',
      progress: 0.96,
      note: '487 responses',
      color: Colors.green,
    ),
    _SupportMetric(
      label: 'First Response Time',
      value: '8 min',
      progress: 0.8,
      note: 'Target: 10 min',
      color: Colors.purple,
    ),
  ];
  final List<_KnowledgeArticle> _knowledgeArticles = const [
    _KnowledgeArticle(title: 'How to reset password', views: 245),
    _KnowledgeArticle(title: 'Uploading documents', views: 189),
    _KnowledgeArticle(title: 'Creating forms guide', views: 156),
    _KnowledgeArticle(title: 'Mobile app setup', views: 142),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredTickets = _tickets.where((ticket) {
      if (_selectedPriority != 'all' &&
          ticket.priority != _selectedPriority) {
        return false;
      }
      if (query.isEmpty) return true;
      return ticket.title.toLowerCase().contains(query) ||
          ticket.user.toLowerCase().contains(query);
    }).toList();
    final layout = ref.watch(dashboardLayoutProvider)[UserRole.techSupport] ??
        DashboardLayoutConfig.defaultsFor(UserRole.techSupport);
    final activeTickets =
        _tickets.where((ticket) => ticket.status != 'resolved').length;
    final recentErrors = const [
      _TechErrorItem(
        title: 'API 500 on /forms',
        detail: 'Supabase edge function timeout',
        time: '2 min ago',
      ),
      _TechErrorItem(
        title: 'Slow query detected',
        detail: 'Tasks search > 1200ms',
        time: '8 min ago',
      ),
      _TechErrorItem(
        title: 'Storage warning',
        detail: 'Bucket nearing limit (82%)',
        time: '15 min ago',
      ),
    ];

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTechHeader(context, activeTickets),
                      ),
                      const SizedBox(width: 16),
                      _buildTechActions(context),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTechHeader(context, activeTickets),
                      const SizedBox(height: 12),
                      _buildTechActions(context),
                    ],
                  ),
            const SizedBox(height: 16),
            _StatsGrid(items: const [
              _StatTile(
                label: 'Open Tickets',
                value: '18',
                icon: Icons.error_outline,
                color: Colors.red,
                trend: '+3 today',
              ),
              _StatTile(
                label: 'In Progress',
                value: '12',
                icon: Icons.schedule,
                color: Colors.orange,
              ),
              _StatTile(
                label: 'Resolved Today',
                value: '24',
                icon: Icons.check_circle,
                color: Colors.green,
                trend: 'Avg time: 2.5h',
              ),
              _StatTile(
                label: 'System Health',
                value: '98%',
                icon: Icons.monitor_heart_outlined,
                color: Colors.blue,
              ),
              _StatTile(
                label: 'Response Time',
                value: '8 min',
                icon: Icons.trending_up,
                color: Colors.purple,
                trend: 'Avg this week',
              ),
            ]),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSupportTicketsCard(context, filteredTickets),
                        const SizedBox(height: 16),
                        if (layout.showDiagnostics) ...[
                          _buildSystemDiagnostics(context),
                          const SizedBox(height: 16),
                          _buildRecentErrors(context, recentErrors),
                          const SizedBox(height: 16),
                        ],
                        if (layout.showActivity) _buildRecentActivity(context),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 360,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (layout.showQuickActions) ...[
                          _buildQuickActions(context),
                          const SizedBox(height: 16),
                        ],
                        _buildSupportMetrics(context),
                        const SizedBox(height: 16),
                        _buildKnowledgeBase(context),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              _buildSupportTicketsCard(context, filteredTickets),
              const SizedBox(height: 16),
              if (layout.showDiagnostics) ...[
                _buildSystemDiagnostics(context),
                const SizedBox(height: 16),
                _buildRecentErrors(context, recentErrors),
                const SizedBox(height: 16),
              ],
              if (layout.showActivity) ...[
                _buildRecentActivity(context),
                const SizedBox(height: 16),
              ],
              if (layout.showQuickActions) ...[
                _buildQuickActions(context),
                const SizedBox(height: 16),
              ],
              _buildSupportMetrics(context),
              const SizedBox(height: 16),
              _buildKnowledgeBase(context),
            ],
          ],
        );
      },
    );
    if (!widget.embedInShell) {
      return content;
    }
    return DashboardShell(
      role: UserRole.techSupport,
      onNavigate: (route) =>
          _navigateFromSideMenu(context, UserRole.techSupport, route),
      child: content,
    );
  }

  Widget _buildTechHeader(BuildContext context, int activeTickets) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tech Support Dashboard',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Managing $activeTickets active support tickets',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildTechActions(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search tickets...',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupportTicketsPage()),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('New Ticket'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTicketsCard(
    BuildContext context,
    List<_SupportTicket> tickets,
  ) {
    return _PanelCard(
      title: 'Support Tickets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: DropdownButton<String>(
              value: _selectedPriority,
              onChanged: (value) {
                setState(() => _selectedPriority = value ?? 'all');
              },
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Priorities')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'low', child: Text('Low')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (tickets.isEmpty)
            const Text('No tickets match your filters.')
          else
            ...tickets.map(
              (ticket) => _TicketRow(
                title: ticket.title,
                user: ticket.user,
                priority: ticket.priority,
                status: ticket.status,
                time: ticket.time,
                category: ticket.category,
                onView: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportTicketsPage()),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupportTicketsPage()),
              );
            },
            child: const Text('View All Tickets'),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemDiagnostics(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final okBackground = isDark
        ? const Color(0xFF064E3B).withValues(alpha: 0.35)
        : const Color(0xFFECFDF3);
    final okBorder = isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0);
    final diagnostics = [
      _DiagnosticTile(
        title: 'API Server',
        status: 'ONLINE',
        detail: 'Response 45ms',
        icon: Icons.router_outlined,
        background: okBackground,
        border: okBorder,
      ),
      _DiagnosticTile(
        title: 'Database',
        status: 'ONLINE',
        detail: 'Connections 342',
        icon: Icons.storage_outlined,
        background: okBackground,
        border: okBorder,
      ),
      _DiagnosticTile(
        title: 'Storage',
        status: 'HEALTHY',
        detail: '75% utilized',
        icon: Icons.cloud_queue_outlined,
        background: okBackground,
        border: okBorder,
      ),
      _DiagnosticTile(
        title: 'CPU Usage',
        status: 'OPTIMAL',
        detail: '45% average',
        icon: Icons.memory,
        background: okBackground,
        border: okBorder,
      ),
    ];

    return _PanelCard(
      title: 'System Diagnostics',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 520 ? 2 : 1;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 2 ? 3 : 4,
            physics: const NeverScrollableScrollPhysics(),
            children: diagnostics,
          );
        },
      ),
    );
  }

  Widget _buildRecentErrors(
    BuildContext context,
    List<_TechErrorItem> errors,
  ) {
    final theme = Theme.of(context);
    return _PanelCard(
      title: 'Recent Errors',
      child: Column(
        children: errors
            .map(
              (error) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            error.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            error.detail,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      error.time,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return _PanelCard(
      title: 'Recent Activity',
      child: Column(
        children:
            _activities.map((activity) => _ActivityRow(activity: activity)).toList(),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return _PanelCard(
      title: 'Quick Actions',
      child: Column(
        children: [
          _SupportQuickActionTile(
            label: 'Create Ticket',
            icon: Icons.chat_bubble_outline,
            color: Colors.blue,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupportTicketsPage()),
              );
            },
          ),
          const SizedBox(height: 10),
          _SupportQuickActionTile(
            label: 'Run Diagnostics',
            icon: Icons.build_outlined,
            color: Colors.green,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SystemLogsPage()),
              );
            },
          ),
          const SizedBox(height: 10),
          _SupportQuickActionTile(
            label: 'User Management',
            icon: Icons.people_outline,
            color: Colors.purple,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserDirectoryPage()),
              );
            },
          ),
          const SizedBox(height: 10),
          _SupportQuickActionTile(
            label: 'System Logs',
            icon: Icons.list_alt_outlined,
            color: Colors.orange,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SystemLogsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupportMetrics(BuildContext context) {
    return _PanelCard(
      title: 'Support Metrics',
      child: Column(
        children:
            _supportMetrics.map((metric) => _SupportMetricRow(metric: metric)).toList(),
      ),
    );
  }

  Widget _buildKnowledgeBase(BuildContext context) {
    return _PanelCard(
      title: 'Popular Articles',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._knowledgeArticles
              .map((article) => _KnowledgeArticleTile(article: article)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SopLibraryPage()),
              );
            },
            child: const Text('Browse Knowledge Base'),
          ),
        ],
      ),
    );
  }
}

void _navigateFromSideMenu(
  BuildContext context,
  UserRole role,
  SideMenuRoute route,
) {
  final navigator = Navigator.of(context);
  if (route == SideMenuRoute.dashboard) {
    navigator.popUntil((route) => route.isFirst);
    return;
  }

  final page = switch (route) {
    SideMenuRoute.dashboard => null,
    SideMenuRoute.notifications => const NotificationsPage(),
    SideMenuRoute.messages => const MessagesPage(),
    SideMenuRoute.companyNews => const NewsPostsPage(),
    SideMenuRoute.organizationChart => OrganizationChartPage(role: role),
    SideMenuRoute.team => const TeamsPage(),
    SideMenuRoute.organization => role.canAccessAdminConsole
        ? AdminDashboardPage(
            userRole: role,
            initialSectionId: 'orgs',
            embedInShell: true,
          )
        : OrganizationChartPage(role: role),
    SideMenuRoute.tasks => const TasksPage(),
    SideMenuRoute.forms => const FormsPage(),
    SideMenuRoute.approvals => const ApprovalsPage(),
    SideMenuRoute.documents => const DocumentsPage(),
    SideMenuRoute.photos => const PhotosPage(),
    SideMenuRoute.beforeAfter => const BeforeAfterPhotosPage(),
    SideMenuRoute.assets => const AssetsPage(),
    SideMenuRoute.qrScanner => const QrScannerPage(),
    SideMenuRoute.training => const TrainingHubPage(),
    SideMenuRoute.incidents => const IncidentsPage(),
    SideMenuRoute.aiTools => const AiToolsPage(),
    SideMenuRoute.timecards => TimecardsPage(role: role),
    SideMenuRoute.reports => const AnalyticsPage(),
    SideMenuRoute.settings => const SettingsPage(),
    SideMenuRoute.projects => const ProjectsPage(),
    SideMenuRoute.workOrders => const WorkOrdersPage(),
    SideMenuRoute.templates => const TemplatesPage(),
    SideMenuRoute.payments => const PaymentRequestsPage(),
    SideMenuRoute.payroll => const PayrollPage(),
    SideMenuRoute.auditLogs => role.canAccessAdminConsole
        ? const AuditLogsPage()
        : const SystemLogsPage(),
    SideMenuRoute.rolesPermissions => role == UserRole.admin
        ? const RolesPage()
        : const RolesPermissionsPage(),
    SideMenuRoute.roleCustomization => const RoleCustomizationPage(),
    SideMenuRoute.systemOverview => const SystemOverviewPage(),
    SideMenuRoute.supportTickets => const SupportTicketsPage(),
    SideMenuRoute.knowledgeBase => const SopLibraryPage(),
    SideMenuRoute.systemLogs => const SystemLogsPage(),
    SideMenuRoute.users => const UserDirectoryPage(),
  };

  if (page == null) return;
  navigator.pushReplacement(
    MaterialPageRoute(
      builder: (ctx) => DashboardShell(
        role: role,
        activeRoute: route,
        onNavigate: (next) => _navigateFromSideMenu(ctx, role, next),
        child: page,
      ),
    ),
  );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.primaryColor,
    required this.onPrimaryTap,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondaryTap,
    this.primaryHoverColor,
    this.secondaryHoverColor,
    this.buttonPadding,
    this.buttonRadius,
    this.iconSize,
    this.buttonTextStyle,
    this.actionButtonsWidth = 380,
    this.wideBreakpoint = 1024,
    required this.stats,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final Color primaryColor;
  final VoidCallback onPrimaryTap;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondaryTap;
  final Color? primaryHoverColor;
  final Color? secondaryHoverColor;
  final EdgeInsets? buttonPadding;
  final double? buttonRadius;
  final double? iconSize;
  final TextStyle? buttonTextStyle;
  final double actionButtonsWidth;
  final double wideBreakpoint;
  final List<_InlineStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final resolvedPadding =
        buttonPadding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    final resolvedRadius = buttonRadius ?? 8;
    final resolvedIconSize = iconSize ?? 20;
    final resolvedTextStyle = buttonTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );

    Widget actionButtons(bool horizontal) {
      Widget buildButton({
        required VoidCallback? onPressed,
        required Color backgroundColor,
        required Color hoverColor,
        required IconData icon,
        required String label,
      }) {
        final button = FilledButton.icon(
          onPressed: onPressed,
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.hovered)) {
                return hoverColor;
              }
              return backgroundColor;
            }),
            foregroundColor: MaterialStateProperty.all(Colors.white),
            padding: MaterialStateProperty.all(resolvedPadding),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(resolvedRadius),
              ),
            ),
            textStyle: MaterialStateProperty.all(resolvedTextStyle),
            elevation: MaterialStateProperty.all(0),
            overlayColor: MaterialStateProperty.all(Colors.transparent),
          ),
          icon: Icon(icon, size: resolvedIconSize),
          label: Text(label),
        );
        if (horizontal) {
          return Expanded(child: button);
        }
        return SizedBox(width: double.infinity, child: button);
      }

      final buttons = <Widget>[
        buildButton(
          onPressed: onPrimaryTap,
          backgroundColor: primaryColor,
          hoverColor: primaryHoverColor ?? primaryColor,
          icon: primaryIcon,
          label: primaryLabel,
        ),
      ];

      if (secondaryLabel != null &&
          secondaryIcon != null &&
          onSecondaryTap != null) {
        buttons.add(SizedBox(
          width: horizontal ? 12 : 0,
          height: horizontal ? 0 : 12,
        ));
        buttons.add(
          buildButton(
            onPressed: onSecondaryTap,
            backgroundColor: const Color(0xFF2563EB),
            hoverColor: secondaryHoverColor ?? const Color(0xFF2563EB),
            icon: secondaryIcon!,
            label: secondaryLabel!,
          ),
        );
      }

      final crossAxisAlignment =
          horizontal ? CrossAxisAlignment.center : CrossAxisAlignment.stretch;
      return Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: crossAxisAlignment,
        children: buttons,
      );
    }

    Widget statsGrid(bool wide) {
      return GridView.count(
        crossAxisCount: wide ? 4 : 2,
        shrinkWrap: true,
        childAspectRatio: wide ? 3.4 : 2.8,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        physics: const NeverScrollableScrollPhysics(),
        children: stats,
      );
    }

    Widget statsRow() {
      final children = <Widget>[];
      for (var i = 0; i < stats.length; i++) {
        if (i > 0) {
          children.add(const SizedBox(width: 16));
        }
        children.add(Expanded(child: stats[i]));
      }
      return Row(children: children);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= wideBreakpoint;
          final horizontalButtons = constraints.maxWidth >= 640;
          if (wide) {
            final dividerHeight = resolvedIconSize + resolvedPadding.vertical;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: actionButtonsWidth,
                  child: actionButtons(true),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: dividerHeight,
                  child: Container(width: 1, color: border),
                ),
                const SizedBox(width: 16),
                Expanded(child: statsRow()),
              ],
            );
          }
          return Column(
            children: [
              actionButtons(horizontalButtons),
              const SizedBox(height: 16),
              statsGrid(false),
            ],
          );
        },
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.backgroundLight,
    this.backgroundDark,
    this.iconColorLight,
    this.iconColorDark,
    this.labelColorLight,
    this.labelColorDark,
    this.valueColorLight,
    this.valueColorDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color? backgroundLight;
  final Color? backgroundDark;
  final Color? iconColorLight;
  final Color? iconColorDark;
  final Color? labelColorLight;
  final Color? labelColorDark;
  final Color? valueColorLight;
  final Color? valueColorDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBackground = isDark
        ? (backgroundDark ?? color.withValues(alpha: 0.25))
        : (backgroundLight ?? color.withValues(alpha: 0.15));
    final iconColor = isDark ? (iconColorDark ?? color) : (iconColorLight ?? color);
    final labelColor = isDark
        ? (labelColorDark ?? const Color(0xFF9CA3AF))
        : (labelColorLight ?? const Color(0xFF4B5563));
    final valueColor = isDark
        ? (valueColorDark ?? Colors.white)
        : (valueColorLight ?? const Color(0xFF111827));
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: labelColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClockStatusBanner extends StatelessWidget {
  const _ClockStatusBanner({
    required this.timeLabel,
    required this.locationLabel,
  });

  final String timeLabel;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF14532D).withValues(alpha: 0.2)
        : const Color(0xFFECFDF5);
    final border = isDark
        ? const Color(0xFF22C55E).withValues(alpha: 0.3)
        : const Color(0xFFBBF7D0);
    final textPrimary =
        isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534);
    final textSecondary =
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const _PulsingDot(color: Colors.green, size: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currently Clocked In',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Since $timeLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.navigation, size: 12, color: textSecondary),
              const SizedBox(width: 6),
              Text(
                locationLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(begin: 1, end: 1.4)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  late final Animation<double> _opacity = Tween<double>(begin: 0.6, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.actions});

  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Quick Actions',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            physics: const NeverScrollableScrollPhysics(),
            children: actions,
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.leading,
    this.trailing,
    this.showDivider = false,
    this.isGradient = false,
    this.backgroundLight,
    this.backgroundDark,
    this.headerPadding,
    this.bodyPadding,
    this.titleStyle,
    this.leadingIconSize,
    this.showShadow = false,
    this.borderRadius,
    this.clipBehavior = Clip.none,
  });

  final String title;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final bool showDivider;
  final bool isGradient;
  final Color? backgroundLight;
  final Color? backgroundDark;
  final EdgeInsets? headerPadding;
  final EdgeInsets? bodyPadding;
  final TextStyle? titleStyle;
  final double? leadingIconSize;
  final bool showShadow;
  final double? borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark
        ? (backgroundDark ?? theme.colorScheme.surface)
        : (backgroundLight ?? theme.colorScheme.surface);
    final radius = borderRadius ?? 12;
    final resolvedHeaderPadding =
        headerPadding ?? const EdgeInsets.fromLTRB(16, 16, 16, 12);
    final resolvedBodyPadding =
        bodyPadding ?? const EdgeInsets.fromLTRB(16, 12, 16, 16);
    final gradient = LinearGradient(
      colors: isDark
          ? [
              const Color(0xFF1E3A8A).withValues(alpha: 0.35),
              const Color(0xFF312E81).withValues(alpha: 0.35),
            ]
          : const [
              Color(0xFFEFF6FF),
              Color(0xFFE0E7FF),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        color: isGradient ? null : background,
        gradient: isGradient ? gradient : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      clipBehavior: clipBehavior,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: resolvedHeaderPadding,
            child: Row(
              children: [
                if (leading != null) ...[
                  IconTheme(
                    data: IconThemeData(
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      size: leadingIconSize ?? 18,
                    ),
                    child: leading!,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: titleStyle ??
                        theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF111827),
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          if (showDivider) Divider(height: 1, color: border),
          Padding(
            padding: resolvedBodyPadding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor:
          isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.more_vert,
          size: 20,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.lightBackground,
    this.darkBackground,
    this.lightHoverBackground,
    this.darkHoverBackground,
    this.lightBorder,
    this.darkBorder,
    this.lightIcon,
    this.darkIcon,
    this.lightText,
    this.darkText,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Color? lightBackground;
  final Color? darkBackground;
  final Color? lightHoverBackground;
  final Color? darkHoverBackground;
  final Color? lightBorder;
  final Color? darkBorder;
  final Color? lightIcon;
  final Color? darkIcon;
  final Color? lightText;
  final Color? darkText;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? (widget.darkBackground ?? widget.color.withValues(alpha: 0.2))
        : (widget.lightBackground ?? widget.color.withValues(alpha: 0.12));
    final hoverBackground = isDark
        ? (widget.darkHoverBackground ?? background)
        : (widget.lightHoverBackground ?? background);
    final border = isDark
        ? (widget.darkBorder ?? widget.color.withValues(alpha: 0.35))
        : (widget.lightBorder ?? widget.color.withValues(alpha: 0.2));
    final iconColor =
        isDark ? (widget.darkIcon ?? widget.color) : (widget.lightIcon ?? widget.color);
    final textColor =
        isDark ? (widget.darkText ?? widget.color) : (widget.lightText ?? widget.color);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isHovered ? hoverBackground : background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, size: 24, color: iconColor),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeTaskCard extends StatefulWidget {
  const _EmployeeTaskCard({required this.task, this.onTap});

  final _EmployeeTask task;
  final VoidCallback? onTap;

  @override
  State<_EmployeeTaskCard> createState() => _EmployeeTaskCardState();
}

class _EmployeeTaskCardState extends State<_EmployeeTaskCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB);
    final hoverBackground =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    const checkboxBorder = Color(0xFFD1D5DB);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _isHovered ? hoverBackground : background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IgnorePointer(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: false,
                      onChanged: (_) {},
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(color: checkboxBorder),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.task.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _EmployeeTaskMeta(
                            icon: Icons.place_outlined,
                            text: widget.task.location,
                          ),
                          _EmployeeTaskMeta(
                            icon: Icons.schedule,
                            text: widget.task.dueTime,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _EmployeePriorityBadge(priority: widget.task.priority),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeTaskMeta extends StatelessWidget {
  const _EmployeeTaskMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 14,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _EmployeePriorityBadge extends StatelessWidget {
  const _EmployeePriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late final Color background;
    late final Color textColor;
    switch (priority) {
      case 'high':
        background = isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
            : const Color(0xFFFEE2E2);
        textColor = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
        break;
      case 'medium':
        background = isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.3)
            : const Color(0xFFFEF3C7);
        textColor = isDark ? const Color(0xFFFACC15) : const Color(0xFFA16207);
        break;
      case 'low':
        background = isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
        textColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
        break;
      default:
        background = isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
        textColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
      ),
    );
  }
}

class _ProgressMetricRow extends StatelessWidget {
  const _ProgressMetricRow({required this.metric, this.bottomSpacing = 16});

  final _ProgressMetric metric;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final labelColor =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                metric.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
              Text(
                '${metric.value}%',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: metric.textColor ?? metric.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: metric.value / 100,
              minHeight: 12,
              backgroundColor: background,
              valueColor: AlwaysStoppedAnimation(metric.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceSummaryBar extends StatelessWidget {
  const _PerformanceSummaryBar({
    required this.completionRate,
    required this.completed,
    required this.total,
  });

  final double completionRate;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentLabel = (completionRate * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$percentLabel% complete',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$completed / $total tasks this week',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: completionRate.clamp(0, 1),
            minHeight: 12,
            backgroundColor: theme.colorScheme.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
          ),
        ),
      ],
    );
  }
}

class _TrainingProgressRow extends StatelessWidget {
  const _TrainingProgressRow({required this.item});

  final _TrainingItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final badgeBackground = isDark
        ? const Color(0xFF78350F).withValues(alpha: 0.2)
        : const Color(0xFFFFFBEB);
    final badgeText = isDark ? const Color(0xFFFACC15) : const Color(0xFFA16207);
    final badgeIcon = isDark ? const Color(0xFFEAB308) : const Color(0xFFD97706);
    final labelColor =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF111827);
    final valueColor =
        isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
              Text(
                '${item.value}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: item.value / 100,
            minHeight: 12,
            backgroundColor: background,
            valueColor: AlwaysStoppedAnimation(item.color),
          ),
          ),
          if (item.badge != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: badgeBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_outlined, color: badgeIcon, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    item.badge!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: badgeText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({required this.event});

  final _UpcomingEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF2D3748) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final dotColor = switch (event.type) {
      'meeting' => const Color(0xFF3B82F6),
      'training' => const Color(0xFFA855F7),
      _ => const Color(0xFF22C55E),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.time,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
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
  }
}

enum ActivityStatus { success, warning, info }

class _ActivityFeedItem {
  const _ActivityFeedItem({
    required this.title,
    required this.detail,
    required this.timeLabel,
    required this.status,
  });

  final String title;
  final String detail;
  final String timeLabel;
  final ActivityStatus status;
}

class _RecentActivityFeed extends StatelessWidget {
  const _RecentActivityFeed({required this.items});

  final List<_ActivityFeedItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Column(
      children: items.map((item) {
        final color = switch (item.status) {
          ActivityStatus.success => Colors.green,
          ActivityStatus.warning => Colors.orange,
          ActivityStatus.info => Colors.blue,
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.detail,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  item.timeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SupervisorMemberCard extends StatelessWidget {
  const _SupervisorMemberCard({required this.member});

  final _SupervisorMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final statusColor = member.status == 'active'
        ? Colors.green
        : member.status == 'away'
            ? Colors.amber
            : Colors.grey;
    final performanceColor = member.performance >= 90
        ? Colors.green
        : member.performance >= 75
            ? Colors.blue
            : Colors.orange;
    final progress = member.tasksTotal == 0
        ? 0.0
        : member.tasksCompleted / member.tasksTotal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
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
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      member.avatar,
                      style: theme.textTheme.titleMedium?.copyWith(
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
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F2937) : Colors.white,
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
                    member.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      Text(
                        '${member.tasksCompleted}/${member.tasksTotal} tasks',
                        style: theme.textTheme.bodySmall,
                      ),
                      _TagChip(
                        label: '${member.performance}%',
                        color: performanceColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor:
                          isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamTaskCard extends StatelessWidget {
  const _TeamTaskCard({required this.task});

  final _TeamTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _TagChip(
                  label: task.priority,
                  color: _priorityColor(task.priority),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(task.assignee, style: theme.textTheme.bodySmall),
                _MetaItem(icon: Icons.calendar_today_outlined, text: task.dueDate),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.item});

  final _ApprovalItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.type,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item.user} • ${item.time}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.color});

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

class _SupervisorTeamCard extends StatelessWidget {
  const _SupervisorTeamCard({
    required this.team,
    required this.expanded,
    required this.onToggle,
  });

  final _SupervisorTeam team;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final headerGradient = LinearGradient(
      colors: isDark
          ? [
              const Color(0xFF1E3A8A).withValues(alpha: 0.35),
              const Color(0xFF312E81).withValues(alpha: 0.35),
            ]
          : const [
              Color(0xFFEFF6FF),
              Color(0xFFE0E7FF),
            ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: headerGradient,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onToggle,
                    icon: Icon(
                      expanded ? Icons.expand_more : Icons.chevron_right,
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        team.avatar,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
                          team.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(team.role, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _SupervisorStat(label: 'Team', value: team.teamSize),
                            _SupervisorStat(
                              label: 'Projects',
                              value: team.projects,
                            ),
                            _SupervisorStat(
                              label: 'Performance',
                              value: team.performance,
                              accentColor: team.performance >= 90
                                  ? Colors.green
                                  : team.performance >= 75
                                      ? Colors.blue
                                      : Colors.orange,
                              suffix: '%',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (expanded)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team Members (${team.employees.length})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...team.employees
                        .map((employee) => _SupervisorEmployeeRow(employee: employee))
                        .toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SupervisorEmployeeRow extends StatelessWidget {
  const _SupervisorEmployeeRow({required this.employee});

  final _SupervisorEmployee employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = employee.status == 'active'
        ? Colors.green
        : employee.status == 'away'
            ? Colors.amber
            : Colors.grey;
    final progress = employee.tasksTotal == 0
        ? 0.0
        : employee.tasksCompleted / employee.tasksTotal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF9CA3AF), Color(0xFF4B5563)],
                  ),
                ),
                child: Center(
                  child: Text(
                    employee.avatar,
                    style: theme.textTheme.labelLarge?.copyWith(
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
                      color: isDark ? const Color(0xFF111827) : Colors.white,
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
                  employee.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${employee.tasksCompleted}/${employee.tasksTotal} tasks',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? const Color(0xFF374151)
                              : const Color(0xFFE5E7EB),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
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
    );
  }
}

class _SupervisorStat extends StatelessWidget {
  const _SupervisorStat({
    required this.label,
    required this.value,
    this.suffix = '',
    this.accentColor,
  });

  final String label;
  final int value;
  final String suffix;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            '$value$suffix',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveProjectCard extends StatelessWidget {
  const _ActiveProjectCard({required this.project});

  final _ActiveProject project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final statusColor = project.status == 'on-track'
        ? Colors.green
        : project.status == 'at-risk'
            ? Colors.red
            : Colors.orange;
    final budgetColor = project.budget > 90 ? Colors.red : Colors.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _TagChip(label: project.status, color: statusColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${project.supervisor} • Due ${project.deadline}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ProgressLine(
                    label: 'Progress',
                    value: project.progress,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProgressLine(
                    label: 'Budget',
                    value: project.budget,
                    color: budgetColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text('$value%', style: theme.textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 6,
            backgroundColor:
                isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _DepartmentMetricCard extends StatelessWidget {
  const _DepartmentMetricCard({required this.metric});

  final _DepartmentMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = metric.color.withValues(alpha: isDark ? 0.15 : 0.12);
    final border = metric.color.withValues(alpha: isDark ? 0.35 : 0.25);
    final textColor = metric.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
                  metric.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Icon(metric.icon, color: textColor, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              metric.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              metric.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _CriticalIssueCard extends StatelessWidget {
  const _CriticalIssueCard({required this.issue});

  final _CriticalIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = issue.severity == 'high' ? Colors.red : Colors.orange;
    final background = color.withValues(alpha: isDark ? 0.2 : 0.15);
    final border = color.withValues(alpha: isDark ? 0.4 : 0.25);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.issue,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issue.project,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.item});

  final _SummaryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor =
        item.accent ? const Color(0xFF22C55E) : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item.label, style: theme.textTheme.bodyMedium),
          Text(
            item.value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceAllocationItem {
  const _ResourceAllocationItem({
    required this.label,
    required this.allocation,
    required this.detail,
  });

  final String label;
  final int allocation;
  final String detail;
}

class _ResourceAllocationGrid extends StatelessWidget {
  const _ResourceAllocationGrid({required this.items});

  final List<_ResourceAllocationItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 320 ? 2 : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children:
              items.map((item) => _ResourceAllocationTile(item: item)).toList(),
        );
      },
    );
  }
}

class _ResourceAllocationTile extends StatelessWidget {
  const _ResourceAllocationTile({required this.item});

  final _ResourceAllocationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
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
                item.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${item.allocation}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: item.allocation / 100,
              minHeight: 10,
              backgroundColor:
                  isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.detail,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CrossDepartmentMetric {
  const _CrossDepartmentMetric({
    required this.title,
    required this.value,
    required this.delta,
    this.isNegative = false,
  });

  final String title;
  final String value;
  final String delta;
  final bool isNegative;
}

class _CrossDepartmentMetricCard extends StatelessWidget {
  const _CrossDepartmentMetricCard({required this.metric});

  final _CrossDepartmentMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deltaColor = metric.isNegative ? Colors.red : Colors.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: deltaColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  metric.delta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: deltaColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            metric.value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceWorkOrderCard extends StatelessWidget {
  const _MaintenanceWorkOrderCard({required this.order});

  final _MaintenanceWorkOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final statusColor = _statusColor(order.status);
    final priorityColor = _priorityColor(order.priority);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
              children: [
                _TagChip(label: order.status.replaceAll('-', ' '), color: statusColor),
                const SizedBox(width: 8),
                _TagChip(
                  label: order.priority,
                  color: priorityColor,
                  outlined: true,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.id,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              order.equipment,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(order.issue, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('User: ${order.assignedTo}', style: theme.textTheme.bodySmall),
                Text('Loc: ${order.location}', style: theme.textTheme.bodySmall),
                Text('Due: ${order.dueDate}', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceScheduleCard extends StatelessWidget {
  const _MaintenanceScheduleCard({required this.item});

  final _MaintenanceScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.equipment,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(item.type, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.date, style: theme.textTheme.bodySmall),
                Text(item.hours, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item});

  final _InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final statusColor = _stockColor(item.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.part,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _TagChip(label: item.status, color: statusColor),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Qty: ${item.quantity}', style: theme.textTheme.bodySmall),
                Text('Min: ${item.minStock}', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
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
        final crossAxisCount = constraints.maxWidth > 1100 ? 5 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount > 2 ? 2.25 : 1.35,
          physics: const NeverScrollableScrollPhysics(),
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
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final gradient = LinearGradient(
      colors: [
        color.withValues(alpha: isDark ? 0.28 : 0.12),
        Color.lerp(
              color.withValues(alpha: isDark ? 0.2 : 0.08),
              isDark ? Colors.black : Colors.white,
              isDark ? 0.2 : 0.35,
            ) ??
            color.withValues(alpha: isDark ? 0.2 : 0.08),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 6),
            Text(
              trend!,
              style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamMemberRow extends StatelessWidget {
  const _TeamMemberRow({
    required this.name,
    required this.role,
    required this.status,
    required this.completion,
  });

  final String name;
  final String role;
  final String status;
  final int completion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor =
        status == 'active' ? Colors.green : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(name.substring(0, 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name),
                  Text(
                    role,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '$completion%',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupervisorRow extends StatelessWidget {
  const _SupervisorRow({
    required this.name,
    required this.role,
    required this.teamSize,
    required this.projects,
    required this.performance,
  });

  final String name;
  final String role;
  final int teamSize;
  final int projects;
  final int performance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(name.substring(0, 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name),
                  Text(
                    role,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$teamSize team'),
                Text(
                  '$projects projects',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(width: 12),
            Text(
              '$performance%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkOrderRow extends StatelessWidget {
  const _WorkOrderRow({
    required this.id,
    required this.equipment,
    required this.issue,
    required this.priority,
    required this.status,
  });

  final String id;
  final String equipment;
  final String issue;
  final String priority;
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$id • $equipment'),
                  Text(
                    issue,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _StatusChip(label: priority, color: _priorityColor(priority)),
            const SizedBox(width: 8),
            _StatusChip(label: status, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({
    required this.title,
    required this.user,
    required this.priority,
    required this.status,
    required this.time,
    required this.category,
    this.onView,
  });

  final String title;
  final String user;
  final String priority;
  final String status;
  final String time;
  final String category;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _StatusChip(
                        label: priority,
                        color: _priorityColor(priority),
                      ),
                      _StatusChip(label: status, color: scheme.primary),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MetaItem(icon: Icons.person_outline, text: user),
                      const Text('•'),
                      Text(category, style: theme.textTheme.bodySmall),
                      const Text('•'),
                      _MetaItem(icon: Icons.schedule, text: time),
                    ],
                  ),
                ],
              ),
            ),
            if (onView != null) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onView,
                child: const Text('View'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _EmployeeTask {
  const _EmployeeTask({
    required this.title,
    required this.location,
    required this.priority,
    required this.dueTime,
  });

  final String title;
  final String location;
  final String priority;
  final String dueTime;
}

class _ProgressMetric {
  const _ProgressMetric({
    required this.label,
    required this.value,
    required this.color,
    this.textColor,
  });

  final String label;
  final int value;
  final Color color;
  final Color? textColor;
}

class _TrainingItem {
  const _TrainingItem({
    required this.label,
    required this.value,
    required this.color,
    this.badge,
  });

  final String label;
  final int value;
  final Color color;
  final String? badge;
}

class _UpcomingEvent {
  const _UpcomingEvent({
    required this.title,
    required this.time,
    required this.type,
  });

  final String title;
  final String time;
  final String type;
}

class _SupervisorMember {
  const _SupervisorMember({
    required this.name,
    required this.avatar,
    required this.status,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.performance,
  });

  final String name;
  final String avatar;
  final String status;
  final int tasksCompleted;
  final int tasksTotal;
  final int performance;
}

class _TeamTask {
  const _TeamTask({
    required this.title,
    required this.assignee,
    required this.priority,
    required this.dueDate,
  });

  final String title;
  final String assignee;
  final String priority;
  final String dueDate;
}

class _ApprovalItem {
  const _ApprovalItem({
    required this.type,
    required this.user,
    required this.time,
  });

  final String type;
  final String user;
  final String time;
}

class _SupervisorTeam {
  const _SupervisorTeam({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
    required this.teamSize,
    required this.projects,
    required this.performance,
    required this.employees,
  });

  final int id;
  final String name;
  final String role;
  final String avatar;
  final int teamSize;
  final int projects;
  final int performance;
  final List<_SupervisorEmployee> employees;
}

class _SupervisorEmployee {
  const _SupervisorEmployee({
    required this.name,
    required this.avatar,
    required this.status,
    required this.tasksCompleted,
    required this.tasksTotal,
  });

  final String name;
  final String avatar;
  final String status;
  final int tasksCompleted;
  final int tasksTotal;
}

class _ActiveProject {
  const _ActiveProject({
    required this.name,
    required this.supervisor,
    required this.progress,
    required this.deadline,
    required this.budget,
    required this.status,
  });

  final String name;
  final String supervisor;
  final int progress;
  final String deadline;
  final int budget;
  final String status;
}

class _DepartmentMetric {
  const _DepartmentMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
}

class _CriticalIssue {
  const _CriticalIssue({
    required this.issue,
    required this.project,
    required this.severity,
  });

  final String issue;
  final String project;
  final String severity;
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;
}

class _MaintenanceWorkOrder {
  const _MaintenanceWorkOrder({
    required this.id,
    required this.equipment,
    required this.issue,
    required this.priority,
    required this.assignedTo,
    required this.dueDate,
    required this.status,
    required this.location,
  });

  final String id;
  final String equipment;
  final String issue;
  final String priority;
  final String assignedTo;
  final String dueDate;
  final String status;
  final String location;
}

class _MaintenanceScheduleItem {
  const _MaintenanceScheduleItem({
    required this.equipment,
    required this.type,
    required this.date,
    required this.hours,
  });

  final String equipment;
  final String type;
  final String date;
  final String hours;
}

class _InventoryItem {
  const _InventoryItem({
    required this.part,
    required this.quantity,
    required this.minStock,
    required this.status,
  });

  final String part;
  final int quantity;
  final int minStock;
  final String status;
}

class _TechActivity {
  const _TechActivity({
    required this.action,
    required this.detail,
    required this.time,
    required this.type,
  });

  final String action;
  final String detail;
  final String time;
  final String type;
}

class _SupportMetric {
  const _SupportMetric({
    required this.label,
    required this.value,
    required this.progress,
    required this.note,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final String note;
  final Color color;
}

class _KnowledgeArticle {
  const _KnowledgeArticle({
    required this.title,
    required this.views,
  });

  final String title;
  final int views;
}

class _SupportTicket {
  const _SupportTicket({
    required this.title,
    required this.user,
    required this.priority,
    required this.status,
    required this.time,
    required this.category,
  });

  final String title;
  final String user;
  final String priority;
  final String status;
  final String time;
  final String category;
}

class _TechErrorItem {
  const _TechErrorItem({
    required this.title,
    required this.detail,
    required this.time,
  });

  final String title;
  final String detail;
  final String time;
}

class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({
    required this.title,
    required this.status,
    required this.detail,
    required this.icon,
    required this.background,
    required this.border,
  });

  final String title;
  final String status;
  final String detail;
  final IconData icon;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: border),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textStyle?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(detail, style: textStyle),
              ],
            ),
          ),
          Text(
            status,
            style: textStyle?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final _TechActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final dotColor = switch (activity.type) {
      'success' => Colors.green,
      'info' => Colors.blue,
      _ => Colors.grey,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
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
                    activity.action,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(activity.detail, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              activity.time,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportQuickActionTile extends StatelessWidget {
  const _SupportQuickActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = color.withValues(alpha: isDark ? 0.2 : 0.12);
    final border = color.withValues(alpha: isDark ? 0.35 : 0.2);
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
            Icon(icon, color: color, size: 18),
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

class _SupportMetricRow extends StatelessWidget {
  const _SupportMetricRow({required this.metric});

  final _SupportMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(metric.label, style: theme.textTheme.bodySmall),
              Text(
                metric.value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: metric.progress,
              minHeight: 8,
              backgroundColor: background,
              valueColor: AlwaysStoppedAnimation(metric.color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeArticleTile extends StatelessWidget {
  const _KnowledgeArticleTile({required this.article});

  final _KnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${article.views} views',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = outlined
        ? Colors.transparent
        : color.withValues(alpha: isDark ? 0.2 : 0.12);
    final borderColor = outlined
        ? color.withValues(alpha: isDark ? 0.7 : 0.6)
        : color.withValues(alpha: isDark ? 0.4 : 0.25);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

Color _priorityColor(String priority) {
  switch (priority) {
    case 'high':
      return Colors.red;
    case 'medium':
      return Colors.orange;
    case 'low':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'in-progress':
      return Colors.blue;
    case 'scheduled':
      return Colors.amber;
    case 'pending':
      return Colors.orange;
    case 'completed':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

Color _stockColor(String status) {
  switch (status) {
    case 'good':
      return Colors.green;
    case 'low':
      return Colors.orange;
    case 'critical':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String _taskLocationLabel(Task task) {
  final metadata = task.metadata ?? const <String, dynamic>{};
  final location = metadata['location']?.toString() ??
      metadata['site']?.toString() ??
      metadata['address']?.toString() ??
      task.assignedTeam ??
      '';
  if (location.trim().isEmpty) return 'Location not set';
  return location;
}

String _taskPriorityLabel(Task task) {
  final priority = task.priority ?? task.metadata?['priority']?.toString();
  if (priority == null || priority.trim().isEmpty) return 'medium';
  return priority.toLowerCase();
}

String _taskDueLabel(Task task) {
  final due = task.dueDate;
  if (due == null) return 'No due date';
  return DateFormat.jm().format(due);
}

bool _isSameDay(DateTime? date, DateTime now) {
  if (date == null) return false;
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

int _onTimeCompletionPercent(List<Task> tasks) {
  final completed = tasks.where(
    (task) => task.isComplete && task.completedAt != null && task.dueDate != null,
  );
  if (completed.isEmpty) return 0;
  final onTime =
      completed.where((task) => !task.completedAt!.isAfter(task.dueDate!));
  return ((onTime.length / completed.length) * 100).round();
}

List<_TrainingItem> _buildTrainingItems(List<Training> records) {
  if (records.isEmpty) return const [];
  final colors = const [
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFA855F7),
  ];
  final items = <_TrainingItem>[];
  for (var i = 0; i < records.length && items.length < 3; i++) {
    final record = records[i];
    final progress = _trainingProgressValue(record);
    final label = _trainingLabel(record);
    final badge = (progress >= 100 ||
            record.status == TrainingStatus.certified ||
            record.certificateUrl != null)
        ? 'Certificate earned!'
        : null;
    items.add(
      _TrainingItem(
        label: label,
        value: progress,
        color: colors[items.length % colors.length],
        badge: badge,
      ),
    );
  }
  return items;
}

String _trainingLabel(Training training) {
  final type = training.trainingType?.trim();
  if (type != null && type.isNotEmpty) {
    return type;
  }
  return training.trainingName;
}

int _trainingProgressValue(Training training) {
  final metadata = training.metadata ?? const <String, dynamic>{};
  final raw = metadata['progress'] ?? metadata['completion'];
  final parsed = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (parsed != null) {
    final normalized = parsed <= 1 ? parsed * 100 : parsed;
    return _clampPercent(normalized.round());
  }
  switch (training.status) {
    case TrainingStatus.certified:
      return 100;
    case TrainingStatus.inProgress:
      return 50;
    case TrainingStatus.dueForRecert:
      return 80;
    case TrainingStatus.failed:
      return 30;
    case TrainingStatus.expired:
    case TrainingStatus.notStarted:
      return 0;
  }
}

int _clampPercent(int value) {
  if (value < 0) return 0;
  if (value > 100) return 100;
  return value;
}

List<_UpcomingEvent> _buildUpcomingEvents(
  List<Task> tasks,
  List<Training> trainings,
) {
  final now = DateTime.now();
  final entries = <({DateTime date, _UpcomingEvent event})>[];
  for (final task in tasks) {
    final due = task.dueDate;
    if (due == null || due.isBefore(now)) continue;
    entries.add((
      date: due,
      event: _UpcomingEvent(
        title: task.title,
        time: _formatEventTime(due, now),
        type: 'task',
      ),
    ));
  }
  for (final training in trainings) {
    final next =
        training.nextRecertificationDate ?? training.expirationDate;
    if (next == null || next.isBefore(now)) continue;
    entries.add((
      date: next,
      event: _UpcomingEvent(
        title: training.trainingName,
        time: _formatEventTime(next, now),
        type: 'training',
      ),
    ));
  }
  entries.sort((a, b) => a.date.compareTo(b.date));
  return entries.map((entry) => entry.event).toList();
}

String _formatEventTime(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final eventDay = DateTime(date.year, date.month, date.day);
  final diff = eventDay.difference(today).inDays;
  if (diff == 0) {
    return 'Today, ${DateFormat.jm().format(date)}';
  }
  if (diff == 1) {
    return 'Tomorrow, ${DateFormat.jm().format(date)}';
  }
  return DateFormat('MMM d, h:mm a').format(date);
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

List<NotificationItem> _buildEmployeeNotifications(
  List<AppNotification> notifications, {
  Set<String>? dismissedIds,
}
) {
  final visible = notifications.where((notification) {
    if (notification.isRead) return false;
    if (dismissedIds != null && dismissedIds.contains(notification.id)) {
      return false;
    }
    return true;
  }).toList();
  if (visible.isEmpty) {
    return const [];
  }
  return visible.map((notification) {
    final priority = _priorityFromNotification(notification);
    final icon = _iconForNotificationType(notification.type);
    return NotificationItem(
      id: notification.id,
      title: notification.title,
      description: notification.body,
      timeLabel: _formatRelativeTime(notification.createdAt),
      icon: icon,
      priority: priority,
    );
  }).toList();
}

NotificationPriority _priorityFromNotification(AppNotification notification) {
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
  return NotificationPriority.low;
}

NotificationPriority? _priorityFromValue(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    switch (value.toInt()) {
      case 1:
        return NotificationPriority.urgent;
      case 2:
        return NotificationPriority.high;
      case 3:
        return NotificationPriority.medium;
      case 4:
        return NotificationPriority.low;
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
      return NotificationPriority.urgent;
    case 'high':
    case 'p2':
    case 'sev2':
    case 'alert':
    case 'error':
    case 'warning':
    case 'incident':
    case 'task':
    case 'task_due':
    case 'task_approval':
    case 'overdue':
    case 'approval':
    case 'sop_ack_due':
      return NotificationPriority.high;
    case 'medium':
    case 'p3':
    case 'sev3':
    case 'training':
    case 'training_expire':
    case 'milestone':
    case 'support':
    case 'ticket':
    case 'system':
    case 'request':
    case 'asset_due':
    case 'inspection_due':
    case 'timesheet':
      return NotificationPriority.medium;
    case 'low':
    case 'p4':
    case 'sev4':
    case 'info':
    case 'success':
    case 'message':
    case 'document':
    case 'submission':
    case 'sop':
    case 'comment':
    case 'update':
    case 'completion':
    case 'backup':
    case 'sync':
      return NotificationPriority.low;
    default:
      return null;
  }
}

IconData _iconForNotificationType(String? type) {
  final normalized = type?.toLowerCase().trim();
  if (normalized == null || normalized.isEmpty) {
    return Icons.notifications;
  }
  if (normalized.contains('task')) {
    return Icons.check_circle_outline;
  }
  if (normalized.contains('training') || normalized.contains('cert')) {
    return Icons.warning_amber_outlined;
  }
  if (normalized.contains('timesheet') ||
      normalized.contains('time') ||
      normalized.contains('clock')) {
    return Icons.schedule;
  }
  if (normalized.contains('message') || normalized.contains('chat')) {
    return Icons.chat_bubble_outline;
  }
  if (normalized.contains('document') || normalized.contains('submission')) {
    return Icons.description_outlined;
  }
  if (normalized.contains('alert') || normalized.contains('incident')) {
    return Icons.warning_amber_outlined;
  }
  return Icons.notifications;
}

String _formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  final weeks = (diff.inDays / 7).floor();
  return '$weeks weeks ago';
}

List<NotificationItem> _sampleEmployeeNotifications() {
  return [
    NotificationItem(
      id: 'task',
      title: 'New Task Assigned',
      description: 'Complete safety inspection for Building A by Friday',
      timeLabel: '15 min ago',
      icon: Icons.check_circle_outline,
      priority: NotificationPriority.high,
    ),
    NotificationItem(
      id: 'training',
      title: 'Training Due Soon',
      description: 'Annual OSHA certification expires in 7 days',
      timeLabel: '1 hour ago',
      icon: Icons.warning_amber_outlined,
      priority: NotificationPriority.medium,
    ),
    NotificationItem(
      id: 'timesheet',
      title: 'Timesheet Reminder',
      description: 'Submit your timesheet for this week by EOD tomorrow',
      timeLabel: '3 hours ago',
      icon: Icons.schedule,
      priority: NotificationPriority.medium,
    ),
    NotificationItem(
      id: 'message',
      title: 'Message from Supervisor',
      description: 'Sarah Johnson: Great work on the Johnson project!',
      timeLabel: '5 hours ago',
      icon: Icons.chat_bubble_outline,
      priority: NotificationPriority.low,
    ),
  ];
}

List<NotificationItem> _sampleSupervisorNotifications() {
  return [
    NotificationItem(
      id: 'urgent',
      title: 'Urgent: Team Emergency',
      description: 'Sarah Johnson injured - immediate attention required',
      timeLabel: 'Just now',
      icon: Icons.warning_amber_outlined,
      priority: NotificationPriority.urgent,
    ),
    NotificationItem(
      id: 'approval',
      title: 'Approval Required',
      description: 'Mike Chen submitted timesheet for review',
      timeLabel: '10 min ago',
      icon: Icons.schedule,
      priority: NotificationPriority.high,
    ),
    NotificationItem(
      id: 'overdue',
      title: 'Task Overdue',
      description: 'Emily Davis has 1 overdue task - Equipment Maintenance',
      timeLabel: '30 min ago',
      icon: Icons.error_outline,
      priority: NotificationPriority.medium,
    ),
    NotificationItem(
      id: 'achievement',
      title: 'Team Achievement',
      description: 'Your team completed 15 tasks this week',
      timeLabel: '2 hours ago',
      icon: Icons.check_circle_outline,
      priority: NotificationPriority.low,
    ),
  ];
}

List<NotificationItem> _sampleManagerNotifications() {
  return [
    NotificationItem(
      id: 'budget',
      title: 'Budget Alert',
      description: 'Department spending at 85% - review Q4 allocations',
      timeLabel: '30 min ago',
      icon: Icons.attach_money,
      priority: NotificationPriority.high,
    ),
    NotificationItem(
      id: 'report',
      title: 'Supervisor Report Due',
      description: 'John Smith quarterly review needs approval',
      timeLabel: '2 hours ago',
      icon: Icons.people_outline,
      priority: NotificationPriority.medium,
    ),
    NotificationItem(
      id: 'milestone',
      title: 'Project Milestone',
      description: 'Building A construction 90% complete - ahead of schedule',
      timeLabel: '4 hours ago',
      icon: Icons.folder_outlined,
      priority: NotificationPriority.low,
    ),
    NotificationItem(
      id: 'performance',
      title: 'Team Performance',
      description: 'Department exceeded productivity goals by 12% this month',
      timeLabel: '1 day ago',
      icon: Icons.trending_up,
      priority: NotificationPriority.low,
    ),
  ];
}
