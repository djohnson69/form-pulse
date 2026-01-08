import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_mode_provider.dart';
import '../../../dashboard/data/active_role_provider.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final role = ref.watch(activeRoleProvider);
    final canManage = role.isAdmin;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage your application preferences',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            border: border,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            child: Column(
              children: [
                _ToggleRow(
                  label: 'Email notifications',
                  value: _emailNotifications,
                  onChanged: (value) =>
                      setState(() => _emailNotifications = value),
                ),
                _ToggleRow(
                  label: 'Push notifications',
                  value: _pushNotifications,
                  onChanged: (value) =>
                      setState(() => _pushNotifications = value),
                ),
                _ToggleRow(
                  label: 'Task reminders',
                  value: _taskReminders,
                  onChanged: (value) => setState(() => _taskReminders = value),
                ),
              ],
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: 16),
            _SettingsCard(
              border: border,
              icon: Icons.security_outlined,
              title: 'Security',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _showMessage('Change password'),
                    child: const Text('Change Password'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => _showMessage('Two-factor authentication'),
                    child: const Text('Two-Factor Authentication'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => _showMessage('Active sessions'),
                    child: const Text('Active Sessions'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _SettingsCard(
            border: border,
            icon: Icons.palette_outlined,
            title: 'Appearance',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ThemeMode>(
                  value: themeMode,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
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
          const SizedBox(height: 16),
          _SettingsCard(
            border: border,
            icon: Icons.public,
            title: 'Language & Region',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _language,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
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
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _timezone,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
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
            const SizedBox(height: 16),
            _SettingsCard(
              border: border,
              icon: Icons.storage_outlined,
              title: 'Data & Privacy',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: () => _showMessage('Exporting data...'),
                    child: const Text('Export Data'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => _showMessage('Downloading report...'),
                    child: const Text('Download Report'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                    onPressed: () => _showMessage('Delete account'),
                    child: const Text('Delete Account'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _showMessage('Cancel'),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: () => _showMessage('Save changes'),
                child: const Text('Save Changes'),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.border,
    required this.icon,
    required this.title,
    required this.child,
  });

  final Color border;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Checkbox(
          value: value,
          onChanged: (next) => onChanged(next ?? false),
        ),
      ],
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
