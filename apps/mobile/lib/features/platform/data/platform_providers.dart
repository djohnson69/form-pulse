import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/data/admin_models.dart';
import '../../admin/data/admin_providers.dart';
import '../../dashboard/data/role_override_provider.dart';

/// Provider for the user being emulated (null = no emulation active)
final emulatedUserProvider = legacy.StateProvider<EmulatedUser?>((ref) => null);

/// Starts emulating a user - sets both emulatedUserProvider AND roleOverrideProvider.
///
/// This ensures the app actually uses the emulated user's permissions, not just
/// displays the emulation banner.
void startEmulation(WidgetRef ref, EmulatedUser user) {
  // Set the emulated user info (for display in banner)
  ref.read(emulatedUserProvider.notifier).state = user;
  // Set the role override (for actual permission checks)
  ref.read(roleOverrideProvider.notifier).state = user.role;
}

/// Stops emulating a user - clears both emulatedUserProvider AND roleOverrideProvider.
void stopEmulation(WidgetRef ref) {
  ref.read(emulatedUserProvider.notifier).state = null;
  ref.read(roleOverrideProvider.notifier).state = null;
}

/// Model for an emulated user session
class EmulatedUser {
  const EmulatedUser({
    required this.id,
    required this.email,
    required this.role,
    required this.orgId,
    this.firstName,
    this.lastName,
    this.orgName,
  });

  final String id;
  final String email;
  final UserRole role;
  final String? orgId;
  final String? firstName;
  final String? lastName;
  final String? orgName;

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      if (lastName != null && lastName!.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName!;
    }
    return email.split('@').first;
  }
}

/// Provider for all organizations (platform-wide)
final platformOrganizationsProvider = FutureProvider<List<AdminOrgSummary>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.fetchOrganizations();
});

/// Provider for all users across all organizations
final platformUsersProvider = FutureProvider<List<AdminUserSummary>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  // Pass null orgId to get users from all orgs
  return repo.fetchUsers(orgId: null);
});

/// Provider for user search across all organizations
final platformUserSearchProvider = legacy.StateProvider<String>((ref) => '');

/// Filtered users based on search
final filteredPlatformUsersProvider = Provider<AsyncValue<List<AdminUserSummary>>>((ref) {
  final usersAsync = ref.watch(platformUsersProvider);
  final search = ref.watch(platformUserSearchProvider).toLowerCase();

  return usersAsync.whenData((users) {
    if (search.isEmpty) return users;
    return users.where((user) {
      final nameMatch = user.firstName.toLowerCase().contains(search) ||
          user.lastName.toLowerCase().contains(search);
      final emailMatch = user.email.toLowerCase().contains(search);
      final roleMatch = user.role.displayName.toLowerCase().contains(search);
      return nameMatch || emailMatch || roleMatch;
    }).toList();
  });
});

/// Platform stats (aggregate across all orgs) - focused on platform-level metrics
final platformStatsProvider = FutureProvider<PlatformStats>((ref) async {
  final client = Supabase.instance.client;

  // Fetch platform-level metrics using safe count for all tables
  final results = await Future.wait<int>([
    // Platform scale metrics
    _safeCount(client, 'orgs'),
    _safeCount(client, 'profiles'),
    // Subscription metrics - handle tables that may not exist
    _safeCount(client, 'subscriptions', filter: {'status': 'active'}),
    _safeCount(client, 'subscriptions', filter: {'status': 'trialing'}),
    // Platform health metrics
    _safeCount(client, 'active_sessions', filter: {'is_active': true}),
    _safeCount(client, 'error_events', filter: {'is_resolved': false}),
    _safeCount(client, 'support_tickets', filter: {'status': 'open'}),
  ]);

  // Try to get API latency from metrics table
  double avgLatency = 0;
  try {
    final latencyResponse = await client
        .from('api_metrics_hourly')
        .select('avg_latency_ms')
        .gte('hour_timestamp', DateTime.now().subtract(const Duration(hours: 1)).toIso8601String())
        .limit(10);
    if ((latencyResponse as List).isNotEmpty) {
      final latencies = latencyResponse
          .map((r) => (r['avg_latency_ms'] as num?)?.toDouble() ?? 0)
          .where((l) => l > 0)
          .toList();
      if (latencies.isNotEmpty) {
        avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
      }
    }
  } catch (e, st) {
    // Table may not exist
    developer.log('api_latency_metrics query failed (table may not exist)',
        error: e, stackTrace: st, name: 'PlatformProviders');
  }

  return PlatformStats(
    totalOrganizations: results[0],
    totalUsers: results[1],
    activeSubscriptions: results[2],
    trialSubscriptions: results[3],
    storageUsedGb: 0, // Would need Supabase storage API
    activeSessions: results[4],
    avgApiLatencyMs: avgLatency,
    openErrors: results[5],
    openTickets: results[6],
  );
});

