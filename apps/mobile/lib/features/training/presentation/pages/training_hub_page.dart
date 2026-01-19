import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/training_provider.dart';
import '../../../dashboard/data/active_role_provider.dart';
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
    final role = ref.watch(activeRoleProvider);
    final canManageTraining = _canManageTraining(role);
    if (!canManageTraining) {
      return const _EmployeeTrainingHub();
    }
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

  bool _canManageTraining(UserRole role) {
    return role == UserRole.supervisor ||
        role == UserRole.manager ||
        role == UserRole.admin ||
        role == UserRole.superAdmin ||
        role == UserRole.developer;
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

class _EmployeeTrainingHub extends ConsumerStatefulWidget {
  const _EmployeeTrainingHub();

  @override
  ConsumerState<_EmployeeTrainingHub> createState() =>
      _EmployeeTrainingHubState();
}

class _EmployeeTrainingHubState extends ConsumerState<_EmployeeTrainingHub> {
  String _filterStatus = 'all';
  late DateTime _currentTime;
  RealtimeChannel? _trainingChannel;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _startClock();
    _subscribeToTrainingChanges();
  }

  @override
  void dispose() {
    _trainingChannel?.unsubscribe();
    super.dispose();
  }

  void _startClock() {
    Future<void>.delayed(const Duration(minutes: 1), () {
      if (!mounted) return;
      setState(() => _currentTime = DateTime.now());
      _startClock();
    });
  }

  void _subscribeToTrainingChanges() {
    final client = Supabase.instance.client;
    _trainingChannel = client.channel('employee-training-changes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'training_records',
        callback: (_) {
          if (!mounted) return;
          final employeeId = ref.read(currentEmployeeIdProvider).value;
          if (employeeId != null) {
            ref.invalidate(trainingRecordsProvider(employeeId));
          }
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final employeeIdAsync = ref.watch(currentEmployeeIdProvider);
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      body: employeeIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _ErrorView(message: 'Training error: $e'),
        data: (employeeId) {
          if (employeeId == null) {
            return _EmployeeEmptyState(
              message: 'No employee profile found for this account.',
            );
          }
          final trainingAsync = ref.watch(trainingRecordsProvider(employeeId));
          return trainingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => _ErrorView(message: 'Training error: $e'),
            data: (records) {
              final courses = records
                  .map((training) => _CourseView.fromTraining(training, _currentTime))
                  .toList();
              final filtered = _applyFilter(courses, _filterStatus);
              final certificates = records
                  .where((training) => _shouldShowCertificate(training))
                  .map((training) => _CertificateView.fromTraining(training, _currentTime))
                  .toList();
              final expiringSoon =
                  certificates.where((cert) => cert.isExpiringSoon).toList();
              final expired = certificates
                  .where((cert) => cert.urgency == _UrgencyLevel.expired)
                  .toList();
              final stats = _TrainingStats.fromCourses(courses, certificates);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth =
                      constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: maxWidth,
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(currentEmployeeIdProvider);
                          ref.invalidate(trainingRecordsProvider(employeeId));
                          await ref.read(trainingRecordsProvider(employeeId).future);
                        },
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _TrainingHeader(isDark: isDark),
                            const SizedBox(height: 16),
                            if (expired.isNotEmpty || expiringSoon.isNotEmpty)
                              _ActionRequiredBanner(
                                isDark: isDark,
                                expiredCount: expired.length,
                                expiringCount: expiringSoon.length,
                                onPressed: () => _showBannerAction(context),
                              ),
                            if (expired.isNotEmpty || expiringSoon.isNotEmpty)
                              const SizedBox(height: 16),
                            _StatsGrid(
                              stats: stats,
                              isDark: isDark,
                              maxWidth: maxWidth,
                            ),
                            const SizedBox(height: 16),
                            _FilterCard(
                              isDark: isDark,
                              filterStatus: _filterStatus,
                              onSelected: (value) =>
                                  setState(() => _filterStatus = value),
                            ),
                            const SizedBox(height: 16),
                            _CoursesSection(
                              isDark: isDark,
                              courses: filtered,
                              maxWidth: maxWidth,
                              totalCount: filtered.length,
                              now: _currentTime,
                              onCourseAction: (course) =>
                                  _handleCourseAction(context, course),
                            ),
                            const SizedBox(height: 16),
                            _CertificatesSection(
                              isDark: isDark,
                              certificates: certificates,
                              needsAttention: expiringSoon.length,
                              maxWidth: maxWidth,
                              onDownload: (certificate) =>
                                  _handleCertificateDownload(context, certificate),
                              onRenew: (certificate) =>
                                  _handleCertificateRenew(context, certificate),
                            ),
                            const SizedBox(height: 16),
                            _CEUTrackingSection(
                              isDark: isDark,
                              stats: stats,
                            ),
                            const SizedBox(height: 16),
                            _LearningPathSection(
                              isDark: isDark,
                              steps: _buildLearningPath(courses),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<_CourseView> _applyFilter(List<_CourseView> courses, String status) {
    if (status == 'all') return courses;
    switch (status) {
      case 'completed':
        return courses
            .where((course) => course.status == _CourseStatus.completed)
            .toList();
      case 'in-progress':
        return courses
            .where((course) => course.status == _CourseStatus.inProgress)
            .toList();
      case 'not-started':
        return courses
            .where((course) => course.status == _CourseStatus.notStarted)
            .toList();
    }
    return courses;
  }

  bool _shouldShowCertificate(Training training) {
    if (training.status == TrainingStatus.certified ||
        training.status == TrainingStatus.dueForRecert ||
        training.status == TrainingStatus.expired) {
      return true;
    }
    return training.certificateUrl != null;
  }

  void _showBannerAction(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact your supervisor to renew.')),
    );
  }

  Future<void> _handleCourseAction(
    BuildContext context,
    _CourseView course,
  ) async {
    final url = course.courseUrl;
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training content not linked yet.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid training link.')),
      );
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open training link.')),
    );
  }

  Future<void> _handleCertificateDownload(
    BuildContext context,
    _CertificateView certificate,
  ) async {
    final url = certificate.certificateUrl;
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certificate is not available.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid certificate link.')),
      );
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open certificate.')),
    );
  }

  void _handleCertificateRenew(BuildContext context, _CertificateView certificate) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request sent to your supervisor.')),
    );
  }

  List<_LearningPathStep> _buildLearningPath(List<_CourseView> courses) {
    if (courses.isEmpty) return const [];
    final completed =
        courses.where((course) => course.status == _CourseStatus.completed).toList();
    final inProgress =
        courses.where((course) => course.status == _CourseStatus.inProgress).toList();
    final upcoming =
        courses.where((course) => course.status == _CourseStatus.notStarted).toList();
    final steps = <_LearningPathStep>[];
    if (completed.isNotEmpty) {
      steps.add(
        _LearningPathStep(
          title: completed.first.title,
          status: _LearningPathStatus.completed,
        ),
      );
    }
    if (inProgress.isNotEmpty) {
      steps.add(
        _LearningPathStep(
          title: inProgress.first.title,
          status: _LearningPathStatus.current,
        ),
      );
    } else if (upcoming.isNotEmpty) {
      steps.add(
        _LearningPathStep(
          title: upcoming.first.title,
          status: _LearningPathStatus.current,
        ),
      );
      upcoming.removeAt(0);
    }
    for (final course in upcoming.take(2)) {
      steps.add(
        _LearningPathStep(
          title: course.title,
          status: _LearningPathStatus.upcoming,
        ),
      );
    }
    return steps;
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

enum _CourseStatus { completed, inProgress, notStarted, locked }

enum _UrgencyLevel { expired, critical, warning, attention, valid }

enum _LearningPathStatus { completed, current, upcoming }

class _CourseView {
  const _CourseView({
    required this.training,
    required this.title,
    required this.status,
    required this.effectiveStatus,
    required this.progress,
    required this.category,
    this.instructor,
    this.duration,
    this.modules,
    this.location,
    this.rating,
    this.ceuCredits,
    this.expirationDate,
    this.requiresRenewal = false,
    this.courseUrl,
    this.isLocked = false,
  });

  final Training training;
  final String title;
  final _CourseStatus status;
  final TrainingStatus effectiveStatus;
  final int progress;
  final String category;
  final String? instructor;
  final String? duration;
  final int? modules;
  final String? location;
  final double? rating;
  final double? ceuCredits;
  final DateTime? expirationDate;
  final bool requiresRenewal;
  final String? courseUrl;
  final bool isLocked;

  factory _CourseView.fromTraining(Training training, DateTime now) {
    final metadata = training.metadata ?? const <String, dynamic>{};
    final locked = _boolFromMetadata(metadata, ['locked', 'isLocked']) ?? false;
    final effectiveStatus = _effectiveStatus(training, now);
    final status = locked
        ? _CourseStatus.locked
        : _courseStatusFromTraining(effectiveStatus);
    final rawProgress = _doubleFromMetadata(metadata, ['progress', 'completion']);
    final progress = rawProgress != null
        ? _clampProgress(rawProgress)
        : _defaultProgress(status);
    final instructor = _stringFromMetadata(metadata, ['instructor']) ??
        training.instructorName;
    final duration = _durationFromMetadata(metadata);
    final modules = _intFromMetadata(metadata, ['modules', 'moduleCount']) ??
        (training.materials != null && training.materials!.isNotEmpty
            ? training.materials!.length
            : null);
    final location = training.location ??
        _stringFromMetadata(metadata, ['location', 'site']);
    final rating = _doubleFromMetadata(metadata, ['rating']);
    final category = training.trainingType?.trim().isNotEmpty == true
        ? training.trainingType!.trim()
        : _stringFromMetadata(metadata, ['category']) ?? 'Training';
    final courseUrl =
        _stringFromMetadata(metadata, ['courseUrl', 'course_url', 'link']);
    final requiresRenewal = _boolFromMetadata(
          metadata,
          ['requiresRenewal', 'renewalRequired'],
        ) ??
        training.expirationDate != null;
    return _CourseView(
      training: training,
      title: training.trainingName,
      status: status,
      effectiveStatus: effectiveStatus,
      progress: progress,
      category: category,
      instructor: instructor,
      duration: duration,
      modules: modules,
      location: location,
      rating: rating,
      ceuCredits: training.ceuCredits ??
          _doubleFromMetadata(metadata, ['ceuCredits', 'ceu']),
      expirationDate: training.expirationDate,
      requiresRenewal: requiresRenewal,
      courseUrl: courseUrl,
      isLocked: locked,
    );
  }
}

class _CertificateView {
  const _CertificateView({
    required this.training,
    required this.name,
    required this.urgency,
    this.issueDate,
    this.expiryDate,
    this.location,
    this.instructor,
    this.ceuCredits,
    this.renewalRequired = false,
    this.daysUntilExpiry,
    this.certificateUrl,
  });

  final Training training;
  final String name;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? location;
  final String? instructor;
  final double? ceuCredits;
  final bool renewalRequired;
  final int? daysUntilExpiry;
  final _UrgencyLevel urgency;
  final String? certificateUrl;

  bool get isExpiringSoon {
    if (daysUntilExpiry == null) return false;
    return daysUntilExpiry! >= 0 &&
        daysUntilExpiry! <= AppConstants.certificationExpiryWarningDays;
  }

  factory _CertificateView.fromTraining(Training training, DateTime now) {
    final metadata = training.metadata ?? const <String, dynamic>{};
    final issueDate = training.completedDate ??
        _dateFromMetadata(metadata, ['issueDate', 'issuedDate']);
    final expiryDate = training.expirationDate ??
        _dateFromMetadata(metadata, ['expiryDate', 'expirationDate']);
    final daysUntilExpiry = _daysUntilExpiration(expiryDate, now);
    final urgency = _urgencyForDays(daysUntilExpiry);
    final renewalRequired = _boolFromMetadata(
          metadata,
          ['requiresRenewal', 'renewalRequired'],
        ) ??
        expiryDate != null;
    return _CertificateView(
      training: training,
      name: training.trainingName,
      issueDate: issueDate,
      expiryDate: expiryDate,
      location: training.location ??
          _stringFromMetadata(metadata, ['location', 'site']),
      instructor: training.instructorName ??
          _stringFromMetadata(metadata, ['instructor']),
      ceuCredits: training.ceuCredits ??
          _doubleFromMetadata(metadata, ['ceuCredits', 'ceu']),
      renewalRequired: renewalRequired,
      daysUntilExpiry: daysUntilExpiry,
      urgency: urgency,
      certificateUrl: training.certificateUrl ??
          _stringFromMetadata(metadata, ['certificateUrl', 'certificate_url']),
    );
  }
}

class _TrainingStats {
  const _TrainingStats({
    required this.totalCourses,
    required this.completedCourses,
    required this.inProgressCourses,
    required this.overallProgress,
    required this.certificateCount,
    required this.expiringCertificates,
    required this.ceuEarned,
    required this.ceuRequired,
  });

  final int totalCourses;
  final int completedCourses;
  final int inProgressCourses;
  final int overallProgress;
  final int certificateCount;
  final int expiringCertificates;
  final double ceuEarned;
  final int ceuRequired;

  int get ceuRemaining {
    final remaining = (ceuRequired - ceuEarned).ceil();
    if (remaining < 0) return 0;
    if (remaining > ceuRequired) return ceuRequired;
    return remaining;
  }

  double get ceuProgress {
    if (ceuRequired == 0) return 0;
    return (ceuEarned / ceuRequired) * 100;
  }

  factory _TrainingStats.fromCourses(
    List<_CourseView> courses,
    List<_CertificateView> certificates,
  ) {
    final totalCourses = courses.length;
    final completedCourses =
        courses.where((course) => course.status == _CourseStatus.completed).length;
    final inProgressCourses =
        courses.where((course) => course.status == _CourseStatus.inProgress).length;
    final overallProgress = totalCourses == 0
        ? 0
        : (courses.fold<int>(0, (sum, course) => sum + course.progress) /
                totalCourses)
            .round();
    final expiringCertificates =
        certificates.where((cert) => cert.isExpiringSoon).length;
    final ceuEarned = courses
        .where((course) =>
            course.status == _CourseStatus.completed && course.ceuCredits != null)
        .fold<double>(0, (sum, course) => sum + (course.ceuCredits ?? 0));
    return _TrainingStats(
      totalCourses: totalCourses,
      completedCourses: completedCourses,
      inProgressCourses: inProgressCourses,
      overallProgress: overallProgress,
      certificateCount: certificates.length,
      expiringCertificates: expiringCertificates,
      ceuEarned: ceuEarned,
      ceuRequired: 30,
    );
  }
}

class _LearningPathStep {
  const _LearningPathStep({required this.title, required this.status});

  final String title;
  final _LearningPathStatus status;
}

class _TrainingHeader extends StatelessWidget {
  const _TrainingHeader({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Training & Certification Management',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Complete required training, track certifications, and earn CEU credits',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
        ),
      ],
    );
  }
}

