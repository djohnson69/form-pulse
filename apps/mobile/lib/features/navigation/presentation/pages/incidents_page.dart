import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../assets/data/assets_provider.dart';
import '../../../assets/presentation/pages/incident_editor_page.dart';

class IncidentsPage extends ConsumerStatefulWidget {
  const IncidentsPage({super.key});

  @override
  ConsumerState<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends ConsumerState<IncidentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _severityFilter = 'all';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(incidentReportsProvider(null));
    final equipment = ref.watch(equipmentProvider).value ?? const <Equipment>[];
    final equipmentNames = {
      for (final asset in equipment) asset.id: asset.name,
    };

    return Scaffold(
      body: incidentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _IncidentsErrorView(error: e.toString()),
        data: (incidents) {
          final models = incidents
              .map(
                (incident) => _IncidentViewModel.fromIncident(
                  incident,
                  equipmentNames: equipmentNames,
                ),
              )
              .toList();
          final filtered = _applyFilters(models);
          final stats = _IncidentStats.fromModels(models);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(incidentReportsProvider(null));
              await ref.read(incidentReportsProvider(null).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _IncidentStatsGrid(stats: stats),
                const SizedBox(height: 16),
                _buildFilters(context),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  _EmptyIncidentsCard(
                    onClear: _clearFilters,
                    onReport: () => _openCreateSheet(context),
                  )
                else
                  ...filtered.map(
                    (incident) => _IncidentCard(
                      incident: incident,
                      onReport: () => _openCreateSheet(context),
                      onView: () => _showDetails(context, incident),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incident Reporting & Safety',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Report, track, and manage workplace incidents and safety concerns',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );

        final controls = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export Report'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () => _openCreateSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Report Incident'),
            ),
          ],
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              controls,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 12),
            controls,
          ],
        );
      },
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final children = [
            Expanded(
              flex: isWide ? 2 : 0,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search incidents...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
              ),
            ),
            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _severityFilter,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Severity')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                ],
                onChanged: (value) {
                  setState(() => _severityFilter = value ?? 'all');
                },
              ),
            ),
            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _statusFilter,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'under-review',
                    child: Text('Under Review'),
                  ),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                ],
                onChanged: (value) {
                  setState(() => _statusFilter = value ?? 'all');
                },
              ),
            ),
          ];

          if (isWide) {
            return Row(children: children);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        },
      ),
    );
  }

  List<_IncidentViewModel> _applyFilters(List<_IncidentViewModel> incidents) {
    return incidents.where((incident) {
      final matchesSearch = _searchQuery.isEmpty ||
          incident.title.toLowerCase().contains(_searchQuery) ||
          incident.description.toLowerCase().contains(_searchQuery);
      final matchesSeverity =
          _severityFilter == 'all' || incident.severity == _severityFilter;
      final matchesStatus =
          _statusFilter == 'all' || incident.status == _statusFilter;
      return matchesSearch && matchesSeverity && matchesStatus;
    }).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _severityFilter = 'all';
      _statusFilter = 'all';
    });
  }

  Future<void> _openCreateSheet(BuildContext context) async {
    final equipment = await ref.read(equipmentProvider.future);
    if (!context.mounted) return;
    if (equipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add equipment before logging incidents.')),
      );
      return;
    }
    Equipment? selected = equipment.first;
    final result = await showModalBottomSheet<Equipment?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select asset',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Equipment>(
                    value: selected,
                    decoration: const InputDecoration(
                      labelText: 'Asset',
                      border: OutlineInputBorder(),
                    ),
                    items: equipment
                        .map(
                          (asset) => DropdownMenuItem(
                            value: asset,
                            child: Text(asset.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selected = value),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(selected),
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (!context.mounted) return;
    if (result == null) return;
    await Navigator.of(context).push<IncidentReport?>(
      MaterialPageRoute(builder: (_) => IncidentEditorPage(asset: result)),
    );
    ref.invalidate(incidentReportsProvider(null));
  }

  Future<void> _showDetails(
    BuildContext context,
    _IncidentViewModel incident,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _IncidentDetailSheet(incident: incident),
    );
  }
}

class _IncidentStats {
  const _IncidentStats({
    required this.total,
    required this.pending,
    required this.resolved,
    required this.highSeverity,
  });

