import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../dashboard/presentation/pages/reports_page.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _dateRange = '30days';
  String _chartPeriod = 'weekly';
  String _selectedChartType = 'bar';
  String _selectedGrouping = 'daily';
  int? _expandedPrediction;
  final TextEditingController _shareEmailController = TextEditingController();
  final List<_CustomKpi> _customKpis = [
    _CustomKpi(
      name: 'Revenue per Employee',
      value: r'$832K',
      change: '+5.2%',
      trendUp: true,
      icon: Icons.attach_money,
      color: Colors.green,
    ),
    _CustomKpi(
      name: 'Customer Satisfaction',
      value: '4.7/5',
      change: '+0.3',
      trendUp: true,
      icon: Icons.star,
      color: Colors.orange,
    ),
    _CustomKpi(
      name: 'Project Completion Time',
      value: '12.4 days',
      change: '-1.8 days',
      trendUp: true,
      icon: Icons.schedule,
      color: Colors.blue,
    ),
    _CustomKpi(
      name: 'Safety Compliance Score',
      value: '98.2%',
      change: '+2.1%',
      trendUp: true,
      icon: Icons.verified,
      color: Colors.green,
    ),
    _CustomKpi(
      name: 'Equipment Utilization',
      value: '76%',
      change: '+4%',
      trendUp: true,
      icon: Icons.build_circle,
      color: Colors.purple,
    ),
    _CustomKpi(
      name: 'First-Time Fix Rate',
      value: '89%',
      change: '+6%',
      trendUp: true,
      icon: Icons.check_circle,
      color: Colors.teal,
    ),
  ];

  @override
  void dispose() {
    _shareEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderSection(
            dateRange: _dateRange,
            onDateRangeChanged: (value) {
              setState(() => _dateRange = value ?? _dateRange);
            },
            onFilterPressed: () => _showFilters(context),
            onExportPressed: () => _openReportsPage(context),
            onSharePressed: _shareDashboard,
            onSavePressed: _saveDashboardView,
          ),
          const SizedBox(height: 16),
          _buildRealTimeDashboard(context),
          const SizedBox(height: 16),
          _buildAutomationSection(context),
          const SizedBox(height: 16),
          _buildKeyMetrics(context),
          const SizedBox(height: 16),
          _buildPerformanceOverview(context),
          const SizedBox(height: 16),
          _buildPredictiveAndBenchmarking(context),
          const SizedBox(height: 16),
          _buildKpiAndInsights(context),
          const SizedBox(height: 16),
          _buildVisualizationControls(context),
          const SizedBox(height: 24),
          _buildCollaborationSection(context),
          const SizedBox(height: 24),
          _buildDataSourcesSection(context),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openReportsPage(context),
            icon: const Icon(Icons.bar_chart_outlined),
            label: const Text('Open Submissions Report'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRealTimeDashboard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = [
      _StatCardData(
        label: 'Active Now',
        value: '156',
        change: '+8',
        icon: Icons.bolt,
        color: Colors.green,
      ),
      _StatCardData(
        label: 'Pending Tasks',
        value: '43',
        change: '-5',
        icon: Icons.schedule,
        color: Colors.orange,
      ),
      _StatCardData(
        label: 'Completed Today',
        value: '89',
        change: '+12',
        icon: Icons.check_circle,
        color: Colors.blue,
      ),
      _StatCardData(
        label: 'Open Incidents',
        value: '7',
        change: '-2',
        icon: Icons.warning_amber,
        color: Colors.red,
      ),
      _StatCardData(
        label: 'Online Users',
        value: '234',
        change: '+15',
        icon: Icons.people,
        color: Colors.purple,
      ),
      _StatCardData(
        label: 'New Documents',
        value: '28',
        change: '+4',
        icon: Icons.description,
        color: Colors.cyan,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.refresh, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Real-Time Data Dashboard',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Text(
                  'Live updates',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Last refreshed: just now',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            _ResponsiveGrid(
              items: stats
                  .map((stat) => _StatCard(stat: stat))
                  .toList(),
              minItemWidth: 160,
              itemAspectRatio: 1.3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Advanced Analytics & Automation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Automated reporting, advanced search, and intelligent reminders.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            _ResponsiveGrid(
              minItemWidth: 220,
              itemAspectRatio: 1.6,
              items: [
                _AutomationCard(
                  icon: Icons.bar_chart,
                  color: Colors.blue,
                  title: 'Automated Reports',
                  subtitle: 'Excel, Tableau, Power BI',
                  description:
                      'Schedule automated reports with custom filters and recurring deliveries.',
                  onTap: () => _showAutomatedReports(context),
                ),
                _AutomationCard(
                  icon: Icons.search,
                  color: Colors.green,
                  title: 'Advanced Search',
                  subtitle: 'Deep Drill-Down Analytics',
                  description:
                      'Search by date, keyword, geography, and custom criteria.',
                  onTap: () => _showAdvancedSearch(context),
                ),
                _AutomationCard(
                  icon: Icons.notifications_active,
                  color: Colors.purple,
                  title: 'Smart Reminders',
                  subtitle: 'Upload-Based Automation',
                  description:
                      'Set automated reminders based on uploads, schedules, or conditions.',
                  onTap: () => _showAutomatedReminders(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetrics(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = [
      _MetricCardData(
        label: 'Total Tasks',
        value: '1,847',
        change: '+12%',
        trendUp: true,
        icon: Icons.check_circle,
        footerLabel: 'Completed',
        footerValue: '1,523',
        accent: Colors.blue,
      ),
      _MetricCardData(
        label: 'Active Users',
        value: '342',
        change: '+8%',
        trendUp: true,
        icon: Icons.people,
        footerLabel: 'Teams',
        footerValue: '24',
        accent: Colors.green,
      ),
      _MetricCardData(
        label: 'Completion Rate',
        value: '87.4%',
        change: '-2.3%',
        trendUp: false,
        icon: Icons.flag,
        footerLabel: 'Progress',
        footerValue: '87.4%',
        accent: Colors.orange,
      ),
      _MetricCardData(
        label: 'Revenue Impact',
        value: r'$284K',
        change: '+15.2%',
        trendUp: true,
        icon: Icons.attach_money,
        footerLabel: 'Target',
        footerValue: r'$320K (88.8%)',
        accent: Colors.purple,
      ),
    ];

    return _ResponsiveGrid(
      minItemWidth: 220,
      itemAspectRatio: 1.3,
      items: metrics
          .map(
            (metric) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          metric.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const Spacer(),
                        Icon(metric.icon, color: metric.accent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      metric.value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          metric.trendUp
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 16,
                          color: metric.trendUp ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${metric.change} from last period',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: metric.trendUp
                                    ? Colors.green
                                    : Colors.red,
                              ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Divider(color: scheme.outlineVariant),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          metric.footerLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        Text(
                          metric.footerValue,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPerformanceOverview(BuildContext context) {
    return _ResponsiveGrid(
      minItemWidth: 280,
      itemAspectRatio: 1.2,
      items: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Performance Trends',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    _PeriodToggle(
                      value: _chartPeriod,
                      onChanged: (value) {
                        setState(() => _chartPeriod = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LineChart(
                    _buildLineChartData(_chartPeriod),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pie_chart, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Task Distribution',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 32,
                      sections: [
                        _pieSection(45, Colors.red, 'Safety'),
                        _pieSection(30, Colors.blue, 'Maintenance'),
                        _pieSection(15, Colors.green, 'Installations'),
                        _pieSection(10, Colors.orange, 'Quality'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _LegendRow(label: 'Safety Inspections', value: '45%'),
                _LegendRow(label: 'Maintenance', value: '30%'),
                _LegendRow(label: 'Installations', value: '15%'),
                _LegendRow(label: 'Quality Checks', value: '10%'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictiveAndBenchmarking(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final predictions = [
      _Prediction(
        title: 'Task Completion Forecast',
        summary:
            'Projected to complete 2,140 tasks next month based on current trends.',
        detail:
            'Week 1: 510 tasks\nWeek 2: 530 tasks\nWeek 3: 545 tasks\nWeek 4: 555 tasks',
        confidence: '94%',
        highlight: '+15.9% vs. current month',
        icon: Icons.trending_up,
        color: Colors.green,
      ),
      _Prediction(
        title: 'Risk Alert Prediction',
        summary:
            'Three high-risk incidents likely in the next 14 days based on patterns.',
        detail:
            'Equipment maintenance overdue (2 units)\nWeather conditions unfavorable\nHigh workload period approaching',
        confidence: '87%',
        highlight: 'Review prevention tasks',
        icon: Icons.warning_amber,
        color: Colors.orange,
      ),
      _Prediction(
        title: 'Revenue Projection',
        summary:
            'Projected revenue next quarter: \$892K based on performance.',
        detail:
            'Month 1: \$285K\nMonth 2: \$295K\nMonth 3: \$312K\nOn track for 94% of target',
        confidence: '91%',
        highlight: 'Target: \$950K (93.9%)',
        icon: Icons.attach_money,
        color: Colors.green,
      ),
    ];

    final benchmarks = [
      _Benchmark(
        metric: 'Task Completion Rate',
        yourValue: '87.4%',
        industry: '82.3%',
        status: 'Above',
      ),
      _Benchmark(
        metric: 'Incident Response Time',
        yourValue: '2.4 hrs',
        industry: '3.1 hrs',
        status: 'Above',
      ),
      _Benchmark(
        metric: 'Training Completion',
        yourValue: '94%',
        industry: '88%',
        status: 'Above',
      ),
      _Benchmark(
        metric: 'Document Processing Speed',
        yourValue: '1.8 days',
        industry: '1.6 days',
        status: 'Below',
      ),
      _Benchmark(
        metric: 'Employee Utilization',
        yourValue: '78%',
        industry: '85%',
        status: 'Below',
      ),
    ];

    return _ResponsiveGrid(
      minItemWidth: 300,
      itemAspectRatio: 1.1,
      items: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'AI-Powered Predictions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Chip(
                      label: const Text('Beta'),
                      backgroundColor: scheme.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...predictions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final prediction = entry.value;
                  final expanded = _expandedPrediction == index;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _expandedPrediction =
                              expanded ? null : index;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(prediction.icon, color: prediction.color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    prediction.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Icon(
                                  expanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              prediction.summary,
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                            if (expanded) ...[
                              const SizedBox(height: 8),
                              Text(
                                prediction.detail,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Confidence: ${prediction.confidence}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  prediction.highlight,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart, color: Colors.cyan),
                    const SizedBox(width: 8),
                    Text(
                      'Industry Benchmarking',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _showBenchmarkUpdate(context),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Update'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...benchmarks.map((benchmark) {
                  final above = benchmark.status == 'Above';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  benchmark.metric,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  above ? 'Above Avg' : 'Below Avg',
                                ),
                                backgroundColor: above
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _BenchmarkValue(
                                  label: 'Your Performance',
                                  value: benchmark.yourValue,
                                ),
                              ),
                              Expanded(
                                child: _BenchmarkValue(
                                  label: 'Industry Average',
                                  value: benchmark.industry,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiAndInsights(BuildContext context) {
    return _ResponsiveGrid(
      minItemWidth: 300,
      itemAspectRatio: 1.1,
      items: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text(
                      'Custom KPI Builder',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _showKpiBuilder(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New KPI'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ResponsiveGrid(
                  minItemWidth: 220,
                  itemAspectRatio: 1.6,
                  items: _customKpis
                      .map(
                        (kpi) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          kpi.color.withValues(alpha: 0.15),
                                      child: Icon(
                                        kpi.icon,
                                        color: kpi.color,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        kpi.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  kpi.value,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      kpi.trendUp
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      size: 14,
                                      color: kpi.trendUp
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${kpi.change} from last period',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on, color: Colors.yellow),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Insights',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._quickInsights.map((insight) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('${insight.actionLabel}: ${insight.text}'),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor:
                            insight.color.withValues(alpha: 0.15),
                        child: Icon(insight.icon, color: insight.color),
                      ),
                      title: Text(insight.text),
                      subtitle: Text(insight.actionLabel),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                }).toList(),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _showAlertSettings(context),
                  icon: const Icon(Icons.notifications_active, size: 16),
                  label: const Text('Configure Alerts'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisualizationControls(BuildContext context) {
    return _ResponsiveGrid(
      minItemWidth: 320,
      itemAspectRatio: 1.05,
      items: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Visualization Controls',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _showVisualizationSettings(context),
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Customize'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Chart Type',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _ResponsiveGrid(
                  minItemWidth: 90,
                  itemAspectRatio: 1.3,
                  items: [
                    _ChartTypeButton(
                      icon: Icons.bar_chart,
                      label: 'Bar',
                      value: 'bar',
                      selected: _selectedChartType == 'bar',
                      onPressed: () => setState(() {
                        _selectedChartType = 'bar';
                      }),
                    ),
                    _ChartTypeButton(
                      icon: Icons.show_chart,
                      label: 'Line',
                      value: 'line',
                      selected: _selectedChartType == 'line',
                      onPressed: () => setState(() {
                        _selectedChartType = 'line';
                      }),
                    ),
                    _ChartTypeButton(
                      icon: Icons.pie_chart,
                      label: 'Pie',
                      value: 'pie',
                      selected: _selectedChartType == 'pie',
                      onPressed: () => setState(() {
                        _selectedChartType = 'pie';
                      }),
                    ),
                    _ChartTypeButton(
                      icon: Icons.stacked_line_chart,
                      label: 'Area',
                      value: 'area',
                      selected: _selectedChartType == 'area',
                      onPressed: () => setState(() {
                        _selectedChartType = 'area';
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Group By',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _GroupingChip(
                      label: 'Daily',
                      value: 'daily',
                      selected: _selectedGrouping == 'daily',
                      onTap: () => setState(() {
                        _selectedGrouping = 'daily';
                      }),
                    ),
                    _GroupingChip(
                      label: 'Weekly',
                      value: 'weekly',
                      selected: _selectedGrouping == 'weekly',
                      onTap: () => setState(() {
                        _selectedGrouping = 'weekly';
                      }),
                    ),
                    _GroupingChip(
                      label: 'Monthly',
                      value: 'monthly',
                      selected: _selectedGrouping == 'monthly',
                      onTap: () => setState(() {
                        _selectedGrouping = 'monthly';
                      }),
                    ),
                    _GroupingChip(
                      label: 'Quarterly',
                      value: 'quarterly',
                      selected: _selectedGrouping == 'quarterly',
                      onTap: () => setState(() {
                        _selectedGrouping = 'quarterly';
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollaborationSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final link = _shareLink();
    final comments = const [
      _CommentEntry(
        user: 'Sarah J.',
        comment: 'Great insights on Q4 performance',
        time: '2h ago',
      ),
      _CommentEntry(
        user: 'Mike C.',
        comment: 'Can we drill down into Alpha Team?',
        time: '5h ago',
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Collaboration & Sharing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _CollaborationCard(
              border: border,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.share_outlined,
                          size: 16,
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Share Dashboard',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _shareEmailController,
                          decoration: InputDecoration(
                            hintText: 'Enter email addresses...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          final email = _shareEmailController.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Enter an email address.')),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Dashboard shared with $email.'),
                            ),
                          );
                          _shareEmailController.clear();
                        },
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CollaborationCard(
              border: border,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link,
                          size: 16,
                          color: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Text(
                        'Shareable Link',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            link,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: _copyShareLink,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CollaborationCard(
              border: border,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.comment_outlined,
                          size: 16,
                          color: isDark
                              ? const Color(0xFFC4B5FD)
                              : const Color(0xFF7C3AED)),
                      const SizedBox(width: 8),
                      Text(
                        'Comments (${comments.length})',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...comments.map((comment) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                comment.user,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                comment.time,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment.comment,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Opening comments thread...')),
                        );
                      },
                      child: const Text('View all comments'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CollaborationCard(
              border: border,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mail_outline,
                          size: 16,
                          color: isDark
                              ? const Color(0xFFFDBA74)
                              : const Color(0xFFEA580C)),
                      const SizedBox(width: 8),
                      Text(
                        'Email Digest',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF7C2D12)
                              : const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Active',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? const Color(0xFFFED7AA)
                                : const Color(0xFF9A3412),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Receive weekly summary every Monday at 9:00 AM',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Opening subscription manager...')),
                        );
                      },
                      child: const Text('Manage subscriptions'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSourcesSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final sources = const [
      _DataSourceEntry(
        name: 'Salesforce',
        status: 'Connected',
        lastSync: '5 min ago',
        color: Color(0xFF3B82F6),
      ),
      _DataSourceEntry(
        name: 'QuickBooks',
        status: 'Connected',
        lastSync: '1 hour ago',
        color: Color(0xFF22C55E),
      ),
      _DataSourceEntry(
        name: 'Google Analytics',
        status: 'Connected',
        lastSync: '15 min ago',
        color: Color(0xFFF97316),
      ),
      _DataSourceEntry(
        name: 'Jira',
        status: 'Connected',
        lastSync: '2 hours ago',
        color: Color(0xFF2563EB),
      ),
      _DataSourceEntry(
        name: 'Slack',
        status: 'Connected',
        lastSync: 'Real-time',
        color: Color(0xFFA855F7),
      ),
      _DataSourceEntry(
        name: 'HubSpot',
        status: 'Setup Required',
        lastSync: 'N/A',
        color: Color(0xFF6B7280),
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage_outlined, color: Colors.cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected Data Sources',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage integrations and data connections',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Opening data source connector...')),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Source'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1100
                    ? 6
                    : width >= 900
                        ? 4
                        : width >= 680
                            ? 3
                            : 2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: sources.map((source) {
                    final isConnected = source.status == 'Connected';
                    return InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${source.name} - ${source.status} (Last sync: ${source.lastSync})',
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF111827)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: source.color,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.storage_outlined,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isConnected
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFF9CA3AF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              source.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              source.lastSync,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChartData(String period) {
    final spots = _lineSpots(period);
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: Colors.blue,
          barWidth: 3,
          isCurved: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _lineSpots(String period) {
    switch (period) {
      case 'daily':
        return const [
          FlSpot(0, 20),
          FlSpot(1, 40),
          FlSpot(2, 35),
          FlSpot(3, 55),
          FlSpot(4, 60),
          FlSpot(5, 70),
          FlSpot(6, 65),
        ];
      case 'monthly':
        return const [
          FlSpot(0, 50),
          FlSpot(1, 60),
          FlSpot(2, 55),
          FlSpot(3, 70),
          FlSpot(4, 68),
          FlSpot(5, 75),
        ];
      case 'weekly':
      default:
        return const [
          FlSpot(0, 45),
          FlSpot(1, 52),
          FlSpot(2, 48),
          FlSpot(3, 60),
          FlSpot(4, 58),
          FlSpot(5, 65),
          FlSpot(6, 62),
        ];
    }
  }

  PieChartSectionData _pieSection(double value, Color color, String title) {
    return PieChartSectionData(
      value: value,
      color: color,
      radius: 50,
      title: title,
      titleStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  void _showAutomatedReports(BuildContext context) {
    _showInfoSheet(
      context,
      title: 'Automated Reports',
      description:
          'Schedule exports to Excel, Tableau, or Power BI with recurring delivery.',
      actionLabel: 'Schedule report',
    );
  }

  void _showAdvancedSearch(BuildContext context) {
    _showInfoSheet(
      context,
      title: 'Advanced Search',
      description:
          'Drill into submissions, assets, incidents, and projects with flexible filters.',
      actionLabel: 'Open advanced search',
    );
  }

  void _showAutomatedReminders(BuildContext context) {
    _showInfoSheet(
      context,
      title: 'Smart Reminders',
      description:
          'Configure automated reminders based on upload activity or schedules.',
      actionLabel: 'Create reminder',
    );
  }

  void _showKpiBuilder(BuildContext context) {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New KPI',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'KPI name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Value'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final value = valueController.text.trim();
                  if (name.isEmpty || value.isEmpty) return;
                  setState(() {
                    _customKpis.add(
                      _CustomKpi(
                        name: name,
                        value: value,
                        change: '+0%',
                        trendUp: true,
                        icon: Icons.insights,
                        color: Colors.indigo,
                      ),
                    );
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Add KPI'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showFilters(BuildContext context) {
    _showInfoSheet(
      context,
      title: 'Filters',
      description: 'Filter by date range, role, location, or status.',
      actionLabel: 'Apply filters',
    );
  }

  void _showBenchmarkUpdate(BuildContext context) {
    _showInfoSheet(
      context,
      title: 'Industry Benchmarks',
      description:
          'Refreshing benchmarks with the latest industry performance data.',
      actionLabel: 'Update benchmarks',
    );
  }

  void _showAlertSettings(BuildContext context) {
    _showInfoSheet(
      context,
      title: 'Alert Configuration',
      description:
          'Set alert thresholds for KPIs, incidents, and operational risks.',
      actionLabel: 'Configure alerts',
    );
  }

  void _showVisualizationSettings(BuildContext context) {
    _showInfoSheet(
      context,
      title: 'Visualization Controls',
      description:
          'Customize chart types, colors, and grouping for the dashboard.',
      actionLabel: 'Save visualization',
    );
  }

  String _shareLink() {
    return 'https://formbridge.app/share/analytics?range=$_dateRange';
  }

  Future<void> _shareDashboard() async {
    final link = _shareLink();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'FormBridge analytics dashboard\n$link',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share right now.')),
      );
    }
  }

  void _saveDashboardView() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dashboard saved to favorites.')),
    );
  }

  Future<void> _copyShareLink() async {
    final link = _shareLink();
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share link copied.')),
    );
  }

  void _showInfoSheet(
    BuildContext context, {
    required String title,
    required String description,
    required String actionLabel,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(actionLabel),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openReportsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReportsPage()),
    );
  }
}

class _CollaborationCard extends StatelessWidget {
  const _CollaborationCard({
    required this.border,
    required this.isDark,
    required this.child,
  });

  final Color border;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.dateRange,
    required this.onDateRangeChanged,
    required this.onFilterPressed,
    required this.onExportPressed,
    required this.onSharePressed,
    required this.onSavePressed,
  });

  final String dateRange;
  final ValueChanged<String?> onDateRangeChanged;
  final VoidCallback onFilterPressed;
  final VoidCallback onExportPressed;
  final VoidCallback onSharePressed;
  final VoidCallback onSavePressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reports & Analytics',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Monitor performance and key metrics across all operations.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                value: dateRange,
                decoration: const InputDecoration(
                  labelText: 'Date range',
                ),
                items: const [
                  DropdownMenuItem(value: '7days', child: Text('Last 7 Days')),
                  DropdownMenuItem(value: '30days', child: Text('Last 30 Days')),
                  DropdownMenuItem(value: '90days', child: Text('Last 90 Days')),
                  DropdownMenuItem(value: 'year', child: Text('This Year')),
                ],
                onChanged: onDateRangeChanged,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onFilterPressed,
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Filters'),
            ),
            OutlinedButton.icon(
              onPressed: onSharePressed,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share'),
            ),
            OutlinedButton.icon(
              onPressed: onSavePressed,
              icon: const Icon(Icons.bookmark_border),
              label: const Text('Save View'),
            ),
            FilledButton.icon(
              onPressed: onExportPressed,
              icon: const Icon(Icons.download),
              label: const Text('Export Report'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.items,
    required this.minItemWidth,
    required this.itemAspectRatio,
  });

  final List<Widget> items;
  final double minItemWidth;
  final double itemAspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = max(1, (constraints.maxWidth / minItemWidth).floor());
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: itemAspectRatio,
          children: items,
        );
      },
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.label,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _StatCardData stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final positive = stat.change.startsWith('+');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(stat.icon, color: stat.color),
              const Spacer(),
              Text(
                stat.change,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: positive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _AutomationCard extends StatelessWidget {
  const _AutomationCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.change,
    required this.trendUp,
    required this.icon,
    required this.footerLabel,
    required this.footerValue,
    required this.accent,
  });

  final String label;
  final String value;
  final String change;
  final bool trendUp;
  final IconData icon;
  final String footerLabel;
  final String footerValue;
  final Color accent;
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        _PeriodChip(
          label: 'Daily',
          selected: value == 'daily',
          onTap: () => onChanged('daily'),
        ),
        _PeriodChip(
          label: 'Weekly',
          selected: value == 'weekly',
          onTap: () => onChanged('weekly'),
        ),
        _PeriodChip(
          label: 'Monthly',
          selected: value == 'monthly',
          onTap: () => onChanged('monthly'),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _Prediction {
  const _Prediction({
    required this.title,
    required this.summary,
    required this.detail,
    required this.confidence,
    required this.highlight,
    required this.icon,
    required this.color,
  });

  final String title;
  final String summary;
  final String detail;
  final String confidence;
  final String highlight;
  final IconData icon;
  final Color color;
}

class _Benchmark {
  const _Benchmark({
    required this.metric,
    required this.yourValue,
    required this.industry,
    required this.status,
  });

  final String metric;
  final String yourValue;
  final String industry;
  final String status;
}

class _BenchmarkValue extends StatelessWidget {
  const _BenchmarkValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _CommentEntry {
  const _CommentEntry({
    required this.user,
    required this.comment,
    required this.time,
  });

  final String user;
  final String comment;
  final String time;
}

class _DataSourceEntry {
  const _DataSourceEntry({
    required this.name,
    required this.status,
    required this.lastSync,
    required this.color,
  });

  final String name;
  final String status;
  final String lastSync;
  final Color color;
}

class _CustomKpi {
  const _CustomKpi({
    required this.name,
    required this.value,
    required this.change,
    required this.trendUp,
    required this.icon,
    required this.color,
  });

  final String name;
  final String value;
  final String change;
  final bool trendUp;
  final IconData icon;
  final Color color;
}

class _InsightItem {
  const _InsightItem({
    required this.text,
    required this.actionLabel,
    required this.icon,
    required this.color,
  });

  final String text;
  final String actionLabel;
  final IconData icon;
  final Color color;
}

const _quickInsights = [
  _InsightItem(
    text: 'Alpha Team exceeds targets',
    actionLabel: 'View Report',
    icon: Icons.trending_up,
    color: Colors.green,
  ),
  _InsightItem(
    text: 'Training deadline in 3 days',
    actionLabel: 'Send Reminder',
    icon: Icons.notifications,
    color: Colors.orange,
  ),
  _InsightItem(
    text: 'New compliance requirements',
    actionLabel: 'Review',
    icon: Icons.description,
    color: Colors.blue,
  ),
  _InsightItem(
    text: 'Asset maintenance overdue',
    actionLabel: 'Schedule',
    icon: Icons.warning_amber,
    color: Colors.red,
  ),
  _InsightItem(
    text: 'Budget variance detected',
    actionLabel: 'Analyze',
    icon: Icons.account_balance_wallet,
    color: Colors.orange,
  ),
];

class _ChartTypeButton extends StatelessWidget {
  const _ChartTypeButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? scheme.primary : scheme.onSurface),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupingChip extends StatelessWidget {
  const _GroupingChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