class _ActionRequiredBanner extends StatelessWidget {
  const _ActionRequiredBanner({
    required this.isDark,
    required this.expiredCount,
    required this.expiringCount,
    required this.onPressed,
  });

  final bool isDark;
  final int expiredCount;
  final int expiringCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hasExpired = expiredCount > 0;
    final background = hasExpired
        ? (isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEE2E2))
        : (isDark ? const Color(0xFF3D2F0E) : const Color(0xFFFEF3C7));
    final border = hasExpired
        ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA))
        : (isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A));
    final text = hasExpired
        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
        : (isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E));
    final buttonColor = hasExpired
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: text,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasExpired
                      ? 'URGENT: Expired Certifications'
                      : 'Action Required: Certifications Expiring Soon',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                ),
                const SizedBox(height: 6),
                if (hasExpired)
                  Text(
                    '• $expiredCount certification(s) have EXPIRED and must be renewed immediately',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: text),
                  ),
                if (expiringCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• $expiringCount certification(s) expiring within 30 days - schedule renewal now',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: text),
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Review & Renew Now'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.stats,
    required this.isDark,
    required this.maxWidth,
  });

  final _TrainingStats stats;
  final bool isDark;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final columns = maxWidth >= 1024
        ? 6
        : maxWidth >= 768
            ? 3
            : 2;
    final spacing = 16.0;
    final itemWidth = (maxWidth - (columns - 1) * spacing) / columns;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        SizedBox(
          width: itemWidth,
          child: _StatCard(
            isDark: isDark,
            title: 'Total Courses',
            value: stats.totalCourses.toString(),
            subtitle: 'Available to you',
            icon: Icons.menu_book_outlined,
            iconColor: const Color(0xFF3B82F6),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: _StatCard(
            isDark: isDark,
            title: 'Completed',
            value: stats.completedCourses.toString(),
            subtitle: 'Certificates earned',
            icon: Icons.check_circle,
            iconColor: const Color(0xFF22C55E),
            subtitleColor:
                isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: _StatCard(
            isDark: isDark,
            title: 'In Progress',
            value: stats.inProgressCourses.toString(),
            subtitle: 'Currently learning',
            icon: Icons.schedule,
            iconColor: const Color(0xFF3B82F6),
            subtitleColor:
                isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: _StatCard(
            isDark: isDark,
            title: 'Overall Progress',
            value: '${stats.overallProgress}%',
            subtitle: 'Across assigned courses',
            icon: Icons.trending_up,
            iconColor: const Color(0xFF8B5CF6),
            progress: stats.overallProgress / 100,
            progressColor: const Color(0xFF7C3AED),
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: _StatCard(
            isDark: isDark,
            title: 'Certificates',
            value: stats.certificateCount.toString(),
            subtitle: stats.expiringCertificates > 0
                ? '${stats.expiringCertificates} expiring soon'
                : 'Active credentials',
            icon: Icons.workspace_premium,
            iconColor: const Color(0xFFF59E0B),
            subtitleColor: stats.expiringCertificates > 0
                ? const Color(0xFFF59E0B)
                : null,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: _StatCard(
            isDark: isDark,
            title: 'CEU Credits',
            value: '${stats.ceuEarned.toStringAsFixed(0)}/${stats.ceuRequired}',
            subtitle: 'Annual requirement',
            icon: Icons.school,
            iconColor: const Color(0xFF6366F1),
            progress: stats.ceuProgress / 100,
            progressColor: const Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.isDark,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.subtitleColor,
    this.progress,
    this.progressColor,
  });

  final bool isDark;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color? subtitleColor;
  final double? progress;
  final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: muted, fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: subtitleColor ?? muted),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                color: progressColor ?? iconColor,
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.isDark,
    required this.filterStatus,
    required this.onSelected,
  });

  final bool isDark;
  final String filterStatus;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Filter by:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                ),
          ),
          _FilterChipButton(
            label: 'All Courses',
            value: 'all',
            selected: filterStatus == 'all',
            isDark: isDark,
            onSelected: onSelected,
          ),
          _FilterChipButton(
            label: 'Completed',
            value: 'completed',
            selected: filterStatus == 'completed',
            isDark: isDark,
            onSelected: onSelected,
          ),
          _FilterChipButton(
            label: 'In Progress',
            value: 'in-progress',
            selected: filterStatus == 'in-progress',
            isDark: isDark,
            onSelected: onSelected,
          ),
          _FilterChipButton(
            label: 'Not Started',
            value: 'not-started',
            selected: filterStatus == 'not-started',
            isDark: isDark,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.isDark,
    required this.onSelected,
  });

  final String label;
  final String value;
  final bool selected;
  final bool isDark;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? const Color(0xFF2563EB)
        : isDark
            ? const Color(0xFF374151)
            : const Color(0xFFF3F4F6);
    final textColor = selected
        ? Colors.white
        : isDark
            ? const Color(0xFFD1D5DB)
            : const Color(0xFF374151);
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w600, color: textColor),
        ),
      ),
    );
  }
}

