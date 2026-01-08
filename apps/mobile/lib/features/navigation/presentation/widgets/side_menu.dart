import 'package:flutter/material.dart';
import 'package:shared/shared.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart';

const double _sideMenuWidth = 256;

enum SideMenuRoute {
  dashboard,
  notifications,
  messages,
  companyNews,
  organizationChart,
  team,
  organization,
  tasks,
  forms,
  approvals,
  documents,
  photos,
  beforeAfter,
  assets,
  qrScanner,
  training,
  incidents,
  aiTools,
  timecards,
  reports,
  settings,
  projects,
  workOrders,
  templates,
  payments,
  payroll,
  auditLogs,
  rolesPermissions,
  systemOverview,
  supportTickets,
  knowledgeBase,
  systemLogs,
  users,
}

class SideMenuItem {
  const SideMenuItem({
    required this.route,
    required this.label,
    required this.icon,
  });

  final SideMenuRoute route;
  final String label;
  final IconData icon;
}

List<SideMenuItem> sideMenuItemsForRole(UserRole role) {
  const common = [
    SideMenuItem(
      route: SideMenuRoute.dashboard,
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
    ),
    SideMenuItem(
      route: SideMenuRoute.notifications,
      label: 'Notifications',
      icon: Icons.notifications_outlined,
    ),
    SideMenuItem(
      route: SideMenuRoute.messages,
      label: 'Messages',
      icon: Icons.chat_bubble_outline,
    ),
    SideMenuItem(
      route: SideMenuRoute.companyNews,
      label: 'Company News',
      icon: Icons.campaign_outlined,
    ),
  ];

  switch (role) {
    case UserRole.employee:
      return [
        ...common,
        const SideMenuItem(
          route: SideMenuRoute.organizationChart,
          label: 'Organization Chart',
          icon: Icons.account_tree_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.tasks,
          label: 'Tasks',
          icon: Icons.checklist_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.forms,
          label: 'Forms',
          icon: Icons.description_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.documents,
          label: 'Documents',
          icon: Icons.folder_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.photos,
          label: 'Photos & Videos',
          icon: Icons.photo_library_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.beforeAfter,
          label: 'Before/After Photos',
          icon: Icons.compare_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.assets,
          label: 'My Assets',
          icon: Icons.inventory_2_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.qrScanner,
          label: 'QR Scanner',
          icon: Icons.qr_code_scanner_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.training,
          label: 'Training',
          icon: Icons.school_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.incidents,
          label: 'Incidents',
          icon: Icons.report_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.aiTools,
          label: 'AI Tools',
          icon: Icons.auto_awesome_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.timecards,
          label: 'Timecards',
          icon: Icons.schedule_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.settings,
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
      ];
    case UserRole.supervisor:
      return [
        ...common,
        const SideMenuItem(
          route: SideMenuRoute.organizationChart,
          label: 'Organization Chart',
          icon: Icons.account_tree_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.team,
          label: 'My Team',
          icon: Icons.groups_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.tasks,
          label: 'Tasks',
          icon: Icons.checklist_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.forms,
          label: 'Forms',
          icon: Icons.description_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.approvals,
          label: 'Approvals',
          icon: Icons.verified_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.documents,
          label: 'Documents',
          icon: Icons.folder_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.photos,
          label: 'Photos & Videos',
          icon: Icons.photo_library_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.beforeAfter,
          label: 'Before/After Photos',
          icon: Icons.compare_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.assets,
          label: 'Assets',
          icon: Icons.inventory_2_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.qrScanner,
          label: 'QR Scanner',
          icon: Icons.qr_code_scanner_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.training,
          label: 'Training',
          icon: Icons.school_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.incidents,
          label: 'Incidents',
          icon: Icons.report_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.aiTools,
          label: 'AI Tools',
          icon: Icons.auto_awesome_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.timecards,
          label: 'Timecards',
          icon: Icons.schedule_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.reports,
          label: 'Reports',
          icon: Icons.bar_chart_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.settings,
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
      ];
    case UserRole.manager:
      return [
        ...common,
        const SideMenuItem(
          route: SideMenuRoute.organizationChart,
          label: 'Organization Chart',
          icon: Icons.account_tree_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.organization,
          label: 'Organization',
          icon: Icons.apartment_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.projects,
          label: 'Projects',
          icon: Icons.work_outline,
        ),
        const SideMenuItem(
          route: SideMenuRoute.tasks,
          label: 'Tasks',
          icon: Icons.checklist_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.workOrders,
          label: 'Work Orders',
          icon: Icons.build_circle_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.forms,
          label: 'Forms',
          icon: Icons.description_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.approvals,
          label: 'Approvals',
          icon: Icons.verified_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.templates,
          label: 'Templates',
          icon: Icons.view_quilt_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.documents,
          label: 'Documents',
          icon: Icons.folder_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.photos,
          label: 'Photos & Videos',
          icon: Icons.photo_library_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.beforeAfter,
          label: 'Before/After Photos',
          icon: Icons.compare_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.assets,
          label: 'Assets',
          icon: Icons.inventory_2_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.training,
          label: 'Training',
          icon: Icons.school_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.aiTools,
          label: 'AI Tools',
          icon: Icons.auto_awesome_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.payments,
          label: 'Payment Requests',
          icon: Icons.payments_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.timecards,
          label: 'Timecards',
          icon: Icons.schedule_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.reports,
          label: 'Reports',
          icon: Icons.bar_chart_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.settings,
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
      ];
    case UserRole.maintenance:
      return [
        ...common,
        const SideMenuItem(
          route: SideMenuRoute.organizationChart,
          label: 'Organization Chart',
          icon: Icons.account_tree_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.workOrders,
          label: 'Work Orders',
          icon: Icons.build_circle_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.assets,
          label: 'Equipment',
          icon: Icons.inventory_2_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.qrScanner,
          label: 'QR Scanner',
          icon: Icons.qr_code_scanner_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.incidents,
          label: 'Incidents',
          icon: Icons.report_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.documents,
          label: 'Documents',
          icon: Icons.folder_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.photos,
          label: 'Photos & Videos',
          icon: Icons.photo_library_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.beforeAfter,
          label: 'Before/After Photos',
          icon: Icons.compare_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.training,
          label: 'Training',
          icon: Icons.school_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.aiTools,
          label: 'AI Tools',
          icon: Icons.auto_awesome_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.settings,
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
      ];
    case UserRole.admin:
      return [
        ...common,
        const SideMenuItem(
          route: SideMenuRoute.organizationChart,
          label: 'Organization Chart',
          icon: Icons.account_tree_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.users,
          label: 'User Management',
          icon: Icons.groups_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.rolesPermissions,
          label: 'Roles & Permissions',
          icon: Icons.security_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.tasks,
          label: 'Tasks',
          icon: Icons.checklist_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.workOrders,
          label: 'Work Orders',
          icon: Icons.build_circle_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.forms,
          label: 'Forms',
          icon: Icons.description_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.approvals,
          label: 'Approvals',
          icon: Icons.verified_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.templates,
          label: 'Templates',
          icon: Icons.view_quilt_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.documents,
          label: 'Documents',
          icon: Icons.folder_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.photos,
          label: 'Photos & Videos',
          icon: Icons.photo_library_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.beforeAfter,
          label: 'Before/After Photos',
          icon: Icons.compare_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.training,
          label: 'Training',
          icon: Icons.school_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.aiTools,
          label: 'AI Tools',
          icon: Icons.auto_awesome_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.payments,
          label: 'Payments',
          icon: Icons.payments_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.payroll,
          label: 'Payroll',
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.reports,
          label: 'Reports',
          icon: Icons.bar_chart_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.auditLogs,
          label: 'Audit Logs',
          icon: Icons.fact_check_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.settings,
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
      ];
    case UserRole.techSupport:
      return [
        ...common,
        const SideMenuItem(
          route: SideMenuRoute.organizationChart,
          label: 'Organization Chart',
          icon: Icons.account_tree_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.supportTickets,
          label: 'Support Tickets',
          icon: Icons.support_agent_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.users,
          label: 'Users',
          icon: Icons.groups_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.documents,
          label: 'Documents',
          icon: Icons.folder_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.photos,
          label: 'Photos & Videos',
          icon: Icons.photo_library_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.beforeAfter,
          label: 'Before/After Photos',
          icon: Icons.compare_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.training,
          label: 'Training',
          icon: Icons.school_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.knowledgeBase,
          label: 'Knowledge Base',
          icon: Icons.menu_book_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.systemLogs,
          label: 'System Logs',
          icon: Icons.storage_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.settings,
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
      ];
    case UserRole.superAdmin:
      return [
        ...common,
        const SideMenuItem(
          route: SideMenuRoute.organizationChart,
          label: 'Organization Chart',
          icon: Icons.account_tree_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.systemOverview,
          label: 'System Overview',
          icon: Icons.storage_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.users,
          label: 'Users',
          icon: Icons.groups_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.rolesPermissions,
          label: 'Roles & Permissions',
          icon: Icons.security_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.projects,
          label: 'Projects',
          icon: Icons.work_outline,
        ),
        const SideMenuItem(
          route: SideMenuRoute.tasks,
          label: 'Tasks',
          icon: Icons.checklist_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.workOrders,
          label: 'Work Orders',
          icon: Icons.build_circle_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.forms,
          label: 'Forms',
          icon: Icons.description_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.documents,
          label: 'Documents',
          icon: Icons.folder_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.photos,
          label: 'Photos & Videos',
          icon: Icons.photo_library_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.beforeAfter,
          label: 'Before/After Photos',
          icon: Icons.compare_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.assets,
          label: 'Assets',
          icon: Icons.inventory_2_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.training,
          label: 'Training',
          icon: Icons.school_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.incidents,
          label: 'Incidents',
          icon: Icons.report_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.aiTools,
          label: 'AI Tools',
          icon: Icons.auto_awesome_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.approvals,
          label: 'Approvals',
          icon: Icons.verified_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.templates,
          label: 'Templates',
          icon: Icons.view_quilt_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.payments,
          label: 'Payments',
          icon: Icons.payments_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.payroll,
          label: 'Payroll',
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.reports,
          label: 'Reports',
          icon: Icons.bar_chart_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.auditLogs,
          label: 'Audit Logs',
          icon: Icons.fact_check_outlined,
        ),
        const SideMenuItem(
          route: SideMenuRoute.settings,
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
      ];
    case UserRole.client:
    case UserRole.vendor:
    case UserRole.viewer:
      return common;
  }
}

class SideMenu extends StatefulWidget {
  const SideMenu({
    super.key,
    required this.role,
    required this.onNavigate,
    this.activeRoute,
    this.onClose,
    this.isMobile = false,
  });

  final UserRole role;
  final SideMenuRoute? activeRoute;
  final ValueChanged<SideMenuRoute> onNavigate;
  final VoidCallback? onClose;
  final bool isMobile;

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = sideMenuItemsForRole(widget.role);
    final query = _query.toLowerCase();
    final filtered = query.isEmpty
        ? items
        : items
            .where((item) => item.label.toLowerCase().contains(query))
            .toList();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final selectedBg = isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final searchBg = isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);
    final searchBorder = isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = _displayName(user);
    final initials = _initials(displayName);
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: _sideMenuWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border(
            right: BorderSide(color: border),
          ),
        ),
        child: Column(
          children: [
            if (widget.isMobile)
              _MobileHeader(
                onClose: widget.onClose,
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                widget.isMobile ? 12 : 20,
                16,
                12,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search, color: muted),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close, color: muted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: searchBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: searchBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: searchBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final selected = item.route == widget.activeRoute;
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      widget.onNavigate(item.route);
                      widget.onClose?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? selectedBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: selected ? textPrimary : textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: selected ? textPrimary : textSecondary,
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF60A5FA),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.role.displayName} Role',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: border, height: 1),
            InkWell(
              onTap: () {
                widget.onNavigate(SideMenuRoute.settings);
                widget.onClose?.call();
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.role.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _displayName(User? user) {
    final metaName = user?.userMetadata?['name']?.toString();
    final email = user?.email ?? 'User';
    if (metaName != null && metaName.trim().isNotEmpty) {
      return metaName.trim();
    }
    return email.split('@').first;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      final first = parts.first;
      if (first.isEmpty) return 'U';
      return first.length == 1
          ? first.toUpperCase()
          : first.substring(0, 2).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 32),
            Expanded(
              child: Text(
                'Menu',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              tooltip: 'Close menu',
            ),
          ],
        ),
      ),
    );
  }
}
