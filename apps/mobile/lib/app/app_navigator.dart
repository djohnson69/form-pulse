import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/dashboard/presentation/pages/role_dashboard_page.dart';
import 'package:mobile/features/auth/presentation/pages/account_disabled_page.dart';
import 'package:mobile/features/auth/presentation/pages/login_page.dart';
import 'package:mobile/features/auth/presentation/pages/org_onboarding_page.dart';
import 'package:shared/shared.dart';

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
          .select('role, is_active')
          .eq('id', user.id)
          .maybeSingle();
      
      // If no profile exists or no role, default to viewer
      if (res == null || res['role'] == null) {
        debugPrint('No profile or role found for user ${user.id}, defaulting to viewer');
        return _UserAccess(
          role: UserRole.viewer,
          isActive: true,
          needsOnboarding: orgId == null || orgId.isEmpty,
        );
      }
      
      final role = UserRole.fromRaw(res['role']?.toString());
      final isActive = res['is_active'] as bool? ?? true;
      return _UserAccess(
        role: role,
        isActive: isActive,
        needsOnboarding: orgId == null || orgId.isEmpty,
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('is_active') || e.code == '42703') {
        try {
          final orgId = await _resolveOrgId(client, user.id);
          final res = await client
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();
          if (res == null || res['role'] == null) {
            debugPrint(
              'No profile or role found for user ${user.id}, defaulting to viewer',
            );
            return _UserAccess(
              role: UserRole.viewer,
              isActive: true,
              needsOnboarding: orgId == null || orgId.isEmpty,
            );
          }
          final role = UserRole.fromRaw(res['role']?.toString());
          return _UserAccess(
            role: role,
            isActive: true,
            needsOnboarding: orgId == null || orgId.isEmpty,
          );
        } catch (inner) {
          debugPrint('Error fetching user role: $inner, defaulting to viewer');
          final orgId = await _resolveOrgId(client, user.id);
          return _UserAccess(
            role: UserRole.viewer,
            isActive: true,
            needsOnboarding: orgId == null || orgId.isEmpty,
          );
        }
      }
      debugPrint('Error fetching user role: $e, defaulting to viewer');
      final orgId = await _resolveOrgId(client, user.id);
      return _UserAccess(
        role: UserRole.viewer,
        isActive: true,
        needsOnboarding: orgId == null || orgId.isEmpty,
      );
    } catch (e) {
      debugPrint('Error fetching user role: $e, defaulting to viewer');
      final orgId = await _resolveOrgId(client, user.id);
      return _UserAccess(
        role: UserRole.viewer,
        isActive: true,
        needsOnboarding: orgId == null || orgId.isEmpty,
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
    } catch (_) {}
    try {
      final res = await client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
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
              return OrgOnboardingPage(
                onCompleted: () => setState(() {}),
              );
            }

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
