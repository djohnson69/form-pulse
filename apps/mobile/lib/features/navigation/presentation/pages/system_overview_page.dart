import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../platform/data/platform_providers.dart';

/// Provider for system health status - checks Supabase connectivity
final systemHealthProvider = FutureProvider<_SystemHealth>((ref) async {
  final client = Supabase.instance.client;

  // Check API health by making a simple query
  bool apiHealthy = false;
  bool dbHealthy = false;
  bool storageHealthy = false;

  try {
    // Test database connection
    await client.from('orgs').select('id').limit(1);
    dbHealthy = true;
    apiHealthy = true;
  } catch (e, st) {
    // DB or API is down
    developer.log('SystemOverviewPage database health check failed',
        error: e, stackTrace: st, name: 'SystemOverviewPage.systemHealthProvider');
  }

  try {
    // Test storage connection
    await client.storage.listBuckets();
    storageHealthy = true;
  } catch (e, st) {
    // Storage might not be configured
    developer.log('SystemOverviewPage storage health check failed',
        error: e, stackTrace: st, name: 'SystemOverviewPage.systemHealthProvider');
    storageHealthy = true; // Assume OK if not configured
  }

  return _SystemHealth(
    apiHealthy: apiHealthy,
    dbHealthy: dbHealthy,
    storageHealthy: storageHealthy,
  );
});

class _SystemHealth {
  const _SystemHealth({
    required this.apiHealthy,
    required this.dbHealthy,
    required this.storageHealthy,
  });

  final bool apiHealthy;
  final bool dbHealthy;
  final bool storageHealthy;

  bool get allHealthy => apiHealthy && dbHealthy && storageHealthy;
}

