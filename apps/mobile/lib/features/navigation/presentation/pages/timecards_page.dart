import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared/shared.dart';

class TimecardsPage extends StatefulWidget {
  const TimecardsPage({super.key, this.role = UserRole.employee});

  final UserRole role;

  @override
  State<TimecardsPage> createState() => _TimecardsPageState();
}

class _TimecardsPageState extends State<TimecardsPage> {
  final TextEditingController _approvalNotesController = TextEditingController();
  late List<_TimecardEntry> _entries;
  String _selectedWeek = 'current';
  String _currentLocation = 'Getting location...';
  int? _editingEntryId;
  bool _isClockedIn = false;
  String? _clockInTime;

  @override
  void initState() {
    super.initState();
    _entries = _demoEntries();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _currentLocation = '40.7128, -74.0060');
    });
  }

  @override
  void dispose() {
    _approvalNotesController.dispose();
    super.dispose();
  }

  double get _totalHours =>
      _entries.fold(0, (sum, entry) => sum + entry.hoursWorked);

  double get _pendingHours => _entries
      .where((entry) => entry.status == _TimecardStatus.pending)
      .fold(0, (sum, entry) => sum + entry.hoursWorked);

  double get _approvedHours => _entries
      .where((entry) => entry.status == _TimecardStatus.approved)
      .fold(0, (sum, entry) => sum + entry.hoursWorked);

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    if (role == UserRole.employee || role == UserRole.maintenance) {
      return _buildEmployeeView(context);
    }
    if (role == UserRole.supervisor) {
      return _buildSupervisorView(context);
    }
    return _buildManagerView(context);
  }

  Scaffold _buildEmployeeView(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _TimecardColors.fromTheme(Theme.of(context));
    final recentEntries = _entries.reversed.take(5).toList();
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Timecards')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: 'Time Clock',
            subtitle: 'Clock in and out with geo-location tracking',
            muted: colors.muted,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isClockedIn
                        ? colors.successSurface
                        : colors.infoSurface,
                    border: Border.all(
                      color: _isClockedIn
                          ? colors.success
                          : colors.info,
                      width: 4,
                    ),
                  ),
                  child: Icon(
                    Icons.schedule_outlined,
                    size: 52,
                    color: _isClockedIn ? colors.success : colors.info,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isClockedIn) ...[
                  Text(
                    'Currently Clocked In',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.title,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _clockInTime ?? '--:--',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Started at ${_clockInTime ?? '--:--'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Ready to Clock In',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.title,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.subtleSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.navigation_outlined,
                        size: 16,
                        color: colors.info,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentLocation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.body,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isClockedIn ? _handleClockOut : _handleClockIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isClockedIn ? colors.danger : colors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(_isClockedIn ? 'Clock Out' : 'Clock In'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _StatsGrid(
            stats: [
              _StatItem(
                label: 'Total Hours This Week',
                value: _totalHours.toStringAsFixed(1),
                icon: Icons.schedule_outlined,
                accent: colors.info,
                surface: colors.infoSurface,
              ),
              _StatItem(
                label: 'Pending Approval',
                value: _pendingHours.toStringAsFixed(1),
                icon: Icons.event_available_outlined,
                accent: colors.warning,
                surface: colors.warningSurface,
              ),
              _StatItem(
                label: 'Approved Hours',
                value: _approvedHours.toStringAsFixed(1),
                icon: Icons.check_circle_outline,
                accent: colors.success,
                surface: colors.successSurface,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TableCard(
            title: 'Recent Time Entries',
            colors: colors,
            child: _EmployeeEntriesTable(
              entries: recentEntries,
              colors: colors,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Scaffold _buildSupervisorView(BuildContext context) {
    final colors = _TimecardColors.fromTheme(Theme.of(context));
    final pending = _entries
        .where((entry) => entry.status == _TimecardStatus.pending)
        .toList();
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Timecards')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderWithAction(
            title: 'Timecard Approvals',
            subtitle: 'Review and approve employee timecards',
            muted: colors.muted,
            actionLabel: 'Export',
            onPressed: _handleExport,
          ),
          const SizedBox(height: 16),
          _StatsGrid(
            stats: [
              _StatItem(
                label: 'Pending Approvals',
                value: pending.length.toString(),
                icon: Icons.error_outline,
                accent: colors.warning,
                surface: colors.warningSurface,
              ),
              _StatItem(
                label: 'Pending Hours',
                value: _pendingHours.toStringAsFixed(1),
                icon: Icons.schedule_outlined,
                accent: colors.info,
                surface: colors.infoSurface,
              ),
              _StatItem(
                label: 'Approved This Week',
                value: _entries
                    .where((entry) => entry.status == _TimecardStatus.approved)
                    .length
                    .toString(),
                icon: Icons.check_circle_outline,
                accent: colors.success,
                surface: colors.successSurface,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TableCard(
            title: 'Pending Timecards',
            colors: colors,
            child: _SupervisorEntriesTable(
              entries: pending,
              colors: colors,
              onReview: _showApprovalDialog,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Scaffold _buildManagerView(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _TimecardColors.fromTheme(theme);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Timecards')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderWithAction(
            title: 'Timecards Management',
            subtitle: 'Review, edit, and adjust employee timecards',
            muted: colors.muted,
            actionLabel: 'Export',
            onPressed: _handleExport,
          ),
          const SizedBox(height: 16),
          _StatsGrid(
            stats: [
              _StatItem(
                label: 'Total Hours This Week',
                value: _totalHours.toStringAsFixed(1),
                icon: Icons.schedule_outlined,
                accent: colors.info,
                surface: colors.infoSurface,
              ),
              _StatItem(
                label: 'Pending Review',
                value: _pendingHours.toStringAsFixed(1),
                icon: Icons.event_available_outlined,
                accent: colors.warning,
                surface: colors.warningSurface,
              ),
              _StatItem(
                label: 'Approved Hours',
                value: _approvedHours.toStringAsFixed(1),
                icon: Icons.check_circle_outline,
                accent: colors.success,
                surface: colors.successSurface,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FiltersCard(
            selectedWeek: _selectedWeek,
            colors: colors,
            onChanged: (value) => setState(() => _selectedWeek = value),
          ),
          const SizedBox(height: 16),
          _TableCard(
            title: 'Timecard Entries',
            colors: colors,
            child: _ManagerEntriesTable(
              entries: _entries,
              colors: colors,
              editingEntryId: _editingEntryId,
              onEdit: (id) => setState(() => _editingEntryId = id),
              onSave: () => setState(() => _editingEntryId = null),
              onDelete: _confirmDelete,
              onUpdate: _updateEntry,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _handleClockIn() {
    final now = DateTime.now();
    final time = DateFormat('hh:mm a').format(now);
    setState(() {
      _isClockedIn = true;
      _clockInTime = time;
    });
    _showSnackBar('Clocked in at $time');
  }

  void _handleClockOut() {
    if (!_isClockedIn) return;
    final now = DateTime.now();
    final time = DateFormat('hh:mm a').format(now);
    final hoursWorked = 8.5;
    final newEntry = _TimecardEntry(
      id: _entries.length + 1,
      date: DateFormat('yyyy-MM-dd').format(now),
      day: DateFormat('EEEE').format(now),
      clockIn: _clockInTime ?? time,
      clockOut: time,
      hoursWorked: hoursWorked,
      project: 'Field Work',
      status: _TimecardStatus.pending,
      approvedBy: null,
      location: _TimecardLocation(
        address: '123 Main St, New York, NY',
        lat: 40.7128,
        lng: -74.0060,
      ),
    );
    setState(() {
      _isClockedIn = false;
      _clockInTime = null;
      _entries = [..._entries, newEntry];
    });
    _showSnackBar('Clocked out at $time');
  }

  Future<void> _handleExport() async {
    if (_entries.isEmpty) {
      _showSnackBar('No timecards to export.');
      return;
    }
    final csv = _buildTimecardsCsv(_entries);
    final filename =
        'timecards-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
    final file = XFile.fromData(
      utf8.encode(csv),
      mimeType: 'text/csv',
      name: filename,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Timecard export',
          files: [file],
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: csv));
    }
  }

  String _buildTimecardsCsv(List<_TimecardEntry> entries) {
    const headers = [
      'Date',
      'Day',
      'Clock In',
      'Clock Out',
      'Project',
      'Hours',
      'Status',
      'Location',
      'Approved By',
    ];
    final rows = entries.map((entry) {
      final location = entry.location?.address ?? '-';
      return [
        entry.date,
        entry.day,
        entry.clockIn,
        entry.clockOut ?? '-',
        entry.project,
        entry.hoursWorked.toStringAsFixed(2),
        entry.status.name,
        location,
        entry.approvedBy ?? '-',
      ];
    });
    return ([headers, ...rows])
        .map((row) => row.map(_csvEscape).join(','))
        .join('\n');
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  void _updateEntry(int id, _TimecardEntry entry) {
    setState(() {
      _entries = _entries.map((item) => item.id == id ? entry : item).toList();
    });
  }

  void _confirmDelete(_TimecardEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete timecard entry?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _entries.removeWhere((item) => item.id == entry.id);
              });
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog(_TimecardEntry entry) {
    _approvalNotesController.text = '';
    showDialog<void>(
      context: context,
      builder: (context) {
        final colors = _TimecardColors.fromTheme(Theme.of(context));
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Timecard - ${entry.date}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.title,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _InfoGrid(
                    items: [
                      _InfoItem(label: 'Date', value: '${entry.date} (${entry.day})'),
                      _InfoItem(label: 'Project', value: entry.project),
                      _InfoItem(label: 'Clock In', value: entry.clockIn),
                      _InfoItem(
                        label: 'Clock Out',
                        value: entry.clockOut ?? 'In Progress',
                      ),
                      _InfoItem(
                        label: 'Total Hours',
                        value: '${entry.hoursWorked} hours',
                      ),
                      _InfoItem(
                        label: 'Location',
                        value: entry.location?.address ?? 'N/A',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Approval Notes (Optional)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.muted,
                        ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _approvalNotesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add any notes or comments...',
                      filled: true,
                      fillColor: colors.subtleSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.danger,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            _applyApproval(entry, _TimecardStatus.rejected);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.success,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            _applyApproval(entry, _TimecardStatus.approved);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _applyApproval(_TimecardEntry entry, _TimecardStatus status) {
    final updated = entry.copyWith(
      status: status,
      approvedBy: status == _TimecardStatus.approved
          ? 'Current Supervisor'
          : entry.approvedBy,
      notes: _approvalNotesController.text.trim(),
    );
    _updateEntry(entry.id, updated);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<_TimecardEntry> _demoEntries() {
    return [
      _TimecardEntry(
        id: 1,
        date: '2024-12-23',
        day: 'Monday',
        clockIn: '08:00 AM',
        clockOut: '05:00 PM',
        hoursWorked: 8.5,
        project: 'Building Maintenance',
        status: _TimecardStatus.approved,
        approvedBy: 'Sarah Chen',
        location: _TimecardLocation(
          lat: 40.7128,
          lng: -74.0060,
          address: '123 Main St, New York, NY',
        ),
      ),
      _TimecardEntry(
        id: 2,
        date: '2024-12-24',
        day: 'Tuesday',
        clockIn: '08:15 AM',
        clockOut: '04:30 PM',
        hoursWorked: 8.0,
        project: 'HVAC Installation',
        status: _TimecardStatus.approved,
        approvedBy: 'Sarah Chen',
        location: _TimecardLocation(
          lat: 40.7128,
          lng: -74.0060,
          address: '123 Main St, New York, NY',
        ),
      ),
      _TimecardEntry(
        id: 3,
        date: '2024-12-25',
        day: 'Wednesday',
        clockIn: '00:00 AM',
        clockOut: '00:00 AM',
        hoursWorked: 0,
        project: 'Holiday',
        status: _TimecardStatus.approved,
        approvedBy: 'System',
      ),
      _TimecardEntry(
        id: 4,
        date: '2024-12-26',
        day: 'Thursday',
        clockIn: '08:00 AM',
        clockOut: '05:30 PM',
        hoursWorked: 9.0,
        project: 'Electrical Repairs',
        status: _TimecardStatus.pending,
        approvedBy: null,
        location: _TimecardLocation(
          lat: 40.7128,
          lng: -74.0060,
          address: '456 Oak Ave, New York, NY',
        ),
      ),
      _TimecardEntry(
        id: 5,
        date: '2024-12-27',
        day: 'Friday',
        clockIn: '07:45 AM',
        clockOut: '03:30 PM',
        hoursWorked: 7.5,
        project: 'Plumbing Work',
        status: _TimecardStatus.pending,
        approvedBy: null,
        location: _TimecardLocation(
          lat: 40.7128,
          lng: -74.0060,
          address: '789 Park Blvd, New York, NY',
        ),
      ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.muted,
  });

  final String title;
  final String subtitle;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF111827);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: muted,
              ),
        ),
      ],
    );
  }
}

class _HeaderWithAction extends StatelessWidget {
  const _HeaderWithAction({
    required this.title,
    required this.subtitle,
    required this.muted,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final Color muted;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, subtitle: subtitle, muted: muted),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.download_outlined),
            label: Text(actionLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final List<_StatItem> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 1;
        final childAspectRatio = columns == 1 ? 3.0 : 2.6;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: stats.map((stat) => _StatCard(stat: stat)).toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _StatItem stat;

  @override
  Widget build(BuildContext context) {
    final colors = _TimecardColors.fromTheme(Theme.of(context));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  stat.value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.title,
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: stat.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(stat.icon, color: stat.accent),
          ),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.selectedWeek,
    required this.colors,
    required this.onChanged,
  });

  final String selectedWeek;
  final _TimecardColors colors;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedWeek,
        decoration: const InputDecoration(
          labelText: 'Week Period',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: 'current',
            child: Text('Current Week (Dec 23-27, 2024)'),
          ),
          DropdownMenuItem(
            value: 'last',
            child: Text('Last Week (Dec 16-20, 2024)'),
          ),
          DropdownMenuItem(
            value: 'twoweeks',
            child: Text('Two Weeks Ago (Dec 9-13, 2024)'),
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          onChanged(value);
        },
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.title,
    required this.colors,
    required this.child,
  });

  final String title;
  final _TimecardColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.title,
                  ),
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class _EmployeeEntriesTable extends StatelessWidget {
  const _EmployeeEntriesTable({
    required this.entries,
    required this.colors,
  });

  final List<_TimecardEntry> entries;
  final _TimecardColors colors;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(colors.tableHeader),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Clock In')),
          DataColumn(label: Text('Clock Out')),
          DataColumn(label: Text('Hours')),
          DataColumn(label: Text('Status')),
        ],
        rows: entries.map((entry) {
          return DataRow(cells: [
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.date),
                  Text(entry.day, style: TextStyle(color: colors.muted)),
                ],
              ),
            ),
            DataCell(Text(entry.clockIn)),
            DataCell(Text(entry.clockOut ?? '-')),
            DataCell(Text('${entry.hoursWorked} hrs')),
            DataCell(_StatusChip(status: entry.status, colors: colors)),
          ]);
        }).toList(),
      ),
    );
  }
}

class _SupervisorEntriesTable extends StatelessWidget {
  const _SupervisorEntriesTable({
    required this.entries,
    required this.colors,
    required this.onReview,
  });

  final List<_TimecardEntry> entries;
  final _TimecardColors colors;
  final ValueChanged<_TimecardEntry> onReview;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(colors.tableHeader),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Clock In/Out')),
          DataColumn(label: Text('Project')),
          DataColumn(label: Text('Hours')),
          DataColumn(label: Text('Location')),
          DataColumn(label: Text('Actions')),
        ],
        rows: entries.map((entry) {
          return DataRow(cells: [
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.date),
                  Text(entry.day, style: TextStyle(color: colors.muted)),
                ],
              ),
            ),
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.clockIn),
                  Text(entry.clockOut ?? 'In Progress'),
                ],
              ),
            ),
            DataCell(Text(entry.project)),
            DataCell(Text('${entry.hoursWorked} hrs')),
            DataCell(
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: colors.muted),
                  const SizedBox(width: 4),
                  Text(entry.location?.address ?? '-'),
                ],
              ),
            ),
            DataCell(
              TextButton(
                onPressed: () => onReview(entry),
                child: const Text('Review'),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}

class _ManagerEntriesTable extends StatelessWidget {
  const _ManagerEntriesTable({
    required this.entries,
    required this.colors,
    required this.editingEntryId,
    required this.onEdit,
    required this.onSave,
    required this.onDelete,
    required this.onUpdate,
  });

  final List<_TimecardEntry> entries;
  final _TimecardColors colors;
  final int? editingEntryId;
  final ValueChanged<int> onEdit;
  final VoidCallback onSave;
  final ValueChanged<_TimecardEntry> onDelete;
  final void Function(int, _TimecardEntry) onUpdate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(colors.tableHeader),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Clock In/Out')),
          DataColumn(label: Text('Project/Task')),
          DataColumn(label: Text('Hours')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Location')),
          DataColumn(label: Text('Actions')),
        ],
        rows: entries.map((entry) {
          final isEditing = editingEntryId == entry.id;
          return DataRow(cells: [
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.date),
                  Text(entry.day, style: TextStyle(color: colors.muted)),
                ],
              ),
            ),
            DataCell(
              isEditing
                  ? Column(
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            initialValue: entry.clockIn,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => onUpdate(
                              entry.id,
                              entry.copyWith(clockIn: value),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            initialValue: entry.clockOut ?? '',
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => onUpdate(
                              entry.id,
                              entry.copyWith(clockOut: value),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(entry.clockIn),
                        Text(entry.clockOut ?? 'In Progress'),
                      ],
                    ),
            ),
            DataCell(
              isEditing
                  ? SizedBox(
                      width: 160,
                      child: TextFormField(
                        initialValue: entry.project,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => onUpdate(
                          entry.id,
                          entry.copyWith(project: value),
                        ),
                      ),
                    )
                  : Text(entry.project),
            ),
            DataCell(
              isEditing
                  ? SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: entry.hoursWorked.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed == null) return;
                          onUpdate(
                            entry.id,
                            entry.copyWith(hoursWorked: parsed),
                          );
                        },
                      ),
                    )
                  : Text('${entry.hoursWorked} hrs'),
            ),
            DataCell(_StatusChip(status: entry.status, colors: colors)),
            DataCell(
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: colors.muted),
                  const SizedBox(width: 4),
                  Text(entry.location?.address ?? '-'),
                ],
              ),
            ),
            DataCell(
              Row(
                children: [
                  IconButton(
                    onPressed: isEditing ? onSave : () => onEdit(entry.id),
                    icon: Icon(
                      isEditing ? Icons.save_outlined : Icons.edit_outlined,
                      color: isEditing ? colors.success : colors.muted,
                    ),
                  ),
                  IconButton(
                    onPressed: () => onDelete(entry),
                    icon: Icon(Icons.delete_outline, color: colors.danger),
                  ),
                ],
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.2,
          children: items.map((item) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

class _InfoItem {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.colors});

  final _TimecardStatus status;
  final _TimecardColors colors;

  @override
  Widget build(BuildContext context) {
    final data = colors.statusStyles[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        data.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: data.foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.surface,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color surface;
}

class _TimecardColors {
  const _TimecardColors({
    required this.background,
    required this.surface,
    required this.subtleSurface,
    required this.border,
    required this.muted,
    required this.title,
    required this.body,
    required this.tableHeader,
    required this.info,
    required this.infoSurface,
    required this.warning,
    required this.warningSurface,
    required this.success,
    required this.successSurface,
    required this.danger,
    required this.statusStyles,
  });

  final Color background;
  final Color surface;
  final Color subtleSurface;
  final Color border;
  final Color muted;
  final Color title;
  final Color body;
  final Color tableHeader;
  final Color info;
  final Color infoSurface;
  final Color warning;
  final Color warningSurface;
  final Color success;
  final Color successSurface;
  final Color danger;
  final Map<_TimecardStatus, _StatusStyle> statusStyles;

  factory _TimecardColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final surface = isDark ? const Color(0xFF1F2937) : Colors.white;
    final subtleSurface =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final title = isDark ? Colors.white : const Color(0xFF111827);
    final body = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final tableHeader =
        isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    const info = Color(0xFF2563EB);
    const warning = Color(0xFFF59E0B);
    const success = Color(0xFF16A34A);
    const danger = Color(0xFFDC2626);
    return _TimecardColors(
      background: background,
      surface: surface,
      subtleSurface: subtleSurface,
      border: border,
      muted: muted,
      title: title,
      body: body,
      tableHeader: tableHeader,
      info: info,
      infoSurface: info.withValues(alpha: isDark ? 0.2 : 0.15),
      warning: warning,
      warningSurface: warning.withValues(alpha: isDark ? 0.25 : 0.2),
      success: success,
      successSurface: success.withValues(alpha: isDark ? 0.25 : 0.2),
      danger: danger,
      statusStyles: {
        _TimecardStatus.approved: _StatusStyle(
          label: 'Approved',
          background: success.withValues(alpha: isDark ? 0.25 : 0.2),
          foreground: success,
        ),
        _TimecardStatus.pending: _StatusStyle(
          label: 'Pending',
          background: warning.withValues(alpha: isDark ? 0.25 : 0.2),
          foreground: warning,
        ),
        _TimecardStatus.rejected: _StatusStyle(
          label: 'Rejected',
          background: danger.withValues(alpha: isDark ? 0.25 : 0.2),
          foreground: danger,
        ),
      },
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

enum _TimecardStatus { approved, pending, rejected }

class _TimecardEntry {
  const _TimecardEntry({
    required this.id,
    required this.date,
    required this.day,
    required this.clockIn,
    required this.clockOut,
    required this.hoursWorked,
    required this.project,
    required this.status,
    required this.approvedBy,
    this.notes,
    this.location,
  });

  final int id;
  final String date;
  final String day;
  final String clockIn;
  final String? clockOut;
  final double hoursWorked;
  final String project;
  final _TimecardStatus status;
  final String? approvedBy;
  final String? notes;
  final _TimecardLocation? location;

  _TimecardEntry copyWith({
    String? clockIn,
    String? clockOut,
    double? hoursWorked,
    String? project,
    _TimecardStatus? status,
    String? approvedBy,
    String? notes,
  }) {
    return _TimecardEntry(
      id: id,
      date: date,
      day: day,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      project: project ?? this.project,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      notes: notes ?? this.notes,
      location: location,
    );
  }
}

class _TimecardLocation {
  const _TimecardLocation({
    required this.lat,
    required this.lng,
    required this.address,
  });

  final double lat;
  final double lng;
  final String address;
}
