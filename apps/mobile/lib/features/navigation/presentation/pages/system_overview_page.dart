import 'package:flutter/material.dart';

class SystemOverviewPage extends StatelessWidget {
  const SystemOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final surface = isDark ? const Color(0xFF1F2937) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    const metrics = _SystemMetrics(
      cpu: 45,
      memory: 68,
      disk: 72,
      network: 34,
      uptime: '99.9%',
      activeUsers: 142,
      apiCalls: '2.4M',
      avgResponseTime: '85ms',
    );

    const services = [
      _ServiceStatus(
        name: 'API Gateway',
        status: _ServiceHealth.healthy,
        uptime: '99.99%',
        responseTime: '12ms',
      ),
      _ServiceStatus(
        name: 'Auth Service',
        status: _ServiceHealth.healthy,
        uptime: '99.95%',
        responseTime: '8ms',
      ),
      _ServiceStatus(
        name: 'Database Primary',
        status: _ServiceHealth.healthy,
        uptime: '100%',
        responseTime: '5ms',
      ),
      _ServiceStatus(
        name: 'Database Replica',
        status: _ServiceHealth.healthy,
        uptime: '99.98%',
        responseTime: '6ms',
      ),
      _ServiceStatus(
        name: 'File Storage',
        status: _ServiceHealth.healthy,
        uptime: '99.97%',
        responseTime: '15ms',
      ),
      _ServiceStatus(
        name: 'Email Service',
        status: _ServiceHealth.warning,
        uptime: '98.5%',
        responseTime: '125ms',
      ),
    ];

    const alerts = [
      _SystemAlert(
        level: _AlertLevel.warning,
        message: 'Email Service response time elevated',
        time: '5 min ago',
      ),
      _SystemAlert(
        level: _AlertLevel.info,
        message: 'Database backup completed successfully',
        time: '2 hours ago',
      ),
      _SystemAlert(
        level: _AlertLevel.info,
        message: 'System update deployed',
        time: '1 day ago',
      ),
    ];

