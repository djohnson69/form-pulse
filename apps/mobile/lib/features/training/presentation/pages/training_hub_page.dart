import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/training_provider.dart';
import 'training_editor_page.dart';
import 'employee_detail_page.dart';
import 'employee_editor_page.dart';

class TrainingHubPage extends ConsumerStatefulWidget {
  const TrainingHubPage({super.key});

  @override
  ConsumerState<TrainingHubPage> createState() => _TrainingHubPageState();
}

class _TrainingHubPageState extends ConsumerState<TrainingHubPage> {
  final List<_ReminderSetting> _reminderSchedule = [
    _ReminderSetting(label: '30 days before expiration', enabled: true),
    _ReminderSetting(label: '2 weeks before expiration', enabled: true),
    _ReminderSetting(label: '1 week before expiration', enabled: true),
    _ReminderSetting(label: '3 days before expiration', enabled: true),
    _ReminderSetting(label: '1 day before expiration', enabled: true),
    _ReminderSetting(label: 'On expiration day', enabled: true),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  final titleBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Training Hub',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage training programs and employee certifications',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openReminderSettings(context),
                        icon: const Icon(Icons.notifications_active_outlined, size: 18),
                        label: const Text('Reminders'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openEmployeeEditor(context),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add Employee'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openTrainingEditor(context),
                        icon: const Icon(Icons.school, size: 18),
                        label: const Text('Assign Training'),
                      ),
                    ],
                  );
                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: titleBlock),
                        actions,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      actions,
                    ],
                  );
                },
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Training'),
                Tab(text: 'Employees'),
              ],
            ),
            const Divider(height: 1),
            const Expanded(
              child: TabBarView(
                children: [
                  TrainingRecordsTab(),
                  EmployeesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEmployeeEditor(BuildContext context) async {
    final result = await Navigator.of(context).push<Employee?>(
      MaterialPageRoute(builder: (_) => const EmployeeEditorPage()),
    );
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(employeesProvider);
    }
  }

  Future<void> _openTrainingEditor(BuildContext context) async {
    final result = await Navigator.of(context).push<Training?>(
      MaterialPageRoute(builder: (_) => const TrainingEditorPage()),
    );
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(trainingRecordsProvider(null));
    }
  }

  Future<void> _openReminderSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Automated Expiration Reminders',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configure when employees receive automatic reminders about expiring certifications.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ..._reminderSchedule.asMap().entries.map((entry) {
                      final index = entry.key;
                      final reminder = entry.value;
                      final activeColor = Theme.of(context).colorScheme.primary;
                      final muted =
                          Theme.of(context).colorScheme.onSurfaceVariant;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: reminder.enabled,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _reminderSchedule[index].enabled = value;
                                });
                                setSheetState(() {});
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reminder.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Email & in-app notification',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: muted),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: reminder.enabled
                                    ? activeColor.withValues(alpha: 0.15)
                                    : muted.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                reminder.enabled ? 'Active' : 'Disabled',
                                style:
                                    Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: reminder.enabled
                                              ? activeColor
                                              : muted,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Save Settings'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class TrainingRecordsTab extends ConsumerStatefulWidget {
  const TrainingRecordsTab({super.key});

  @override
  ConsumerState<TrainingRecordsTab> createState() => _TrainingRecordsTabState();
}

class _TrainingRecordsTabState extends ConsumerState<TrainingRecordsTab> {
  TrainingStatus? _statusFilter;
  bool _expiringOnly = false;
  bool _sendingReminders = false;
  RealtimeChannel? _trainingChannel;

  @override
  void initState() {
    super.initState();
    _subscribeToTrainingChanges();
  }

