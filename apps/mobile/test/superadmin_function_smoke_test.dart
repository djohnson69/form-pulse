import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/core/di/injection.dart';
import 'package:mobile/features/admin/presentation/pages/super_admin_dashboard_page.dart';
import 'package:mobile/features/assets/presentation/pages/assets_page.dart';
import 'package:mobile/features/dashboard/presentation/pages/reports_page.dart';
import 'package:mobile/features/documents/presentation/pages/documents_page.dart';
import 'package:mobile/features/navigation/presentation/pages/approvals_page.dart';
import 'package:mobile/features/navigation/presentation/pages/audit_logs_page.dart';
import 'package:mobile/features/navigation/presentation/pages/before_after_photos_page.dart';
import 'package:mobile/features/navigation/presentation/pages/forms_page.dart';
import 'package:mobile/features/navigation/presentation/pages/incidents_page.dart';
import 'package:mobile/features/navigation/presentation/pages/notifications_page.dart';
import 'package:mobile/features/navigation/presentation/pages/organization_chart_page.dart';
import 'package:mobile/features/navigation/presentation/pages/payroll_page.dart';
import 'package:mobile/features/navigation/presentation/pages/photos_page.dart';
import 'package:mobile/features/navigation/presentation/pages/roles_permissions_page.dart';
import 'package:mobile/features/navigation/presentation/pages/system_overview_page.dart';
import 'package:mobile/features/navigation/presentation/pages/user_directory_page.dart';
import 'package:mobile/features/navigation/presentation/pages/work_orders_page.dart';
import 'package:mobile/features/navigation/presentation/widgets/side_menu.dart';
import 'package:mobile/features/ops/presentation/pages/ai_tools_page.dart';
import 'package:mobile/features/ops/presentation/pages/news_posts_page.dart';
import 'package:mobile/features/ops/presentation/pages/payment_requests_page.dart';
import 'package:mobile/features/partners/presentation/pages/messages_page.dart';
import 'package:mobile/features/projects/presentation/pages/projects_page.dart';
import 'package:mobile/features/settings/presentation/pages/settings_page.dart';
import 'package:mobile/features/tasks/presentation/pages/tasks_page.dart';
import 'package:mobile/features/templates/presentation/pages/templates_page.dart';
import 'package:mobile/features/training/presentation/pages/training_hub_page.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://xpcibptzncfmifaneoop.supabase.co',
);

