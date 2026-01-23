import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/dashboard/presentation/pages/role_dashboard_page.dart';
import 'package:mobile/features/auth/presentation/pages/account_disabled_page.dart';
import 'package:mobile/features/auth/presentation/pages/login_page.dart';
import 'package:mobile/features/auth/presentation/pages/enterprise_onboarding_page.dart';
import 'package:shared/shared.dart';

import '../core/services/session_monitor.dart';
import '../core/utils/error_logger.dart';
import 'app_lifecycle_observer.dart';

/// Main app navigator and entry point with admin routing
class AppNavigator extends ConsumerStatefulWidget {
  const AppNavigator({super.key});

  @override
  ConsumerState<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends ConsumerState<AppNavigator> {
  Future<_UserAccess?> _fetchUserAccess() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;
    
    try {
      final orgId = await _resolveOrgId(client, user.id);
      final res = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      String? rawRole = res?['role']?.toString();
      if (rawRole == null || rawRole.isEmpty) {
        try {
          final member = await client
              .from('org_members')
              .select('role')
              .eq('user_id', user.id)
              .maybeSingle();
          rawRole = member?['role']?.toString();
        } catch (e, st) {
          ErrorLogger.log(
            e,
            stackTrace: st,
            context: 'AppNavigator._fetchUserAccess - org_members fallback',
          );
        }
      }

      if (rawRole == null || rawRole.isEmpty) {
        debugPrint(
          'No profile or role found for user ${user.id}, defaulting to viewer',
        );
        const fallbackRole = UserRole.viewer;
        return _UserAccess(
          role: fallbackRole,
          isActive: true,
          needsOnboarding: (orgId == null || orgId.isEmpty) && !fallbackRole.canViewAcrossOrgs,
        );
      }

      final role = UserRole.fromRaw(rawRole);
      final isActive = res?['is_active'] as bool? ?? true;
      final needsOnboarding =
          (orgId == null || orgId.isEmpty) && !role.canViewAcrossOrgs;
      debugPrint(
        'AppNavigator: user=${user.id}, rawRole=$rawRole, role=$role, '
        'orgId=$orgId, canViewAcrossOrgs=${role.canViewAcrossOrgs}, '
        'needsOnboarding=$needsOnboarding',
      );
      return _UserAccess(
        role: role,
        isActive: isActive,
        needsOnboarding: needsOnboarding,
      );
    } on PostgrestException catch (e) {
      debugPrint('Error fetching user role: $e, defaulting to viewer');
      final orgId = await _resolveOrgId(client, user.id);
      const fallbackRole = UserRole.viewer;
      return _UserAccess(
        role: fallbackRole,
        isActive: true,
        needsOnboarding: (orgId == null || orgId.isEmpty) && !fallbackRole.canViewAcrossOrgs,
      );
    } catch (e) {
      debugPrint('Error fetching user role: $e, defaulting to viewer');
      final orgId = await _resolveOrgId(client, user.id);
      const fallbackRole = UserRole.viewer;
      return _UserAccess(
        role: fallbackRole,
        isActive: true,
        needsOnboarding: (orgId == null || orgId.isEmpty) && !fallbackRole.canViewAcrossOrgs,
      );
    }
  }

  Future<String?> _resolveOrgId(SupabaseClient client, String userId) async {
    try {
      final res = await client
          .from('org_members')
          .select('org_id')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (e, st) {
      ErrorLogger.log(
        e,
        stackTrace: st,
        context: 'AppNavigator._resolveOrgId - org_members lookup',
      );
    }
    try {
      final res = await client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (e, st) {
      ErrorLogger.log(
        e,
        stackTrace: st,
        context: 'AppNavigator._resolveOrgId - profiles fallback',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (snapshot.connectionState == ConnectionState.waiting && session == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (session == null) {
          // Stop session monitoring and lifecycle observer when logged out
          ref.read(sessionMonitorProvider).stop();
          ref.read(appLifecycleObserverProvider).unregister();
          return const LoginPage();
        }
        // Fetch user role and route accordingly
        return FutureBuilder<_UserAccess?>(
          future: _fetchUserAccess(),
          builder: (context, accessSnap) {
            if (accessSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            // Handle errors or missing data by defaulting to viewer role
            final access =
                accessSnap.data ??
                    const _UserAccess(
                      role: UserRole.viewer,
                      isActive: true,
                      needsOnboarding: false,
                    );
            
            if (accessSnap.hasError) {
              debugPrint('Error loading user role: ${accessSnap.error}');
            }
            
            if (!access.isActive) {
              return const AccountDisabledPage();
            }

            if (access.needsOnboarding) {
              return EnterpriseOnboardingPage(
                onCompleted: () => setState(() {}),
              );
            }

            // Start session monitoring and lifecycle observer for authenticated users
            ref.read(sessionMonitorProvider).start();
            ref.read(appLifecycleObserverProvider).register();

            return RoleDashboardPage(role: access.role);
          },
        );
      },
    );
  }
}

class _UserAccess {
  const _UserAccess({
    required this.role,
    required this.isActive,
    required this.needsOnboarding,
  });

  final UserRole role;
  final bool isActive;
  final bool needsOnboarding;
}
