import 'package:flutter/material.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  bool _syncing = false;
  late _AdpConfig _adpConfig;
  late List<_PayrollStat> _stats;
  late List<_PayrollRun> _runs;
  late List<_PendingTimesheet> _pending;

  @override
  void initState() {
    super.initState();
    _adpConfig = _AdpConfig(
      clientId: 'YOUR_ADP_CLIENT_ID_HERE',
      clientSecret: 'YOUR_ADP_CLIENT_SECRET_HERE',
      apiEndpoint: 'https://api.adp.com/payroll/v1',
      connected: true,
      lastSynced: '2 hours ago',
    );
    _stats = [
      _PayrollStat(
        label: 'Total Payroll (Current Period)',
        value: '\$458,932.00',
        change: '+2.3%',
        color: _StatColor.green,
        icon: Icons.attach_money,
      ),
      _PayrollStat(
        label: 'Employees Paid',
        value: '127',
        change: '+3 from last period',
        color: _StatColor.blue,
        icon: Icons.groups_outlined,
      ),
      _PayrollStat(
        label: 'Hours Processed',
        value: '5,234',
        change: '+124 hours',
        color: _StatColor.purple,
        icon: Icons.schedule_outlined,
      ),
      _PayrollStat(
        label: 'Pending Approvals',
        value: '8',
        change: '3 timesheets, 5 expenses',
        color: _StatColor.yellow,
        icon: Icons.error_outline,
      ),
    ];
    _runs = [
      _PayrollRun(
        id: 1,
        period: 'Dec 16-22, 2024',
        status: 'Completed',
        amount: '\$458,932.00',
        date: 'Dec 23, 2024',
        employees: 127,
      ),
      _PayrollRun(
        id: 2,
        period: 'Dec 9-15, 2024',
        status: 'Completed',
        amount: '\$446,120.00',
        date: 'Dec 16, 2024',
        employees: 126,
      ),
      _PayrollRun(
        id: 3,
        period: 'Dec 2-8, 2024',
        status: 'Completed',
        amount: '\$451,890.00',
        date: 'Dec 9, 2024',
        employees: 125,
      ),
      _PayrollRun(
        id: 4,
        period: 'Nov 25-Dec 1, 2024',
        status: 'Completed',
        amount: '\$448,560.00',
        date: 'Dec 2, 2024',
        employees: 124,
      ),
    ];
    _pending = [
      _PendingTimesheet(
        id: 1,
        employee: 'Sarah Johnson',
        department: 'Field Operations',
        hours: 42,
        overtime: 2,
        status: 'Pending Review',
        submitted: '2 hours ago',
      ),
      _PendingTimesheet(
        id: 2,
        employee: 'Mike Chen',
        department: 'Maintenance',
        hours: 40,
        overtime: 0,
        status: 'Pending Review',
        submitted: '3 hours ago',
      ),
      _PendingTimesheet(
        id: 3,
        employee: 'Emily Davis',
        department: 'Inspections',
        hours: 38,
        overtime: 0,
        status: 'Pending Review',
        submitted: '5 hours ago',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PayrollColors.fromTheme(Theme.of(context));
    return Scaffold(
      backgroundColor: colors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(
            colors: colors,
            syncing: _syncing,
            connected: _adpConfig.connected,
            onSync: _syncPayroll,
            onExport: _exportPayroll,
          ),
          const SizedBox(height: 16),
          _ConnectionBanner(
            colors: colors,
            config: _adpConfig,
            onToggle: _toggleConnection,
          ),
          const SizedBox(height: 16),
          _StatsGrid(stats: _stats, colors: colors),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1000;
              final left = _PayrollRunsTable(
                colors: colors,
                runs: _runs,
                onDownload: _downloadRun,
              );
              final right = _PendingApprovalsCard(
                colors: colors,
                pending: _pending,
                onApprove: _approveTimesheet,
                onReview: _reviewTimesheet,
              );
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: left),
                    const SizedBox(width: 12),
                    Expanded(child: right),
                  ],
                );
              }
              return Column(
                children: [
                  left,
                  const SizedBox(height: 12),
                  right,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _IntegrationCard(
            colors: colors,
            config: _adpConfig,
            onOpenPortal: () => _showMessage('Opening ADP Developer Portal...'),
            onViewLogs: () => _showMessage('Viewing integration logs...'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _syncPayroll() async {
    if (!_adpConfig.connected || _syncing) return;
    setState(() => _syncing = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _syncing = false;
      _adpConfig = _adpConfig.copyWith(lastSynced: 'Just now');
    });
    _showMessage('Payroll data synced successfully from ADP.');
  }

  void _exportPayroll() {
    _showMessage('Payroll report exported successfully.');
  }

  void _downloadRun(_PayrollRun run) {
    _showMessage('Downloading payroll report for ${run.period}...');
  }

  void _toggleConnection() {
    setState(() {
      _adpConfig = _adpConfig.copyWith(connected: !_adpConfig.connected);
    });
  }

  void _approveTimesheet(_PendingTimesheet timesheet) {
    setState(() {
      _pending.removeWhere((item) => item.id == timesheet.id);
      _updatePendingStat();
    });
    _showMessage('Approved timesheet for ${timesheet.employee}');
  }

  void _rejectTimesheet(_PendingTimesheet timesheet) {
    setState(() {
      _pending.removeWhere((item) => item.id == timesheet.id);
      _updatePendingStat();
    });
    _showMessage('Rejected timesheet for ${timesheet.employee}');
  }

  void _reviewTimesheet(_PendingTimesheet timesheet) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final colors = _PayrollColors.fromTheme(Theme.of(context));
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Review Timesheet - ${timesheet.employee}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.title,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: colors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoGrid(
                  colors: colors,
                  items: [
                    _InfoItem(label: 'Employee', value: timesheet.employee),
                    _InfoItem(label: 'Department', value: timesheet.department),
                    _InfoItem(
                      label: 'Regular Hours',
                      value: '${timesheet.hours} hours',
                    ),
                    _InfoItem(
                      label: 'Overtime Hours',
                      value: '${timesheet.overtime} hours',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add any notes or feedback...',
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
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _rejectTimesheet(timesheet);
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _approveTimesheet(timesheet);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updatePendingStat() {
    _stats = _stats.map((stat) {
      if (stat.label == 'Pending Approvals') {
        return stat.copyWith(value: _pending.length.toString());
      }
      return stat;
    }).toList();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.colors,
    required this.syncing,
    required this.connected,
    required this.onSync,
    required this.onExport,
  });

  final _PayrollColors colors;
  final bool syncing;
  final bool connected;
  final VoidCallback onSync;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final title = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.successSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.successBorder),
              ),
              child: Icon(Icons.attach_money, color: colors.success),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payroll Management',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.title,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Integrated with ADP Workforce Now',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colors.muted),
                ),
              ],
            ),
          ],
        );
        final buttons = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: syncing || !connected ? null : onSync,
              icon: Icon(
                Icons.sync,
                size: 18,
                color: syncing ? colors.muted : Colors.white,
              ),
              label: Text(syncing ? 'Syncing...' : 'Sync with ADP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: colors.tabSurface,
                disabledForegroundColor: colors.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export Report'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.body,
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              buttons,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 12),
            buttons,
          ],
        );
      },
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.colors,
    required this.config,
    required this.onToggle,
  });

  final _PayrollColors colors;
  final _AdpConfig config;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final connected = config.connected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: connected ? colors.successSurface : colors.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected ? colors.successBorder : colors.warningBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: connected ? colors.success : colors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected
                      ? 'Connected to ADP Workforce Now'
                      : 'ADP Connection Required',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: connected ? colors.successText : colors.warningText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  connected
                      ? 'Last synced: ${config.lastSynced} • Real-time payroll data integration active'
                      : 'Configure your ADP API credentials in Settings to enable automatic sync',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: connected
                            ? colors.successTextSecondary
                            : colors.warningTextSecondary,
                      ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: onToggle,
                child: Text(connected ? 'Disconnect' : 'Connect'),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.settings, color: colors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.colors});

  final List<_PayrollStat> stats;
  final _PayrollColors colors;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 2 ? 1.4 : 1.2,
          children: stats.map((stat) {
            final style = colors.statStyles[stat.color]!;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: style.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(stat.icon, color: style.color, size: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stat.label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat.value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.title,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (stat.color != _StatColor.yellow)
                        Icon(Icons.trending_up,
                            size: 14, color: style.color),
                      if (stat.color != _StatColor.yellow)
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          stat.change,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: style.color,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PayrollRunsTable extends StatelessWidget {
  const _PayrollRunsTable({
    required this.colors,
    required this.runs,
    required this.onDownload,
  });

  final _PayrollColors colors;
  final List<_PayrollRun> runs;
  final ValueChanged<_PayrollRun> onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: colors.muted),
                const SizedBox(width: 8),
                Text(
                  'Recent Payroll Runs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.title,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(colors.tableHeader),
              columns: const [
                DataColumn(label: Text('Pay Period')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Employees')),
                DataColumn(label: Text('Actions')),
              ],
              rows: runs.map((run) {
                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(run.period),
                          Text(run.date, style: TextStyle(color: colors.muted)),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.successSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 14, color: colors.success),
                            const SizedBox(width: 4),
                            Text(
                              run.status,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        run.amount,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.title,
                            ),
                      ),
                    ),
                    DataCell(Text(run.employees.toString())),
                    DataCell(
                      IconButton(
                        onPressed: () => onDownload(run),
                        icon: Icon(Icons.download_outlined, color: colors.muted),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingApprovalsCard extends StatelessWidget {
  const _PendingApprovalsCard({
    required this.colors,
    required this.pending,
    required this.onApprove,
    required this.onReview,
  });

  final _PayrollColors colors;
  final List<_PendingTimesheet> pending;
  final ValueChanged<_PendingTimesheet> onApprove;
  final ValueChanged<_PendingTimesheet> onReview;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.schedule_outlined, color: colors.warning),
                const SizedBox(width: 8),
                Text(
                  'Pending Approvals',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.title,
                      ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: pending.isEmpty
                ? Column(
                    children: [
                      Icon(Icons.check_circle,
                          size: 40, color: colors.muted),
                      const SizedBox(height: 8),
                      Text(
                        'No pending approvals',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.muted),
                      ),
                    ],
                  )
                : Column(
                    children: pending.map((timesheet) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.subtleSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        timesheet.employee,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: colors.title,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        timesheet.department,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: colors.muted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.warningSurface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    timesheet.status,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colors.warning,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _MetaText(
                                  label: 'Hours',
                                  value: '${timesheet.hours}',
                                  colors: colors,
                                ),
                                const SizedBox(width: 12),
                                _MetaText(
                                  label: 'OT',
                                  value: '${timesheet.overtime}',
                                  colors: colors,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => onApprove(timesheet),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colors.success,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => onReview(timesheet),
                                  child: const Text('Review'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Submitted ${timesheet.submitted}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colors.muted),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final _PayrollColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.muted,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.title,
              ),
        ),
      ],
    );
  }
}

class _IntegrationCard extends StatelessWidget {
  const _IntegrationCard({
    required this.colors,
    required this.config,
    required this.onOpenPortal,
    required this.onViewLogs,
  });

  final _PayrollColors colors;
  final _AdpConfig config;
  final VoidCallback onOpenPortal;
  final VoidCallback onViewLogs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.primarySurface),
            ),
            child: Icon(Icons.description_outlined, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADP Workforce Now Integration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.title,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  "This payroll system integrates with ADP's Workforce Now API for seamless payroll processing, timesheet sync, and employee data management.",
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.subtleSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '// Configure in Settings -> Integrations',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Client ID: ${config.clientId}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'API Endpoint: ${config.apiEndpoint}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onOpenPortal,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('ADP Developer Portal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onViewLogs,
                      child: const Text('View Integration Logs'),
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

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items, required this.colors});

  final List<_InfoItem> items;
  final _PayrollColors colors;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 12,
          childAspectRatio: 3.4,
          children: items.map((item) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.title,
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

class _PayrollColors {
  const _PayrollColors({
    required this.background,
    required this.surface,
    required this.subtleSurface,
    required this.border,
    required this.muted,
    required this.body,
    required this.title,
    required this.primary,
    required this.primarySurface,
    required this.success,
    required this.warning,
    required this.danger,
    required this.successSurface,
    required this.successBorder,
    required this.successText,
    required this.successTextSecondary,
    required this.warningSurface,
    required this.warningBorder,
    required this.warningText,
    required this.warningTextSecondary,
    required this.tableHeader,
    required this.tabSurface,
    required this.statStyles,
  });

  final Color background;
  final Color surface;
  final Color subtleSurface;
  final Color border;
  final Color muted;
  final Color body;
  final Color title;
  final Color primary;
  final Color primarySurface;
  final Color success;
  final Color warning;
  final Color danger;
  final Color successSurface;
  final Color successBorder;
  final Color successText;
  final Color successTextSecondary;
  final Color warningSurface;
  final Color warningBorder;
  final Color warningText;
  final Color warningTextSecondary;
  final Color tableHeader;
  final Color tabSurface;
  final Map<_StatColor, _StatStyle> statStyles;

  factory _PayrollColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    const success = Color(0xFF16A34A);
    const warning = Color(0xFFF59E0B);
    const danger = Color(0xFFDC2626);
    return _PayrollColors(
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      subtleSurface:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      body: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      title: isDark ? Colors.white : const Color(0xFF111827),
      primary: primary,
      primarySurface: isDark
          ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
          : const Color(0xFFDBEAFE),
      success: success,
      warning: warning,
      danger: danger,
      successSurface: isDark
          ? const Color(0xFF14532D).withValues(alpha: 0.25)
          : const Color(0xFFDCFCE7),
      successBorder: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0),
      successText: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
      successTextSecondary:
          isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      warningSurface: isDark
          ? const Color(0xFF78350F).withValues(alpha: 0.3)
          : const Color(0xFFFEF3C7),
      warningBorder: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
      warningText: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
      warningTextSecondary:
          isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309),
      tableHeader:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      tabSurface: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      statStyles: {
        _StatColor.green: _StatStyle(
          color: success,
          surface: success.withValues(alpha: isDark ? 0.25 : 0.15),
        ),
        _StatColor.blue: _StatStyle(
          color: primary,
          surface: primary.withValues(alpha: isDark ? 0.25 : 0.15),
        ),
        _StatColor.purple: _StatStyle(
          color: const Color(0xFF8B5CF6),
          surface: const Color(0xFF8B5CF6)
              .withValues(alpha: isDark ? 0.25 : 0.15),
        ),
        _StatColor.yellow: _StatStyle(
          color: warning,
          surface: warning.withValues(alpha: isDark ? 0.25 : 0.15),
        ),
      },
    );
  }
}

