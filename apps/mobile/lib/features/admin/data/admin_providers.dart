import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_models.dart';
import 'admin_repository.dart';
import '../../dashboard/data/active_role_provider.dart';
import '../../dashboard/data/user_profile_provider.dart';

final _supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final client = ref.read(_supabaseClientProvider);
  return AdminRepository(client);
});

final adminOrganizationsProvider = FutureProvider<List<AdminOrgSummary>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return repo.fetchOrganizations();
});

final adminSelectedOrgIdProvider = legacy.StateProvider<String?>((ref) => null);

final adminActiveOrgIdProvider = Provider<String?>((ref) {
  final selectedId = ref.watch(adminSelectedOrgIdProvider);
  if (selectedId != null && selectedId.isNotEmpty) return selectedId;
  final role = ref.watch(activeRoleProvider);
  // Only developer and techSupport can view across orgs
  if (role.canViewAcrossOrgs) return null;
  // Try to get org from loaded orgs list
  final orgs = ref.watch(adminOrganizationsProvider).asData?.value;
  if (orgs != null && orgs.isNotEmpty) return orgs.first.id;
  // Fallback: use current user's org_id from profile
  final profile = ref.watch(userProfileProvider).asData?.value;
  return profile?.orgId;
});

final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  final orgId = ref.watch(adminActiveOrgIdProvider);
  return repo.fetchStats(orgId: orgId);
});

final adminAiUsageProvider = FutureProvider<AdminAiUsageSummary>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  final orgId = ref.watch(adminActiveOrgIdProvider);
  return repo.fetchAiUsageSummary(orgId: orgId);
});

final adminFormsFilterProvider =
    legacy.StateProvider<({String search, String category, bool? published})>((ref) {
  return (search: '', category: '', published: null);
});

final adminFormsProvider = FutureProvider.autoDispose<List<AdminFormSummary>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  final filters = ref.watch(adminFormsFilterProvider);
  final orgId = ref.watch(adminActiveOrgIdProvider);
  return repo.fetchForms(
    orgId: orgId,
    search: filters.search.isEmpty ? null : filters.search,
    category: filters.category.isEmpty ? null : filters.category,
    published: filters.published,
  );
});

final adminSubmissionsStatusProvider =
    legacy.StateProvider<String?>((ref) => null);
final adminSubmissionsRoleProvider =
    legacy.StateProvider<UserRole?>((ref) => null);

final adminSubmissionsProvider =
    FutureProvider.autoDispose<List<AdminSubmissionSummary>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  final status = ref.watch(adminSubmissionsStatusProvider);
  final orgId = ref.watch(adminActiveOrgIdProvider);
  return repo.fetchRecentSubmissions(orgId: orgId, status: status);
});

final adminUsersFilterProvider =
    legacy.StateProvider<({String search, UserRole? role})>((ref) {
  return (search: '', role: null);
});

final adminUsersProvider =
    FutureProvider.autoDispose<List<AdminUserSummary>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  final orgId = ref.watch(adminActiveOrgIdProvider);
  final filters = ref.watch(adminUsersFilterProvider);
  return repo.fetchUsers(
    orgId: orgId,
    search: filters.search.isEmpty ? null : filters.search,
    role: filters.role,
  );
});

/// Role-aware user provider for messaging - platform roles see all users
final messagingUsersForRoleProvider =
    FutureProvider.autoDispose.family<List<AdminUserSummary>, UserRole?>((ref, role) async {
  final repo = ref.read(adminRepositoryProvider);
  final isGlobalView = role?.canViewAcrossOrgs ?? false;

  if (isGlobalView) {
    // Platform roles see all active users
    return repo.fetchUsers();
  } else {
    // Org roles see users in their org
    final orgId = ref.watch(adminActiveOrgIdProvider);
    return repo.fetchUsers(orgId: orgId);
  }
});

final adminAuditProvider =
    FutureProvider.autoDispose<List<AdminAuditEvent>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  final orgId = ref.watch(adminActiveOrgIdProvider);
  return repo.fetchAuditLog(orgId: orgId);
});

/// Provider for pending invitations in the current organization
final adminPendingInvitationsProvider =
    FutureProvider.autoDispose<List<PendingInvitation>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  final orgId = ref.watch(adminActiveOrgIdProvider);
  return repo.fetchPendingInvitations(orgId: orgId);
});
