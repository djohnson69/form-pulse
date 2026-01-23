import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/platform_providers.dart';

/// Page showing API performance metrics
class ApiMetricsPage extends ConsumerStatefulWidget {
  const ApiMetricsPage({super.key});

  @override
  ConsumerState<ApiMetricsPage> createState() => _ApiMetricsPageState();
}

class _ApiMetricsPageState extends ConsumerState<ApiMetricsPage> {
  String _sortBy = 'requests';
  bool _sortAsc = false;
  String _filterMethod = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overviewAsync = ref.watch(apiOverviewStatsProvider);
    final endpointsAsync = ref.watch(endpointMetricsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.speed,
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'API Metrics',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time API performance monitoring',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(apiOverviewStatsProvider);
                  ref.invalidate(endpointMetricsProvider);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),

        // Overview stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: overviewAsync.when(
            data: (stats) => _buildOverviewStats(stats, isDark),
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        const SizedBox(height: 20),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterMethod,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Methods')),
                      DropdownMenuItem(value: 'GET', child: Text('GET')),
                      DropdownMenuItem(value: 'POST', child: Text('POST')),
                      DropdownMenuItem(value: 'PUT', child: Text('PUT')),
                      DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _filterMethod = value);
                      }
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    items: const [
                      DropdownMenuItem(value: 'requests', child: Text('Sort by Requests')),
                      DropdownMenuItem(value: 'latency', child: Text('Sort by Latency')),
                      DropdownMenuItem(value: 'errors', child: Text('Sort by Error Rate')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sortBy = value);
                      }
                    },
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _sortAsc = !_sortAsc),
                icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Endpoints table
        Expanded(
          child: endpointsAsync.when(
            data: (endpoints) {
              var filteredEndpoints = endpoints.where((e) {
                if (_filterMethod != 'all' && e.method != _filterMethod) return false;
                return true;
              }).toList();

              // Sort
              filteredEndpoints.sort((a, b) {
                int result;
                switch (_sortBy) {
                  case 'latency':
                    result = a.avgLatencyMs.compareTo(b.avgLatencyMs);
                    break;
                  case 'errors':
                    result = a.errorRate.compareTo(b.errorRate);
                    break;
                  default:
                    result = a.requestCount.compareTo(b.requestCount);
                }
                return _sortAsc ? result : -result;
              });

              if (filteredEndpoints.isEmpty) {
                return Center(
                  child: Text(
                    'No endpoints match your filters',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filteredEndpoints.length,
                itemBuilder: (context, index) {
                  final endpoint = filteredEndpoints[index];
                  return _EndpointCard(endpoint: endpoint);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load API metrics',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewStats(ApiOverviewStats stats, bool isDark) {
    final numberFormat = NumberFormat('#,###');

    final cards = [
      _StatCard(
        label: 'Total Requests',
        value: numberFormat.format(stats.totalRequests),
        icon: Icons.call_made,
        color: const Color(0xFF3B82F6),
        isDark: isDark,
      ),
      _StatCard(
        label: 'Avg Latency',
        value: '${stats.avgLatencyMs.toStringAsFixed(1)}ms',
        icon: Icons.timer,
        color: stats.avgLatencyMs < 200 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        isDark: isDark,
      ),
      _StatCard(
        label: 'Error Rate',
        value: '${(stats.errorRate * 100).toStringAsFixed(2)}%',
        icon: Icons.error_outline,
        color: stats.errorRate < 0.01 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        isDark: isDark,
      ),
      _StatCard(
        label: 'Active Connections',
        value: stats.activeConnections.toString(),
        icon: Icons.cable,
        color: const Color(0xFF8B5CF6),
        isDark: isDark,
      ),
      _StatCard(
        label: 'Requests/min',
        value: stats.requestsPerMinute.toStringAsFixed(0),
        icon: Icons.trending_up,
        color: const Color(0xFF14B8A6),
        isDark: isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile: 2 columns, Tablet: 3 columns, Desktop: 5 columns
        final crossAxisCount = constraints.maxWidth < 500
            ? 2
            : constraints.maxWidth < 900
                ? 3
                : 5;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth < 500 ? 1.5 : 1.8,
          children: cards,
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    // Create gradient from color (darken for end color)
    final gradient = LinearGradient(
      colors: [color, Color.lerp(color, Colors.black, 0.15)!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointCard extends StatelessWidget {
  const _EndpointCard({required this.endpoint});

  final EndpointMetrics endpoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final numberFormat = NumberFormat('#,###');

    final methodColor = switch (endpoint.method) {
      'GET' => const Color(0xFF10B981),
      'POST' => const Color(0xFF3B82F6),
      'PUT' => const Color(0xFFF59E0B),
      'DELETE' => const Color(0xFFEF4444),
      _ => const Color(0xFF6B7280),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            // Method badge
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: methodColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                endpoint.method,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: methodColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Endpoint path
            Expanded(
              flex: 3,
              child: Text(
                endpoint.endpoint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ),

            // Request count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    numberFormat.format(endpoint.requestCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        endpoint.lastHourTrend >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: endpoint.lastHourTrend >= 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${(endpoint.lastHourTrend * 100).abs().toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: endpoint.lastHourTrend >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),

            // Latency
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${endpoint.avgLatencyMs.toStringAsFixed(0)}ms',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: endpoint.latencyColor,
                    ),
                  ),
                  Text(
                    'p95: ${endpoint.p95LatencyMs?.toStringAsFixed(0) ?? '-'}ms',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),

            // Error rate
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: endpoint.errorRateColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${(endpoint.errorRate * 100).toStringAsFixed(2)}%',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: endpoint.errorRateColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
