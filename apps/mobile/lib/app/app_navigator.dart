import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:mobile/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:mobile/features/auth/presentation/pages/account_disabled_page.dart';
import 'package:mobile/features/auth/presentation/pages/login_page.dart';
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
      final res = await client
          .from('profiles')
          .select('role, is_active')
          .eq('id', user.id)
          .maybeSingle();
      
      // If no profile exists or no role, default to viewer
      if (res == null || res['role'] == null) {
        debugPrint('No profile or role found for user ${user.id}, defaulting to viewer');
        return const _UserAccess(role: UserRole.viewer, isActive: true);
      }
      
      final role = UserRole.values.firstWhere(
        (r) => r.name == res['role'],
        orElse: () => UserRole.viewer,
      );
      final isActive = res['is_active'] as bool? ?? true;
      return _UserAccess(role: role, isActive: isActive);
    } on PostgrestException catch (e) {
      if (e.message.contains('is_active') || e.code == '42703') {
        try {
          final res = await client
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();
          if (res == null || res['role'] == null) {
            debugPrint(
              'No profile or role found for user ${user.id}, defaulting to viewer',
            );
            return const _UserAccess(role: UserRole.viewer, isActive: true);
          }
          final role = UserRole.values.firstWhere(
            (r) => r.name == res['role'],
            orElse: () => UserRole.viewer,
          );
          return _UserAccess(role: role, isActive: true);
        } catch (inner) {
          debugPrint('Error fetching user role: $inner, defaulting to viewer');
          return const _UserAccess(role: UserRole.viewer, isActive: true);
        }
      }
      debugPrint('Error fetching user role: $e, defaulting to viewer');
      return const _UserAccess(role: UserRole.viewer, isActive: true);
    } catch (e) {
      debugPrint('Error fetching user role: $e, defaulting to viewer');
      return const _UserAccess(role: UserRole.viewer, isActive: true);
    }
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
                accessSnap.data ?? const _UserAccess(role: UserRole.viewer, isActive: true);
            
            if (accessSnap.hasError) {
              debugPrint('Error loading user role: ${accessSnap.error}');
            }
            
            if (!access.isActive) {
              return const AccountDisabledPage();
            }

            if (access.role.canAccessAdminConsole) {
              return AdminDashboardPage(userRole: access.role);
            }
            return const DashboardPage();
          },
        );
      },
    );
  }
}

class _UserAccess {
  const _UserAccess({required this.role, required this.isActive});

  final UserRole role;
  final bool isActive;
}
