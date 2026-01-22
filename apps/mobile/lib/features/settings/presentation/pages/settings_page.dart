import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_mode_provider.dart';
import '../../../dashboard/data/active_role_provider.dart';
import '../../../dashboard/data/dashboard_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _taskReminders = true;
  String _language = _languages.first;
  String _timezone = _timezones.first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _SettingsColors.fromTheme(theme);
    final role = ref.watch(activeRoleProvider);
    final canManage = role.isAdmin;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;
          final maxWidth =
              constraints.maxWidth > 896 ? 896.0 : constraints.maxWidth;
          final horizontalPadding = isWide ? 24.0 : 16.0;
          final verticalPadding = isWide ? 24.0 : 16.0;
          final cardPadding = EdgeInsets.all(isWide ? 24 : 20);
          final titleStyle = theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: isWide ? 30 : 24,
            color: colors.title,
          );
          final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
            color: colors.subtitle,
            fontSize: 16,
          );
          final buttonTextStyle = theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          );
          final outlineStyle = OutlinedButton.styleFrom(
            foregroundColor: colors.outlineText,
            side: BorderSide(color: colors.outlineBorder),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: buttonTextStyle,
          );
          final primaryStyle = ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: colors.primaryShadow,
            textStyle: buttonTextStyle,
          );
          final inputDecoration = _inputDecoration(colors);

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  horizontalPadding,
                  80,
                ),
                children: [
                  Text('Settings', style: titleStyle),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your application preferences',
                    style: subtitleStyle,
                  ),
                  const SizedBox(height: 24),
                  _SettingsCard(
                    background: colors.cardBackground,
                    border: colors.border,
                    icon: Icons.notifications_outlined,
                    iconColor: colors.icon,
                    title: 'Notifications',
                    titleColor: colors.title,
                    padding: cardPadding,
                    shadowColor: colors.cardShadow,
                    child: Column(
                      children: [
                        _ToggleRow(
                          label: 'Email notifications',
                          value: _emailNotifications,
                          textColor: colors.label,
                          activeColor: colors.primary,
                          onChanged: (value) =>
                              setState(() => _emailNotifications = value),
                        ),
                        const SizedBox(height: 12),
                        _ToggleRow(
                          label: 'Push notifications',
                          value: _pushNotifications,
                          textColor: colors.label,
                          activeColor: colors.primary,
                          onChanged: (value) =>
                              setState(() => _pushNotifications = value),
                        ),
                        const SizedBox(height: 12),
                        _ToggleRow(
                          label: 'Task reminders',
                          value: _taskReminders,
                          textColor: colors.label,
                          activeColor: colors.primary,
                          onChanged: (value) =>
                              setState(() => _taskReminders = value),
                        ),
                      ],
                    ),
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 24),
                    _SettingsCard(
                      background: colors.cardBackground,
                      border: colors.border,
                      icon: Icons.security_outlined,
                      iconColor: colors.icon,
                      title: 'Security',
                      titleColor: colors.title,
                      padding: cardPadding,
                      shadowColor: colors.cardShadow,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: primaryStyle,
                              onPressed: () => _showMessage('Change password'),
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Change Password'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: outlineStyle,
                              onPressed: () =>
                                  _showMessage('Two-factor authentication'),
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Two-Factor Authentication'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: outlineStyle,
                              onPressed: () => _showMessage('Active sessions'),
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Active Sessions'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SettingsCard(
                    background: colors.cardBackground,
                    border: colors.border,
                    icon: Icons.palette_outlined,
                    iconColor: colors.icon,
                    title: 'Appearance',
                    titleColor: colors.title,
                    padding: cardPadding,
                    shadowColor: colors.cardShadow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Theme',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.label,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ThemeMode>(
                          value: themeMode,
                          dropdownColor: colors.inputBackground,
                          decoration: inputDecoration,
                          style: TextStyle(color: colors.inputText),
                          items: const [
                            DropdownMenuItem(
                              value: ThemeMode.light,
                              child: Text('Light'),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.dark,
                              child: Text('Dark'),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.system,
                              child: Text('Auto'),
                            ),
                          ],
                          onChanged: (mode) {
                            if (mode == null) return;
                            ref.read(themeModeProvider.notifier).setMode(mode);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SettingsCard(
                    background: colors.cardBackground,
                    border: colors.border,
                    icon: Icons.public,
                    iconColor: colors.icon,
                    title: 'Language & Region',
                    titleColor: colors.title,
                    padding: cardPadding,
                    shadowColor: colors.cardShadow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Language',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.label,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _language,
                          dropdownColor: colors.inputBackground,
                          decoration: inputDecoration,
                          style: TextStyle(color: colors.inputText),
                          items: _languages
                              .map((language) => DropdownMenuItem(
                                    value: language,
                                    child: Text(language),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _language = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Timezone',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.label,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _timezone,
                          dropdownColor: colors.inputBackground,
                          decoration: inputDecoration,
                          style: TextStyle(color: colors.inputText),
                          items: _timezones
                              .map((timezone) => DropdownMenuItem(
                                    value: timezone,
                                    child: Text(timezone),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _timezone = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 24),
                    _SettingsCard(
                      background: colors.cardBackground,
                      border: colors.border,
                      icon: Icons.storage_outlined,
                      iconColor: colors.icon,
                      title: 'Data & Privacy',
                      titleColor: colors.title,
                      padding: cardPadding,
                      shadowColor: colors.cardShadow,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: outlineStyle,
                              onPressed: () =>
                                  _showMessage('Exporting data...'),
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Export Data'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: outlineStyle,
                              onPressed: () =>
                                  _showMessage('Downloading report...'),
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Download Report'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: outlineStyle.copyWith(
                                side: MaterialStateProperty.all(
                                  BorderSide(color: colors.dangerBorder),
                                ),
                                foregroundColor: MaterialStateProperty.all(
                                  colors.dangerText,
                                ),
                              ),
                              onPressed: () => _showMessage('Delete account'),
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Delete Account'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton(
                        style: outlineStyle,
                        onPressed: () => _showMessage('Cancel'),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: primaryStyle,
                        onPressed: () => _showMessage('Save changes'),
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SettingsCard(
                    background: colors.cardBackground,
                    border: colors.border,
                    icon: Icons.logout,
                    iconColor: colors.dangerText,
                    title: 'Account',
                    titleColor: colors.title,
                    padding: cardPadding,
                    shadowColor: colors.cardShadow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.dangerText,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: colors.dangerText.withValues(alpha: 0.3),
                              textStyle: buttonTextStyle,
                            ),
                            onPressed: () => _confirmSignOut(context, ref),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Sign Out'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final client = ref.read(supabaseClientProvider);
        await client.auth.signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }

  InputDecoration _inputDecoration(_SettingsColors colors) {
    return InputDecoration(
      filled: true,
      fillColor: colors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.child,
    required this.padding,
    required this.shadowColor,
  });

  final Color background;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final Widget child;
  final EdgeInsets padding;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.textColor,
    required this.activeColor,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color textColor;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: textColor),
          ),
        ),
        Checkbox(
          value: value,
          onChanged: (next) => onChanged(next ?? false),
          activeColor: activeColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _SettingsColors {
  const _SettingsColors({
    required this.background,
    required this.cardBackground,
    required this.border,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.icon,
    required this.inputBackground,
    required this.inputBorder,
    required this.inputText,
    required this.outlineBorder,
    required this.outlineText,
    required this.primary,
    required this.primaryShadow,
    required this.dangerBorder,
    required this.dangerText,
    required this.cardShadow,
  });

  final Color background;
  final Color cardBackground;
  final Color border;
  final Color title;
  final Color subtitle;
  final Color label;
  final Color icon;
  final Color inputBackground;
  final Color inputBorder;
  final Color inputText;
  final Color outlineBorder;
  final Color outlineText;
  final Color primary;
  final Color primaryShadow;
  final Color dangerBorder;
  final Color dangerText;
  final Color cardShadow;

  factory _SettingsColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    return _SettingsColors(
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      cardBackground: isDark ? const Color(0xFF1F2937) : Colors.white,
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      title: isDark ? Colors.white : const Color(0xFF111827),
      subtitle: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      label: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      icon: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
      inputBackground: isDark ? const Color(0xFF111827) : Colors.white,
      inputBorder: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      inputText: isDark ? Colors.white : const Color(0xFF111827),
      outlineBorder: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      outlineText: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      primary: primary,
      primaryShadow: primary.withValues(alpha: 0.2),
      dangerBorder: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
      dangerText: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      cardShadow: isDark
          ? Colors.black.withValues(alpha: 0.2)
          : Colors.black.withValues(alpha: 0.06),
    );
  }
}

const _languages = ['English', 'Spanish', 'French'];

const _timezones = [
  'UTC-5 (Eastern Time)',
  'UTC-6 (Central Time)',
  'UTC-7 (Mountain Time)',
  'UTC-8 (Pacific Time)',
];