class _StatStyle {
  const _StatStyle({required this.color, required this.surface});

  final Color color;
  final Color surface;
}

enum _StatColor { green, blue, purple, yellow }

class _PayrollStat {
  const _PayrollStat({
    required this.label,
    required this.value,
    required this.change,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String change;
  final _StatColor color;
  final IconData icon;

  _PayrollStat copyWith({String? value}) {
    return _PayrollStat(
      label: label,
      value: value ?? this.value,
      change: change,
      color: color,
      icon: icon,
    );
  }
}

class _PayrollRun {
  const _PayrollRun({
    required this.id,
    required this.period,
    required this.status,
    required this.amount,
    required this.date,
    required this.employees,
  });

  final int id;
  final String period;
  final String status;
  final String amount;
  final String date;
  final int employees;
}

class _PendingTimesheet {
  const _PendingTimesheet({
    required this.id,
    required this.employee,
    required this.department,
    required this.hours,
    required this.overtime,
    required this.status,
    required this.submitted,
  });

  final int id;
  final String employee;
  final String department;
  final int hours;
  final int overtime;
  final String status;
  final String submitted;
}

class _AdpConfig {
  const _AdpConfig({
    required this.clientId,
    required this.clientSecret,
    required this.apiEndpoint,
    required this.connected,
    required this.lastSynced,
  });

  final String clientId;
  final String clientSecret;
  final String apiEndpoint;
  final bool connected;
  final String lastSynced;

  _AdpConfig copyWith({bool? connected, String? lastSynced}) {
    return _AdpConfig(
      clientId: clientId,
      clientSecret: clientSecret,
      apiEndpoint: apiEndpoint,
      connected: connected ?? this.connected,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }
}