class _CoursesSection extends StatelessWidget {
  const _CoursesSection({
    required this.isDark,
    required this.courses,
    required this.maxWidth,
    required this.totalCount,
    required this.now,
    required this.onCourseAction,
  });

  final bool isDark;
  final List<_CourseView> courses;
  final double maxWidth;
  final int totalCount;
  final DateTime now;
  final ValueChanged<_CourseView> onCourseAction;

  @override
  Widget build(BuildContext context) {
    final columns = maxWidth >= 1024
        ? 3
        : maxWidth >= 768
            ? 2
            : 1;
    final spacing = 16.0;
    final itemWidth = (maxWidth - (columns - 1) * spacing) / columns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Courses',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
            ),
            Text(
              '$totalCount courses',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (courses.isEmpty)
          _SectionEmptyCard(
            isDark: isDark,
            title: 'No courses assigned',
            subtitle: 'Training will appear here when assigned.',
          )
        else
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: courses
                .map(
                  (course) => SizedBox(
                    width: itemWidth,
                  child: _CourseCard(
                      isDark: isDark,
                      course: course,
                      now: now,
                      onAction: () => onCourseAction(course),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.isDark,
    required this.course,
    required this.now,
    required this.onAction,
  });

  final bool isDark;
  final _CourseView course;
  final DateTime now;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final statusColor = _courseStatusColor(course.status);
    final iconColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280);
    final daysUntilExpiry = _daysUntilExpiration(course.expirationDate, now);
    final urgency = _urgencyForDays(daysUntilExpiry);
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        course.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                      ),
                    ),
                    if (course.status == _CourseStatus.locked)
                      Icon(Icons.lock_outline, color: iconColor),
                    if (course.status == _CourseStatus.completed)
                      const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.people_alt_outlined,
                  label: course.instructor ?? 'Instructor not set',
                  color: muted,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.schedule,
                  label: _durationLabel(course.duration, course.modules),
                  color: muted,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: course.location ?? 'Location not set',
                  color: muted,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.star, color: const Color(0xFFFBBF24), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      course.rating?.toStringAsFixed(1) ?? 'No rating',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(
                      label: course.category,
                      background: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFF3F4F6),
                      textColor:
                          isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                    ),
                    if (course.ceuCredits != null) ...[
                      const SizedBox(width: 6),
                      _Badge(
                        label: '${course.ceuCredits!.toStringAsFixed(0)} CEU',
                        background: isDark
                            ? const Color(0xFF312E81)
                            : const Color(0xFFE0E7FF),
                        textColor:
                            isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                      ),
                    ],
                  ],
                ),
                if (course.status != _CourseStatus.locked) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: muted),
                      ),
                      Text(
                        '${course.progress}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark ? Colors.white : const Color(0xFF111827),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: course.progress / 100,
                      minHeight: 8,
                      backgroundColor: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                      color: course.status == _CourseStatus.completed
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF2563EB),
                    ),
                  ),
                ],
                if (course.expirationDate != null) ...[
                  const SizedBox(height: 12),
                  _ExpiryBanner(
                    isDark: isDark,
                    urgency: urgency,
                    daysUntilExpiry: daysUntilExpiry,
                    expiryDate: course.expirationDate!,
                    requiresRenewal: course.requiresRenewal,
                    onRenew: () => _showRenewSnackBar(context),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: course.isLocked ? null : onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: course.isLocked
                          ? (isDark
                              ? const Color(0xFF374151)
                              : const Color(0xFFF3F4F6))
                          : const Color(0xFF2563EB),
                      foregroundColor: course.isLocked
                          ? (isDark
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF9CA3AF))
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      course.isLocked ? Icons.lock_outline : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(
                      course.isLocked
                          ? 'Locked'
                          : course.status == _CourseStatus.completed
                              ? 'Review Course'
                              : course.status == _CourseStatus.inProgress
                                  ? 'Continue Learning'
                                  : 'Start Course',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _durationLabel(String? duration, int? modules) {
    final buffer = <String>[];
    if (duration != null && duration.trim().isNotEmpty) {
      buffer.add(duration.trim());
    } else {
      buffer.add('Duration not set');
    }
    if (modules != null && modules > 0) {
      buffer.add('$modules modules');
    }
    return buffer.join(' • ');
  }

  void _showRenewSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact your supervisor to renew.')),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.textColor,
  });

  final String label;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
      ),
    );
  }
}

