import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/platform_providers.dart';

/// Page showing the impersonation audit log
class ImpersonationLogPage extends ConsumerStatefulWidget {
  const ImpersonationLogPage({super.key});

  @override
  ConsumerState<ImpersonationLogPage> createState() => _ImpersonationLogPageState();
}

class _ImpersonationLogPageState extends ConsumerState<ImpersonationLogPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterBy = 'all'; // all, active, completed

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final logsAsync = ref.watch(impersonationLogProvider);

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
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.history,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Impersonation Log',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Audit trail of all user emulation sessions',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(impersonationLogProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
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

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by user name or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                    value: _filterBy,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Sessions')),
                      DropdownMenuItem(value: 'active', child: Text('Active Only')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _filterBy = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Log entries
        Expanded(
          child: logsAsync.when(
            data: (logs) {
              var filteredLogs = logs.where((log) {
                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  final matchesSearch = log.emulatorName.toLowerCase().contains(_searchQuery) ||
                      log.emulatorEmail.toLowerCase().contains(_searchQuery) ||
                      log.emulatedUserName.toLowerCase().contains(_searchQuery) ||
                      log.emulatedUserEmail.toLowerCase().contains(_searchQuery);
                  if (!matchesSearch) return false;
                }
                // Filter by status
                if (_filterBy == 'active' && !log.isActive) return false;
                if (_filterBy == 'completed' && log.isActive) return false;
                return true;
              }).toList();

              if (filteredLogs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty && _filterBy == 'all'
                            ? 'No impersonation sessions recorded'
                            : 'No sessions match your filters',
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
                itemCount: filteredLogs.length,
                itemBuilder: (context, index) {
                  final log = filteredLogs[index];
                  return _LogEntryCard(log: log);
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
                    'Failed to load impersonation log',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(impersonationLogProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({required this.log});

  final ImpersonationLogEntry log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: log.isActive
                ? const Color(0xFF10B981)
                : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
            width: log.isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with status
            Row(
              children: [
                // Emulator info
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(log.emulatorName),
                            style: const TextStyle(
                              color: Color(0xFF7C3AED),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
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
                              log.emulatorName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            Text(
                              log.emulatorEmail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 16),

                // Emulated user info
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(log.emulatedUserName),
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
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
                              log.emulatedUserName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            Text(
                              log.emulatedUserRole,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: log.isActive
                        ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1)
                        : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (log.isActive)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      Text(
                        log.isActive ? 'Active' : 'Completed',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: log.isActive
                              ? const Color(0xFF10B981)
                              : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
            const SizedBox(height: 12),

            // Details row
            Row(
              children: [
                // Date/Time
                _DetailChip(
                  icon: Icons.calendar_today,
                  label: dateFormat.format(log.startedAt),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _DetailChip(
                  icon: Icons.access_time,
                  label: '${timeFormat.format(log.startedAt)}${log.endedAt != null ? ' - ${timeFormat.format(log.endedAt!)}' : ''}',
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _DetailChip(
                  icon: Icons.timer,
                  label: log.formattedDuration,
                  isDark: isDark,
                ),
                if (log.reason != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DetailChip(
                      icon: Icons.note,
                      label: log.reason!,
                      isDark: isDark,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'U';
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