    return Scaffold(
      backgroundColor: background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth > 1280 ? 1280.0 : constraints.maxWidth;
          final isWide = constraints.maxWidth >= 768;
          final pagePadding = EdgeInsets.all(isWide ? 24 : 16);
          final sectionSpacing = isWide ? 24.0 : 20.0;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: ListView(
                padding: pagePadding,
                children: [
                  Text(
                    'System Overview',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF111827),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monitor system health, performance, and infrastructure',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: muted,
                          fontSize: 16,
                        ),
                  ),
                  SizedBox(height: sectionSpacing),
                  _MetricsGrid(metrics: metrics),
                  SizedBox(height: sectionSpacing),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1024;
                      final children = [
                        Expanded(
                          child: _ResourceUsageCard(
                            metrics: metrics,
                            surface: surface,
                            border: border,
                            muted: muted,
                          ),
                        ),
                        const SizedBox(width: 24, height: 24),
                        Expanded(
                          child: _ServicesStatusCard(
                            services: services,
                            surface: surface,
                            border: border,
                            muted: muted,
                          ),
                        ),
                      ];
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: children,
                        );
                      }
                      return Column(children: children);
                    },
                  ),
                  SizedBox(height: sectionSpacing),
                  _AlertsCard(
                    alerts: alerts,
                    surface: surface,
                    border: border,
                    muted: muted,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final _SystemMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1024 ? 4 : 2;
        final aspectRatio = columns == 2 ? 1.1 : 1.2;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: [
            _MetricCard(
              label: 'System Uptime',
              value: metrics.uptime,
              icon: Icons.dns_outlined,
              accent: const Color(0xFF2563EB),
              secondaryAccent: const Color(0xFF4F46E5),
              trailing: const Icon(
                Icons.check_circle,
                color: Color(0xFF22C55E),
                size: 24,
              ),
            ),
            _MetricCard(
              label: 'Active Users',
              value: metrics.activeUsers.toString(),
              icon: Icons.groups_outlined,
              accent: const Color(0xFF7C3AED),
              secondaryAccent: const Color(0xFFDB2777),
            ),
            _MetricCard(
              label: 'API Calls Today',
              value: metrics.apiCalls,
              icon: Icons.bolt_outlined,
              accent: const Color(0xFF16A34A),
              secondaryAccent: const Color(0xFF059669),
            ),
            _MetricCard(
              label: 'Avg Response Time',
              value: metrics.avgResponseTime,
              icon: Icons.speed_outlined,
              accent: const Color(0xFFF97316),
              secondaryAccent: const Color(0xFFEF4444),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.secondaryAccent,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color? secondaryAccent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = accent.withValues(alpha: isDark ? 0.5 : 0.35);
    final gradient = LinearGradient(
      colors: [
        accent.withValues(alpha: isDark ? 0.3 : 0.15),
        (secondaryAccent ?? accent)
            .withValues(alpha: isDark ? 0.3 : 0.12),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: _cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 30,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: accent.withValues(alpha: isDark ? 0.8 : 0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );
  }
}

class _ResourceUsageCard extends StatelessWidget {
  const _ResourceUsageCard({
    required this.metrics,
    required this.surface,
    required this.border,
    required this.muted,
  });

  final _SystemMetrics metrics;
  final Color surface;
  final Color border;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: _cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resource Usage',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 16),
          _UsageRow(
            label: 'CPU Usage',
            value: metrics.cpu,
            icon: Icons.memory_outlined,
            color: const Color(0xFF3B82F6),
            muted: muted,
          ),
          const SizedBox(height: 20),
          _UsageRow(
            label: 'Memory Usage',
            value: metrics.memory,
            icon: Icons.storage_outlined,
            color: const Color(0xFF8B5CF6),
            muted: muted,
          ),
          const SizedBox(height: 20),
          _UsageRow(
            label: 'Disk Usage',
            value: metrics.disk,
            icon: Icons.sd_storage_outlined,
            color: const Color(0xFFF97316),
            muted: muted,
          ),
          const SizedBox(height: 20),
          _UsageRow(
            label: 'Network Usage',
            value: metrics.network,
            icon: Icons.network_check,
            color: const Color(0xFF22C55E),
            muted: muted,
          ),
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.muted,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: muted,
                        fontSize: 14,
                      ),
                ),
              ],
            ),
            Text(
              '$value%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontSize: 14,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 12,
            backgroundColor:
                isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ServicesStatusCard extends StatelessWidget {
  const _ServicesStatusCard({
    required this.services,
    required this.surface,
    required this.border,
    required this.muted,
  });

  final List<_ServiceStatus> services;
  final Color surface;
  final Color border;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: _cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 16),
          ...services.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ServiceStatusTile(
                service: service,
                muted: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceStatusTile extends StatelessWidget {
  const _ServiceStatusTile({required this.service, required this.muted});

  final _ServiceStatus service;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHealthy = service.status == _ServiceHealth.healthy;
    final accent = isHealthy ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
    final background = accent.withValues(alpha: isDark ? 0.18 : 0.12);
    final border = accent.withValues(alpha: isDark ? 0.5 : 0.35);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 20,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    service.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                          fontSize: 14,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isHealthy ? 'healthy' : 'warning',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: accent,
                        fontSize: 12,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Uptime: ${service.uptime}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 14,
                    ),
              ),
              const SizedBox(width: 12),
              Text(
                'Response: ${service.responseTime}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 14,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({
    required this.alerts,
    required this.surface,
    required this.border,
    required this.muted,
  });

  final List<_SystemAlert> alerts;
  final Color surface;
  final Color border;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: _cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Alerts',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 16),
          ...alerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AlertTile(alert: alert, muted: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.muted});

  final _SystemAlert alert;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWarning = alert.level == _AlertLevel.warning;
    final accent = isWarning ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6);
    final background = accent.withValues(alpha: isDark ? 0.18 : 0.12);
    final border = accent.withValues(alpha: isDark ? 0.45 : 0.3);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.check_circle,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                        fontSize: 14,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontSize: 14,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<BoxShadow> _cardShadow(bool isDark) {
  return [
    BoxShadow(
      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

class _SystemMetrics {
  const _SystemMetrics({
    required this.cpu,
    required this.memory,
    required this.disk,
    required this.network,
    required this.uptime,
    required this.activeUsers,
    required this.apiCalls,
    required this.avgResponseTime,
  });

  final int cpu;
  final int memory;
  final int disk;
  final int network;
  final String uptime;
  final int activeUsers;
  final String apiCalls;
  final String avgResponseTime;
}

enum _ServiceHealth { healthy, warning }

class _ServiceStatus {
  const _ServiceStatus({
    required this.name,
    required this.status,
    required this.uptime,
    required this.responseTime,
  });

  final String name;
  final _ServiceHealth status;
  final String uptime;
  final String responseTime;
}

enum _AlertLevel { info, warning }

class _SystemAlert {
  const _SystemAlert({
    required this.level,
    required this.message,
    required this.time,
  });

  final _AlertLevel level;
  final String message;
  final String time;
}
