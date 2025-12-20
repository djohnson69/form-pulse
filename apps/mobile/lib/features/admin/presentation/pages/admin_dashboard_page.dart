import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../ops/presentation/pages/project_galleries_page.dart';
import '../../../ops/presentation/pages/reviews_page.dart';
import '../../../ops/presentation/pages/signature_requests_page.dart';
import '../../../partners/presentation/pages/clients_page.dart';
import '../../../partners/presentation/pages/messages_page.dart';
import '../../../partners/presentation/pages/vendors_page.dart';
import '../../../projects/presentation/pages/projects_page.dart';
import '../../../tasks/presentation/pages/tasks_page.dart';
import '../../../training/presentation/pages/training_hub_page.dart';
import '../../data/admin_models.dart';
import '../../data/admin_providers.dart';

final _dateFmt = DateFormat('MMM d, h:mm a');
final _shortDateFmt = DateFormat('MMM d, yyyy');

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key, required this.userRole});

  final UserRole userRole;

  @override
  ConsumerState<AdminDashboardPage> createState() =>
      _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _sectionIndex = 0;
  late final ProviderSubscription<AsyncValue<List<AdminOrgSummary>>> _orgListener;

  @override
  void initState() {
    super.initState();
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

    final sections = <_AdminSection>[
      if (permissions.canViewOverview)
        _AdminSection(
          id: 'overview',
          label: 'Overview',
          icon: Icons.dashboard,
          builder: (context, ref) =>
              _OverviewSection(permissions: permissions),
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

    if (_sectionIndex >= sections.length) {
      _sectionIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 1024;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Console'),
            actions: [
              if (showOrgSwitcher)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _OrgSwitcher(compact: true),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  label: Text(widget.userRole.displayName),
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                ),
              ),
            ],
          ),
          body: Row(
            children: [
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
  const _OverviewSection({required this.permissions});

  final _AdminPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final orgs = ref.watch(adminOrganizationsProvider);
    final activeOrgId = ref.watch(adminActiveOrgIdProvider);
    final orgList = orgs.asData?.value ?? const <AdminOrgSummary>[];
    AdminOrgSummary? activeOrg;
    if (orgList.isNotEmpty) {
      activeOrg = orgList.firstWhere(
        (org) => org.id == activeOrgId,
        orElse: () => orgList.first,
      );
    }

    return _SectionShell(
      title: 'Overview',
      subtitle: activeOrg == null
          ? 'No organization selected'
          : 'Active org: ${activeOrg.name}',
      children: [
        if (permissions.canSwitchOrg)
          Row(
            children: const [
              Icon(Icons.swap_horiz, size: 18),
              SizedBox(width: 8),
              Text('Switch organizations using the selector above.'),
            ],
          ),
        if (permissions.canSwitchOrg) const SizedBox(height: 12),
        stats.when(
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatsGrid(stats: data),
              const SizedBox(height: 16),
              _OverviewHighlights(stats: data),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorTile(
            message: 'Failed to load overview stats',
            onRetry: () => ref.invalidate(adminStatsProvider),
          ),
        ),
      ],
    );
  }
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
                        trailing: permissions.canManageUsers &&
                                roleOptions.contains(user.role)
                            ? DropdownButton<UserRole>(
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
          error: (_, __) => const SizedBox.shrink(),
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

    return _SectionShell(
      title: 'Submissions',
      subtitle: permissions.canManageSubmissions
          ? 'Review recent submissions and drill into details.'
          : 'View recent submissions for the active organization.',
      children: [
        Row(
          children: [
            DropdownButton<String?>(
              value: status,
              hint: const Text('Status'),
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
            const Spacer(),
            TextButton.icon(
              onPressed: () => ref.invalidate(adminSubmissionsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            )
          ],
        ),
        const SizedBox(height: 12),
        submissions.when(
          data: (data) => _SubmissionsList(
            submissions: data,
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
          ),
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
                  MaterialPageRoute(builder: (_) => const ProjectGalleriesPage()),
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

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.card});

  final _MetricCardData card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: card.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(card.icon),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  card.value.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
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
        DropdownButton<String>(
          hint: const Text('Category'),
          value: category.isEmpty ? null : category,
          items: forms.when(
            data: (data) {
              final set = <String>{};
              for (final f in data) {
                if (f.category != null && f.category!.isNotEmpty) {
                  set.add(f.category!);
                }
              }
              final list = set.toList()..sort();
              return [
                const DropdownMenuItem(value: '', child: Text('All')),
                ...list.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ];
            },
            loading: () => [
              const DropdownMenuItem(value: '', child: Text('Loading...'))
            ],
            error: (_, _) => [
              const DropdownMenuItem(value: '', child: Text('Error'))
            ],
          ),
          onChanged: (val) => onChanged(search, val ?? '', published),
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
              (s) => ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      _statusColor(context, s.status).withValues(alpha: 0.1),
                  child: Icon(Icons.description, color: _statusColor(context, s.status)),
                ),
                title: Text(s.formId),
                subtitle: Text(
                  '${s.status.toUpperCase()} • ${_dateFmt.format(s.submittedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
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
                onTap: () => onTap(s),
              ),
            )
            .toList(),
      ),
    );
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
        UserRole.client,
        UserRole.vendor,
        UserRole.viewer,
      ];
    case UserRole.manager:
      return const [
        UserRole.manager,
        UserRole.supervisor,
        UserRole.employee,
        UserRole.client,
        UserRole.vendor,
        UserRole.viewer,
      ];
    case UserRole.supervisor:
      return const [
        UserRole.supervisor,
        UserRole.employee,
        UserRole.viewer,
      ];
    case UserRole.employee:
    case UserRole.client:
    case UserRole.vendor:
    case UserRole.viewer:
      return const [];
  }
}
