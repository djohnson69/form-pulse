import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../admin/data/admin_models.dart';
import '../../../admin/data/admin_providers.dart';

class AuditLogsPage extends ConsumerStatefulWidget {
  const AuditLogsPage({super.key});

  @override
  ConsumerState<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends ConsumerState<AuditLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(adminAuditProvider);
    final auditEvents = auditAsync.asData?.value ?? const <AdminAuditEvent>[];
    final logs = _logsFromAudit(auditEvents);
    final filteredLogs = _filterLogs(logs);
    final stats = _AuditStats.fromLogs(logs);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final surface = isDark ? const Color(0xFF1F2937) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auditAsync.isLoading) const LinearProgressIndicator(),
          if (auditAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ErrorBanner(message: auditAsync.error.toString()),
            ),
          _Header(
            muted: muted,
            onExport: () {},
          ),
          const SizedBox(height: 16),
          _StatsGrid(stats: stats),
          const SizedBox(height: 16),
          _FiltersCard(
            selectedFilter: _selectedFilter,
            searchController: _searchController,
            onFilterChanged: (value) => setState(() => _selectedFilter = value),
            onSearchChanged: (value) =>
                setState(() => _searchTerm = value.trim()),
            surface: surface,
            border: border,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _LogsTable(
            logs: filteredLogs,
            surface: surface,
            border: border,
            muted: muted,
            isDark: isDark,
          ),
          if (filteredLogs.isEmpty) ...[
            const SizedBox(height: 12),
            _EmptyState(muted: muted),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<_AuditLogEntry> _filterLogs(List<_AuditLogEntry> logs) {
    final term = _searchTerm.toLowerCase();
    return logs.where((log) {
      final matchesSearch = term.isEmpty ||
          log.action.toLowerCase().contains(term) ||
          log.user.toLowerCase().contains(term) ||
          log.details.toLowerCase().contains(term);
      final matchesFilter =
          _selectedFilter == 'all' || log.category == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  List<_AuditLogEntry> _logsFromAudit(List<AdminAuditEvent> events) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return events.map((event) {
      final payload = event.payload ?? const <String, dynamic>{};
      final category = _categoryForEvent(event);
      final actorName = payload['actor_name']?.toString() ??
          payload['user_name']?.toString() ??
          event.actorId ??
          'System';
      final actorEmail = payload['actor_email']?.toString() ??
          payload['user_email']?.toString() ??
          'system@company.com';
      final details = payload['details']?.toString() ??
          payload['message']?.toString() ??
          '${event.action} on ${event.resourceType}';
      final ipAddress =
          payload['ip_address']?.toString() ?? payload['ip']?.toString() ?? '';
      return _AuditLogEntry(
        id: event.id.toString(),
        timestamp: formatter.format(event.createdAt),
        user: actorName,
        userEmail: actorEmail,
        action: event.action,
        category: category,
        details: details,
        ipAddress: ipAddress.isEmpty ? '192.168.1.100' : ipAddress,
      );
    }).toList();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.muted, required this.onExport});

  final Color muted;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audit Logs',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Track all administrative actions and system changes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: muted,
                  ),
            ),
          ],
        );
        final button = ElevatedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Export Report'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 3,
            shadowColor: const Color(0x332563EB),
          ),
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: text),
              const SizedBox(width: 16),
              button,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: button),
          ],
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final _AuditStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final aspectRatio = columns == 2 ? 1.25 : 1.1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: [
            _StatCard(
              label: 'Total Events',
              value: stats.total.toString(),
              icon: Icons.description_outlined,
              accent: const Color(0xFF3B82F6),
            ),
            _StatCard(
              label: 'User Actions',
              value: stats.user.toString(),
              icon: Icons.person_outline,
              accent: const Color(0xFF8B5CF6),
            ),
            _StatCard(
              label: 'Security Events',
              value: stats.security.toString(),
              icon: Icons.shield_outlined,
              accent: const Color(0xFFEF4444),
            ),
            _StatCard(
              label: 'System Events',
              value: stats.system.toString(),
              icon: Icons.storage_outlined,
              accent: const Color(0xFF22C55E),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1F2937) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.9),
                  accent.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
          ),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.selectedFilter,
    required this.searchController,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.surface,
    required this.border,
    required this.isDark,
  });

  final String selectedFilter;
  final TextEditingController searchController;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final Color surface;
  final Color border;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final filters = ['all', 'user', 'security', 'forms', 'settings', 'system'];
    final searchDecoration = InputDecoration(
      hintText: 'Search audit logs...',
      prefixIcon: Icon(Icons.search, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
      filled: true,
      fillColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF2563EB),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

    final filterButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final selected = selectedFilter == filter;
        final label =
            filter.substring(0, 1).toUpperCase() + filter.substring(1);
        return TextButton(
          onPressed: () => onFilterChanged(filter),
          style: TextButton.styleFrom(
            backgroundColor: selected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6)),
            foregroundColor:
                selected ? Colors.white : (isDark ? Colors.white : const Color(0xFF374151)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
    );

    final searchField = TextField(
      controller: searchController,
      decoration: searchDecoration,
      onChanged: onSearchChanged,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: filterButtons),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: searchField),
              ],
            );
          }
          return Column(
            children: [
              filterButtons,
              const SizedBox(height: 12),
              searchField,
            ],
          );
        },
      ),
    );
  }
}