/// Helper to safely count from a table that may not exist
Future<int> _safeCount(
  SupabaseClient client,
  String table, {
  Map<String, dynamic>? filter,
}) async {
  try {
    var query = client.from(table).select('id');
    if (filter != null) {
      for (final entry in filter.entries) {
        query = query.eq(entry.key, entry.value);
      }
    }
    final response = await query.count(CountOption.exact);
    return response.count;
  } catch (e, st) {
    developer.log('_safeCount for $table failed',
        error: e, stackTrace: st, name: 'PlatformProviders');
    return 0;
  }
}

/// Platform statistics model - focused on platform-level metrics
class PlatformStats {
  const PlatformStats({
    required this.totalOrganizations,
    required this.totalUsers,
    required this.activeSubscriptions,
    required this.trialSubscriptions,
    required this.storageUsedGb,
    required this.activeSessions,
    required this.avgApiLatencyMs,
    required this.openErrors,
    required this.openTickets,
  });

  final int totalOrganizations;
  final int totalUsers;
  final int activeSubscriptions;
  final int trialSubscriptions;
  final double storageUsedGb;
  final int activeSessions;
  final double avgApiLatencyMs;
  final int openErrors;
  final int openTickets;
}

/// Recent audit events across all orgs
final platformAuditProvider = FutureProvider<List<AdminAuditEvent>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.fetchAuditLog(orgId: null, limit: 50);
});

/// Support tickets across all orgs
final platformSupportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final client = Supabase.instance.client;

  try {
    final response = await client
        .from('support_tickets')
        .select('*, profiles!support_tickets_user_id_fkey(first_name, last_name, email), orgs!support_tickets_org_id_fkey(name)')
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List).map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      final org = row['orgs'] as Map<String, dynamic>?;
      return SupportTicket(
        id: row['id'] as String,
        title: row['title'] as String? ?? 'No title',
        description: row['description'] as String?,
        status: row['status'] as String? ?? 'open',
        priority: row['priority'] as String? ?? 'medium',
        category: row['category'] as String?,
        userId: row['user_id'] as String?,
        userName: _formatUserName(profile),
        orgId: row['org_id'] as String?,
        orgName: org?['name'] as String?,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
      );
    }).toList();
  } catch (e, st) {
    // Table might not exist or have different structure
    developer.log('support_tickets query failed (table may not exist)',
        error: e, stackTrace: st, name: 'PlatformProviders');
    return [];
  }
});

String _formatUserName(Map<String, dynamic>? profile) {
  if (profile == null) return 'Unknown';
  final first = profile['first_name'] as String?;
  final last = profile['last_name'] as String?;
  final email = profile['email'] as String?;
  if (first != null && first.isNotEmpty) {
    if (last != null && last.isNotEmpty) {
      return '$first $last';
    }
    return first;
  }
  return email?.split('@').first ?? 'Unknown';
}

/// Support ticket model
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.category,
    this.userId,
    this.userName,
    this.orgId,
    this.orgName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final String? category;
  final String? userId;
  final String? userName;
  final String? orgId;
  final String? orgName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

// ============================================================================
// ACTIVE SESSIONS
// ============================================================================

/// Model for an active user session
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    this.orgId,
    this.orgName,
    required this.startedAt,
    required this.lastActivityAt,
    this.currentRoute,
    this.deviceInfo,
  });

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final UserRole userRole;
  final String? orgId;
  final String? orgName;
  final DateTime startedAt;
  final DateTime lastActivityAt;
  final String? currentRoute;
  final String? deviceInfo;

  Duration get sessionDuration => DateTime.now().difference(startedAt);

  Duration get idleTime => DateTime.now().difference(lastActivityAt);

  bool get isIdle => idleTime.inMinutes > 5;

  String get formattedDuration {
    final d = sessionDuration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  String get formattedIdleTime {
    final d = idleTime;
    if (d.inMinutes < 1) return 'Active now';
    if (d.inHours > 0) return 'Idle ${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return 'Idle ${d.inMinutes}m';
  }
}

