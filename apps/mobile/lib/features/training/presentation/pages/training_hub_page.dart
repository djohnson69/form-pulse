import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

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
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Training Hub'),
          actions: [
            IconButton(
              tooltip: 'Add employee',
              icon: const Icon(Icons.person_add),
              onPressed: () => _openEmployeeEditor(context),
            ),
            IconButton(
              tooltip: 'Assign training',
              icon: const Icon(Icons.school),
              onPressed: () => _openTrainingEditor(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Training'),
              Tab(text: 'Employees'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TrainingRecordsTab(),
            EmployeesTab(),
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
    final status = _effectiveStatus(training).displayName;
    final expires = training.expirationDate;
    final expiresText = expires == null
        ? 'No expiration'
        : 'Expires ${expires.month}/${expires.day}/${expires.year}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.school),
        title: Text(training.trainingName),
        subtitle: Text(
          [
            if (employee != null) employee!.fullName,
            status,
            expiresText,
          ].join(' • '),
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
