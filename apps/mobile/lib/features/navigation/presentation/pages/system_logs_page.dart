import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../admin/data/admin_models.dart';
import '../../../admin/data/admin_providers.dart';

class SystemLogsPage extends ConsumerStatefulWidget {
  const SystemLogsPage({super.key});

  @override
  ConsumerState<SystemLogsPage> createState() => _SystemLogsPageState();
}

class _SystemLogsPageState extends ConsumerState<SystemLogsPage> {
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
    final filteredLogs = logs.where((log) {
      final matchesSearch = log.message
              .toLowerCase()
              .contains(_searchTerm.toLowerCase()) ||
          log.source.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesFilter =
          _selectedFilter == 'all' || log.level == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();
    final stats = _LogStats.fromLogs(logs);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auditAsync.isLoading) const LinearProgressIndicator(),
          if (auditAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ErrorBanner(message: auditAsync.error.toString()),
            ),
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildStatsGrid(context, stats),
          const SizedBox(height: 16),
          _buildFilters(context),
          const SizedBox(height: 16),
          if (filteredLogs.isEmpty)
            _EmptyLogsCard(searchTerm: _searchTerm)
          else
            ...filteredLogs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LogCard(log: log),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Logs',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Monitor system activity and troubleshoot issues',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
        ),
      ],
    );

    final actionButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      onPressed: () {},
      icon: const Icon(Icons.download_outlined, size: 20),
      label: const Text('Export Logs'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              actionButton,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: actionButton),
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, _LogStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 4 : 2;
        // Use taller cards on narrow screens to avoid bottom overflow
        final aspectRatio = constraints.maxWidth < 400 ? 1.2 : 1.4;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _LogStatCard(
              title: 'Total Logs',
              value: stats.total.toString(),
              icon: Icons.storage_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
            ),
            _LogStatCard(
              title: 'Errors',
              value: stats.errors.toString(),
              icon: Icons.cancel_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
            ),
            _LogStatCard(
              title: 'Warnings',
              value: stats.warnings.toString(),
              icon: Icons.warning_amber_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
            ),
            _LogStatCard(
              title: 'Info',
              value: stats.info.toString(),
              icon: Icons.info_outline,
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final filters = const ['all', 'error', 'warning', 'info', 'success'];
    final searchDecoration = InputDecoration(
      prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
      hintText: 'Search logs...',
      filled: true,
      fillColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB)),
      ),
    );
    final filterButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final isSelected = _selectedFilter == filter;
        return TextButton(
          onPressed: () => setState(() => _selectedFilter = filter),
          style: TextButton.styleFrom(
            backgroundColor: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6)),
            foregroundColor:
                isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF374151)),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            _capitalize(filter),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
    );
    final searchField = TextField(
      controller: _searchController,
      decoration: searchDecoration,
      onChanged: (value) => setState(() => _searchTerm = value.trim()),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});

  final _LogEntry log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = _levelColors(log.level, isDark);
    final cardColor = isDark
        ? colors.background.withValues(alpha: 0.5)
        : colors.background;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_levelIcon(log.level), color: colors.icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaTag(
                      label: log.timestampLabel,
                      muted: isDark ? Colors.grey[400]! : Colors.grey[700]!,
                    ),
                    _MetaTag(
                      label: log.source,
                      muted: colors.foreground,
                      border: colors.border,
                      background: isDark
                          ? Colors.black.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.message,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _LevelBadge(
                      label: _capitalize(log.level),
                      background: colors.background,
                      foreground: colors.foreground,
                      border: colors.border,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  log.details,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({
    required this.label,
    required this.muted,
    this.background,
    this.border,
  });

  final String label;
  final Color muted;
  final Color? background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border ?? Colors.transparent),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: muted,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _LogStatCard extends StatelessWidget {
  const _LogStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLogsCard extends StatelessWidget {
  const _EmptyLogsCard({required this.searchTerm});

  final String searchTerm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.storage_outlined,
            size: 48,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No logs found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            searchTerm.isEmpty
                ? 'Try adjusting your filters'
                : 'No results for "$searchTerm"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
            textAlign: TextAlign.center,
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
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF991B1B),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogEntry {
  const _LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    required this.details,
  });

  final String id;
  final DateTime timestamp;
  final String level;
  final String source;
  final String message;
  final String details;

  String get timestampLabel => DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
}

class _LogStats {
  const _LogStats({
    required this.total,
    required this.errors,
    required this.warnings,
    required this.info,
  });

  final int total;
  final int errors;
  final int warnings;
  final int info;

  factory _LogStats.fromLogs(List<_LogEntry> logs) {
    return _LogStats(
      total: logs.length,
      errors: logs.where((log) => log.level == 'error').length,
      warnings: logs.where((log) => log.level == 'warning').length,
      info: logs
          .where((log) => log.level == 'info' || log.level == 'success')
          .length,
    );
  }
}

class _LevelColors {
  const _LevelColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color icon;
}

List<_LogEntry> _logsFromAudit(List<AdminAuditEvent> events) {
  return events.map((event) {
    final level = _levelFromAction(event.action);
    final message = '${event.resourceType} ${event.action}'.trim();
    final detailsParts = <String>[
      if (event.resourceId != null) 'Resource: ${event.resourceId}',
      if (event.actorId != null) 'Actor: ${event.actorId}',
    ];
    final details = detailsParts.isEmpty
        ? 'No additional details available.'
        : detailsParts.join(' - ');
    return _LogEntry(
      id: event.id.toString(),
      timestamp: event.createdAt,
      level: level,
      source: event.resourceType,
      message: message,
      details: details,
    );
  }).toList();
}

String _levelFromAction(String action) {
  final normalized = action.toLowerCase();
  if (normalized.contains('delete') ||
      normalized.contains('remove') ||
      normalized.contains('error') ||
      normalized.contains('fail')) {
    return 'error';
  }
  if (normalized.contains('update') ||
      normalized.contains('edit') ||
      normalized.contains('change')) {
    return 'warning';
  }
  if (normalized.contains('create') ||
      normalized.contains('submit') ||
      normalized.contains('approve') ||
      normalized.contains('complete')) {
    return 'success';
  }
  return 'info';
}

IconData _levelIcon(String level) {
  switch (level) {
    case 'error':
      return Icons.cancel_outlined;
    case 'warning':
      return Icons.warning_amber_outlined;
    case 'success':
      return Icons.check_circle_outline;
    case 'info':
    default:
      return Icons.info_outline;
  }
}

_LevelColors _levelColors(String level, bool isDark) {
  switch (level) {
    case 'error':
      return _LevelColors(
        background: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
        foreground: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
        border: isDark ? const Color(0xFFB91C1C) : const Color(0xFFFECACA),
        icon: const Color(0xFFEF4444),
      );
    case 'warning':
      return _LevelColors(
        background: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
        foreground: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
        border: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A),
        icon: const Color(0xFFF59E0B),
      );
    case 'success':
      return _LevelColors(
        background: isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
        foreground: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
        border: isDark ? const Color(0xFF15803D) : const Color(0xFFBBF7D0),
        icon: const Color(0xFF22C55E),
      );
    case 'info':
    default:
      return _LevelColors(
        background: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
        foreground: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
        border: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE),
        icon: const Color(0xFF3B82F6),
      );
  }
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
