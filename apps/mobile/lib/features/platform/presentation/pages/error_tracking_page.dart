import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/platform_providers.dart';

/// Page showing error tracking and aggregation
class ErrorTrackingPage extends ConsumerStatefulWidget {
  const ErrorTrackingPage({super.key});

  @override
  ConsumerState<ErrorTrackingPage> createState() => _ErrorTrackingPageState();
}

class _ErrorTrackingPageState extends ConsumerState<ErrorTrackingPage> {
  String _filterSeverity = 'all';
  String _filterStatus = 'all';
  String _sortBy = 'lastSeen';
  bool _sortAsc = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final errorsAsync = ref.watch(errorEventsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bug_report,
                  color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error Tracking',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    errorsAsync.when(
                      data: (errors) {
                        final openErrors = errors.where((e) => e.status == 'open' || e.status == 'investigating').length;
                        return Text(
                          '$openErrors open errors',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: openErrors > 0
                                ? const Color(0xFFEF4444)
                                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                          ),
                        );
                      },
                      loading: () => Text(
                        'Loading...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(errorEventsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),

        // Summary cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: errorsAsync.when(
            data: (errors) => _buildSummaryCards(errors, isDark),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        const SizedBox(height: 16),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterSeverity,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Severities')),
                      DropdownMenuItem(value: 'critical', child: Text('Critical')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _filterSeverity = value);
                      }
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterStatus,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(value: 'investigating', child: Text('Investigating')),
                      DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                      DropdownMenuItem(value: 'ignored', child: Text('Ignored')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _filterStatus = value);
                      }
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    items: const [
                      DropdownMenuItem(value: 'lastSeen', child: Text('Sort by Last Seen')),
                      DropdownMenuItem(value: 'occurrences', child: Text('Sort by Occurrences')),
                      DropdownMenuItem(value: 'users', child: Text('Sort by Affected Users')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sortBy = value);
                      }
                    },
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _sortAsc = !_sortAsc),
                icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Error list
        Expanded(
          child: errorsAsync.when(
            data: (errors) {
              var filteredErrors = errors.where((e) {
                if (_filterSeverity != 'all' && e.severity != _filterSeverity) return false;
                if (_filterStatus != 'all' && e.status != _filterStatus) return false;
                return true;
              }).toList();

              // Sort
              filteredErrors.sort((a, b) {
                int result;
                switch (_sortBy) {
                  case 'occurrences':
                    result = a.occurrenceCount.compareTo(b.occurrenceCount);
                    break;
                  case 'users':
                    result = a.affectedUsers.compareTo(b.affectedUsers);
                    break;
                  default:
                    result = a.lastSeen.compareTo(b.lastSeen);
                }
                return _sortAsc ? result : -result;
              });

              if (filteredErrors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No errors match your filters',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filteredErrors.length,
                itemBuilder: (context, index) {
                  final error = filteredErrors[index];
                  return _ErrorCard(
                    error: error,
                    onTap: () => _showErrorDetails(error),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load errors',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(List<ErrorEvent> errors, bool isDark) {
    final critical = errors.where((e) => e.severity == 'critical' && e.status != 'resolved' && e.status != 'ignored').length;
    final high = errors.where((e) => e.severity == 'high' && e.status != 'resolved' && e.status != 'ignored').length;
    final totalOccurrences = errors.fold<int>(0, (sum, e) => sum + e.occurrenceCount);
    final totalAffectedUsers = errors.fold<int>(0, (sum, e) => sum + e.affectedUsers);

    return Row(
      children: [
        _SummaryCard(
          label: 'Critical',
          value: critical.toString(),
          color: const Color(0xFFDC2626),
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          label: 'High',
          value: high.toString(),
          color: const Color(0xFFF59E0B),
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          label: 'Total Occurrences',
          value: NumberFormat('#,###').format(totalOccurrences),
          color: const Color(0xFF3B82F6),
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          label: 'Affected Users',
          value: totalAffectedUsers.toString(),
          color: const Color(0xFF8B5CF6),
          isDark: isDark,
        ),
      ],
    );
  }

  void _showErrorDetails(ErrorEvent error) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: error.severityColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(IconData(error.severityIconCodePoint, fontFamily: 'MaterialIcons'), color: error.severityColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            error.errorType,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            error.message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats row
                      Row(
                        children: [
                          _DetailItem(
                            label: 'Occurrences',
                            value: NumberFormat('#,###').format(error.occurrenceCount),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 24),
                          _DetailItem(
                            label: 'Affected Users',
                            value: error.affectedUsers.toString(),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 24),
                          _DetailItem(
                            label: 'First Seen',
                            value: dateFormat.format(error.firstSeen),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 24),
                          _DetailItem(
                            label: 'Last Seen',
                            value: dateFormat.format(error.lastSeen),
                            isDark: isDark,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Stack trace
                      Text(
                        'Stack Trace',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: SelectableText(
                          error.stackTrace ?? 'No stack trace available',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ),

                      if (error.affectedOrgs != null && error.affectedOrgs!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Affected Organizations',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: error.affectedOrgs!.map((org) => Chip(
                            label: Text(org),
                            backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (error.status != 'resolved')
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error marked as resolved'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark Resolved'),
                      ),
                    const SizedBox(width: 8),
                    if (error.status != 'ignored')
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error ignored'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_off),
                        label: const Text('Ignore'),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.error,
    required this.onTap,
  });

  final ErrorEvent error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeAgo = _formatTimeAgo(error.lastSeen);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                // Severity indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: error.severityColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    IconData(error.severityIconCodePoint, fontFamily: 'MaterialIcons'),
                    color: error.severityColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),

                // Error info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            error.errorType,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: error.statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              error.status.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: error.statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,###').format(error.occurrenceCount)} occurrences',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white : const Color(0xFF111827),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${error.affectedUsers} users',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}