class _ExpiryBanner extends StatelessWidget {
  const _ExpiryBanner({
    required this.isDark,
    required this.urgency,
    required this.daysUntilExpiry,
    required this.expiryDate,
    required this.requiresRenewal,
    this.onRenew,
  });

  final bool isDark;
  final _UrgencyLevel urgency;
  final int? daysUntilExpiry;
  final DateTime expiryDate;
  final bool requiresRenewal;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final tone = _urgencyTone(urgency, isDark);
    final daysLabel = daysUntilExpiry == null
        ? 'No expiration date'
        : daysUntilExpiry! < 0
            ? 'EXPIRED'
            : urgency == _UrgencyLevel.critical
                ? 'URGENT: Expires in $daysUntilExpiry days'
                : 'Expires in $daysUntilExpiry days';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: tone.border, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: tone.text),
              const SizedBox(width: 6),
              Text(
                daysLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.text,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            daysUntilExpiry != null && daysUntilExpiry! < 0
                ? 'Expired on ${DateFormat.yMd().format(expiryDate)} - Renewal Required'
                : 'Expiry Date: ${DateFormat.yMd().format(expiryDate)}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: tone.text),
          ),
          if (requiresRenewal &&
              daysUntilExpiry != null &&
              daysUntilExpiry! <= AppConstants.certificationExpiryWarningDays) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onRenew,
              style: ElevatedButton.styleFrom(
                backgroundColor: urgency == _UrgencyLevel.expired ||
                        urgency == _UrgencyLevel.critical
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Schedule Renewal'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CertificatesSection extends StatelessWidget {
  const _CertificatesSection({
    required this.isDark,
    required this.certificates,
    required this.needsAttention,
    required this.maxWidth,
    required this.onDownload,
    required this.onRenew,
  });

  final bool isDark;
  final List<_CertificateView> certificates;
  final int needsAttention;
  final double maxWidth;
  final ValueChanged<_CertificateView> onDownload;
  final ValueChanged<_CertificateView> onRenew;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final columns = maxWidth >= 1024
        ? 3
        : maxWidth >= 768
            ? 2
            : 1;
    final spacing = 16.0;
    final itemWidth = (maxWidth - (columns - 1) * spacing) / columns;
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Text(
                      'My Certificates & Credentials',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                    ),
                  ],
                ),
                if (needsAttention > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '$needsAttention Need Attention',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (certificates.isEmpty)
              _SectionEmptyCard(
                isDark: isDark,
                title: 'No certificates yet',
                subtitle: 'Completed certifications will appear here.',
              )
            else
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: certificates
                    .map(
                      (certificate) => SizedBox(
                        width: itemWidth,
                        child: _CertificateCard(
                          isDark: isDark,
                          certificate: certificate,
                          onDownload: () => onDownload(certificate),
                          onRenew: () => onRenew(certificate),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({
    required this.isDark,
    required this.certificate,
    required this.onDownload,
    required this.onRenew,
  });

  final bool isDark;
  final _CertificateView certificate;
  final VoidCallback onDownload;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final tone = _urgencyTone(certificate.urgency, isDark);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.workspace_premium, color: Color(0xFFF59E0B)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Badge(
                    label: _urgencyLabel(certificate.urgency),
                    background: tone.badge,
                    textColor: tone.text,
                  ),
                  if (certificate.renewalRequired) ...[
                    const SizedBox(height: 6),
                    _Badge(
                      label: 'Renewable',
                      background: isDark
                          ? const Color(0xFF312E81)
                          : const Color(0xFFE0E7FF),
                      textColor:
                          isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            certificate.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tone.badge.withOpacity(isDark ? 0.6 : 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  certificate.daysUntilExpiry == null
                      ? 'No expiration'
                      : certificate.daysUntilExpiry! < 0
                          ? 'EXPIRED'
                          : '${certificate.daysUntilExpiry} days',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tone.text,
                      ),
                ),
                Text(
                  certificate.daysUntilExpiry == null
                      ? 'No expiration date'
                      : certificate.daysUntilExpiry! < 0
                          ? 'Renewal required'
                          : 'until expiration',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: tone.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Issued: ${_formatDate(certificate.issueDate)}',
            color: muted,
          ),
          const SizedBox(height: 6),
          _DetailRow(
            icon: Icons.schedule_outlined,
            label: 'Expires: ${_formatDate(certificate.expiryDate)}',
            color: muted,
          ),
          const SizedBox(height: 6),
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: certificate.location ?? 'Location not set',
            color: muted,
          ),
          const SizedBox(height: 6),
          _DetailRow(
            icon: Icons.people_alt_outlined,
            label: certificate.instructor ?? 'Instructor not set',
            color: muted,
          ),
          const SizedBox(height: 6),
          _DetailRow(
            icon: Icons.school_outlined,
            label: certificate.ceuCredits == null
                ? 'CEU credits not set'
                : '${certificate.ceuCredits!.toStringAsFixed(0)} CEU Credits',
            color: muted,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                    side: BorderSide(
                      color:
                          isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (certificate.renewalRequired &&
                  certificate.daysUntilExpiry != null &&
                  certificate.daysUntilExpiry! <=
                      AppConstants.certificationExpiryWarningDays) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRenew,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          certificate.urgency == _UrgencyLevel.expired ||
                                  certificate.urgency == _UrgencyLevel.critical
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      certificate.urgency == _UrgencyLevel.expired
                          ? 'Renew Now'
                          : 'Schedule',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _CEUTrackingSection extends StatelessWidget {
  const _CEUTrackingSection({required this.isDark, required this.stats});

  final bool isDark;
  final _TrainingStats stats;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final year = DateTime.now().year;
    final ceuProgress = stats.ceuProgress.clamp(0, 100);
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.school, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    'CEU Credit Tracking',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                  ),
                ],
              ),
              Text(
                'Annual Period: Jan $year - Dec $year',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricTile(
                isDark: isDark,
                label: 'Credits Earned',
                value: stats.ceuEarned.toStringAsFixed(0),
              ),
              _MetricTile(
                isDark: isDark,
                label: 'Credits Required',
                value: stats.ceuRequired.toString(),
              ),
              _MetricTile(
                isDark: isDark,
                label: 'Credits Remaining',
                value: stats.ceuRemaining.toString(),
                highlight: stats.ceuEarned >= stats.ceuRequired,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Progress',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF374151),
                    ),
              ),
              Text(
                '${ceuProgress.round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: stats.ceuEarned >= stats.ceuRequired
                          ? const Color(0xFF22C55E)
                          : isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ceuProgress / 100,
              minHeight: 8,
              backgroundColor:
                  isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              color: stats.ceuEarned >= stats.ceuRequired
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF6366F1),
            ),
          ),
          if (stats.ceuEarned >= stats.ceuRequired) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF166534) : const Color(0xFF86EFAC),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Annual CEU Requirement Met!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF166534),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.isDark,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final bool isDark;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final background = isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);
    final valueColor = highlight
        ? const Color(0xFF22C55E)
        : isDark
            ? Colors.white
            : const Color(0xFF111827);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _LearningPathSection extends StatelessWidget {
  const _LearningPathSection({
    required this.isDark,
    required this.steps,
  });

  final bool isDark;
  final List<_LearningPathStep> steps;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Learning Path',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 12),
          if (steps.isEmpty)
            Text(
              'Assignments will appear as they are added.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                  ),
            )
          else
            ...steps.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    _LearningStepIndicator(
                      status: entry.value.status,
                      index: entry.key + 1,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  entry.value.status == _LearningPathStatus.current
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                              decoration:
                                  entry.value.status ==
                                          _LearningPathStatus.completed
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                              color: entry.value.status ==
                                      _LearningPathStatus.completed
                                  ? const Color(0xFF9CA3AF)
                                  : isDark
                                      ? Colors.white
                                      : const Color(0xFF111827),
                            ),
                      ),
                    ),
                    if (entry.value.status == _LearningPathStatus.current)
                      _Badge(
                        label: 'Current',
                        background: isDark
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFFDBEAFE),
                        textColor:
                            isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
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