/// Provider for active sessions - fetches from Supabase
final activeSessionsProvider = FutureProvider<List<ActiveSession>>((ref) async {
  final client = Supabase.instance.client;

  try {
    final response = await client
        .from('active_sessions')
        .select('''
          id,
          user_id,
          org_id,
          started_at,
          last_activity_at,
          current_route,
          device_info,
          profiles!active_sessions_user_id_fkey(first_name, last_name, email, role),
          orgs!active_sessions_org_id_fkey(name)
        ''')
        .eq('is_active', true)
        .order('last_activity_at', ascending: false);

    return (response as List).map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      final org = row['orgs'] as Map<String, dynamic>?;
      final roleStr = profile?['role'] as String? ?? 'employee';

      return ActiveSession(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        userName: _formatUserName(profile),
        userEmail: profile?['email'] as String? ?? 'unknown@example.com',
        userRole: UserRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => UserRole.employee,
        ),
        orgId: row['org_id'] as String?,
        orgName: org?['name'] as String?,
        startedAt: DateTime.parse(row['started_at'] as String),
        lastActivityAt: DateTime.parse(row['last_activity_at'] as String),
        currentRoute: row['current_route'] as String?,
        deviceInfo: row['device_info'] as String?,
      );
    }).toList();
  } catch (e) {
    // If table doesn't exist or query fails, return empty list
    return [];
  }
});

// ============================================================================
// IMPERSONATION LOG
// ============================================================================

/// Model for an impersonation log entry
class ImpersonationLogEntry {
  const ImpersonationLogEntry({
    required this.id,
    required this.emulatorId,
    required this.emulatorName,
    required this.emulatorEmail,
    required this.emulatedUserId,
    required this.emulatedUserName,
    required this.emulatedUserEmail,
    required this.emulatedUserRole,
    required this.startedAt,
    this.endedAt,
    this.reason,
  });

  final String id;
  final String emulatorId;
  final String emulatorName;
  final String emulatorEmail;
  final String emulatedUserId;
  final String emulatedUserName;
  final String emulatedUserEmail;
  final String emulatedUserRole;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? reason;

  bool get isActive => endedAt == null;

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  String get formattedDuration {
    final d = duration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }
}

/// Provider for impersonation log - fetches from Supabase
final impersonationLogProvider = FutureProvider<List<ImpersonationLogEntry>>((ref) async {
  final client = Supabase.instance.client;

  try {
    final response = await client
        .from('impersonation_log')
        .select('''
          id,
          emulator_id,
          emulated_user_id,
          started_at,
          ended_at,
          reason,
          emulator:profiles!impersonation_log_emulator_id_fkey(first_name, last_name, email),
          emulated:profiles!impersonation_log_emulated_user_id_fkey(first_name, last_name, email, role)
        ''')
        .order('started_at', ascending: false)
        .limit(100);

    return (response as List).map((row) {
      final emulator = row['emulator'] as Map<String, dynamic>?;
      final emulated = row['emulated'] as Map<String, dynamic>?;
      final roleStr = emulated?['role'] as String? ?? 'employee';
      final role = UserRole.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => UserRole.employee,
      );

      return ImpersonationLogEntry(
        id: row['id'] as String,
        emulatorId: row['emulator_id'] as String,
        emulatorName: _formatUserName(emulator),
        emulatorEmail: emulator?['email'] as String? ?? 'unknown@example.com',
        emulatedUserId: row['emulated_user_id'] as String,
        emulatedUserName: _formatUserName(emulated),
        emulatedUserEmail: emulated?['email'] as String? ?? 'unknown@example.com',
        emulatedUserRole: role.displayName,
        startedAt: DateTime.parse(row['started_at'] as String),
        endedAt: row['ended_at'] != null ? DateTime.parse(row['ended_at'] as String) : null,
        reason: row['reason'] as String?,
      );
    }).toList();
  } catch (e) {
    // If table doesn't exist or query fails, return empty list
    return [];
  }
});

