import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../analytics/presentation/pages/analytics_page.dart';
import '../../../assets/presentation/pages/assets_page.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../../documents/presentation/pages/documents_page.dart';
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
import '../../../navigation/presentation/pages/support_tickets_page.dart';
import '../../../navigation/presentation/pages/system_overview_page.dart';
import '../../../navigation/presentation/pages/system_logs_page.dart';
import '../../../navigation/presentation/pages/timecards_page.dart';
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
import '../../../teams/presentation/pages/teams_page.dart';
import '../../../templates/presentation/pages/templates_page.dart';
import '../../../training/presentation/pages/training_hub_page.dart';
import 'admin_dashboard_page.dart';

class AdminShellPage extends ConsumerStatefulWidget {
  const AdminShellPage({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends ConsumerState<AdminShellPage> {
  SideMenuRoute _activeRoute = SideMenuRoute.dashboard;

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      role: widget.role,
      activeRoute: _activeRoute,
      onNavigate: (route) => setState(() => _activeRoute = route),
      child: _adminPageForRoute(widget.role, _activeRoute),
    );
  }
}

Widget _adminPageForRoute(UserRole role, SideMenuRoute route) {
  if (route == SideMenuRoute.dashboard) {
    return AdminDashboardPage(userRole: role, embedInShell: true);
  }
  return switch (route) {
    SideMenuRoute.notifications => const NotificationsPage(),
    SideMenuRoute.messages => const MessagesPage(),
    SideMenuRoute.companyNews => const NewsPostsPage(),
    SideMenuRoute.organizationChart => OrganizationChartPage(role: role),
    SideMenuRoute.team => const TeamsPage(),
    SideMenuRoute.organization =>
      AdminDashboardPage(userRole: role, embedInShell: true, initialSectionId: 'orgs'),
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
    SideMenuRoute.auditLogs => const AuditLogsPage(),
    SideMenuRoute.rolesPermissions => role == UserRole.admin
        ? const RolesPage()
        : const RolesPermissionsPage(),
    SideMenuRoute.systemOverview => const SystemOverviewPage(),
    SideMenuRoute.supportTickets => const SupportTicketsPage(),
    SideMenuRoute.knowledgeBase => const SopLibraryPage(),
    SideMenuRoute.systemLogs => const SystemLogsPage(),
    SideMenuRoute.users => const UserDirectoryPage(),
    SideMenuRoute.dashboard => AdminDashboardPage(userRole: role, embedInShell: true),
  };
}
