import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../data/platform_providers.dart';

/// Page showing currently active user sessions
class ActiveSessionsPage extends ConsumerStatefulWidget {
  const ActiveSessionsPage({super.key});

  @override
  ConsumerState<ActiveSessionsPage> createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends ConsumerState<ActiveSessionsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterOrg = 'all';
  String _filterStatus = 'all'; // all, active, idle

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sessionsAsync = ref.watch(activeSessionsProvider);
    final orgsAsync = ref.watch(platformOrganizationsProvider);

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
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.people_alt,
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Sessions',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    sessionsAsync.when(
                      data: (sessions) => Text(
                        '${sessions.length} users currently online',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
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
                onPressed: () => ref.invalidate(activeSessionsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
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
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
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
                    value: _filterOrg,
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Organizations')),
                      ...orgsAsync.asData?.value.map((org) => DropdownMenuItem(
                            value: org.id,
                            child: Text(org.name),
                          )) ??
                          [],
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _filterOrg = value);
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
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(value: 'active', child: Text('Active Only')),
                      DropdownMenuItem(value: 'idle', child: Text('Idle Only')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _filterStatus = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Sessions list
        Expanded(
          child: sessionsAsync.when(
            data: (sessions) {
              var filteredSessions = sessions.where((session) {
                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  final matchesSearch = session.userName.toLowerCase().contains(_searchQuery) ||
                      session.userEmail.toLowerCase().contains(_searchQuery);
                  if (!matchesSearch) return false;
                }
                // Filter by org
                if (_filterOrg != 'all' && session.orgId != _filterOrg) return false;
                // Filter by status
                if (_filterStatus == 'active' && session.isIdle) return false;
                if (_filterStatus == 'idle' && !session.isIdle) return false;
                return true;
              }).toList();

              if (filteredSessions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty && _filterOrg == 'all' && _filterStatus == 'all'
                            ? 'No active sessions'
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
                itemCount: filteredSessions.length,
                itemBuilder: (context, index) {
                  final session = filteredSessions[index];
                  return _SessionCard(
                    session: session,
                    onEmulate: () => _emulateUser(session),
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
                    'Failed to load active sessions',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(activeSessionsProvider),
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

  void _emulateUser(ActiveSession session) {
    final emulated = EmulatedUser(
      id: session.userId,
      email: session.userEmail,
      role: session.userRole,
      orgId: session.orgId,
      firstName: session.userName.split(' ').first,
      lastName: session.userName.split(' ').length > 1 ? session.userName.split(' ').last : null,
      orgName: session.orgName,
    );
    ref.read(emulatedUserProvider.notifier).state = emulated;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now emulating ${session.userName}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onEmulate,
  });

  final ActiveSession session;
  final VoidCallback onEmulate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');
    final roleColor = _getRoleColor(session.userRole);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            // Avatar with status indicator
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(session.userName),
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: session.isIdle ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F2937) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        session.userName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          session.userRole.displayName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: roleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.userEmail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (session.orgName != null) ...[
                        Icon(
                          Icons.apartment,
                          size: 12,
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session.orgName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(
                        Icons.devices,
                        size: 12,
                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.deviceInfo ?? 'Unknown device',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Session info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.route,
                        size: 12,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.currentRoute ?? '/',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Started ${timeFormat.format(session.startedAt)} (${session.formattedDuration})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.formattedIdleTime,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: session.isIdle
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Actions
            IconButton(
              onPressed: onEmulate,
              icon: const Icon(Icons.supervisor_account),
              tooltip: 'Emulate User',
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
              ),
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

  Color _getRoleColor(UserRole role) {
    return switch (role) {
      UserRole.developer => const Color(0xFF7C3AED),
      UserRole.techSupport => const Color(0xFF0EA5E9),
      UserRole.superAdmin => const Color(0xFFDC2626),
      UserRole.admin => const Color(0xFFF59E0B),
      UserRole.manager => const Color(0xFF10B981),
      UserRole.supervisor => const Color(0xFF3B82F6),
      UserRole.employee => const Color(0xFF6366F1),
      UserRole.maintenance => const Color(0xFF8B5CF6),
      UserRole.client => const Color(0xFF14B8A6),
      UserRole.vendor => const Color(0xFFEC4899),
      UserRole.viewer => const Color(0xFF6B7280),
    };
  }
}