/// Log the start of an impersonation session
Future<String?> logImpersonationStart(String emulatedUserId, {String? reason}) async {
  final client = Supabase.instance.client;
  final currentUser = client.auth.currentUser;
  if (currentUser == null) return null;

  try {
    final response = await client
        .from('impersonation_log')
        .insert({
          'emulator_id': currentUser.id,
          'emulated_user_id': emulatedUserId,
          'reason': reason,
        })
        .select('id')
        .single();

    return response['id'] as String?;
  } catch (e) {
    return null;
  }
}

/// Log the end of an impersonation session
Future<void> logImpersonationEnd(String logId) async {
  final client = Supabase.instance.client;

  try {
    await client
        .from('impersonation_log')
        .update({'ended_at': DateTime.now().toIso8601String()})
        .eq('id', logId);
  } catch (e, st) {
    developer.log('logImpersonationEnd failed',
        error: e, stackTrace: st, name: 'PlatformProviders');
  }
}

// ============================================================================
// USER ACTIVITY
// ============================================================================

/// Model for a user activity event
class UserActivityEvent {
  const UserActivityEvent({
    required this.id,
    required this.action,
    required this.resourceType,
    this.resourceId,
    required this.timestamp,
    this.payload,
  });

  final String id;
  final String action;
  final String resourceType;
  final String? resourceId;
  final DateTime timestamp;
  final Map<String, dynamic>? payload;

  String get details {
    final actionVerb = switch (action) {
      'create' => 'Created',
      'update' => 'Updated',
      'delete' => 'Deleted',
      'view' => 'Viewed',
      'login' => 'Logged in',
      'logout' => 'Logged out',
      'submit' => 'Submitted',
      _ => action,
    };
    return '$actionVerb $resourceType${resourceId != null ? ' ($resourceId)' : ''}';
  }

  String get route => payload?['route'] as String? ?? '/$resourceType';

  /// Icon for the action type (requires flutter/material import)
  int get actionIconCodePoint {
    return switch (action) {
      'view' => 0xe8f4, // Icons.visibility
      'submit' => 0xe163, // Icons.send
      'login' => 0xe3e6, // Icons.login
      'logout' => 0xe3e7, // Icons.logout
      'create' => 0xe145, // Icons.add_circle
      'update' => 0xe3c9, // Icons.edit
      'delete' => 0xe872, // Icons.delete
      _ => 0xef4a, // Icons.circle
    };
  }

  /// Color for the action type
  Color get actionColor {
    return switch (action) {
      'view' => const Color(0xFF3B82F6),
      'submit' => const Color(0xFF10B981),
      'login' => const Color(0xFF10B981),
      'logout' => const Color(0xFFF59E0B),
      'create' => const Color(0xFF10B981),
      'update' => const Color(0xFF3B82F6),
      'delete' => const Color(0xFFEF4444),
      _ => const Color(0xFF6B7280),
    };
  }
}

/// Provider for user activity events - fetches from audit_log
final userActivityProvider = FutureProvider.family<List<UserActivityEvent>, String?>((ref, userId) async {
  if (userId == null) return [];

  final client = Supabase.instance.client;

  try {
    final response = await client
        .from('audit_log')
        .select('id, resource_type, resource_id, action, payload, created_at')
        .eq('actor_id', userId)
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List).map((row) {
      return UserActivityEvent(
        id: row['id'].toString(),
        action: row['action'] as String,
        resourceType: row['resource_type'] as String,
        resourceId: row['resource_id'] as String?,
        timestamp: DateTime.parse(row['created_at'] as String),
        payload: row['payload'] as Map<String, dynamic>?,
      );
    }).toList();
  } catch (e) {
    return [];
  }
});

// ============================================================================
// API METRICS
// ============================================================================

/// Model for API endpoint metrics
class EndpointMetrics {
  const EndpointMetrics({
    required this.endpoint,
    required this.method,
    required this.requestCount,
    required this.avgLatencyMs,
    this.p95LatencyMs,
    this.p99LatencyMs,
    required this.errorRate,
    this.lastHourTrend = 0,
  });

  final String endpoint;
  final String method;
  final int requestCount;
  final double avgLatencyMs;
  final double? p95LatencyMs;
  final double? p99LatencyMs;
  final double errorRate;
  final double lastHourTrend;

