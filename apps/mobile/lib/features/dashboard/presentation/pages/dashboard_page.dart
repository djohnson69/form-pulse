import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
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
import 'submission_detail_page.dart';
import 'template_gallery_page.dart';
import 'reports_page.dart';

final _navToAlertsProvider = legacy.StateProvider<bool>((ref) => false);
final _navToTasksProvider = legacy.StateProvider<bool>((ref) => false);
final dashboardPrefsProvider =
    legacy.StateNotifierProvider<DashboardPrefsNotifier, DashboardPreferences>(
      (ref) => DashboardPrefsNotifier(),
    );

/// Main dashboard container that holds the bottom navigation experience.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _currentIndex = 0;
  ProviderSubscription<bool>? _navSubscription;
  ProviderSubscription<bool>? _taskNavSubscription;
  PendingSubmissionQueue? _pendingQueue;
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
    ref.read(dashboardPrefsProvider.notifier).ensureLoaded();
    final supabaseClient = Supabase.instance.client;
    _pendingQueue = PendingSubmissionQueue(
      ref.read(dashboardRepositoryProvider),
      supabaseClient,
      bucketName: _supabaseBucket,
    );
    // Attempt to flush any pending offline submissions.
    _pendingQueue?.flush();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Bridge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Customize dashboard',
            onPressed: _openPrefsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.view_comfy_alt),
            tooltip: 'Templates',
            onPressed: () async {
              final data = await ref.read(dashboardDataProvider.future);
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TemplateGalleryPage(forms: data.forms),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Reports',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Create form',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateFormPage()),
              );
              if (!mounted) return;
              ref.invalidate(dashboardDataProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search forms',
            onPressed: () async {
              await showSearch<String?>(
                context: context,
                delegate: _FormSearchDelegate(ref),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                  break;
                case 'profile':
                  setState(() => _currentIndex = 5);
                  break;
                case 'logout':
                  Supabase.instance.client.auth.signOut();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
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

  Future<void> _openPrefsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => const _DashboardPrefsSheet(),
    );
    if (!mounted) return;
    setState(() {});
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardDataProvider);
        await ref.read(dashboardDataProvider.future);
      },
      child: dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ListView(
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
        data: (data) {
          if (data.forms.isEmpty) {
            return ListView(
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                              onPressed: () => ref.invalidate(dashboardDataProvider),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.view_comfy_alt),
                              label: const Text('Template gallery'),
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TemplateGalleryPage(forms: data.forms),
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
            );
          }
          final summaryCards = [
            _StatCardData(
              icon: Icons.assignment,
              title: 'Active Forms',
              value: data.activeForms.toString(),
              color: Colors.blue,
            ),
            _StatCardData(
              icon: Icons.check_circle,
              title: 'Submissions',
              value: data.completedSubmissions.toString(),
              color: Colors.green,
            ),
            _StatCardData(
              icon: Icons.notifications_active,
              title: 'Unread Alerts',
              value: data.unreadNotifications.toString(),
              color: Colors.orange,
            ),
            _StatCardData(
              icon: Icons.schedule,
              title: 'Latest Sync',
              value:
                  _formatTimeAgo(data.submissions.map((s) => s.submittedAt)) ??
                  'N/A',
              color: Colors.purple,
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

          final horizontalPadding = prefs.compactCards ? 12.0 : 16.0;
          return ListView(
            padding: EdgeInsets.all(horizontalPadding),
            children: [
              if (prefs.showStats)
                _StatisticsGrid(
                  cards: orderedCards.isEmpty ? filteredCards : orderedCards,
                  compact: prefs.compactCards,
                ),
              if (prefs.showStats) const SizedBox(height: 24),
              if (prefs.showQuickActions)
                _buildQuickActions(
                  context,
                  ref,
                  data,
                  compact: prefs.compactCards,
                ),
              if (prefs.showQuickActions) const SizedBox(height: 24),
              if (prefs.showRecentActivity)
                _buildRecentActivity(
                  context,
                  data,
                  compact: prefs.compactCards,
                ),
            ],
          );
        },
      ),
    );
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
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search forms',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final selected =
                    _categoryFilter == null ? cat == 'All' : _categoryFilter == cat;
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
    _searchController.dispose();
    super.dispose();
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'John Doe',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'john.doe@formpulse.com',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Chip(
                label: Text('Manager'),
                avatar: Icon(Icons.badge, size: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_copy),
            title: const Text('Documents'),
            subtitle: const Text('Manage SOPs, templates, and files'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DocumentsPage()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.school),
            title: const Text('Training Hub'),
            subtitle: const Text('View certifications and compliance'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrainingHubPage()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Assets'),
            subtitle: const Text('Track equipment inspections and incidents'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AssetsPage()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.hub),
            title: const Text('Operations Hub'),
            subtitle: const Text('Automation, AI, exports, and marketing'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OpsHubPage()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Messages'),
            subtitle: const Text('Communicate with clients and vendors'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MessagesPage()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Clients'),
            subtitle: const Text('Manage client contacts and portals'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ClientsPage()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.handshake),
            title: const Text('Vendors'),
            subtitle: const Text('Manage vendor contacts and access'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VendorsPage()),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
        Card(
          child: Column(
            children: [
              _ProfileTile(
                icon: Icons.person,
                text: 'Edit Profile',
                message: 'Edit profile coming soon',
              ),
              const Divider(height: 1),
              _ProfileTile(
                icon: Icons.notifications,
                text: 'Notifications',
                message: 'Notification settings coming soon',
              ),
              const Divider(height: 1),
              _ProfileTile(
                icon: Icons.security,
                text: 'Security',
                message: 'Security settings coming soon',
              ),
              const Divider(height: 1),
              _ProfileTile(
                icon: Icons.help,
                text: 'Help & Support',
                message: 'Help coming soon',
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Form Bridge',
                    applicationVersion: '2.0.0',
                    applicationIcon: const Icon(
                      Icons.assignment_turned_in,
                      size: 48,
                    ),
                    children: const [
                      Text('Intelligent Form Management Platform'),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => Supabase.instance.client.auth.signOut(),
          ),
        ),
      ],
    );
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

  _StatCardData({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
}

class _StatisticsGrid extends StatelessWidget {
  const _StatisticsGrid({required this.cards, this.compact = false});

  final List<_StatCardData> cards;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 2;
        if (width > 1100) {
          crossAxisCount = 4;
        } else if (width > 800) {
          crossAxisCount = 3;
        } else if (compact && width > 600) {
          crossAxisCount = 3;
        }
        final spacing = compact ? 10.0 : 14.0;
        final aspect = compact ? 1.25 : 1.35;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: aspect,
          children: cards
              .map(
                (card) => _StatCard(
                  icon: card.icon,
                  title: card.title,
                  value: card.value,
                  color: card.color,
                  compact: compact,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final bool compact;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: compact ? 8 : 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
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

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final String message;

  const _ProfileTile({
    required this.icon,
    required this.text,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
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

String? _formatTimeAgo(Iterable<DateTime> timestamps) {
  if (timestamps.isEmpty) return null;
  final latest = timestamps.reduce((a, b) => a.isAfter(b) ? a : b);
  final diff = DateTime.now().difference(latest);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
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
    this.statOrder = const [0, 1, 2, 3],
    this.enabledStats = const [0, 1, 2, 3],
    this.quickActions = const [
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
      quickActions:
          prefs.getStringList('dash.quickActions') ?? state.quickActions,
    );
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
              children: List.generate(4, (i) {
                final labels = [
                  'Active Forms',
                  'Submissions',
                  'Unread',
                  'Latest',
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