  final int total;
  final int pending;
  final int resolved;
  final int highSeverity;

  factory _IncidentStats.fromModels(List<_IncidentViewModel> incidents) {
    final pending =
        incidents.where((incident) => incident.status == 'pending').length;
    final resolved =
        incidents.where((incident) => incident.status == 'resolved').length;
    final high =
        incidents.where((incident) => incident.severity == 'high').length;
    return _IncidentStats(
      total: incidents.length,
      pending: pending,
      resolved: resolved,
      highSeverity: high,
    );
  }
}

class _IncidentStatsGrid extends StatelessWidget {
  const _IncidentStatsGrid({required this.stats});

  final _IncidentStats stats;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: crossAxisCount > 2 ? 2.3 : 1.5,
          children: [
            _IncidentStatCard(
              label: 'Total Incidents',
              value: formatter.format(stats.total),
              note: 'This month',
              icon: Icons.report_outlined,
              color: const Color(0xFF3B82F6),
            ),
            _IncidentStatCard(
              label: 'Pending Review',
              value: formatter.format(stats.pending),
              note: 'Requires attention',
              icon: Icons.schedule,
              color: const Color(0xFFF59E0B),
            ),
            _IncidentStatCard(
              label: 'Resolved',
              value: formatter.format(stats.resolved),
              note: 'Completed',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF22C55E),
            ),
            _IncidentStatCard(
              label: 'High Severity',
              value: formatter.format(stats.highSeverity),
              note: 'Critical items',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFEF4444),
            ),
          ],
        );
      },
    );
  }
}

class _IncidentStatCard extends StatelessWidget {
  const _IncidentStatCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentViewModel {
  _IncidentViewModel({
    required this.incident,
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.location,
    required this.reportedBy,
    required this.assignedTo,
    required this.category,
    required this.occurredAt,
    required this.photoCount,
    required this.videoCount,
    required this.audioCount,
    required this.witnesses,
    required this.geoAddress,
    required this.geoLat,
    required this.geoLng,
  });

  final IncidentReport incident;
  final String id;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String location;
  final String reportedBy;
  final String assignedTo;
  final String category;
  final DateTime occurredAt;
  final int photoCount;
  final int videoCount;
  final int audioCount;
  final int witnesses;
  final String? geoAddress;
  final double? geoLat;
  final double? geoLng;

  String get dateLabel => DateFormat('MMM d, y').format(occurredAt);

  factory _IncidentViewModel.fromIncident(
    IncidentReport incident, {
    required Map<String, String> equipmentNames,
  }) {
    final metadata = incident.metadata ?? const <String, dynamic>{};
    final severity = _normalizeSeverity(incident.severity);
    final status = _normalizeStatus(incident.status);
    final location = _resolveLocation(incident, metadata, equipmentNames);
    final reportedBy = _readString(
          incident.submittedByName ?? metadata['reportedBy'],
          'Unknown',
        ) ??
        'Unknown';
    final assignedTo = _readString(metadata['assignedTo'], 'Unassigned') ??
        'Unassigned';
    final category = _readString(incident.category, 'General') ?? 'General';
    final attachments = incident.attachments ?? const <MediaAttachment>[];
    final photoCount =
        attachments.where((a) => _isType(a, 'photo', 'image')).length;
    final videoCount =
        attachments.where((a) => _isType(a, 'video', 'video')).length;
    final audioCount =
        attachments.where((a) => _isType(a, 'audio', 'audio')).length;
    final witnesses = _readInt(metadata['witnesses']) ??
        _readInt(metadata['witnessCount']) ??
        0;
    final locationData = incident.location;
    final geoAddress = locationData?.address;
    final geoLat = locationData?.latitude;
    final geoLng = locationData?.longitude;

    return _IncidentViewModel(
      incident: incident,
      id: incident.id,
      title: incident.title,
      description: incident.description ?? '',
      severity: severity,
      status: status,
      location: location,
      reportedBy: reportedBy,
      assignedTo: assignedTo,
      category: category,
      occurredAt: incident.occurredAt,
      photoCount: photoCount,
      videoCount: videoCount,
      audioCount: audioCount,
      witnesses: witnesses,
      geoAddress: geoAddress,
      geoLat: geoLat,
      geoLng: geoLng,
    );
  }

  static String _normalizeSeverity(String? severity) {
    final value = severity?.toLowerCase().trim() ?? 'medium';
    if (value == 'critical') return 'high';
    if (value == 'moderate') return 'medium';
    return value.isEmpty ? 'medium' : value;
  }

  static String _normalizeStatus(String? status) {
    final raw = status?.toLowerCase().replaceAll('_', '-') ?? '';
    if (raw == 'open' || raw == 'new') return 'pending';
    if (raw == 'review' || raw == 'in-review') return 'under-review';
    if (raw.isEmpty) return 'pending';
    return raw;
  }

  static String _resolveLocation(
    IncidentReport incident,
    Map<String, dynamic> metadata,
    Map<String, String> equipmentNames,
  ) {
    final location =
        _readString(metadata['location'], '') ??
        _readString(metadata['site'], '') ??
        incident.location?.address ??
        '';
    if (location.isNotEmpty) return location;
    final equipmentId = incident.equipmentId;
    if (equipmentId != null && equipmentNames.containsKey(equipmentId)) {
      return equipmentNames[equipmentId]!;
    }
    return 'Location not set';
  }

  static String? _readString(dynamic value, String? fallback) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _isType(MediaAttachment attachment, String type, String mimePrefix) {
    if (attachment.type.toLowerCase() == type) return true;
    final mime = attachment.mimeType ?? '';
    return mime.startsWith('$mimePrefix/');
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.incident,
    required this.onReport,
    required this.onView,
  });

