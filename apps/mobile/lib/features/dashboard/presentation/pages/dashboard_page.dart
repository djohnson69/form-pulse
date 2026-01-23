import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/dashboard_provider.dart';
import '../../data/dashboard_repository.dart';
import '../../data/pending_queue.dart';
import 'create_form_page.dart';
import 'form_detail_page.dart';
import 'form_fill_page.dart';
import '../../../projects/data/projects_provider.dart';
import '../../../projects/presentation/pages/project_detail_page.dart';
import '../../../projects/presentation/pages/project_editor_page.dart';
import '../../../projects/presentation/pages/projects_page.dart';
import '../../../documents/presentation/pages/documents_page.dart';
import '../../../tasks/data/tasks_provider.dart';
import '../../../tasks/presentation/pages/task_detail_page.dart';
import '../../../tasks/presentation/pages/task_editor_page.dart';
import '../../../tasks/presentation/pages/tasks_page.dart';
import '../../../training/presentation/pages/training_hub_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../partners/presentation/pages/messages_page.dart';
import '../../../partners/presentation/pages/clients_page.dart';
import '../../../partners/presentation/pages/vendors_page.dart';
import '../../../assets/presentation/pages/assets_page.dart';
import '../../../ops/presentation/pages/ops_hub_page.dart';
import '../../../ops/presentation/pages/ai_tools_page.dart';
import '../../../ops/presentation/pages/news_posts_page.dart';
import '../../../ops/data/ops_provider.dart';
import '../../../ops/data/ops_repository.dart';
import '../../../ai_assistant/presentation/widgets/ai_chat_panel_v2.dart';
import '../../../navigation/presentation/widgets/side_menu.dart';
import '../widgets/top_bar.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import 'submission_detail_page.dart';
import 'template_gallery_page.dart';
import 'reports_page.dart';
import '../../../../core/utils/automation_scheduler.dart';
import '../../../../core/utils/ai_job_scheduler.dart';

final _navToAlertsProvider = legacy.StateProvider<bool>((ref) => false);
final _navToTasksProvider = legacy.StateProvider<bool>((ref) => false);
final dashboardPrefsProvider =
    legacy.StateNotifierProvider<DashboardPrefsNotifier, DashboardPreferences>(
      (ref) => DashboardPrefsNotifier(),
    );

/// Main dashboard container that holds the bottom navigation experience.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _currentIndex = 0;
  ProviderSubscription<bool>? _navSubscription;
  ProviderSubscription<bool>? _taskNavSubscription;
  PendingSubmissionQueue? _pendingQueue;
  late final OpsRepositoryBase _opsRepository;
  Timer? _automationTimer;
  static const _supabaseBucket =
      String.fromEnvironment('SUPABASE_BUCKET', defaultValue: 'formbridge-attachments');

  late final List<Widget> _pages = [
    const DashboardHomeView(),
    const FormsListView(),
    const ProjectsPage(),
    const TasksPage(),
    const NotificationsView(),
    const ProfileView(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _pages.length - 1);
    ref.read(dashboardPrefsProvider.notifier).ensureLoaded();
    _opsRepository = ref.read(opsRepositoryProvider);
    final supabaseClient = Supabase.instance.client;
    _pendingQueue = PendingSubmissionQueue(
      ref.read(dashboardRepositoryProvider),
      supabaseClient,
      bucketName: _supabaseBucket,
    );
    // Attempt to flush any pending offline submissions.
    _pendingQueue?.flush();
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
    _navSubscription = ref.listenManual<bool>(
      _navToAlertsProvider,
      (previous, next) {
        if (next) {
          setState(() => _currentIndex = 4);
          ref.read(_navToAlertsProvider.notifier).state = false;
        }
      },
    );
    _taskNavSubscription = ref.listenManual<bool>(
      _navToTasksProvider,
      (previous, next) {
        if (next) {
          setState(() => _currentIndex = 3);
          ref.read(_navToTasksProvider.notifier).state = false;
        }
      },
    );
  }

  @override
  void dispose() {
    _navSubscription?.close();
    _taskNavSubscription?.close();
    _automationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar = kIsWeb || constraints.maxWidth >= 768;
        final activeRoute = _activeRouteForIndex(_currentIndex);
        return Scaffold(
          drawer: showSidebar
              ? null
              : Drawer(
                  child: SideMenu(
                    role: UserRole.viewer,
                    activeRoute: activeRoute,
                    isMobile: true,
                    onNavigate: (route) =>
                        _handleSideMenuNavigation(context, route),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
          body: Column(
            children: [
              Builder(
                builder: (context) => TopBar(
                  role: UserRole.viewer,
                  isMobile: !showSidebar,
                  onMenuPressed: showSidebar
                      ? null
                      : () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (showSidebar)
                      SideMenu(
                        role: UserRole.viewer,
                        activeRoute: activeRoute,
                        onNavigate: (route) =>
                            _handleSideMenuNavigation(context, route),
                      ),
                    Expanded(child: _pages[_currentIndex]),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: showSidebar
              ? null
              : NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.description_outlined),
                      selectedIcon: Icon(Icons.description),
                      label: 'Forms',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.work_outline),
                      selectedIcon: Icon(Icons.work),
                      label: 'Projects',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.checklist_outlined),
                      selectedIcon: Icon(Icons.checklist),
                      label: 'Tasks',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.notifications_outlined),
                      selectedIcon: Icon(Icons.notifications),
                      label: 'Alerts',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                ),
          floatingActionButton: _currentIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: () => _openSubmissionSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New Submission'),
                )
              : _currentIndex == 2
              ? FloatingActionButton.extended(
                  onPressed: () => _openProjectEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New Project'),
                )
              : _currentIndex == 3
              ? FloatingActionButton.extended(
                  onPressed: () => _openTaskEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New Task'),
                )
              : null,
        );
      },
    );
  }

  SideMenuRoute? _activeRouteForIndex(int index) {
    switch (index) {
      case 0:
        return SideMenuRoute.dashboard;
      case 1:
        return SideMenuRoute.forms;
      case 2:
        return SideMenuRoute.projects;
      case 3:
        return SideMenuRoute.tasks;
      case 4:
        return SideMenuRoute.notifications;
      default:
        return null;
    }
  }

  void _handleSideMenuNavigation(BuildContext context, SideMenuRoute route) {
    switch (route) {
      case SideMenuRoute.dashboard:
        setState(() => _currentIndex = 0);
        return;
      case SideMenuRoute.forms:
        setState(() => _currentIndex = 1);
        return;
      case SideMenuRoute.projects:
        setState(() => _currentIndex = 2);
        return;
      case SideMenuRoute.tasks:
        setState(() => _currentIndex = 3);
        return;
      case SideMenuRoute.notifications:
        setState(() => _currentIndex = 4);
        return;
      case SideMenuRoute.messages:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ViewerShellPage(
              activeRoute: SideMenuRoute.messages,
              child: const MessagesPage(),
            ),
          ),
        );
        return;
      case SideMenuRoute.companyNews:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ViewerShellPage(
              activeRoute: SideMenuRoute.companyNews,
              child: const NewsPostsPage(),
            ),
          ),
        );
        return;
      case SideMenuRoute.settings:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ViewerShellPage(
              activeRoute: SideMenuRoute.settings,
              child: const SettingsPage(),
            ),
          ),
        );
        return;
      default:
        return;
    }
  }

  Future<void> _openSubmissionSheet(BuildContext context) async {
    final data = await ref.read(dashboardDataProvider.future);
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        return SubmissionSheet(forms: data.forms);
      },
    );
    if (!context.mounted) return;
    if (result != null && result['form'] is FormDefinition) {
      final FormDefinition form = result['form'] as FormDefinition;
      final Map<String, dynamic>? prefill =
          result['prefill'] as Map<String, dynamic>?;
      if (!context.mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => FormFillPage(form: form, prefillData: prefill),
        ),
      );
      ref.invalidate(dashboardDataProvider);
    }
  }

  Future<void> _openProjectEditor(BuildContext context) async {
    final project = await Navigator.of(context).push<Project?>(
      MaterialPageRoute(builder: (_) => const ProjectEditorPage()),
    );
    if (!context.mounted) return;
    if (project != null) {
      ref.invalidate(projectsProvider);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProjectDetailPage(project: project)),
      );
    }
  }

  Future<void> _openTaskEditor(BuildContext context) async {
    final task = await Navigator.of(context).push<Task?>(
      MaterialPageRoute(builder: (_) => const TaskEditorPage()),
    );
    if (!context.mounted) return;
    if (task != null) {
      ref.invalidate(tasksProvider);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskDetailPage(task: task)),
      );
    }
  }
}