class _LearningStepIndicator extends StatelessWidget {
  const _LearningStepIndicator({required this.status, required this.index});

  final _LearningPathStatus status;
  final int index;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color textColor;
    switch (status) {
      case _LearningPathStatus.completed:
        background = const Color(0xFF22C55E);
        textColor = Colors.white;
        break;
      case _LearningPathStatus.current:
        background = const Color(0xFF2563EB);
        textColor = Colors.white;
        break;
      case _LearningPathStatus.upcoming:
        background = const Color(0xFFE5E7EB);
        textColor = const Color(0xFF6B7280);
        break;
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: status == _LearningPathStatus.completed
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : Text(
              index.toString(),
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: textColor),
            ),
    );
  }
}

class _SectionEmptyCard extends StatelessWidget {
  const _SectionEmptyCard({
    required this.isDark,
    required this.title,
    required this.subtitle,
  });

  final bool isDark;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
                ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeEmptyState extends StatelessWidget {
  const _EmployeeEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _UrgencyTone {
  const _UrgencyTone({
    required this.background,
    required this.border,
    required this.text,
    required this.badge,
  });

  final Color background;
  final Color border;
  final Color text;
  final Color badge;
}

_UrgencyTone _urgencyTone(_UrgencyLevel level, bool isDark) {
  switch (level) {
    case _UrgencyLevel.expired:
    case _UrgencyLevel.critical:
      return _UrgencyTone(
        background: isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEE2E2),
        border: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
        text: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
        badge: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
      );
    case _UrgencyLevel.warning:
      return _UrgencyTone(
        background: isDark ? const Color(0xFF3D2F0E) : const Color(0xFFFEF3C7),
        border: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
        text: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
        badge: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
      );
    case _UrgencyLevel.attention:
      return _UrgencyTone(
        background: isDark ? const Color(0xFF2C2F10) : const Color(0xFFFDF6B2),
        border: isDark ? const Color(0xFF6B5E00) : const Color(0xFFFDE047),
        text: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
        badge: isDark ? const Color(0xFF6B5E00) : const Color(0xFFFDE047),
      );
    case _UrgencyLevel.valid:
      return _UrgencyTone(
        background: isDark ? const Color(0xFF0F2E1D) : const Color(0xFFDCFCE7),
        border: isDark ? const Color(0xFF166534) : const Color(0xFF86EFAC),
        text: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
        badge: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0),
      );
  }
}

