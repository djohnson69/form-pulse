import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/dashboard/data/dashboard_provider.dart';

/// Provider for the session monitor service
final sessionMonitorProvider = Provider<SessionMonitor>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SessionMonitor(client);
});

/// Monitors user session status and signs out deactivated users.
///
/// This service periodically checks if the current user's account is still active.
/// If the user has been deactivated by an admin, they will be signed out automatically.
class SessionMonitor {
  SessionMonitor(this._client);

  final SupabaseClient _client;
  Timer? _timer;
  bool _isChecking = false;

  /// Check interval in minutes
  static const int _checkIntervalMinutes = 5;

  /// Starts periodic session monitoring.
  ///
  /// Call this after successful authentication.
  void start() {
    stop(); // Cancel any existing timer
    _timer = Timer.periodic(
      const Duration(minutes: _checkIntervalMinutes),
      (_) => checkStatus(),
    );
    developer.log('SessionMonitor: Started with ${_checkIntervalMinutes}min interval');
  }

  /// Stops the periodic session monitoring.
  ///
  /// Call this on sign out or when disposing.
  void stop() {
    _timer?.cancel();
    _timer = null;
    developer.log('SessionMonitor: Stopped');
  }

  /// Manually check if the current user's session is still valid.
  ///
  /// Returns `true` if the user is active, `false` if deactivated or error.
  Future<bool> checkStatus() async {
    if (_isChecking) return true; // Prevent concurrent checks
    _isChecking = true;

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        developer.log('SessionMonitor: No user logged in');
        return false;
      }

      final response = await _client
          .from('profiles')
          .select('is_active')
          .eq('id', userId)
          .maybeSingle();

      final isActive = response?['is_active'] as bool? ?? true;

      if (!isActive) {
        developer.log('SessionMonitor: User $userId has been deactivated, signing out');
        await _client.auth.signOut();
        return false;
      }

      developer.log('SessionMonitor: User $userId is active');
      return true;
    } catch (e, st) {
      developer.log(
        'SessionMonitor: Error checking status',
        error: e,
        stackTrace: st,
      );
      // Don't sign out on error - could be network issue
      return true;
    } finally {
      _isChecking = false;
    }
  }

  /// Check if the monitor is currently running
  bool get isRunning => _timer?.isActive ?? false;

  /// Dispose the session monitor
  void dispose() {
    stop();
  }
}
