import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../features/dashboard/data/role_override_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class TopBar extends ConsumerWidget {
  const TopBar({
    super.key,
    required this.role,
    this.onMenuPressed,
    this.isMobile = false,
  });

  final UserRole role;
  final VoidCallback? onMenuPressed;
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final iconColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
    final themeMode = ref.watch(themeModeProvider);
    final allowRoleOverride = role == UserRole.developer || !kReleaseMode;
    final override =
        allowRoleOverride ? ref.watch(roleOverrideProvider) : null;
    final activeRole = override ?? role;
    final horizontalPadding = isMobile ? 12.0 : 24.0;
    final verticalPadding = 12.0;
    final logoHeight = isMobile ? 64.0 : 80.0;
    final bar = Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        verticalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (isMobile)
                  IconButton(
                    onPressed: onMenuPressed,
                    icon: const Icon(Icons.menu),
                    color: iconColor,
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    splashRadius: 20,
                  ),
              ],
            ),
          ),
          Image.asset(
            'assets/branding/form_bridge_logo.png',
            height: logoHeight,
            fit: BoxFit.contain,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () {
                    final next = themeMode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
                    ref.read(themeModeProvider.notifier).setMode(next);
                  },
                  icon: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.light_mode
                        : Icons.dark_mode,
                  ),
                  color: iconColor,
                  splashRadius: 20,
                ),
                const SizedBox(width: 10),
                if (allowRoleOverride) ...[
                  _RoleDropdown(
                    role: activeRole,
                    isMobile: isMobile,
                    onChanged: (next) {
                      ref.read(roleOverrideProvider.notifier).state = next;
                    },
                  ),
                  const SizedBox(width: 10),
                ],
                if (!isMobile) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                    color: iconColor,
                    splashRadius: 20,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (isMobile) {
      return SafeArea(bottom: false, child: bar);
    }
    return bar;
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({
    required this.role,
    required this.onChanged,
    required this.isMobile,
  });

  final UserRole role;
  final ValueChanged<UserRole?> onChanged;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF374151) : Colors.white;
    final border = isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF374151);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 10,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserRole>(
          value: role,
          icon: Icon(Icons.expand_more, color: textColor, size: 18),
          items: UserRole.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(
                    isMobile
                        ? value.displayName.substring(
                            0,
                            value.displayName.length > 3
                                ? 3
                                : value.displayName.length,
                          )
                        : value.displayName,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          style: theme.textTheme.labelMedium?.copyWith(color: textColor),
          dropdownColor: background,
          isDense: true,
        ),
      ),
    );
  }
}