class _LogsTable extends StatelessWidget {
  const _LogsTable({
    required this.logs,
    required this.surface,
    required this.border,
    required this.muted,
    required this.isDark,
  });

  final List<_AuditLogEntry> logs;
  final Color surface;
  final Color border;
  final Color muted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          headingRowColor: MaterialStateProperty.all(
            isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
          ),
          columns: const [
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('Details')),
            DataColumn(label: Text('IP Address')),
          ],
          rows: logs.map((log) {
            final style = _categoryStyle(log.category);
            return DataRow(
              cells: [
                DataCell(Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: muted),
                    const SizedBox(width: 6),
                    Text(
                      log.timestamp,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: isDark
                            ? const Color(0xFFD1D5DB)
                            : const Color(0xFF374151),
                      ),
                    ),
                  ],
                )),
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      log.user,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      log.userEmail,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  ],
                )),
                DataCell(Row(
                  children: [
                    Icon(style.icon, size: 16, color: style.color),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: style.color.withValues(alpha: isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        log.action,
                        style: TextStyle(
                          color: style.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )),
                DataCell(SizedBox(
                  width: 320,
                  child: Text(
                    log.details,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF374151),
                    ),
                  ),
                )),
                DataCell(Text(
                  log.ipAddress,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: muted,
                  ),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1F2937) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.description_outlined, size: 56, color: muted),
          const SizedBox(height: 12),
          Text(
            'No audit logs found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search or filters',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF7F1D1D)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditStats {
  const _AuditStats({
    required this.total,
    required this.user,
    required this.security,
    required this.system,
  });

  final int total;
  final int user;
  final int security;
  final int system;

  factory _AuditStats.fromLogs(List<_AuditLogEntry> logs) {
    return _AuditStats(
      total: logs.length,
      user: logs.where((log) => log.category == 'user').length,
      security: logs.where((log) => log.category == 'security').length,
      system: logs.where((log) => log.category == 'system').length,
    );
  }
}

class _CategoryStyle {
  const _CategoryStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_CategoryStyle _categoryStyle(String category) {
  switch (category) {
    case 'user':
      return const _CategoryStyle(
        icon: Icons.person_outline,
        color: Color(0xFF3B82F6),
      );
    case 'security':
      return const _CategoryStyle(
        icon: Icons.shield_outlined,
        color: Color(0xFFEF4444),
      );
    case 'forms':
      return const _CategoryStyle(
        icon: Icons.description_outlined,
        color: Color(0xFF8B5CF6),
      );
    case 'settings':
      return const _CategoryStyle(
        icon: Icons.settings_outlined,
        color: Color(0xFFF97316),
      );
    case 'system':
      return const _CategoryStyle(
        icon: Icons.storage_outlined,
        color: Color(0xFF22C55E),
      );
    default:
      return const _CategoryStyle(
        icon: Icons.description_outlined,
        color: Color(0xFF6B7280),
      );
  }
}

String _categoryForEvent(AdminAuditEvent event) {
  final resource = event.resourceType.toLowerCase();
  final action = event.action.toLowerCase();
  if (resource.contains('user') || action.contains('user')) {
    return 'user';
  }
  if (action.contains('permission') ||
      action.contains('role') ||
      resource.contains('security')) {
    return 'security';
  }
  if (resource.contains('form')) {
    return 'forms';
  }
  if (resource.contains('setting') || action.contains('setting')) {
    return 'settings';
  }
  return 'system';
}

class _AuditLogEntry {
  const _AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.user,
    required this.userEmail,
    required this.action,
    required this.category,
    required this.details,
    required this.ipAddress,
  });

  final String id;
  final String timestamp;
  final String user;
  final String userEmail;
  final String action;
  final String category;
  final String details;
  final String ipAddress;
}
