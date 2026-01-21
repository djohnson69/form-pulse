import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../admin/data/admin_models.dart';
import '../../data/platform_providers.dart';

/// Dialog for selecting a user to emulate
class EmulateUserDialog extends ConsumerStatefulWidget {
  const EmulateUserDialog({super.key});

  static Future<EmulatedUser?> show(BuildContext context) {
    return showDialog<EmulatedUser>(
      context: context,
      builder: (_) => const EmulateUserDialog(),
    );
  }

  @override
  ConsumerState<EmulateUserDialog> createState() => _EmulateUserDialogState();
}

class _EmulateUserDialogState extends ConsumerState<EmulateUserDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final usersAsync = ref.watch(platformUsersProvider);

    final filteredUsers = usersAsync.whenData((users) {
      if (_searchQuery.isEmpty) return users;
      final query = _searchQuery.toLowerCase();
      return users.where((user) {
        final nameMatch = user.firstName.toLowerCase().contains(query) ||
            user.lastName.toLowerCase().contains(query);
        final emailMatch = user.email.toLowerCase().contains(query);
        final roleMatch = user.role.displayName.toLowerCase().contains(query);
        return nameMatch || emailMatch || roleMatch;
      }).toList();
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E40AF).withValues(alpha: 0.5)
                          : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.supervisor_account,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emulate User',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View the app as another user for debugging',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or role...',
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                  ),
                ),
              ),
            ),

            // User list
            Flexible(
              child: filteredUsers.when(
                data: (users) {
                  if (users.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 48,
                              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No users found'
                                  : 'No users match "$_searchQuery"',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _UserTile(
                        user: user,
                        onTap: () => _selectUser(user),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load users',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _selectUser(AdminUserSummary user) {
    final emulated = EmulatedUser(
      id: user.id,
      email: user.email,
      role: user.role,
      orgId: user.orgId,
      firstName: user.firstName,
      lastName: user.lastName,
    );
    Navigator.of(context).pop(emulated);
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onTap,
  });

  final AdminUserSummary user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayName = _formatDisplayName();
    final initials = _getInitials(displayName);
    final roleColor = _getRoleColor(user.role);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [roleColor, roleColor.withValues(alpha: 0.7)],
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

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                      if (user.orgId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Org: ${user.orgId.substring(0, 8)}...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: roleColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    user.role.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: roleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDisplayName() {
    if (user.firstName.isNotEmpty) {
      if (user.lastName.isNotEmpty) {
        return '${user.firstName} ${user.lastName}';
      }
      return user.firstName;
    }
    return user.email.split('@').first;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      final first = parts.first;
      if (first.isEmpty) return 'U';
      return first.length == 1 ? first.toUpperCase() : first.substring(0, 2).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color _getRoleColor(UserRole? role) {
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
      null => const Color(0xFF6B7280),
    };
  }
}