  final _IncidentViewModel incident;
  final VoidCallback onReport;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final severityColor = _severityColor(incident.severity, isDark);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: severityColor.accent,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      incident.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _ChipLabel(
                      label: incident.severity.toUpperCase(),
                      background: severityColor.background,
                      foreground: severityColor.text,
                      border: severityColor.border,
                    ),
                    _ChipLabel(
                      label: incident.status.replaceAll('-', ' ').toUpperCase(),
                      background: _statusColor(incident.status, isDark),
                      foreground: _statusText(incident.status, isDark),
                      border: _statusBorder(incident.status, isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  incident.description.isEmpty
                      ? 'No description provided.'
                      : incident.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailsGrid(incident: incident),
                const SizedBox(height: 12),
                _IncidentMetaRow(incident: incident),
                if (incident.geoAddress != null ||
                    (incident.geoLat != null && incident.geoLng != null))
                  _GeoLocationCard(incident: incident),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (incident.status == 'pending')
                      FilledButton(
                        onPressed: onReport,
                        child: const Text('Review'),
                      ),
                    if (incident.status == 'pending')
                      const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onView,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.incident});

  final _IncidentViewModel incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 720 ? 4 : 2;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.8,
            children: [
              _DetailItem(
                icon: Icons.place_outlined,
                label: 'Location',
                value: incident.location,
              ),
              _DetailItem(
                icon: Icons.person_outline,
                label: 'Reported By',
                value: incident.reportedBy,
              ),
              _DetailItem(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: incident.dateLabel,
              ),
              _DetailItem(
                icon: Icons.assignment_ind_outlined,
                label: 'Assigned To',
                value: incident.assignedTo,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IncidentMetaRow extends StatelessWidget {
  const _IncidentMetaRow({required this.incident});

  final _IncidentViewModel incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _MetaItem(
          icon: Icons.photo_camera_outlined,
          label: '${incident.photoCount} photos',
          style: metaStyle,
        ),
        if (incident.videoCount > 0)
          _MetaItem(
            icon: Icons.videocam_outlined,
            label: '${incident.videoCount} videos',
            style: metaStyle,
          ),
        if (incident.audioCount > 0)
          _MetaItem(
            icon: Icons.mic_none,
            label: '${incident.audioCount} audio',
            style: metaStyle,
          ),
        _MetaItem(
          icon: Icons.visibility_outlined,
          label: '${incident.witnesses} witnesses',
          style: metaStyle,
        ),
        _CategoryPill(label: incident.category),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    this.style,
  });

  final IconData icon;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: style?.color),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall,
      ),
    );
  }
}

