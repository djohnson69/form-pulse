import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:intl/intl.dart';

import '../../data/platform_providers.dart';

/// Provider for selected user's activity
final selectedUserForActivityProvider = legacy.StateProvider<String?>((ref) => null);

/// Page showing user activity timeline
class UserActivityPage extends ConsumerStatefulWidget {
  const UserActivityPage({super.key});

  @override
  ConsumerState<UserActivityPage> createState() => _UserActivityPageState();
}

class _UserActivityPageState extends ConsumerState<UserActivityPage> {
  String _filterAction = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedUserId = ref.watch(selectedUserForActivityProvider);
    final usersAsync = ref.watch(platformUsersProvider);

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
                  color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.timeline,
                  color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Activity',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Timeline of user actions for debugging',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // User selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: usersAsync.when(
                  data: (users) {
                    return Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        final query = textEditingValue.text.toLowerCase();
                        return users
                            .where((user) =>
                                user.firstName.toLowerCase().contains(query) ||
                                user.lastName.toLowerCase().contains(query) ||
                                user.email.toLowerCase().contains(query))
                            .map((user) => '${user.firstName} ${user.lastName} (${user.email})')
                            .take(10);
                      },
                      onSelected: (selection) {
                        // Extract email from selection
                        final emailMatch = RegExp(r'\((.+)\)').firstMatch(selection);
                        if (emailMatch != null) {
                          final email = emailMatch.group(1);
                          final user = users.firstWhere((u) => u.email == email);
                          ref.read(selectedUserForActivityProvider.notifier).state = user.id;
                        }
                      },
                      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: 'Search for a user by name or email...',
                            prefixIcon: const Icon(Icons.search),
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
                        );
                      },
                    );
                  },
                  loading: () => TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: 'Loading users...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  error: (_, __) => TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: 'Failed to load users',
                      prefixIcon: const Icon(Icons.error),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
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
                    value: _filterAction,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Actions')),
                      DropdownMenuItem(value: 'page_view', child: Text('Page Views')),
                      DropdownMenuItem(value: 'form_submit', child: Text('Form Submits')),
                      DropdownMenuItem(value: 'create', child: Text('Creates')),
                      DropdownMenuItem(value: 'update', child: Text('Updates')),
                      DropdownMenuItem(value: 'delete', child: Text('Deletes')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _filterAction = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Activity timeline
        Expanded(
          child: selectedUserId == null
              ? _buildEmptyState(theme, isDark)
              : _buildActivityTimeline(selectedUserId, theme, isDark),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_search,
            size: 64,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a user to view their activity',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the search box above to find a user',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline(String userId, ThemeData theme, bool isDark) {
    final activityAsync = ref.watch(userActivityProvider(userId));
    final usersAsync = ref.watch(platformUsersProvider);

    // Find the selected user
    final selectedUser = usersAsync.asData?.value.where((u) => u.id == userId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected user info card
        if (selectedUser != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials('${selectedUser.firstName} ${selectedUser.lastName}'),
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedUser.firstName} ${selectedUser.lastName}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          selectedUser.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final emulated = EmulatedUser(
                        id: selectedUser.id,
                        email: selectedUser.email,
                        role: selectedUser.role,
                        orgId: selectedUser.orgId,
                        firstName: selectedUser.firstName,
                        lastName: selectedUser.lastName,
                      );
                      startEmulation(ref, emulated);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Now emulating ${selectedUser.firstName} ${selectedUser.lastName}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.supervisor_account, size: 18),
                    label: const Text('Emulate'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      ref.read(selectedUserForActivityProvider.notifier).state = null;
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Activity list
        Expanded(
          child: activityAsync.when(
            data: (events) {
              var filteredEvents = events;
              if (_filterAction != 'all') {
                filteredEvents = events.where((e) => e.action == _filterAction).toList();
              }

              if (filteredEvents.isEmpty) {
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
                        'No activity found',
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
                itemCount: filteredEvents.length,
                itemBuilder: (context, index) {
                  final event = filteredEvents[index];
                  final isLast = index == filteredEvents.length - 1;
                  return _ActivityTimelineItem(
                    event: event,
                    isLast: isLast,
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
                    'Failed to load activity',
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

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'U';
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _ActivityTimelineItem extends StatelessWidget {
  const _ActivityTimelineItem({
    required this.event,
    required this.isLast,
  });

  final UserActivityEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: event.actionColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconData(event.actionIconCodePoint, fontFamily: 'MaterialIcons'),
                  size: 18,
                  color: event.actionColor,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        event.details,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeFormat.format(event.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                          event.route,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
