import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/session_monitor.dart';
import '../features/dashboard/data/dashboard_provider.dart';
import '../features/dashboard/data/user_profile_provider.dart';

/// Provider for the app lifecycle observer
final appLifecycleObserverProvider = Provider<AppLifecycleObserver>((ref) {
  return AppLifecycleObserver(ref);
});

/// Observes app lifecycle events and refreshes data when the app resumes.
///
/// This ensures that:
/// 1. Dashboard data is fresh when the user returns to the app
/// 2. User session status is checked on resume (in case they were deactivated)
/// 3. Profile data is refreshed to catch any admin-initiated changes
class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver(this._ref);

  final Ref _ref;
  bool _isRegistered = false;

  /// Registers the observer with the WidgetsBinding.
  ///
  /// Safe to call multiple times - will only register once.
  void register() {
    if (_isRegistered) return;
    WidgetsBinding.instance.addObserver(this);
    _isRegistered = true;
    developer.log('AppLifecycleObserver: Registered');
  }

  /// Unregisters the observer from the WidgetsBinding.
  void unregister() {
    if (!_isRegistered) return;
    WidgetsBinding.instance.removeObserver(this);
    _isRegistered = false;
    developer.log('AppLifecycleObserver: Unregistered');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    developer.log('AppLifecycleObserver: State changed to $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // No action needed for these states
        break;
    }
  }

  /// Called when the app returns to the foreground.
  void _onAppResumed() {
    developer.log('AppLifecycleObserver: App resumed, refreshing data');

    // Check if user is still active (may have been deactivated while app was backgrounded)
    _ref.read(sessionMonitorProvider).checkStatus();

    // Invalidate providers to force a refresh of critical data
    // Using invalidate() rather than refresh() to avoid blocking
    _ref.invalidate(dashboardDataProvider);
    _ref.invalidate(userProfileProvider);

    developer.log('AppLifecycleObserver: Data refresh triggered');
  }

  /// Whether the observer is currently registered
  bool get isRegistered => _isRegistered;
}
