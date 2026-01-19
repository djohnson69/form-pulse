import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:shared/shared.dart';

/// Configurable dashboard layout switches per role so the Roles & Permissions
/// screen can customize which sections render.
class DashboardLayoutConfig {
  const DashboardLayoutConfig({
    this.showActionBar = true,
    this.showNotifications = true,
    this.showQuickActions = true,
    this.showPerformance = true,
    this.showTraining = true,
    this.showActivity = true,
    this.showApprovals = true,
    this.showResourceAllocation = true,
    this.showDiagnostics = true,
  });

  final bool showActionBar;
  final bool showNotifications;
  final bool showQuickActions;
  final bool showPerformance;
  final bool showTraining;
  final bool showActivity;
  final bool showApprovals;
  final bool showResourceAllocation;
  final bool showDiagnostics;

  DashboardLayoutConfig copyWith({
    bool? showActionBar,
    bool? showNotifications,
    bool? showQuickActions,
    bool? showPerformance,
    bool? showTraining,
    bool? showActivity,
    bool? showApprovals,
    bool? showResourceAllocation,
    bool? showDiagnostics,
  }) {
    return DashboardLayoutConfig(
      showActionBar: showActionBar ?? this.showActionBar,
      showNotifications: showNotifications ?? this.showNotifications,
      showQuickActions: showQuickActions ?? this.showQuickActions,
      showPerformance: showPerformance ?? this.showPerformance,
      showTraining: showTraining ?? this.showTraining,
      showActivity: showActivity ?? this.showActivity,
      showApprovals: showApprovals ?? this.showApprovals,
      showResourceAllocation:
          showResourceAllocation ?? this.showResourceAllocation,
      showDiagnostics: showDiagnostics ?? this.showDiagnostics,
    );
  }

  static DashboardLayoutConfig defaultsFor(UserRole role) {
    switch (role) {
      case UserRole.employee:
        return const DashboardLayoutConfig(
          showApprovals: false,
          showResourceAllocation: false,
        );
      case UserRole.supervisor:
        return const DashboardLayoutConfig(
          showTraining: false,
          showResourceAllocation: false,
        );
      case UserRole.manager:
        return const DashboardLayoutConfig(
          showTraining: false,
        );
      case UserRole.maintenance:
        return const DashboardLayoutConfig(
          showApprovals: false,
          showPerformance: false,
          showResourceAllocation: false,
        );
      case UserRole.techSupport:
        return const DashboardLayoutConfig(
          showPerformance: false,
          showTraining: false,
          showActivity: true,
          showApprovals: false,
          showResourceAllocation: false,
        );
      case UserRole.admin:
      case UserRole.superAdmin:
      case UserRole.developer:
      case UserRole.client:
      case UserRole.vendor:
      case UserRole.viewer:
        return const DashboardLayoutConfig();
    }
  }
}

enum DashboardLayoutField {
  actionBar,
  notifications,
  quickActions,
  performance,
  training,
  activity,
  approvals,
  resourceAllocation,
  diagnostics,
}

class DashboardLayoutNotifier
    extends legacy.StateNotifier<Map<UserRole, DashboardLayoutConfig>> {
  DashboardLayoutNotifier()
      : super({
          for (final role in UserRole.values)
            role: DashboardLayoutConfig.defaultsFor(role),
        });

  void updateRole(UserRole role, DashboardLayoutConfig config) {
    state = {
      ...state,
      role: config,
    };
  }

  void toggle(UserRole role, DashboardLayoutField field, bool value) {
    final current =
        state[role] ?? DashboardLayoutConfig.defaultsFor(role);
    switch (field) {
      case DashboardLayoutField.actionBar:
        updateRole(role, current.copyWith(showActionBar: value));
        return;
      case DashboardLayoutField.notifications:
        updateRole(role, current.copyWith(showNotifications: value));
        return;
      case DashboardLayoutField.quickActions:
        updateRole(role, current.copyWith(showQuickActions: value));
        return;
      case DashboardLayoutField.performance:
        updateRole(role, current.copyWith(showPerformance: value));
        return;
      case DashboardLayoutField.training:
        updateRole(role, current.copyWith(showTraining: value));
        return;
      case DashboardLayoutField.activity:
        updateRole(role, current.copyWith(showActivity: value));
        return;
      case DashboardLayoutField.approvals:
        updateRole(role, current.copyWith(showApprovals: value));
        return;
      case DashboardLayoutField.resourceAllocation:
        updateRole(role, current.copyWith(showResourceAllocation: value));
        return;
      case DashboardLayoutField.diagnostics:
        updateRole(role, current.copyWith(showDiagnostics: value));
        return;
    }
  }
}

final dashboardLayoutProvider = legacy.StateNotifierProvider<
    DashboardLayoutNotifier, Map<UserRole, DashboardLayoutConfig>>(
  (ref) => DashboardLayoutNotifier(),
);