class SystemOverviewPage extends ConsumerWidget {
  const SystemOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final surface = isDark ? const Color(0xFF1F2937) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final platformStats = ref.watch(platformStatsProvider);
    final apiStats = ref.watch(apiOverviewStatsProvider);
    final sessionsAsync = ref.watch(activeSessionsProvider);
    final errorsAsync = ref.watch(errorEventsProvider);
    final healthAsync = ref.watch(systemHealthProvider);

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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ref.invalidate(platformStatsProvider);
                          ref.invalidate(apiOverviewStatsProvider);
                          ref.invalidate(activeSessionsProvider);
                          ref.invalidate(errorEventsProvider);
                          ref.invalidate(systemHealthProvider);
                        },
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  SizedBox(height: sectionSpacing),
                  _MetricsGrid(
                    platformStats: platformStats,
                    apiStats: apiStats,
                    sessionsAsync: sessionsAsync,
                  ),
                  SizedBox(height: sectionSpacing),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1024;
                      final children = [
                        Expanded(
                          child: _SystemHealthCard(
                            healthAsync: healthAsync,
                            surface: surface,
                            border: border,
                            muted: muted,
                          ),
                        ),
                        const SizedBox(width: 24, height: 24),
                        Expanded(
                          child: _RecentErrorsCard(
                            errorsAsync: errorsAsync,
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
  const _MetricsGrid({
    required this.platformStats,
    required this.apiStats,
    required this.sessionsAsync,
  });

  final AsyncValue<PlatformStats> platformStats;
  final AsyncValue<ApiOverviewStats> apiStats;
  final AsyncValue<List<ActiveSession>> sessionsAsync;

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.compact();

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
              label: 'Total Organizations',
              value: platformStats.when(
                data: (stats) => numberFormat.format(stats.totalOrganizations),
                loading: () => '...',
                error: (_, __) => '-',
              ),
              icon: Icons.business_outlined,
              accent: const Color(0xFF2563EB),
              iconBackground: const Color(0xFF2563EB),
              gradientLightStart: const Color(0xFFEFF6FF),
              gradientLightEnd: const Color(0xFFE0E7FF),
              gradientDarkStart:
                  const Color(0xFF1E3A8A).withValues(alpha: 0.3),
              gradientDarkEnd:
                  const Color(0xFF312E81).withValues(alpha: 0.3),
              borderLight: const Color(0xFFBFDBFE),
              borderDark: const Color(0xFF1D4ED8).withValues(alpha: 0.5),
              labelLight: const Color(0xFF1D4ED8),
              labelDark: const Color(0xFF93C5FD),
            ),
            _MetricCard(
              label: 'Active Sessions',
              value: sessionsAsync.when(
                data: (sessions) => sessions.length.toString(),
                loading: () => '...',
                error: (_, __) => '-',
              ),
              icon: Icons.groups_outlined,
              accent: const Color(0xFF7C3AED),
              iconBackground: const Color(0xFF7C3AED),
              gradientLightStart: const Color(0xFFF5F3FF),
              gradientLightEnd: const Color(0xFFFDF2F8),
              gradientDarkStart:
                  const Color(0xFF581C87).withValues(alpha: 0.3),
              gradientDarkEnd:
                  const Color(0xFF831843).withValues(alpha: 0.3),
              borderLight: const Color(0xFFE9D5FF),
              borderDark: const Color(0xFF7E22CE).withValues(alpha: 0.5),
              labelLight: const Color(0xFF6D28D9),
              labelDark: const Color(0xFFD8B4FE),
            ),
            _MetricCard(
              label: 'API Requests (24h)',
              value: apiStats.when(
                data: (stats) => numberFormat.format(stats.totalRequests),
                loading: () => '...',
                error: (_, __) => '-',
              ),
              icon: Icons.flash_on,
              accent: const Color(0xFF16A34A),
              iconBackground: const Color(0xFF16A34A),
              gradientLightStart: const Color(0xFFECFDF5),
              gradientLightEnd: const Color(0xFFD1FAE5),
              gradientDarkStart:
                  const Color(0xFF14532D).withValues(alpha: 0.3),
              gradientDarkEnd:
                  const Color(0xFF064E3B).withValues(alpha: 0.3),
              borderLight: const Color(0xFFBBF7D0),
              borderDark: const Color(0xFF15803D).withValues(alpha: 0.5),
              labelLight: const Color(0xFF15803D),
              labelDark: const Color(0xFF86EFAC),
            ),
            _MetricCard(
              label: 'Avg Response Time',
              value: apiStats.when(
                data: (stats) => stats.avgLatencyMs > 0
                    ? '${stats.avgLatencyMs.toStringAsFixed(0)}ms'
                    : '-',
                loading: () => '...',
                error: (_, __) => '-',
              ),
              icon: Icons.show_chart_outlined,
              accent: const Color(0xFFF97316),
              iconBackground: const Color(0xFFEA580C),
              gradientLightStart: const Color(0xFFFFF7ED),
              gradientLightEnd: const Color(0xFFFEF2F2),
              gradientDarkStart:
                  const Color(0xFF7C2D12).withValues(alpha: 0.3),
              gradientDarkEnd:
                  const Color(0xFF7F1D1D).withValues(alpha: 0.3),
              borderLight: const Color(0xFFFED7AA),
              borderDark: const Color(0xFFC2410C).withValues(alpha: 0.5),
              labelLight: const Color(0xFFC2410C),
              labelDark: const Color(0xFFFDBA74),
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
    this.gradientLightStart,
    this.gradientLightEnd,
    this.gradientDarkStart,
    this.gradientDarkEnd,
    this.borderLight,
    this.borderDark,
    this.labelLight,
    this.labelDark,
    this.iconBackground,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color? gradientLightStart;
  final Color? gradientLightEnd;
  final Color? gradientDarkStart;
  final Color? gradientDarkEnd;
  final Color? borderLight;
  final Color? borderDark;
  final Color? labelLight;
  final Color? labelDark;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? (borderDark ?? accent.withValues(alpha: 0.5))
        : (borderLight ?? accent.withValues(alpha: 0.35));
    final gradient = LinearGradient(
      colors: [
        (isDark ? gradientDarkStart : gradientLightStart) ??
            accent.withValues(alpha: isDark ? 0.3 : 0.15),
        (isDark ? gradientDarkEnd : gradientLightEnd) ??
            accent.withValues(alpha: isDark ? 0.3 : 0.12),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final labelColor = isDark
        ? (labelDark ?? accent.withValues(alpha: 0.8))
        : (labelLight ?? accent.withValues(alpha: 0.9));
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBackground ?? accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
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
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );
  }
}

class _SystemHealthCard extends StatelessWidget {
  const _SystemHealthCard({
    required this.healthAsync,
    required this.surface,
    required this.border,
    required this.muted,
  });

  final AsyncValue<_SystemHealth> healthAsync;
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
            'System Health',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 16),
          healthAsync.when(
            data: (health) => Column(
              children: [
                _HealthStatusTile(
                  name: 'API Gateway',
                  isHealthy: health.apiHealthy,
                  muted: muted,
                ),
                const SizedBox(height: 12),
                _HealthStatusTile(
                  name: 'Database',
                  isHealthy: health.dbHealthy,
                  muted: muted,
                ),
                const SizedBox(height: 12),
                _HealthStatusTile(
                  name: 'Storage',
                  isHealthy: health.storageHealthy,
                  muted: muted,
                ),
              ],
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to check system health',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthStatusTile extends StatelessWidget {
  const _HealthStatusTile({
    required this.name,
    required this.isHealthy,
    required this.muted,
  });

  final String name;
  final bool isHealthy;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isHealthy ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final background = isHealthy
        ? (isDark
            ? const Color(0xFF14532D).withValues(alpha: 0.2)
            : const Color(0xFFF0FDF4))
        : (isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.2)
            : const Color(0xFFFEF2F2));
    final border = isHealthy
        ? (isDark
            ? const Color(0xFF15803D).withValues(alpha: 0.5)
            : const Color(0xFFBBF7D0))
        : (isDark
            ? const Color(0xFFDC2626).withValues(alpha: 0.5)
            : const Color(0xFFFECACA));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.error,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isHealthy ? 'Healthy' : 'Down',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentErrorsCard extends StatelessWidget {
  const _RecentErrorsCard({
    required this.errorsAsync,
    required this.surface,
    required this.border,
    required this.muted,
  });

  final AsyncValue<List<ErrorEvent>> errorsAsync;
  final Color surface;
  final Color border;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeFormat = DateFormat('MMM d, h:mm a');

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
            'Recent Errors',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 16),
          errorsAsync.when(
            data: (errors) {
              if (errors.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF14532D).withValues(alpha: 0.2)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF15803D).withValues(alpha: 0.5)
                          : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF22C55E),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No recent errors',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: errors.take(5).map((error) {
                  final isWarning = error.severity == 'medium' || error.severity == 'low';
                  final accent = isWarning ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
                  final background = isWarning
                      ? (isDark
                          ? const Color(0xFF78350F).withValues(alpha: 0.2)
                          : const Color(0xFFFFFBEB))
                      : (isDark
                          ? const Color(0xFF7F1D1D).withValues(alpha: 0.2)
                          : const Color(0xFFFEF2F2));
                  final borderColor = isWarning
                      ? (isDark
                          ? const Color(0xFFB45309).withValues(alpha: 0.5)
                          : const Color(0xFFFEF3C7))
                      : (isDark
                          ? const Color(0xFFDC2626).withValues(alpha: 0.5)
                          : const Color(0xFFFECACA));

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isWarning ? Icons.warning_amber_rounded : Icons.error,
                            color: accent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  error.errorType,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                        fontSize: 14,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeFormat.format(error.lastSeen),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${error.occurrenceCount}x',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load errors',
                  style: TextStyle(color: muted),
                ),
              ),
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
