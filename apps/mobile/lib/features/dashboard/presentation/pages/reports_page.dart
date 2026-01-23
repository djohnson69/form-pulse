import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/csv_utils.dart';
import '../../../../core/utils/submission_utils.dart';
import '../../data/dashboard_provider.dart';
import '../../data/dashboard_repository.dart';
import 'submission_detail_page.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({
    super.key,
    this.initialSubmittedBy,
    this.initialHasLocation,
    this.initialLat,
    this.initialLng,
    this.initialRadiusKm,
  });

  final String? initialSubmittedBy;
  final bool? initialHasLocation;
  final double? initialLat;
  final double? initialLng;
  final double? initialRadiusKm;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTimeRange? _range;
  SubmissionStatus? _status;
  String? _formId;
  String? _submittedBy;
  UserRole? _submitterRole;
  String? _provider;
  bool _hasLocation = false;
  String? _inputType;
  String? _accessLevel;
  String _query = '';
  String _fieldKey = '';
  String _fieldValue = '';
  double? _centerLat;
  double? _centerLng;
  double? _radiusKm;
  Map<String, UserRole> _submitterRoles = const {};

  late Future<List<FormSubmission>> _future;
  final _queryController = TextEditingController();
  final _fieldKeyController = TextEditingController();
  final _fieldValueController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();
  RealtimeChannel? _submissionsChannel;

  @override
  void initState() {
    super.initState();
    _submittedBy = widget.initialSubmittedBy;
    _centerLat = widget.initialLat;
    _centerLng = widget.initialLng;
    _radiusKm = widget.initialRadiusKm;
    _hasLocation = widget.initialHasLocation ??
        (widget.initialLat != null && widget.initialLng != null);
    if (_centerLat != null) {
      _latController.text = _centerLat!.toString();
    }
    if (_centerLng != null) {
      _lngController.text = _centerLng!.toString();
    }
    if (_radiusKm != null) {
      _radiusController.text = _radiusKm!.toString();
    }
    _future = _load();
    _subscribeToSubmissionChanges();
  }

  @override
  void dispose() {
    _submissionsChannel?.unsubscribe();
    _queryController.dispose();
    _fieldKeyController.dispose();
    _fieldValueController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _subscribeToSubmissionChanges() {
    final client = Supabase.instance.client;
    _submissionsChannel = client.channel('report-submissions')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'submissions',
        callback: (_) {
          if (!mounted) return;
          _refresh();
        },
      )
      ..subscribe();
  }

  Future<List<FormSubmission>> _load() {
    final repo = ref.read(dashboardRepositoryProvider);
    return repo.fetchSubmissions(
      filters: SubmissionFilters(
        status: _status,
        formId: _formId,
        startDate: _range?.start,
        endDate: _range?.end,
      ),
    ).then((submissions) async {
      await _refreshSubmitterRoles(submissions);
      return submissions;
    });
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final forms = ref.watch(dashboardDataProvider).asData?.value.forms ??
        const <FormDefinition>[];
    return Scaffold(
      body: FutureBuilder<List<FormSubmission>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorCard(
              message: 'Unable to load submissions.',
              details: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          final submissions = snapshot.data ?? const <FormSubmission>[];
          final providerOptions = _providerOptions(submissions);
          final filtered = _applyClientFilters(submissions);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ReportsHeader(onRefresh: _refresh),
              const SizedBox(height: 12),
              _buildQuickFilters(context),
              const SizedBox(height: 12),
              _FiltersCard(
                range: _range,
                status: _status,
                formId: _formId,
                submittedBy: _submittedBy,
                submitterRole: _submitterRole,
                provider: _provider,
                hasLocation: _hasLocation,
                inputType: _inputType,
                accessLevel: _accessLevel,
                forms: forms,
                submitters: _submitterOptions(submissions),
                providers: providerOptions,
                queryController: _queryController,
                fieldKeyController: _fieldKeyController,
                fieldValueController: _fieldValueController,
                latController: _latController,
                lngController: _lngController,
                radiusController: _radiusController,
                onRangePicked: (range) {
                  setState(() => _range = range);
                  _refresh();
                },
                onStatusChanged: (status) {
                  setState(() => _status = status);
                  _refresh();
                },
                onFormChanged: (id) {
                  setState(() => _formId = id);
                  _refresh();
                },
                onSubmittedByChanged: (value) {
                  setState(() => _submittedBy = value);
                },
                onSubmitterRoleChanged: (role) {
                  setState(() => _submitterRole = role);
                },
                onProviderChanged: (value) {
                  setState(() => _provider = value);
                },
                onHasLocationChanged: (value) {
                  setState(() => _hasLocation = value);
                },
                onInputTypeChanged: (value) {
                  setState(() => _inputType = value);
                },
                onAccessLevelChanged: (value) {
                  setState(() => _accessLevel = value);
                },
                onQueryChanged: (value) => setState(() => _query = value),
                onFieldKeyChanged: (value) => setState(() => _fieldKey = value),
                onFieldValueChanged: (value) => setState(() => _fieldValue = value),
                onGeoChanged: (lat, lng, radius) {
                  setState(() {
                    _centerLat = lat;
                    _centerLng = lng;
                    _radiusKm = radius;
                  });
                },
                onReset: () {
                  setState(() {
                    _range = null;
                    _status = null;
                    _formId = null;
                    _submittedBy = null;
                    _submitterRole = null;
                    _provider = null;
                    _hasLocation = false;
                    _inputType = null;
                    _accessLevel = null;
                    _query = '';
                    _fieldKey = '';
                    _fieldValue = '';
                    _centerLat = null;
                    _centerLng = null;
                    _radiusKm = null;
                    _queryController.text = '';
                    _fieldKeyController.text = '';
                    _fieldValueController.text = '';
                    _latController.text = '';
                    _lngController.text = '';
                    _radiusController.text = '';
                  });
                  _refresh();
                },
              ),
              const SizedBox(height: 16),
              _SummaryCard(
                submissions: filtered,
                onSelectForm: (formTitle) {
                  final match = forms.firstWhere(
                    (f) => f.title == formTitle,
                    orElse: () => FormDefinition(
                      id: '',
                      title: '',
                      description: '',
                      fields: const [],
                      createdBy: '',
                      createdAt: DateTime.now(),
                    ),
                  );
                  if (match.id.isEmpty) return;
                  setState(() => _formId = match.id);
                  _refresh();
                },
                onSelectSubmitter: (submitter) {
                  setState(() => _submittedBy = submitter);
                },
              ),
              const SizedBox(height: 16),
              _ExportRow(
                onExport: () => _exportCsv(filtered),
                count: filtered.length,
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                const _EmptyState()
              else
                ...filtered.map(
                  (submission) => _SubmissionTile(
                    submission: submission,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SubmissionDetailPage(submission: submission),
                        ),
                      );
                      ref.invalidate(dashboardDataProvider);
                      _refresh();
                    },
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickFilters(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: 'Needs review',
          selected: _status == SubmissionStatus.underReview,
          onSelected: (value) {
            setState(() => _status = value ? SubmissionStatus.underReview : null);
            _refresh();
          },
        ),
        _FilterChip(
          label: 'Requires changes',
          selected: _status == SubmissionStatus.requiresChanges,
          onSelected: (value) {
            setState(
              () => _status = value ? SubmissionStatus.requiresChanges : null,
            );
            _refresh();
          },
        ),
        _FilterChip(
          label: 'Approved',
          selected: _status == SubmissionStatus.approved,
          onSelected: (value) {
            setState(() => _status = value ? SubmissionStatus.approved : null);
            _refresh();
          },
        ),
        if (userId != null)
          _FilterChip(
            label: 'My submissions',
            selected: _submittedBy == userId,
            onSelected: (value) {
              setState(() => _submittedBy = value ? userId : null);
            },
          ),
        _FilterChip(
          label: 'Last 7 days',
          selected: _range != null &&
              _range!.start.isAfter(
                DateTime.now().subtract(const Duration(days: 7)),
              ),
          onSelected: (_) {
            final now = DateTime.now();
            setState(
              () => _range = DateTimeRange(
                start: now.subtract(const Duration(days: 7)),
                end: now,
              ),
            );
            _refresh();
          },
        ),
        _FilterChip(
          label: 'Has GPS',
          selected: _hasLocation,
          onSelected: (value) => setState(() => _hasLocation = value),
        ),
      ],
    );
  }

  Map<String, String> _submitterOptions(List<FormSubmission> submissions) {
    final options = <String, String>{};
    for (final submission in submissions) {
      final label = submission.submittedByName?.trim();
      if (label != null && label.isNotEmpty) {
        options[label] = label;
      } else if (submission.submittedBy.isNotEmpty) {
        options[submission.submittedBy] = submission.submittedBy;
      }
    }
    final sortedKeys = options.keys.toList()..sort();
    return {for (final key in sortedKeys) key: options[key]!};
  }

  Map<String, String> _providerOptions(List<FormSubmission> submissions) {
    final providers = submissions
        .map(resolveSubmissionProvider)
        .where((provider) => provider.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return {for (final provider in providers) provider: provider};
  }

  Future<void> _refreshSubmitterRoles(List<FormSubmission> submissions) async {
    final ids = submissions
        .map((submission) => submission.submittedBy)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      if (!mounted) return;
      setState(() => _submitterRoles = const {});
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id, role')
          .inFilter('id', ids);
      final roles = <String, UserRole>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null) continue;
        final rawRole = row['role']?.toString() ?? UserRole.viewer.name;
        roles[id] = UserRole.fromRaw(rawRole);
      }
      if (!mounted) return;
      setState(() => _submitterRoles = roles);
    } catch (e, st) {
      // Ignore role lookup failures; filter will be unavailable.
      developer.log('ReportsPage load submitter roles failed',
          error: e, stackTrace: st, name: 'ReportsPage._loadSubmitterRoles');
    }
  }

  List<FormSubmission> _applyClientFilters(List<FormSubmission> submissions) {
    final query = _query.trim().toLowerCase();
    final fieldKey = _fieldKey.trim().toLowerCase();
    final fieldValue = _fieldValue.trim().toLowerCase();
    final submittedBy = _submittedBy?.toLowerCase();

    return submissions.where((submission) {
      if (_submitterRole != null) {
        final role = _submitterRoles[submission.submittedBy];
        if (role != _submitterRole) return false;
      }
      if (_provider != null && _provider!.isNotEmpty) {
        final provider = resolveSubmissionProvider(submission);
        if (provider != _provider) return false;
      }
      if (_inputType != null && _inputType!.isNotEmpty) {
        final types = resolveSubmissionInputTypes(submission);
        if (!types.contains(_inputType)) return false;
      }
      if (_accessLevel != null && _accessLevel!.isNotEmpty) {
        final access = resolveSubmissionAccessLevel(submission);
        if (access != _accessLevel) return false;
      }
      if (submittedBy != null && submittedBy.isNotEmpty) {
        final byName = submission.submittedByName?.toLowerCase();
        final byId = submission.submittedBy.toLowerCase();
        if (byName != submittedBy && byId != submittedBy) return false;
      }
      if (_hasLocation && submission.location == null) return false;
      if (query.isNotEmpty && !_matchesQuery(submission, query)) return false;
      if (fieldKey.isNotEmpty) {
        final hasKey = submission.data.keys.any(
          (k) => k.toString().toLowerCase().contains(fieldKey),
        );
        if (!hasKey) return false;
        if (fieldValue.isNotEmpty) {
          final valueMatches = submission.data.entries.any((entry) {
            if (!entry.key.toString().toLowerCase().contains(fieldKey)) {
              return false;
            }
            return entry.value
                .toString()
                .toLowerCase()
                .contains(fieldValue);
          });
          if (!valueMatches) return false;
        }
      } else if (fieldValue.isNotEmpty) {
        final valueMatches = submission.data.values.any(
          (value) => value.toString().toLowerCase().contains(fieldValue),
        );
        if (!valueMatches) return false;
      }
      if (_centerLat != null &&
          _centerLng != null &&
          _radiusKm != null &&
          _radiusKm! > 0) {
        final location = submission.location;
        if (location == null) return false;
        final distance = _distanceKm(
          location.latitude,
          location.longitude,
          _centerLat!,
          _centerLng!,
        );
        if (distance > _radiusKm!) return false;
      }
      return true;
    }).toList();
  }

  bool _matchesQuery(FormSubmission submission, String query) {
    if (submission.formTitle.toLowerCase().contains(query)) return true;
    if ((submission.submittedByName ?? '').toLowerCase().contains(query)) {
      return true;
    }
    if (submission.submittedBy.toLowerCase().contains(query)) return true;
    return submission.data.entries.any(
      (entry) =>
          entry.key.toString().toLowerCase().contains(query) ||
          entry.value.toString().toLowerCase().contains(query),
    );
  }

  Future<void> _exportCsv(List<FormSubmission> submissions) async {
    if (submissions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submissions to export.')),
      );
      return;
    }
    final csv = buildSubmissionsCsv(submissions);
    final file = XFile.fromData(
      utf8.encode(csv),
      mimeType: 'text/csv',
      name: 'formbridge_submissions.csv',
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Form Bridge submissions export',
          files: [file],
        ),
      );
    } catch (e, st) {
      developer.log('ReportsPage shareXFiles failed, falling back',
          error: e, stackTrace: st, name: 'ReportsPage._exportCsv');
      await SharePlus.instance.share(ShareParams(text: csv));
    }
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.range,
    required this.status,
    required this.formId,
    required this.submittedBy,
    required this.submitterRole,
    required this.provider,
    required this.hasLocation,
    required this.inputType,
    required this.accessLevel,
    required this.forms,
    required this.submitters,
    required this.providers,
    required this.queryController,
    required this.fieldKeyController,
    required this.fieldValueController,
    required this.latController,
    required this.lngController,
    required this.radiusController,
    required this.onRangePicked,
    required this.onStatusChanged,
    required this.onFormChanged,
    required this.onSubmittedByChanged,
    required this.onSubmitterRoleChanged,
    required this.onProviderChanged,
    required this.onHasLocationChanged,
    required this.onInputTypeChanged,
    required this.onAccessLevelChanged,
    required this.onQueryChanged,
    required this.onFieldKeyChanged,
    required this.onFieldValueChanged,
    required this.onGeoChanged,
    required this.onReset,
  });

  final DateTimeRange? range;
  final SubmissionStatus? status;
  final String? formId;
  final String? submittedBy;
  final UserRole? submitterRole;
  final String? provider;
  final bool hasLocation;
  final String? inputType;
  final String? accessLevel;
  final List<FormDefinition> forms;
  final Map<String, String> submitters;
  final Map<String, String> providers;
  final TextEditingController queryController;
  final TextEditingController fieldKeyController;
  final TextEditingController fieldValueController;
  final TextEditingController latController;
  final TextEditingController lngController;
  final TextEditingController radiusController;
  final ValueChanged<DateTimeRange?> onRangePicked;
  final ValueChanged<SubmissionStatus?> onStatusChanged;
  final ValueChanged<String?> onFormChanged;
  final ValueChanged<String?> onSubmittedByChanged;
  final ValueChanged<UserRole?> onSubmitterRoleChanged;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<bool> onHasLocationChanged;
  final ValueChanged<String?> onInputTypeChanged;
  final ValueChanged<String?> onAccessLevelChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onFieldKeyChanged;
  final ValueChanged<String> onFieldValueChanged;
  final void Function(double? lat, double? lng, double? radius) onGeoChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: queryController,
              decoration: const InputDecoration(
                labelText: 'Search keyword',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: onQueryChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(_rangeLabel(range)),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: range,
                      );
                      onRangePicked(picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<SubmissionStatus?>(
                    decoration: const InputDecoration(labelText: 'Status'),
                    initialValue: status,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      ...SubmissionStatus.values.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.displayName),
                        ),
                      ),
                    ],
                    onChanged: onStatusChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              decoration: const InputDecoration(labelText: 'Form'),
              initialValue: formId,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All forms'),
                ),
                ...forms.map(
                  (form) => DropdownMenuItem(
                    value: form.id,
                    child: Text(form.title),
                  ),
                ),
              ],
              onChanged: onFormChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              decoration: const InputDecoration(labelText: 'Submitted by'),
              initialValue: submittedBy,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All submitters'),
                ),
                ...submitters.entries.map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                ),
              ],
              onChanged: onSubmittedByChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole?>(
              decoration: const InputDecoration(labelText: 'Submitter role'),
              initialValue: submitterRole,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All roles'),
                ),
                ...UserRole.values.map(
                  (role) => DropdownMenuItem(
                    value: role,
                    child: Text(role.displayName),
                  ),
                ),
              ],
              onChanged: onSubmitterRoleChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              decoration: const InputDecoration(labelText: 'Auth provider'),
              initialValue: provider,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All providers'),
                ),
                ...providers.entries.map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                ),
              ],
              onChanged: onProviderChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(labelText: 'Input type'),
                    initialValue: inputType,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All types'),
                      ),
                      ...submissionInputTypeLabels.entries.map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      ),
                    ],
                    onChanged: onInputTypeChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    decoration:
                        const InputDecoration(labelText: 'Access level'),
                    initialValue: accessLevel,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All access levels'),
                      ),
                      ...submissionAccessLevelLabels.entries.map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      ),
                    ],
                    onChanged: onAccessLevelChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fieldKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Field key',
                      prefixIcon: Icon(Icons.tune),
                    ),
                    onChanged: onFieldKeyChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: fieldValueController,
                    decoration: const InputDecoration(
                      labelText: 'Field value contains',
                    ),
                    onChanged: onFieldValueChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Has GPS location'),
              value: hasLocation,
              onChanged: onHasLocationChanged,
            ),
            const SizedBox(height: 8),
            _GeoFilter(
              latController: latController,
              lngController: lngController,
              radiusController: radiusController,
              onChanged: onGeoChanged,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _rangeLabel(DateTimeRange? range) {
    if (range == null) return 'Any date';
    return '${_fmt(range.start)} → ${_fmt(range.end)}';
  }

  static String _fmt(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _GeoFilter extends StatelessWidget {
  const _GeoFilter({
    required this.latController,
    required this.lngController,
    required this.radiusController,
    required this.onChanged,
  });

  final TextEditingController latController;
  final TextEditingController lngController;
  final TextEditingController radiusController;
  final void Function(double? lat, double? lng, double? radius) onChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Geography filter'),
      subtitle: const Text('Filter submissions within a radius'),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
                onChanged: (value) => onChanged(
                  _parseDouble(value),
                  _parseDouble(lngController.text),
                  _parseDouble(radiusController.text),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: lngController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
                onChanged: (value) => onChanged(
                  _parseDouble(latController.text),
                  _parseDouble(value),
                  _parseDouble(radiusController.text),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: radiusController,
          decoration: const InputDecoration(labelText: 'Radius (km)'),
          keyboardType: TextInputType.number,
          onChanged: (value) => onChanged(
            _parseDouble(latController.text),
            _parseDouble(lngController.text),
            _parseDouble(value),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.submissions,
    required this.onSelectForm,
    required this.onSelectSubmitter,
  });

  final List<FormSubmission> submissions;
  final ValueChanged<String> onSelectForm;
  final ValueChanged<String> onSelectSubmitter;

  @override
  Widget build(BuildContext context) {
    final statusCounts = <SubmissionStatus, int>{};
    final formCounts = <String, int>{};
    final submitterCounts = <String, int>{};
    var geotagged = 0;

    for (final submission in submissions) {
      statusCounts[submission.status] =
          (statusCounts[submission.status] ?? 0) + 1;
      formCounts[submission.formTitle] =
          (formCounts[submission.formTitle] ?? 0) + 1;
      final submitter =
          submission.submittedByName?.trim().isNotEmpty == true
              ? submission.submittedByName!.trim()
              : submission.submittedBy;
      if (submitter.isNotEmpty) {
        submitterCounts[submitter] = (submitterCounts[submitter] ?? 0) + 1;
      }
      if (submission.location != null) geotagged += 1;
    }

    final topForms = _topEntries(formCounts);
    final topSubmitters = _topEntries(submitterCounts);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(label: 'Submissions', value: submissions.length),
                _SummaryChip(label: 'Geotagged', value: geotagged),
                ...SubmissionStatus.values.map(
                  (status) => _SummaryChip(
                    label: status.displayName,
                    value: statusCounts[status] ?? 0,
                  ),
                ),
              ],
            ),
            if (topForms.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Top forms', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...topForms.map(
                (entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.$1),
                  trailing: Text(entry.$2.toString()),
                  onTap: () => onSelectForm(entry.$1),
                ),
              ),
            ],
            if (topSubmitters.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Top submitters',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...topSubmitters.map(
                (entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.$1),
                  trailing: Text(entry.$2.toString()),
                  onTap: () => onSelectSubmitter(entry.$1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<(String, int)> _topEntries(Map<String, int> counts) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).map((e) => (e.key, e.value)).toList();
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label • $value'),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({required this.onExport, required this.count});

  final VoidCallback onExport;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Results: $count',
            style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        FilledButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.file_download),
          label: const Text('Export CSV'),
        ),
      ],
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.submission, required this.onTap});

  final FormSubmission submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inputTypes = resolveSubmissionInputTypes(submission)
        .map(submissionInputTypeLabel)
        .toList();
    final accessLevel =
        submissionAccessLevelLabel(resolveSubmissionAccessLevel(submission));
    final showTags = inputTypes.isNotEmpty || accessLevel.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(context, submission.status)
              .withValues(alpha: 0.15),
          child: Icon(
            Icons.assignment_turned_in,
            color: _statusColor(context, submission.status),
          ),
        ),
        title: Text(submission.formTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${submission.status.displayName} • ${submission.submittedByName ?? submission.submittedBy}',
            ),
            if (showTags) const SizedBox(height: 6),
            if (showTags)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...inputTypes.map(
                    (label) => Chip(
                      label: Text(label),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.lock_outline, size: 16),
                    label: Text(accessLevel),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
          ],
        ),
        trailing: Text(
          _formatDate(submission.submittedAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        isThreeLine: showTags,
        onTap: onTap,
      ),
    );
  }

  Color _statusColor(BuildContext context, SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.approved:
        return Colors.green;
      case SubmissionStatus.rejected:
        return Colors.red;
      case SubmissionStatus.underReview:
        return Colors.orange;
      case SubmissionStatus.requiresChanges:
        return Colors.deepOrange;
      case SubmissionStatus.pendingSync:
        return Colors.blueGrey;
      case SubmissionStatus.archived:
        return Colors.grey;
      case SubmissionStatus.draft:
      case SubmissionStatus.submitted:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reports',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Analyze submissions, trends, and export insights',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );

    final refreshButton = FilledButton.icon(
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Refresh'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              refreshButton,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: refreshButton),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'No submissions match your filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Adjust filters or export from a broader range.'),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.details,
    required this.onRetry,
  });

  final String message;
  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                details,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a = (sin(dLat / 2) * sin(dLat / 2)) +
      cos(_degToRad(lat1)) *
          cos(_degToRad(lat2)) *
          (sin(dLon / 2) * sin(dLon / 2));
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degToRad(double deg) => deg * (pi / 180.0);
