import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:mobile/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:mobile/features/auth/presentation/pages/login_page.dart';
import 'package:shared/shared.dart';

/// Main app navigator and entry point with admin routing
class AppNavigator extends ConsumerStatefulWidget {
  const AppNavigator({super.key});

  @override
  ConsumerState<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends ConsumerState<AppNavigator> {
  Future<UserRole?> _fetchUserRole() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;
    
    try {
      final res = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      
      // If no profile exists or no role, default to viewer
      if (res == null || res['role'] == null) {
        debugPrint('No profile or role found for user ${user.id}, defaulting to viewer');
        return UserRole.viewer;
      }
      
      return UserRole.values.firstWhere(
        (r) => r.name == res['role'],
        orElse: () => UserRole.viewer,
      );
    } catch (e) {
      debugPrint('Error fetching user role: $e, defaulting to viewer');
      return UserRole.viewer;
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
        return FutureBuilder<UserRole?>(
          future: _fetchUserRole(),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            // Handle errors or missing data by defaulting to viewer role
            final role = roleSnap.data ?? UserRole.viewer;
            
            if (roleSnap.hasError) {
              debugPrint('Error loading user role: ${roleSnap.error}');
            }
            
            if (role.canAccessAdminConsole) {
              return AdminDashboardPage(userRole: role);
            }
            return const DashboardPage();
          },
        );
      },
    );
  }
}