  Color get latencyColor {
    if (avgLatencyMs < 100) return const Color(0xFF10B981);
    if (avgLatencyMs < 500) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color get errorRateColor {
    if (errorRate < 0.01) return const Color(0xFF10B981);
    if (errorRate < 0.05) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

/// Model for overall API stats
class ApiOverviewStats {
  const ApiOverviewStats({
    required this.totalRequests,
    required this.avgLatencyMs,
    required this.errorRate,
    this.activeConnections = 0,
    this.requestsPerMinute = 0,
  });

  final int totalRequests;
  final double avgLatencyMs;
  final double errorRate;
  final int activeConnections;
  final double requestsPerMinute;
}

/// Provider for API overview stats - fetches from api_metrics_hourly
final apiOverviewStatsProvider = FutureProvider<ApiOverviewStats>((ref) async {
  final client = Supabase.instance.client;

  try {
    // Get aggregated stats from the last 24 hours
    final response = await client
        .from('api_metrics_hourly')
        .select('total_requests, avg_latency_ms, successful_requests, failed_requests')
        .gte('hour_timestamp', DateTime.now().subtract(const Duration(hours: 24)).toIso8601String());

    if ((response as List).isEmpty) {
      return const ApiOverviewStats(
        totalRequests: 0,
        avgLatencyMs: 0,
        errorRate: 0,
      );
    }

    int totalRequests = 0;
    int failedRequests = 0;
    double totalLatency = 0;
    int latencyCount = 0;

    for (final row in response) {
      final requests = row['total_requests'] as int? ?? 0;
      totalRequests += requests;
      failedRequests += row['failed_requests'] as int? ?? 0;
      final latency = row['avg_latency_ms'] as num?;
      if (latency != null) {
        totalLatency += latency.toDouble() * requests;
        latencyCount += requests;
      }
    }

    return ApiOverviewStats(
      totalRequests: totalRequests,
      avgLatencyMs: latencyCount > 0 ? totalLatency / latencyCount : 0,
      errorRate: totalRequests > 0 ? failedRequests / totalRequests : 0,
      requestsPerMinute: totalRequests / (24 * 60),
    );
  } catch (e) {
    return const ApiOverviewStats(
      totalRequests: 0,
      avgLatencyMs: 0,
      errorRate: 0,
    );
  }
});

/// Provider for endpoint metrics - fetches from api_metrics_hourly
final endpointMetricsProvider = FutureProvider<List<EndpointMetrics>>((ref) async {
  final client = Supabase.instance.client;

  try {
    final response = await client
        .from('api_metrics_hourly')
        .select('endpoint, method, total_requests, avg_latency_ms, p95_latency_ms, p99_latency_ms, successful_requests, failed_requests')
        .gte('hour_timestamp', DateTime.now().subtract(const Duration(hours: 24)).toIso8601String());

    // Group by endpoint and method
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final row in response as List) {
      final key = '${row['method']}:${row['endpoint']}';
      if (grouped.containsKey(key)) {
        grouped[key]!['total_requests'] += row['total_requests'] as int? ?? 0;
        grouped[key]!['failed_requests'] += row['failed_requests'] as int? ?? 0;
        grouped[key]!['latency_sum'] += (row['avg_latency_ms'] as num? ?? 0).toDouble() * (row['total_requests'] as int? ?? 0);
      } else {
        grouped[key] = {
          'endpoint': row['endpoint'],
          'method': row['method'],
          'total_requests': row['total_requests'] as int? ?? 0,
          'failed_requests': row['failed_requests'] as int? ?? 0,
          'latency_sum': (row['avg_latency_ms'] as num? ?? 0).toDouble() * (row['total_requests'] as int? ?? 0),
          'p95_latency_ms': row['p95_latency_ms'] as num?,
          'p99_latency_ms': row['p99_latency_ms'] as num?,
        };
      }
    }

    return grouped.values.map((data) {
      final totalRequests = data['total_requests'] as int;
      final failedRequests = data['failed_requests'] as int;
      final latencySum = data['latency_sum'] as double;

      return EndpointMetrics(
        endpoint: data['endpoint'] as String,
        method: data['method'] as String,
        requestCount: totalRequests,
        avgLatencyMs: totalRequests > 0 ? latencySum / totalRequests : 0,
        p95LatencyMs: (data['p95_latency_ms'] as num?)?.toDouble(),
        p99LatencyMs: (data['p99_latency_ms'] as num?)?.toDouble(),
        errorRate: totalRequests > 0 ? failedRequests / totalRequests : 0,
      );
    }).toList()
      ..sort((a, b) => b.requestCount.compareTo(a.requestCount));
  } catch (e) {
    return [];
  }
});

// ============================================================================
// ERROR TRACKING
// ============================================================================

/// Model for an error event
class ErrorEvent {
  const ErrorEvent({
    required this.id,
    required this.errorType,
    required this.message,
    this.stackTrace,
    required this.occurrenceCount,
    required this.affectedUsers,
    required this.firstSeen,
    required this.lastSeen,
    required this.severity,
    required this.status,
    this.affectedOrgs,
    this.endpoint,
  });

  final String id;
  final String errorType;
  final String message;
  final String? stackTrace;
  final int occurrenceCount;
  final int affectedUsers;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String severity;
  final String status;
  final List<String>? affectedOrgs;
  final String? endpoint;

  Color get severityColor {
    return switch (severity) {
      'critical' => const Color(0xFFDC2626),
      'high' => const Color(0xFFF59E0B),
      'medium' => const Color(0xFF3B82F6),
      'low' => const Color(0xFF6B7280),
      _ => const Color(0xFF6B7280),
    };
  }

  /// Icon code point for severity (use with IconData)
  int get severityIconCodePoint {
    return switch (severity) {
      'critical' => 0xe000, // Icons.error
      'high' => 0xe002, // Icons.warning
      'medium' => 0xe88e, // Icons.info
      'low' => 0xe88f, // Icons.info_outline
      _ => 0xe88f,
    };
  }

  Color get statusColor {
    return switch (status) {
      'open' => const Color(0xFFEF4444),
      'investigating' => const Color(0xFFF59E0B),
      'resolved' => const Color(0xFF10B981),
      'ignored' => const Color(0xFF6B7280),
      _ => const Color(0xFF6B7280),
    };
  }
}

/// Provider for error events - fetches from error_events table
final errorEventsProvider = FutureProvider<List<ErrorEvent>>((ref) async {
  final client = Supabase.instance.client;

  try {
    final response = await client
        .from('error_events')
        .select('id, error_type, error_message, stack_trace, occurrence_count, severity, is_resolved, first_seen_at, last_seen_at, route, user_id')
        .order('last_seen_at', ascending: false)
        .limit(100);

    // Count affected users per error type
    final Map<String, Set<String>> usersByError = {};

    for (final row in response as List) {
      final errorType = row['error_type'] as String;
      final userId = row['user_id'] as String?;
      if (userId != null) {
        usersByError.putIfAbsent(errorType, () => {}).add(userId);
      }
    }

    return (response as List).map((row) {
      final errorType = row['error_type'] as String;
      final isResolved = row['is_resolved'] as bool? ?? false;

      return ErrorEvent(
        id: row['id'] as String,
        errorType: errorType,
        message: row['error_message'] as String,
        stackTrace: row['stack_trace'] as String?,
        occurrenceCount: row['occurrence_count'] as int? ?? 1,
        affectedUsers: usersByError[errorType]?.length ?? 0,
        firstSeen: DateTime.parse(row['first_seen_at'] as String),
        lastSeen: DateTime.parse(row['last_seen_at'] as String),
        severity: row['severity'] as String? ?? 'medium',
        status: isResolved ? 'resolved' : 'open',
        endpoint: row['route'] as String?,
      );
    }).toList();
  } catch (e) {
    return [];
  }
});

/// Report an error to the error_events table
Future<void> reportError({
  required String errorType,
  required String message,
  String? stackTrace,
  String? severity,
  String? route,
  String? deviceInfo,
}) async {
  final client = Supabase.instance.client;

  try {
    await client.rpc('report_error', params: {
      'p_error_type': errorType,
      'p_error_message': message,
      'p_stack_trace': stackTrace,
      'p_severity': severity ?? 'error',
      'p_route': route,
      'p_device_info': deviceInfo,
    });
  } catch (e, st) {
    // Still log locally when reporting errors fails
    developer.log('reportError RPC failed',
        error: e, stackTrace: st, name: 'PlatformProviders');
  }
}
