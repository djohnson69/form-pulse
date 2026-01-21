import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/data/admin_providers.dart';
import '../../data/platform_providers.dart';

/// Dropdown widget for selecting an organization to view
/// Used by Developer and TechSupport roles to switch between orgs
class OrgSelector extends ConsumerWidget {
  const OrgSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final orgsAsync = ref.watch(platformOrganizationsProvider);
    final selectedOrgId = ref.watch(adminSelectedOrgIdProvider);

    return orgsAsync.when(
      data: (orgs) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedOrgId,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
              dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.public,
                        size: 18,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'All Organizations',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF111827),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                ...orgs.map((org) => DropdownMenuItem<String?>(
                  value: org.id,
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            org.name.isNotEmpty ? org.name[0].toUpperCase() : 'O',
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          org.name,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${org.memberCount})',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
              onChanged: (value) {
                ref.read(adminSelectedOrgIdProvider.notifier).state = value;
              },
              selectedItemBuilder: (context) {
                return [
                  // "All Organizations" selected item
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.public,
                        size: 18,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'All Organizations',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF111827),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Each org's selected item
                  ...orgs.map((org) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            org.name.isNotEmpty ? org.name[0].toUpperCase() : 'O',
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          org.name,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )),
                ];
              },
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading orgs...',
              style: TextStyle(
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 16,
              color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 8),
            Text(
              'Failed to load',
              style: TextStyle(
                color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact version of org selector for tighter spaces
class OrgSelectorCompact extends ConsumerWidget {
  const OrgSelectorCompact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final orgsAsync = ref.watch(platformOrganizationsProvider);
    final selectedOrgId = ref.watch(adminSelectedOrgIdProvider);

    return orgsAsync.when(
      data: (orgs) {
        String label = 'All Orgs';
        if (selectedOrgId != null) {
          final org = orgs.where((o) => o.id == selectedOrgId).firstOrNull;
          if (org != null) {
            label = org.name.length > 12 ? '${org.name.substring(0, 12)}...' : org.name;
          }
        }

        return PopupMenuButton<String?>(
          initialValue: selectedOrgId,
          onSelected: (value) {
            ref.read(adminSelectedOrgIdProvider.notifier).state = value;
          },
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          itemBuilder: (context) => [
            PopupMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(
                    Icons.public,
                    size: 18,
                    color: selectedOrgId == null
                        ? const Color(0xFF3B82F6)
                        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'All Organizations',
                    style: TextStyle(
                      fontWeight: selectedOrgId == null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            ...orgs.map((org) => PopupMenuItem<String?>(
              value: org.id,
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        org.name.isNotEmpty ? org.name[0].toUpperCase() : 'O',
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      org.name,
                      style: TextStyle(
                        fontWeight: selectedOrgId == org.id ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${org.memberCount}',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selectedOrgId == null ? Icons.public : Icons.apartment,
                  size: 16,
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.error_outline,
          size: 16,
          color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
        ),
      ),
    );
  }
}