  @override
  void dispose() {
    _trainingChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToTrainingChanges() {
    final client = Supabase.instance.client;
    _trainingChannel = client.channel('training-changes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'training_records',
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(trainingRecordsProvider(null));
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'employees',
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(employeesProvider);
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final trainingAsync = ref.watch(trainingRecordsProvider(null));
    return employeesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _ErrorView(message: 'Employees error: $e'),
      data: (employees) {
        final employeeIndex = {
          for (final employee in employees) employee.id: employee,
        };
        return trainingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => _ErrorView(message: 'Training error: $e'),
          data: (records) {
            final expiringSoon = _expiringSoon(records);
            final filtered = _applyFilters(records);
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(trainingRecordsProvider(null));
                ref.invalidate(employeesProvider);
                await ref.read(trainingRecordsProvider(null).future);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TrainingSummaryCard(
                    total: records.length,
                    expiringSoon: expiringSoon.length,
                    expired: records.where(_isExpired).length,
                  ),
                  const SizedBox(height: 12),
                  if (expiringSoon.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${expiringSoon.length} certification${expiringSoon.length == 1 ? '' : 's'} expiring soon',
                              ),
                            ),
                            TextButton(
                              onPressed: _sendingReminders
                                  ? null
                                  : () => _sendExpiringReminders(expiringSoon),
                              child: Text(
                                _sendingReminders ? 'Sending...' : 'Remind',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (expiringSoon.isNotEmpty) const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _statusFilter == null,
                        onSelected: (_) => setState(() => _statusFilter = null),
                      ),
                      ...TrainingStatus.values.map((status) {
                        return FilterChip(
                          label: Text(status.displayName),
                          selected: _statusFilter == status,
                          onSelected: (_) => setState(() => _statusFilter = status),
                        );
                      }),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiring soon only'),
                    value: _expiringOnly,
                    onChanged: (value) => setState(() => _expiringOnly = value),
                  ),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'No training records',
                              style:
                                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text('Assign training to start tracking compliance.'),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (record) => _TrainingRecordCard(
                        training: record,
                        employee: employeeIndex[record.employeeId],
                        onTap: () => _openTrainingEditor(record, employeeIndex),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Training> _applyFilters(List<Training> records) {
    return records.where((record) {
      final status = _effectiveStatus(record);
      final matchesStatus = _statusFilter == null || status == _statusFilter;
      final matchesExpiring = !_expiringOnly || _isExpiringSoon(record);
      return matchesStatus && matchesExpiring;
    }).toList();
  }

  TrainingStatus _effectiveStatus(Training training) {
    final expiration = training.expirationDate;
    if (expiration == null) return training.status;
    if (expiration.isBefore(DateTime.now())) {
      return TrainingStatus.expired;
    }
    final days = expiration.difference(DateTime.now()).inDays;
    if (days <= AppConstants.certificationExpiryWarningDays &&
        training.status == TrainingStatus.certified) {
      return TrainingStatus.dueForRecert;
    }
    return training.status;
  }

  List<Training> _expiringSoon(List<Training> records) {
    return records.where(_isExpiringSoon).toList();
  }

  bool _isExpiringSoon(Training training) {
    final expiration = training.expirationDate;
    if (expiration == null) return false;
    final days = expiration.difference(DateTime.now()).inDays;
    return days >= 0 && days <= AppConstants.certificationExpiryWarningDays;
  }

  bool _isExpired(Training training) {
    final expiration = training.expirationDate;
    if (expiration == null) return false;
    return expiration.isBefore(DateTime.now());
  }

  Future<void> _openTrainingEditor(
    Training training,
    Map<String, Employee> employees,
  ) async {
    final employee = employees[training.employeeId];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingEditorPage(
          existing: training,
          employee: employee,
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(trainingRecordsProvider(null));
  }

  Future<void> _sendExpiringReminders(List<Training> trainings) async {
    setState(() => _sendingReminders = true);
    final repo = ref.read(trainingRepositoryProvider);
    for (final training in trainings) {
      await repo.sendTrainingReminder(training);
    }
    if (!mounted) return;
    setState(() => _sendingReminders = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminders sent')),
    );
  }
}

class EmployeesTab extends ConsumerStatefulWidget {
  const EmployeesTab({super.key});

  @override
  ConsumerState<EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends ConsumerState<EmployeesTab> {
  String _search = '';
  bool _activeOnly = true;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    return employeesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _ErrorView(message: 'Employees error: $e'),
      data: (employees) {
        final filtered = _applyFilters(employees);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(employeesProvider);
            await ref.read(employeesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search employees',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setState(() => _search = value.trim().toLowerCase()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active only'),
                value: _activeOnly,
                onChanged: (value) => setState(() => _activeOnly = value),
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'No employees found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('Add employees to track training and compliance.'),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.map(
                  (employee) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(employee.initials),
                      ),
                      title: Text(employee.fullName),
                      subtitle: Text(
                        [
                          if ((employee.position ?? '').isNotEmpty)
                            employee.position!,
                          if ((employee.department ?? '').isNotEmpty)
                            employee.department!,
                          if ((employee.jobSiteName ?? '').isNotEmpty)
                            employee.jobSiteName!,
                        ].join(' • '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EmployeeDetailPage(employee: employee),
                          ),
                        );
                        ref.invalidate(employeesProvider);
                        ref.invalidate(trainingRecordsProvider(employee.id));
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  List<Employee> _applyFilters(List<Employee> employees) {
    return employees.where((employee) {
      final matchesQuery = _search.isEmpty ||
          employee.fullName.toLowerCase().contains(_search) ||
          employee.email.toLowerCase().contains(_search);
      final matchesActive = !_activeOnly || employee.isActive;
      return matchesQuery && matchesActive;
    }).toList();
  }
}

class _TrainingSummaryCard extends StatelessWidget {
  const _TrainingSummaryCard({
    required this.total,
    required this.expiringSoon,
    required this.expired,
  });

  final int total;
  final int expiringSoon;
  final int expired;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _SummaryItem(label: 'Total', value: total.toString()),
            const SizedBox(width: 12),
            _SummaryItem(label: 'Expiring', value: expiringSoon.toString()),
            const SizedBox(width: 12),
            _SummaryItem(label: 'Expired', value: expired.toString()),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _TrainingRecordCard extends StatelessWidget {
  const _TrainingRecordCard({
    required this.training,
    required this.employee,
    required this.onTap,
  });

  final Training training;
  final Employee? employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = _effectiveStatus(training);
    final status = effectiveStatus.displayName;
    final expires = training.expirationDate;
    final expiresText = expires == null
        ? 'No expiration'
        : 'Expires ${expires.month}/${expires.day}/${expires.year}';
    final actionRequired =
        effectiveStatus == TrainingStatus.dueForRecert ||
            effectiveStatus == TrainingStatus.expired;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.school),
        title: Text(training.trainingName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (employee != null) employee!.fullName,
                status,
                expiresText,
              ].join(' • '),
            ),
            if (actionRequired)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Chip(
                  label: const Text('Action required'),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  TrainingStatus _effectiveStatus(Training training) {
    final expiration = training.expirationDate;
    if (expiration == null) return training.status;
    if (expiration.isBefore(DateTime.now())) {
      return TrainingStatus.expired;
    }
    final days = expiration.difference(DateTime.now()).inDays;
    if (days <= AppConstants.certificationExpiryWarningDays &&
        training.status == TrainingStatus.certified) {
      return TrainingStatus.dueForRecert;
    }
    return training.status;
  }
}

class _ReminderSetting {
  _ReminderSetting({required this.label, required this.enabled});

  final String label;
  bool enabled;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