String _urgencyLabel(_UrgencyLevel level) {
  switch (level) {
    case _UrgencyLevel.expired:
      return 'EXPIRED';
    case _UrgencyLevel.critical:
      return 'CRITICAL';
    case _UrgencyLevel.warning:
      return 'EXPIRING SOON';
    case _UrgencyLevel.attention:
      return 'ATTENTION';
    case _UrgencyLevel.valid:
      return 'VALID';
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Not recorded';
  return DateFormat.yMd().format(date);
}

_CourseStatus _courseStatusFromTraining(TrainingStatus status) {
  switch (status) {
    case TrainingStatus.inProgress:
      return _CourseStatus.inProgress;
    case TrainingStatus.notStarted:
    case TrainingStatus.failed:
      return _CourseStatus.notStarted;
    case TrainingStatus.certified:
    case TrainingStatus.dueForRecert:
    case TrainingStatus.expired:
      return _CourseStatus.completed;
  }
}

TrainingStatus _effectiveStatus(Training training, DateTime now) {
  final expiration = training.expirationDate;
  if (expiration == null) return training.status;
  if (expiration.isBefore(now)) {
    return TrainingStatus.expired;
  }
  final days = expiration.difference(now).inDays;
  if (days <= AppConstants.certificationExpiryWarningDays &&
      training.status == TrainingStatus.certified) {
    return TrainingStatus.dueForRecert;
  }
  return training.status;
}

int _defaultProgress(_CourseStatus status) {
  switch (status) {
    case _CourseStatus.completed:
      return 100;
    case _CourseStatus.inProgress:
      return 50;
    case _CourseStatus.notStarted:
    case _CourseStatus.locked:
      return 0;
  }
}

int _clampProgress(double value) {
  final rounded = value.round();
  if (rounded < 0) return 0;
  if (rounded > 100) return 100;
  return rounded;
}

int? _daysUntilExpiration(DateTime? expiration, DateTime now) {
  if (expiration == null) return null;
  final diff = expiration.difference(now).inDays;
  return diff;
}

_UrgencyLevel _urgencyForDays(int? days) {
  if (days == null) return _UrgencyLevel.valid;
  if (days < 0) return _UrgencyLevel.expired;
  if (days <= 7) return _UrgencyLevel.critical;
  if (days <= 14) return _UrgencyLevel.warning;
  if (days <= 30) return _UrgencyLevel.attention;
  return _UrgencyLevel.valid;
}

Color _courseStatusColor(_CourseStatus status) {
  switch (status) {
    case _CourseStatus.completed:
      return const Color(0xFF22C55E);
    case _CourseStatus.inProgress:
      return const Color(0xFF3B82F6);
    case _CourseStatus.locked:
      return const Color(0xFF9CA3AF);
    case _CourseStatus.notStarted:
      return const Color(0xFFF59E0B);
  }
}

String? _stringFromMetadata(Map<String, dynamic> metadata, List<String> keys) {
  for (final key in keys) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

double? _doubleFromMetadata(Map<String, dynamic> metadata, List<String> keys) {
  for (final key in keys) {
    final value = metadata[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

int? _intFromMetadata(Map<String, dynamic> metadata, List<String> keys) {
  for (final key in keys) {
    final value = metadata[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

bool? _boolFromMetadata(Map<String, dynamic> metadata, List<String> keys) {
  for (final key in keys) {
    final value = metadata[key];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
  }
  return null;
}

DateTime? _dateFromMetadata(Map<String, dynamic> metadata, List<String> keys) {
  for (final key in keys) {
    final value = metadata[key];
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String? _durationFromMetadata(Map<String, dynamic> metadata) {
  final raw = _stringFromMetadata(metadata, ['duration', 'durationText']);
  if (raw != null) return raw;
  final minutes = _doubleFromMetadata(metadata, ['durationMinutes', 'minutes']);
  if (minutes != null) {
    return '${minutes.toStringAsFixed(0)} mins';
  }
  final hours = _doubleFromMetadata(metadata, ['durationHours', 'hours']);
  if (hours != null) {
    final formatted = hours % 1 == 0
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
    return '$formatted hours';
  }
  return null;
}