class _GeoLocationCard extends StatelessWidget {
  const _GeoLocationCard({required this.incident});

  final _IncidentViewModel incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFBFDBFE);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.navigation_outlined,
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GPS Coordinates',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (incident.geoAddress != null)
                  Text(
                    incident.geoAddress!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (incident.geoLat != null && incident.geoLng != null)
                  Text(
                    'Lat: ${incident.geoLat!.toStringAsFixed(6)}, '
                    'Lng: ${incident.geoLng!.toStringAsFixed(6)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('View Map'),
          ),
        ],
      ),
    );
  }
}

class _IncidentDetailSheet extends StatelessWidget {
  const _IncidentDetailSheet({required this.incident});

  final _IncidentViewModel incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    incident.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              incident.description.isEmpty
                  ? 'No description provided.'
                  : incident.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Severity', value: incident.severity),
            _DetailRow(label: 'Status', value: incident.status),
            _DetailRow(label: 'Location', value: incident.location),
            _DetailRow(label: 'Reported By', value: incident.reportedBy),
            _DetailRow(label: 'Assigned To', value: incident.assignedTo),
            _DetailRow(label: 'Date', value: incident.dateLabel),
            _DetailRow(label: 'Category', value: incident.category),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipLabel(
                  label: '${incident.photoCount} photos',
                  background: theme.colorScheme.surfaceContainerHighest,
                  foreground: theme.colorScheme.onSurfaceVariant,
                  border: theme.colorScheme.surfaceContainerHighest,
                ),
                if (incident.videoCount > 0)
                  _ChipLabel(
                    label: '${incident.videoCount} videos',
                    background: theme.colorScheme.surfaceContainerHighest,
                    foreground: theme.colorScheme.onSurfaceVariant,
                    border: theme.colorScheme.surfaceContainerHighest,
                  ),
                if (incident.audioCount > 0)
                  _ChipLabel(
                    label: '${incident.audioCount} audio',
                    background: theme.colorScheme.surfaceContainerHighest,
                    foreground: theme.colorScheme.onSurfaceVariant,
                    border: theme.colorScheme.surfaceContainerHighest,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SeverityColors {
  const _SeverityColors({
    required this.background,
    required this.border,
    required this.text,
    required this.accent,
  });

  final Color background;
  final Color border;
  final Color text;
  final Color accent;
}

_SeverityColors _severityColor(String severity, bool isDark) {
  switch (severity) {
    case 'high':
      return _SeverityColors(
        background: isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEE2E2),
        border: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
        text: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
        accent: const Color(0xFFEF4444),
      );
    case 'low':
      return _SeverityColors(
        background: isDark ? const Color(0xFF3D2F0E) : const Color(0xFFFEF3C7),
        border: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
        text: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
        accent: const Color(0xFFF59E0B),
      );
    default:
      return _SeverityColors(
        background: isDark ? const Color(0xFF1F2937) : const Color(0xFFFED7AA),
        border: isDark ? const Color(0xFF4B5563) : const Color(0xFFFDBA74),
        text: isDark ? const Color(0xFFFBBF24) : const Color(0xFFEA580C),
        accent: const Color(0xFFF97316),
      );
  }
}

Color _statusColor(String status, bool isDark) {
  switch (status) {
    case 'resolved':
      return isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
    case 'under-review':
      return isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
    default:
      return isDark ? const Color(0xFF3D2F0E) : const Color(0xFFFEF3C7);
  }
}

Color _statusText(String status, bool isDark) {
  switch (status) {
    case 'resolved':
      return isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
    case 'under-review':
      return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    default:
      return isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
  }
}

Color _statusBorder(String status, bool isDark) {
  switch (status) {
    case 'resolved':
      return isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0);
    case 'under-review':
      return isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE);
    default:
      return isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A);
  }
}

class _EmptyIncidentsCard extends StatelessWidget {
  const _EmptyIncidentsCard({required this.onClear, required this.onReport});

  final VoidCallback onClear;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No incidents match your filters.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Clear filters or report a new incident.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear filters'),
                  onPressed: onClear,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Report incident'),
                  onPressed: onReport,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentsErrorView extends StatelessWidget {
  const _IncidentsErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $error'),
      ),
    );
  }
}