class _ViewerShellPage extends StatelessWidget {
  const _ViewerShellPage({
    required this.child,
    required this.activeRoute,
  });

  final Widget child;
  final SideMenuRoute activeRoute;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar = kIsWeb || constraints.maxWidth >= 768;
        return Scaffold(
          drawer: showSidebar
              ? null
              : Drawer(
                  child: SideMenu(
                    role: UserRole.viewer,
                    activeRoute: activeRoute,
                    isMobile: true,
                    onNavigate: (route) =>
                        Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => _ViewerShellPage(
                          activeRoute: route,
                          child: _viewerRoutePage(route),
                        ),
                      ),
                    ),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
          body: Column(
            children: [
              Builder(
                builder: (context) => TopBar(
                  role: UserRole.viewer,
                  isMobile: !showSidebar,
                  onMenuPressed: showSidebar
                      ? null
                      : () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (showSidebar)
                      SideMenu(
                        role: UserRole.viewer,
                        activeRoute: activeRoute,
                        onNavigate: (route) => Navigator.of(context)
                            .pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => _ViewerShellPage(
                              activeRoute: route,
                              child: _viewerRoutePage(route),
                            ),
                          ),
                        ),
                      ),
                    Expanded(child: child),
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

Widget _viewerRoutePage(SideMenuRoute route) {
  return switch (route) {
    SideMenuRoute.dashboard => const DashboardPage(initialIndex: 0),
    SideMenuRoute.notifications => const DashboardPage(initialIndex: 4),
    SideMenuRoute.messages => const MessagesPage(),
    SideMenuRoute.companyNews => const NewsPostsPage(),
    SideMenuRoute.settings => const SettingsPage(),
    _ => const DashboardPage(initialIndex: 0),
  };
}

class _FormSearchDelegate extends SearchDelegate<String?> {
  final WidgetRef ref;
  _FormSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search forms';

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults(context);

  Widget _buildResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Enter a search term.'));
    }
    final repo = ref.read(dashboardRepositoryProvider);
    return FutureBuilder<DashboardData>(
      future: repo.loadDashboard(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final forms = snapshot.data!.forms
            .where((f) =>
                f.title.toLowerCase().contains(query.toLowerCase()) ||
                f.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
        if (forms.isEmpty) {
          return const Center(child: Text('No forms found.'));
        }
        return ListView.builder(
          itemCount: forms.length,
          itemBuilder: (context, i) {
            final form = forms[i];
            return ListTile(
              title: Text(form.title),
              subtitle: Text(form.description),
              onTap: () => close(context, form.id),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard home view with summary widgets
// ---------------------------------------------------------------------------

class DashboardHomeView extends ConsumerWidget {
  const DashboardHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(dashboardPrefsProvider);
    final dashboard = ref.watch(dashboardDataProvider);
    final projects = ref.watch(projectsProvider);
    final tasks = ref.watch(tasksProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardDataProvider);
        await ref.read(dashboardDataProvider.future);
      },
      child: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _wrapDashboardSurface(
          context,
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Dashboard Load Error',
                            style:
                                Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to load dashboard data from database.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error: ${e.toString()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try: pull to refresh, check network, or sign out/in. If you just added the user to an org, restart the app to refresh the session.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(dashboardDataProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data.forms.isEmpty) {
            return _wrapDashboardSurface(
              context,
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No templates yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You are signed in but have no published forms. Add the user to an org and publish templates, or browse the gallery to copy templates.',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reload'),
                                onPressed: () =>
                                    ref.invalidate(dashboardDataProvider),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.view_comfy_alt),
                                label: const Text('Template gallery'),
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TemplateGalleryPage(
                                        forms: data.forms,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final activeProjects = projects.asData?.value.length;
          final openTasks = tasks.asData?.value
              .where((task) => !task.isComplete)
              .length;
          final submissionsLastWeek = _countRecentSubmissions(
            data.submissions,
            days: 7,
          );
          final scheme = Theme.of(context).colorScheme;
          final summaryCards = [
            _StatCardData(
              icon: Icons.folder_open,
              title: 'Active Projects',
              value: _formatCount(activeProjects),
              color: scheme.primary,
              subtitle: 'Active pipelines',
            ),
            _StatCardData(
              icon: Icons.description_outlined,
              title: 'Active Forms',
              value: _formatCount(data.activeForms),
              color: scheme.secondary,
              subtitle: 'Published templates',
            ),
            _StatCardData(
              icon: Icons.check_circle_outline,
              title: 'Open Tasks',
              value: _formatCount(openTasks),
              color: scheme.tertiary,
              subtitle: 'Awaiting review',
            ),
            _StatCardData(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Submissions',
              value: _formatCount(data.completedSubmissions),
              color: scheme.primary,
              subtitle: 'Last 7d: ${_formatCount(submissionsLastWeek)}',
            ),
            _StatCardData(
              icon: Icons.notifications_active_outlined,
              title: 'Alerts',
              value: _formatCount(data.unreadNotifications),
              color: Colors.orange.shade600,
              subtitle: 'Unread alerts',
            ),
          ];
          final filteredCards = prefs.enabledStats
              .where((i) => i >= 0 && i < summaryCards.length)
              .map((i) => summaryCards[i])
              .toList();
          final orderedCards = prefs.statOrder
              .map((i) => i < filteredCards.length ? filteredCards[i] : null)
              .whereType<_StatCardData>()
              .toList();
          final statCards = orderedCards.isEmpty ? filteredCards : orderedCards;
          final latestSubmissions = _latestSubmissions(data.submissions);
          final alerts = _latestAlerts(data.notifications);
          final categorySummary = _categorySummary(data.forms);

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final showSidebar = width >= 1400;
              final showRightRail = width >= 1000;
              final isWide = width >= 900;
              final horizontalPadding = prefs.compactCards ? 16.0 : 20.0;

              final workspacePanel = _buildWorkspacePanel(
                context,
                data,
                activeProjects: activeProjects,
                openTasks: openTasks,
              );
              final quickActions = prefs.showQuickActions
                  ? _buildQuickActions(
                      context,
                      ref,
                      data,
                      compact: prefs.compactCards,
                    )
                  : null;

              final mainColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLatestSubmissionsCard(context, latestSubmissions),
                  const SizedBox(height: 16),
                  _buildProjectHighlightsCard(context, projects),
                  const SizedBox(height: 16),
                  _buildFormsSnapshotCard(
                    context,
                    categorySummary,
                    data.forms,
                  ),
                  if (prefs.showRecentActivity) ...[
                    const SizedBox(height: 16),
                    _buildRecentActivity(
                      context,
                      data,
                      compact: prefs.compactCards,
                    ),
                  ],
                ],
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAlertsCard(context, ref, alerts),
                  const SizedBox(height: 16),
                  _buildTaskPulseCard(context, tasks),
                  const SizedBox(height: 16),
                  _buildAiAssistantCard(context, ref),
                ],
              );

              final sidebarColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  workspacePanel,
                  if (quickActions != null) const SizedBox(height: 16),
                  if (quickActions != null) quickActions,
                ],
              );

              return _wrapDashboardSurface(
                context,
                ListView(
                  padding: EdgeInsets.all(horizontalPadding),
                  children: [
                    _buildCommandBar(
                      context,
                      ref,
                      data,
                      isWide: isWide,
                    ),
                    const SizedBox(height: 16),
                    _buildDashboardHeader(
                      context,
                      ref,
                      data,
                      isWide: isWide,
                    ),
                    const SizedBox(height: 16),
                    if (prefs.showStats)
                      _StatisticsGrid(
                        cards: statCards,
                        compact: prefs.compactCards,
                      ),
                    if (prefs.showStats) const SizedBox(height: 20),
                    if (!showSidebar) ...[
                      workspacePanel,
                      if (quickActions != null) const SizedBox(height: 16),
                      if (quickActions != null) quickActions,
                      const SizedBox(height: 16),
                    ],
                    if (showSidebar)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 260, child: sidebarColumn),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: mainColumn),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: rightColumn),
                        ],
                      )
                    else if (showRightRail)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: mainColumn),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: rightColumn),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          mainColumn,
                          const SizedBox(height: 16),
                          rightColumn,
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _wrapDashboardSurface(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cardTheme = theme.cardTheme.copyWith(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
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
        child: child,
      ),
    );
  }

  Widget _buildDashboardHeader(
    BuildContext context,
    WidgetRef ref,
    DashboardData data, {
    required bool isWide,
  }) {
    final titleStyle = Theme.of(context)
        .textTheme
        .headlineSmall
        ?.copyWith(fontWeight: FontWeight.w700);
    final actions = [
      FilledButton.icon(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateFormPage()),
          );
          ref.invalidate(dashboardDataProvider);
        },
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Create form'),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TemplateGalleryPage(forms: data.forms),
            ),
          );
        },
        icon: const Icon(Icons.view_comfy_alt),
        label: const Text('Templates'),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReportsPage()),
          );
        },
        icon: const Icon(Icons.insights),
        label: const Text('Reports'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User Dashboard', style: titleStyle),
                  const SizedBox(height: 4),
                  Text(
                    'Track submissions, tasks, and compliance performance.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions,
        ),
      ],
    );
  }

  Widget _buildCommandBar(
    BuildContext context,
    WidgetRef ref,
    DashboardData data, {
    required bool isWide,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final searchField = TextField(
      readOnly: true,
      onTap: () {
        showSearch<String?>(
          context: context,
          delegate: _FormSearchDelegate(ref),
        );
      },
      decoration: InputDecoration(
        hintText: 'Search forms, submissions, or people',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: const Icon(Icons.tune),
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
    final navPills = [
      const _DashboardNavPill(label: 'Dashboard', selected: true),
      _DashboardNavPill(
        label: 'Forms',
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TemplateGalleryPage(forms: data.forms),
            ),
          );
        },
      ),
      _DashboardNavPill(
        label: 'Account',
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileView()),
          );
        },
      ),
      _DashboardNavPill(
        label: 'Audit Log',
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReportsPage()),
          );
        },
      ),
    ];
    final actions = [
      _CommandIcon(
        icon: Icons.notifications_none,
        label: 'Alerts',
        count: data.unreadNotifications,
        onTap: () => ref.read(_navToAlertsProvider.notifier).state = true,
      ),
      _CommandIcon(
        icon: Icons.assignment_turned_in_outlined,
        label: 'Entries',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReportsPage()),
        ),
      ),
      PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'preferences':
              await showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                builder: (_) => const _DashboardPrefsSheet(),
              );
              break;
            case 'settings':
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
              break;
            case 'profile':
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileView()),
              );
              break;
            case 'logout':
              await Supabase.instance.client.auth.signOut();
              break;
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'preferences',
            child: ListTile(
              leading: Icon(Icons.tune),
              title: Text('Customize dashboard'),
            ),
          ),
          PopupMenuItem(
            value: 'settings',
            child: ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
            ),
          ),
          PopupMenuItem(
            value: 'profile',
            child: ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
        child: const CircleAvatar(
          radius: 16,
          child: Icon(Icons.person, size: 18),
        ),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
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
            final wide = constraints.maxWidth >= 900 && isWide;
            if (wide) {
              return Row(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          Icons.dashboard_outlined,
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
                        Icons.dashboard_outlined,
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

  List<FormSubmission> _latestSubmissions(List<FormSubmission> submissions) {
    final sorted = [...submissions]
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return sorted.take(6).toList();
  }

  int _countRecentSubmissions(
    List<FormSubmission> submissions, {
    required int days,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return submissions.where((s) => s.submittedAt.isAfter(cutoff)).length;
  }

  List<AppNotification> _latestAlerts(List<AppNotification> notifications) {
    final sorted = [...notifications]
      ..sort((a, b) {
        if (a.isRead != b.isRead) {
          return a.isRead ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    return sorted.take(6).toList();
  }

  Map<String, int> _categorySummary(List<FormDefinition> forms) {
    final summary = <String, int>{};
    for (final form in forms) {
      final category = (form.category ?? 'Other').trim();
      summary[category] = (summary[category] ?? 0) + 1;
    }
    final entries = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in entries) entry.key: entry.value};
  }

  Widget _buildLatestSubmissionsCard(
    BuildContext context,
    List<FormSubmission> submissions,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Latest Submissions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReportsPage()),
                  ),
                  child: const Text('View reports'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (submissions.isEmpty)
              const Text('No submissions yet.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 640;
                  if (isCompact) {
                    return Column(
                      children: submissions.map((submission) {
                        final name =
                            submission.submittedByName ?? submission.submittedBy;
                        final timeLabel =
                            _formatTimeAgo([submission.submittedAt]) ??
                                DateFormat('MMM d').format(submission.submittedAt);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            child: const Icon(Icons.assignment_outlined),
                          ),
                          title: Text(submission.formTitle),
                          subtitle: Text('$name • $timeLabel'),
                          trailing: _StatusPill(
                            label: submission.status.displayName,
                            color: _statusColor(context, submission.status),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SubmissionDetailPage(submission: submission),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  }

                  return Column(
                    children: [
                      _buildSubmissionTableHeader(context),
                      const SizedBox(height: 8),
                      ...submissions.map(
                        (submission) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildSubmissionTableRow(context, submission),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectHighlightsCard(
    BuildContext context,
    AsyncValue<List<Project>> projects,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Active Projects',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProjectsPage()),
                  ),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            projects.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => const Text('Unable to load projects.'),
              data: (items) {
                if (items.isEmpty) {
                  return const Text('No active projects yet.');
                }
                final sorted = [...items]
                  ..sort(
                    (a, b) => (b.updatedAt ?? b.createdAt)
                        .compareTo(a.updatedAt ?? a.createdAt),
                  );
                final preview = sorted.take(4).toList();
                return Column(
                  children: preview.map((project) {
                    final updated = DateFormat('MMM d')
                        .format(project.updatedAt ?? project.createdAt);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: const Icon(Icons.work_outline),
                      ),
                      title: Text(project.name),
                      subtitle: Text(
                        '${project.status.toUpperCase()} • Updated $updated',
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProjectsPage()),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
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
          Expanded(flex: 2, child: Text('Updated', style: headerStyle)),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildSubmissionTableRow(
    BuildContext context,
    FormSubmission submission,
  ) {
    final name = submission.submittedByName ?? submission.submittedBy;
    final timeLabel = _formatTimeAgo([submission.submittedAt]) ??
        DateFormat('MMM d').format(submission.submittedAt);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SubmissionDetailPage(submission: submission),
          ),
        );
      },
      child: Container(
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
              child: Text(
                submission.formTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(flex: 2, child: Text(name)),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusPill(
                  label: submission.status.displayName,
                  color: _statusColor(context, submission.status),
                ),
              ),
            ),
            Expanded(flex: 2, child: Text(timeLabel)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsCard(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> alerts,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Incidents & Alerts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      ref.read(_navToAlertsProvider.notifier).state = true,
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (alerts.isEmpty)
              const Text('No alerts right now.')
            else
              Column(
                children: alerts.map((alert) {
                  final timeLabel =
                      _formatTimeAgo([alert.createdAt]) ?? 'Just now';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: alert.isRead
                          ? Colors.grey.shade200
                          : Theme.of(context)
                              .colorScheme
                              .secondaryContainer,
                      child: Icon(
                        alert.isRead
                            ? Icons.notifications_none
                            : Icons.notifications,
                        color: alert.isRead
                            ? Colors.grey
                            : Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    title: Text(alert.title),
                    subtitle: Text('${alert.body} • $timeLabel'),
                    trailing: alert.isRead
                        ? null
                        : const Icon(Icons.fiber_manual_record, size: 10),
                    onTap: () =>
                        ref.read(_navToAlertsProvider.notifier).state = true,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspacePanel(
    BuildContext context,
    DashboardData data, {
    required int? activeProjects,
    required int? openTasks,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workspace',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _WorkspaceMetricRow(
              icon: Icons.folder_open,
              label: 'Projects',
              value: _formatCount(activeProjects),
              color: scheme.primary,
            ),
            _WorkspaceMetricRow(
              icon: Icons.description_outlined,
              label: 'Forms',
              value: _formatCount(data.activeForms),
              color: scheme.secondary,
            ),
            _WorkspaceMetricRow(
              icon: Icons.checklist,
              label: 'Tasks',
              value: _formatCount(openTasks),
              color: scheme.tertiary,
            ),
            _WorkspaceMetricRow(
              icon: Icons.notifications_active_outlined,
              label: 'Alerts',
              value: _formatCount(data.unreadNotifications),
              color: Colors.orange.shade600,
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProjectsPage()),
                  ),
                  icon: const Icon(Icons.work_outline),
                  label: const Text('Projects'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TasksPage()),
                  ),
                  icon: const Icon(Icons.checklist_outlined),
                  label: const Text('Tasks'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DocumentsPage()),
                  ),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Documents'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AssetsPage()),
                  ),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Assets'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TrainingHubPage()),
                  ),
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Training'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MessagesPage()),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Messaging'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiToolsPage()),
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('AI'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskPulseCard(
    BuildContext context,
    AsyncValue<List<Task>> tasks,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Task Pulse',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TasksPage()),
                  ),
                  child: const Text('View tasks'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            tasks.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => const Text('Unable to load tasks.'),
              data: (items) {
                final openTasks = items.where((task) => !task.isComplete).toList();
                if (openTasks.isEmpty) {
                  return const Text('No active tasks right now.');
                }
                return Column(
                  children: openTasks.take(5).map((task) {
                    final dueLabel = task.dueDate == null
                        ? 'No due date'
                        : DateFormat('MMM d').format(task.dueDate!);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: const Icon(Icons.checklist_outlined),
                      ),
                      title: Text(task.title),
                      subtitle: Text('${task.status.name} • $dueLabel'),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TaskDetailPage(task: task),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAssistantCard(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: 8),
                Text(
                  'AI Assistant',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiToolsPage()),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ask questions, generate summaries, and draft responses for your team.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            const AiChatPanelV2(
              suggestions: [
                'Summarize the latest submissions for my projects.',
                'Draft a daily log from my task list.',
                'What should I follow up on today?',
              ],
              placeholder: 'Ask AI about tasks, forms, or reports...',
              maxHeight: 260,
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
        ),
      ),
    );
  }

  Widget _buildFormsSnapshotCard(
    BuildContext context,
    Map<String, int> categories,
    List<FormDefinition> forms,
  ) {
    final sortedForms = [...forms]
      ..sort((a, b) => (b.updatedAt ?? b.createdAt)
          .compareTo(a.updatedAt ?? a.createdAt));
    final topForms = sortedForms.take(3).toList();
    final entries = categories.entries.take(8).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Form Library Snapshot',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('No form categories yet.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entries
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.key} (${entry.value})'),
                      ),
                    )
                    .toList(),
              ),
            if (topForms.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Recently updated'),
              const SizedBox(height: 6),
              Column(
                children: topForms
                    .map(
                      (form) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(form.title),
                        subtitle: Text(form.category ?? 'General'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FormDetailPage(form: form),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.approved:
        return Colors.green.shade600;
      case SubmissionStatus.rejected:
        return Colors.red.shade400;
      case SubmissionStatus.underReview:
        return Colors.orange.shade600;
      case SubmissionStatus.requiresChanges:
        return Colors.deepOrange.shade400;
      case SubmissionStatus.pendingSync:
        return Colors.blueGrey.shade400;
      case SubmissionStatus.archived:
        return Colors.grey.shade500;
      case SubmissionStatus.draft:
        return Colors.blueGrey.shade300;
      case SubmissionStatus.submitted:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    DashboardData data, {
    required bool compact,
  }) {
    final prefs = ref.watch(dashboardPrefsProvider);
    final allActions =
        <String, (IconData icon, String label, Future<void> Function())>{
          'capture': (
            Icons.add_photo_alternate,
            'Capture Evidence',
            () async {
              if (data.forms.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No forms available yet')),
                );
                return;
              }
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FormFillPage(
                    form: data.forms.first,
                    prefillData: const {'notes': 'Captured evidence'},
                  ),
                ),
              );
              if (!context.mounted) return;
              ref.invalidate(dashboardDataProvider);
            },
          ),
          'scan': (
            Icons.qr_code_scanner,
            'Scan Asset',
            () async {
              if (data.forms.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No forms available yet')),
                );
                return;
              }
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FormFillPage(
                    form: data.forms.first,
                    preferredField: 'assetTag',
                  ),
                ),
              );
              if (!context.mounted) return;
              ref.invalidate(dashboardDataProvider);
            },
          ),
          'start': (
            Icons.description,
            'Start Form',
            () async {
              if (data.forms.isNotEmpty) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormDetailPage(form: data.forms.first),
                  ),
                );
                if (!context.mounted) return;
                ref.invalidate(dashboardDataProvider);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No forms available yet')),
                );
              }
            },
          ),
          'documents': (
            Icons.folder_copy,
            'Documents',
            () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DocumentsPage()),
              );
            },
          ),
          'alerts': (
            Icons.notifications_active,
            'View Alerts',
            () async {
              ref.read(_navToAlertsProvider.notifier).state = true;
            },
          ),
          'tasks': (
            Icons.checklist,
            'View Tasks',
            () async {
              ref.read(_navToTasksProvider.notifier).state = true;
            },
          ),
          'assets': (
            Icons.inventory_2,
            'Assets',
            () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AssetsPage()),
              );
            },
          ),
          'ops': (
            Icons.hub,
            'Ops Hub',
            () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OpsHubPage()),
              );
            },
          ),
          'ai_tools': (
            Icons.auto_awesome,
            'AI Tools',
            () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiToolsPage()),
              );
            },
          ),
          'training': (
            Icons.school,
            'Training Hub',
            () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrainingHubPage()),
              );
            },
          ),
          'reports': (
            Icons.insights,
            'Reports',
            () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportsPage()),
              );
            },
          ),
          'messages': (
            Icons.chat_bubble_outline,
            'Messages',
            () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MessagesPage()),
              );
            },
          ),
          'clients': (
            Icons.business,
            'Clients',
            () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ClientsPage()),
              );
            },
          ),
          'vendors': (
            Icons.handshake,
            'Vendors',
            () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VendorsPage()),
              );
            },
          ),
        };
    final actions = prefs.quickActions
        .where(allActions.containsKey)
        .map((id) => allActions[id]!)
        .toList();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Icon(
                  Icons.tips_and_updates,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            Wrap(
              spacing: compact ? 8 : 12,
              runSpacing: compact ? 8 : 12,
              children: actions
                  .map(
                    (action) => _ActionChip(
                      icon: action.$1,
                      label: action.$2,
                      onTap: action.$3,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(
    BuildContext context,
    DashboardData data, {
    required bool compact,
  }) {
    final sorted = [...data.submissions]
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: compact ? 8 : 16),
            if (sorted.isEmpty)
              const Text('No submissions yet.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorted.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = sorted[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.assignment,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(item.formTitle),
                    subtitle: Text(item.submittedByName ?? item.submittedBy),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SubmissionDetailPage(submission: item),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Secondary tabs
// ---------------------------------------------------------------------------

class FormsListView extends ConsumerStatefulWidget {
  const FormsListView({super.key});

  @override
  ConsumerState<FormsListView> createState() => _FormsListViewState();
}

class _FormsListViewState extends ConsumerState<FormsListView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _categoryFilter;
  String _savedFilter = 'All';

  static const Map<String, String> _savedFilters = {
    'All': 'All',
    'Safety': 'Safety',
    'Operations': 'Operations',
    'Audit': 'Audit',
    'HR': 'HR',
  };

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dashboardDataProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _ErrorView(error: e.toString(), stackTrace: st),
      data: (payload) {
        final categories = <String>{'All'};
        for (final form in payload.forms) {
          categories.add(form.category ?? 'Other');
        }
        final categoriesList = categories.toList()..sort();
        final query = _searchController.text.toLowerCase();
        final filtered = payload.forms.where((form) {
          final matchesQuery =
              query.isEmpty ||
              form.title.toLowerCase().contains(query) ||
              form.description.toLowerCase().contains(query) ||
              (form.tags ?? []).any((t) => t.toLowerCase().contains(query));
          final cat = _categoryFilter ?? 'All';
          final matchesCat = cat == 'All' || (form.category ?? 'Other') == cat;
          final matchesSaved =
              _savedFilter == 'All' || (form.category ?? 'Other') == _savedFilter;
          return matchesQuery && matchesCat && matchesSaved;
        }).toList();

        filtered.sort((a, b) => (b.updatedAt ?? b.createdAt)
            .compareTo(a.updatedAt ?? a.createdAt));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search & Filters',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    RawAutocomplete<String>(
                      textEditingController: _searchController,
                      focusNode: _searchFocusNode,
                      optionsBuilder: (value) {
                        final input = value.text.trim().toLowerCase();
                        if (input.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        final options = payload.forms
                            .map((form) => form.title)
                            .where(
                              (title) => title.toLowerCase().contains(input),
                            );
                        return options.take(8);
                      },
                      onSelected: (selection) {
                        _searchController.text = selection;
                        _searchController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _searchController.text.length),
                        );
                        setState(() {});
                      },
                      fieldViewBuilder: (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Search forms, tags, or templates',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => onFieldSubmitted(),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240),
                              child: ListView(
                                padding: const EdgeInsets.all(8),
                                shrinkWrap: true,
                                children: options.map((option) {
                                  return ListTile(
                                    title: Text(option),
                                    onTap: () => onSelected(option),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Master filters',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _savedFilters.keys.map((key) {
                          final selected = _savedFilter == key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_savedFilters[key]!),
                              selected: selected,
                              onSelected: (_) {
                                setState(() => _savedFilter = key);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Categories',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categoriesList.map((cat) {
                        final selected = _categoryFilter == null
                            ? cat == 'All'
                            : _categoryFilter == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _categoryFilter = cat == 'All' ? null : cat;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No forms match your filters.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Clear filters or open the template gallery to start.'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Clear filters'),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _categoryFilter = null;
                                _savedFilter = 'All';
                              });
                            },
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.view_comfy_alt),
                            label: const Text('Template gallery'),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TemplateGalleryPage(forms: payload.forms),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map((form) {
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.description,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(form.title),
                    subtitle: Text(form.description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FormDetailPage(form: form),
                        ),
                      );
                    },
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  final TextEditingController _searchController = TextEditingController();
  bool _showUnreadOnly = false;
  String _typeFilter = 'All';
  RealtimeChannel? _notificationsChannel;

  static const List<String> _types = [
    'All',
    'alert',
    'task',
    'training',
    'document',
    'info',
  ];

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
  }

  void _subscribeToNotifications() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    _notificationsChannel = client
        .channel('notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            if (!mounted) return;
            ref.invalidate(dashboardDataProvider);
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dashboardDataProvider);
    final repo = ref.read(dashboardRepositoryProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _ErrorView(error: e.toString(), stackTrace: st),
      data: (payload) {
        final query = _searchController.text.toLowerCase();
        final filtered = payload.notifications.where((n) {
          final matchesQuery =
              query.isEmpty ||
              n.title.toLowerCase().contains(query) ||
              n.body.toLowerCase().contains(query);
          final matchesUnread = !_showUnreadOnly || !n.isRead;
          final matchesType = _typeFilter == 'All' || n.type == _typeFilter;
          return matchesQuery && matchesUnread && matchesType;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search notifications',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _types.map((t) {
                final selected = _typeFilter == t;
                return ChoiceChip(
                  label: Text(t),
                  selected: selected,
                  onSelected: (_) => setState(() => _typeFilter = t),
                );
              }).toList(),
            ),
            SwitchListTile(
              title: const Text('Show unread only'),
              value: _showUnreadOnly,
              onChanged: (val) => setState(() => _showUnreadOnly = val),
            ),
            if (filtered.isEmpty)
              const Text('No notifications match your filters.')
            else
              ...filtered.map((notif) {
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: notif.isRead
                          ? Colors.grey.shade200
                          : Colors.orange.shade100,
                      child: Icon(
                        notif.isRead
                            ? Icons.notifications_none
                            : Icons.notifications,
                        color: notif.isRead ? Colors.grey : Colors.orange,
                      ),
                    ),
                    title: Text(notif.title),
                    subtitle: Text(notif.body),
                    trailing: notif.isRead
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.mark_email_read),
                            onPressed: () async {
                              await repo.markNotificationRead(notif.id);
                              ref.invalidate(dashboardDataProvider);
                            },
                          ),
                    onTap: () {},
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfilePage();
  }
}

// ---------------------------------------------------------------------------
// Submission bottom sheet
// ---------------------------------------------------------------------------

class SubmissionSheet extends ConsumerStatefulWidget {
  const SubmissionSheet({required this.forms, super.key});

  final List<FormDefinition> forms;

  @override
  ConsumerState<SubmissionSheet> createState() => _SubmissionSheetState();
}

class _SubmissionSheetState extends ConsumerState<SubmissionSheet> {
  FormDefinition? _selectedForm;
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'New Submission',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FormDefinition>(
            decoration: const InputDecoration(labelText: 'Select form'),
            initialValue: _selectedForm,
            items: widget.forms
                .map((f) => DropdownMenuItem(value: f, child: Text(f.title)))
                .toList(),
            onChanged: (value) => setState(() => _selectedForm = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes / context'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _selectedForm == null
                ? null
                : () {
                    Navigator.pop<Map<String, dynamic>>(context, {
                      'form': _selectedForm!,
                      'prefill': {
                        if (_notesController.text.isNotEmpty)
                          'notes': _notesController.text,
                      },
                    });
                  },
            icon: const Icon(Icons.playlist_add),
            label: const Text('Start Form'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _StatCardData {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final String? subtitle;

  _StatCardData({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.subtitle,
  });
}

class _StatisticsGrid extends StatelessWidget {
  const _StatisticsGrid({required this.cards, this.compact = false});

  final List<_StatCardData> cards;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Compact list row design - no grid, just vertical list of horizontal rows
    return Column(
      children: cards
          .map((card) => _StatRow(
                icon: card.icon,
                title: card.title,
                value: card.value,
                color: card.color,
              ))
          .toList(),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              // Icon with colored background
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              // Title
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                ),
              ),
              // Value
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(width: 8),
              // Chevron
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

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

class _CommandIcon extends StatelessWidget {
  const _CommandIcon({
    required this.icon,
    required this.label,
    this.count,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayCount = (count ?? 0) > 0 ? count! : null;
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                if (displayCount != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        displayCount > 9 ? '9+' : displayCount.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
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

class _DashboardNavPill extends StatelessWidget {
  const _DashboardNavPill({
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

class _WorkspaceMetricRow extends StatelessWidget {
  const _WorkspaceMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async => onTap(),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, this.stackTrace});

  final String error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  const Text('Load failed', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                error,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (stackTrace != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  stackTrace.toString(),
                  maxLines: 5,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontFamily: 'monospace', color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatCount(int? value) {
  if (value == null) return '--';
  return NumberFormat.compact().format(value);
}

String? _formatTimeAgo(Iterable<DateTime> timestamps) {
  if (timestamps.isEmpty) return null;
  final latest = timestamps.reduce((a, b) => a.isAfter(b) ? a : b);
  final diff = DateTime.now().difference(latest);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

const _legacyQuickActions = [
  'capture',
  'scan',
  'start',
  'documents',
  'tasks',
  'assets',
  'ops',
  'training',
  'alerts',
  'reports',
  'messages',
  'clients',
  'vendors',
];

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Dashboard preferences
// ---------------------------------------------------------------------------

class DashboardPreferences {
  const DashboardPreferences({
    this.showStats = true,
    this.showQuickActions = true,
    this.showRecentActivity = true,
    this.compactCards = true,
    this.statOrder = const [0, 1, 2, 3, 4],
    this.enabledStats = const [0, 1, 2, 3, 4],
    this.quickActions = const [
      'capture',
      'scan',
      'start',
      'documents',
      'tasks',
      'assets',
      'ops',
      'ai_tools',
      'training',
      'alerts',
      'reports',
      'messages',
      'clients',
      'vendors',
    ],
  });

  final bool showStats;
  final bool showQuickActions;
  final bool showRecentActivity;
  final bool compactCards;
  final List<int> statOrder;
  final List<int> enabledStats;
  final List<String> quickActions;

  DashboardPreferences copyWith({
    bool? showStats,
    bool? showQuickActions,
    bool? showRecentActivity,
    bool? compactCards,
    List<int>? statOrder,
    List<int>? enabledStats,
    List<String>? quickActions,
  }) {
    return DashboardPreferences(
      showStats: showStats ?? this.showStats,
      showQuickActions: showQuickActions ?? this.showQuickActions,
      showRecentActivity: showRecentActivity ?? this.showRecentActivity,
      compactCards: compactCards ?? this.compactCards,
      statOrder: statOrder ?? this.statOrder,
      enabledStats: enabledStats ?? this.enabledStats,
      quickActions: quickActions ?? this.quickActions,
    );
  }
}

class DashboardPrefsNotifier extends legacy.StateNotifier<DashboardPreferences> {
  DashboardPrefsNotifier() : super(const DashboardPreferences());

  bool _loaded = false;

  void toggleStats(bool value) => state = state.copyWith(showStats: value);
  void toggleQuickActions(bool value) =>
      state = state.copyWith(showQuickActions: value);
  void toggleRecentActivity(bool value) =>
      state = state.copyWith(showRecentActivity: value);
  void toggleCompact(bool value) => state = state.copyWith(compactCards: value);
  void setStatOrder(List<int> order) =>
      state = state.copyWith(statOrder: order);
  void setEnabledStats(List<int> enabled) =>
      state = state.copyWith(enabledStats: enabled);
  void setQuickActions(List<String> actions) =>
      state = state.copyWith(quickActions: actions);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final storedQuickActions = prefs.getStringList('dash.quickActions');
    var mergedQuickActions = storedQuickActions ?? state.quickActions;
    if (storedQuickActions != null &&
        !mergedQuickActions.contains('ai_tools') &&
        _listEquals(storedQuickActions, _legacyQuickActions)) {
      mergedQuickActions = [...storedQuickActions, 'ai_tools'];
    }
    state = DashboardPreferences(
      showStats: prefs.getBool('dash.showStats') ?? state.showStats,
      showQuickActions:
          prefs.getBool('dash.showQuickActions') ?? state.showQuickActions,
      showRecentActivity:
          prefs.getBool('dash.showRecentActivity') ?? state.showRecentActivity,
      compactCards: prefs.getBool('dash.compact') ?? state.compactCards,
      statOrder:
          prefs.getStringList('dash.statOrder')?.map(int.parse).toList() ??
          state.statOrder,
      enabledStats:
          prefs.getStringList('dash.enabledStats')?.map(int.parse).toList() ??
          state.enabledStats,
      quickActions: mergedQuickActions,
    );
    if (!state.statOrder.contains(4)) {
      state = state.copyWith(statOrder: [...state.statOrder, 4]);
    }
    if (!state.enabledStats.contains(4)) {
      state = state.copyWith(enabledStats: [...state.enabledStats, 4]);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dash.showStats', state.showStats);
    await prefs.setBool('dash.showQuickActions', state.showQuickActions);
    await prefs.setBool('dash.showRecentActivity', state.showRecentActivity);
    await prefs.setBool('dash.compact', state.compactCards);
    await prefs.setStringList(
      'dash.statOrder',
      state.statOrder.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(
      'dash.enabledStats',
      state.enabledStats.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList('dash.quickActions', state.quickActions);
  }

  @override
  set state(DashboardPreferences value) {
    super.state = value;
    _persist();
  }
}

class _DashboardPrefsSheet extends ConsumerWidget {
  const _DashboardPrefsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(dashboardPrefsProvider);
    final notifier = ref.read(dashboardPrefsProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Customize dashboard',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SwitchListTile(
              title: const Text('Show stats'),
              value: prefs.showStats,
              onChanged: notifier.toggleStats,
            ),
            SwitchListTile(
              title: const Text('Show quick actions'),
              value: prefs.showQuickActions,
              onChanged: notifier.toggleQuickActions,
            ),
            SwitchListTile(
              title: const Text('Show recent activity'),
              value: prefs.showRecentActivity,
              onChanged: notifier.toggleRecentActivity,
            ),
            SwitchListTile(
              title: const Text('Compact layout'),
              value: prefs.compactCards,
              onChanged: notifier.toggleCompact,
            ),
            const Divider(),
            Text('My KPIs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(5, (i) {
                final labels = [
                  'Active Projects',
                  'Active Forms',
                  'Open Tasks',
                  'Submissions',
                  'Alerts',
                ];
                final enabled = prefs.enabledStats.contains(i);
                return FilterChip(
                  label: Text(labels[i]),
                  selected: enabled,
                  onSelected: (val) {
                    final next = [...prefs.enabledStats];
                    if (val) {
                      if (!next.contains(i)) next.add(i);
                    } else {
                      next.remove(i);
                    }
                    notifier.setEnabledStats(next);
                  },
                );
              }),
            ),
            const SizedBox(height: 12),
            Text(
              'Reorder KPIs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                final order = [...prefs.statOrder];
                if (newIndex > oldIndex) newIndex -= 1;
                final item = order.removeAt(oldIndex);
                order.insert(newIndex, item);
                notifier.setStatOrder(order);
              },
              children: prefs.statOrder
                  .map(
                    (i) => ListTile(
                      key: ValueKey('stat-$i'),
                      title: Text('Slot ${i + 1}'),
                      trailing: const Icon(Icons.drag_handle),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Divider(),
            Text(
              'Quick actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                    ('capture', 'Capture'),
                    ('scan', 'Scan'),
                    ('start', 'Start Form'),
                    ('documents', 'Documents'),
                    ('tasks', 'Tasks'),
                    ('assets', 'Assets'),
                    ('ops', 'Ops Hub'),
                    ('ai_tools', 'AI Tools'),
                    ('training', 'Training'),
                    ('alerts', 'Alerts'),
                    ('reports', 'Reports'),
                    ('messages', 'Messages'),
                    ('clients', 'Clients'),
                    ('vendors', 'Vendors'),
                  ].map((item) {
                    final enabled = prefs.quickActions.contains(item.$1);
                    return FilterChip(
                      label: Text(item.$2),
                      selected: enabled,
                      onSelected: (val) {
                        final next = [...prefs.quickActions];
                        if (val) {
                          if (!next.contains(item.$1)) next.add(item.$1);
                        } else {
                          next.remove(item.$1);
                        }
                        notifier.setQuickActions(next);
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 8),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                final list = [...prefs.quickActions];
                if (newIndex > oldIndex) newIndex -= 1;
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
                notifier.setQuickActions(list);
              },
              children: prefs.quickActions
                  .map(
                    (id) => ListTile(
                      key: ValueKey('qa-$id'),
                      title: Text(id),
                      trailing: const Icon(Icons.drag_handle),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preferences are local to this device for now.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