const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW',
);

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _ensureSupabaseInitialized();
    await configureDependencies();
  });

  test('Super Admin side menu matches React', () {
    const expected = [
      'Dashboard',
      'Notifications',
      'Messages',
      'Company News',
      'Organization Chart',
      'System Overview',
      'Users',
      'Roles & Permissions',
      'Projects',
      'Tasks',
      'Work Orders',
      'Forms',
      'Documents',
      'Photos & Videos',
      'Before/After Photos',
      'Assets',
      'Training',
      'Incidents',
      'AI Tools',
      'Approvals',
      'Templates',
      'Payments',
      'Payroll',
      'Reports',
      'Audit Logs',
      'Settings',
    ];
    final labels =
        sideMenuItemsForRole(UserRole.superAdmin).map((e) => e.label).toList();
    expect(labels, expected);
  });

  testWidgets('Super Admin web: menu persists and navigates', (tester) async {
    await _setSurfaceSize(tester, const Size(1400, 900));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SuperAdminDashboardPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SideMenu), findsOneWidget);
    expect(find.byType(DropdownButton<UserRole>), findsOneWidget);

    final cases = <({String label, Type pageType})>[
      (label: 'Users', pageType: UserDirectoryPage),
      (label: 'Roles & Permissions', pageType: RolesPermissionsPage),
      (label: 'Work Orders', pageType: WorkOrdersPage),
      (label: 'Projects', pageType: ProjectsPage),
      (label: 'Tasks', pageType: TasksPage),
      (label: 'Forms', pageType: FormsPage),
      (label: 'Documents', pageType: DocumentsPage),
      (label: 'Photos & Videos', pageType: PhotosPage),
      (label: 'Approvals', pageType: ApprovalsPage),
      (label: 'Templates', pageType: TemplatesPage),
      (label: 'Payments', pageType: PaymentRequestsPage),
      (label: 'Payroll', pageType: PayrollPage),
      (label: 'Reports', pageType: ReportsPage),
      (label: 'Audit Logs', pageType: AuditLogsPage),
      (label: 'Settings', pageType: SettingsPage),
      (label: 'System Overview', pageType: SystemOverviewPage),
      (label: 'Organization Chart', pageType: OrganizationChartPage),
      (label: 'Company News', pageType: NewsPostsPage),
      (label: 'Messages', pageType: MessagesPage),
      (label: 'Notifications', pageType: NotificationsPage),
      (label: 'Before/After Photos', pageType: BeforeAfterPhotosPage),
      (label: 'Assets', pageType: AssetsPage),
      (label: 'Training', pageType: TrainingHubPage),
      (label: 'Incidents', pageType: IncidentsPage),
      (label: 'AI Tools', pageType: AiToolsPage),
    ];

    for (final testCase in cases) {
      await _tapSideMenuItem(tester, testCase.label);
      expect(find.byType(testCase.pageType), findsOneWidget);
      expect(find.byType(SideMenu), findsOneWidget);
    }
  });

  testWidgets('Super Admin mobile: drawer opens and navigates', (tester) async {
    await _setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) {
            final data = MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 44),
            );
            return MediaQuery(data: data, child: child!);
          },
          home: const SuperAdminDashboardPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DropdownButton<UserRole>), findsOneWidget);

    final scaffoldFinder = find.byWidgetPredicate(
      (widget) => widget is Scaffold && widget.drawer != null,
    );
    final scaffoldState = tester.state<ScaffoldState>(scaffoldFinder);
    final mobileMenuFinder = find.byWidgetPredicate(
      (widget) => widget is SideMenu && widget.isMobile,
    );

    await _openDrawer(tester, scaffoldState, mobileMenuFinder);

    expect(mobileMenuFinder, findsOneWidget);

    await _tapSideMenuItem(
      tester,
      'Work Orders',
      menuFinder: mobileMenuFinder,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(WorkOrdersPage), findsOneWidget);

    // Ensure the drawer can open again after navigation.
    await _openDrawer(tester, scaffoldState, mobileMenuFinder);
    expect(mobileMenuFinder, findsOneWidget);
  });

  testWidgets('Messages mobile: Inbox returns to list', (tester) async {
    await _setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SuperAdminDashboardPage(initialRoute: SideMenuRoute.messages),
        ),
      ),
    );
    await tester.pump();

    final conversation = find.text('Sarah Johnson');
    await _pumpUntilFound(tester, conversation);

    await tester.tap(conversation);
    await tester.pump();

    expect(find.text('Messages'), findsNothing);
    expect(find.text('Inbox'), findsOneWidget);

    await tester.tap(find.text('Inbox'));
    await tester.pump();

    expect(find.text('Messages'), findsOneWidget);
    expect(conversation, findsOneWidget);
  });
}

Future<void> _tapSideMenuItem(
  WidgetTester tester,
  String label, {
  Finder? menuFinder,
}) async {
  final menu = menuFinder ?? find.byType(SideMenu);
  final item = find.descendant(of: menu, matching: find.text(label));
  final tapTarget = find.ancestor(of: item, matching: find.byType(InkWell));

  final listView = find.descendant(of: menu, matching: find.byType(ListView));
  if (listView.evaluate().isNotEmpty) {
    try {
      await tester.dragUntilVisible(
        item,
        listView.first,
        const Offset(0, -200),
      );
    } catch (_) {
      await tester.dragUntilVisible(
        item,
        listView.first,
        const Offset(0, 200),
      );
    }
  }
  await tester.pump();
  await tester.tap(tapTarget.evaluate().isNotEmpty ? tapTarget.first : item);
  await tester.pump();
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.binding.window.physicalSizeTestValue = size;
  tester.binding.window.devicePixelRatioTestValue = 1.0;
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
  addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
}

Future<void> _openDrawer(
  WidgetTester tester,
  ScaffoldState scaffoldState,
  Finder menuFinder,
) async {
  scaffoldState.openDrawer();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    try {
      final dx = tester.getTopLeft(menuFinder).dx;
      if (dx >= 0) return;
    } catch (_) {}
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}
