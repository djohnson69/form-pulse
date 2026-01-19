import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'active_role_provider.dart';

class DashboardPermissions {
  const DashboardPermissions({
    required this.viewDashboard,
    required this.manageTasks,
    required this.manageUsers,
    required this.manageDocuments,
    required this.manageAssets,
    required this.manageTraining,
    required this.manageForms,
    required this.approveReports,
    required this.viewAnalytics,
    required this.manageRoles,
    required this.manageIncidents,
    required this.assignTasks,
    required this.viewTeam,
    required this.manageProjects,
    required this.systemAccess,
    required this.techSupport,
    required this.managePayroll,
  });

  final bool viewDashboard;
  final bool manageTasks;
  final bool manageUsers;
  final bool manageDocuments;
  final bool manageAssets;
  final bool manageTraining;
  final bool manageForms;
  final bool approveReports;
  final bool viewAnalytics;
  final bool manageRoles;
  final bool manageIncidents;
  final bool assignTasks;
  final bool viewTeam;
  final bool manageProjects;
  final bool systemAccess;
  final bool techSupport;
  final bool managePayroll;

  static const DashboardPermissions none = DashboardPermissions(
    viewDashboard: true,
    manageTasks: false,
    manageUsers: false,
    manageDocuments: false,
    manageAssets: false,
    manageTraining: false,
    manageForms: false,
    approveReports: false,
    viewAnalytics: false,
    manageRoles: false,
    manageIncidents: false,
    assignTasks: false,
    viewTeam: false,
    manageProjects: false,
    systemAccess: false,
    techSupport: false,
    managePayroll: false,
  );

  static DashboardPermissions forRole(UserRole role) {
    switch (role) {
      case UserRole.employee:
        return const DashboardPermissions(
          viewDashboard: true,
          manageTasks: false,
          manageUsers: false,
          manageDocuments: false,
          manageAssets: false,
          manageTraining: false,
          manageForms: false,
          approveReports: false,
          viewAnalytics: false,
          manageRoles: false,
          manageIncidents: false,
          assignTasks: false,
          viewTeam: false,
          manageProjects: false,
          systemAccess: false,
          techSupport: false,
          managePayroll: false,
        );
      case UserRole.supervisor:
        return const DashboardPermissions(
          viewDashboard: true,
          manageTasks: true,
          manageUsers: false,
          manageDocuments: true,
          manageAssets: true,
          manageTraining: true,
          manageForms: true,
          approveReports: true,
          viewAnalytics: true,
          manageRoles: false,
          manageIncidents: true,
          assignTasks: true,
          viewTeam: true,
          manageProjects: false,
          systemAccess: false,
          techSupport: false,
          managePayroll: false,
        );
      case UserRole.manager:
        return const DashboardPermissions(
          viewDashboard: true,
          manageTasks: true,
          manageUsers: true,
          manageDocuments: true,
          manageAssets: true,
          manageTraining: true,
          manageForms: true,
          approveReports: true,
          viewAnalytics: true,
          manageRoles: false,
          manageIncidents: true,
          assignTasks: true,
          viewTeam: true,
          manageProjects: true,
          systemAccess: false,
          techSupport: false,
          managePayroll: false,
        );
      case UserRole.maintenance:
        return const DashboardPermissions(
          viewDashboard: true,
          manageTasks: true,
          manageUsers: false,
          manageDocuments: false,
          manageAssets: false,
          manageTraining: false,
          manageForms: false,
          approveReports: false,
          viewAnalytics: false,
          manageRoles: false,
          manageIncidents: true,
          assignTasks: false,
          viewTeam: false,
          manageProjects: false,
          systemAccess: false,
          techSupport: false,
          managePayroll: false,
        );
      case UserRole.admin:
        return const DashboardPermissions(
          viewDashboard: true,
          manageTasks: true,
          manageUsers: true,
          manageDocuments: true,
          manageAssets: true,
          manageTraining: true,
          manageForms: true,
          approveReports: true,
          viewAnalytics: true,
          manageRoles: true,
          manageIncidents: true,
          assignTasks: true,
          viewTeam: true,
          manageProjects: true,
          systemAccess: false,
          techSupport: false,
          managePayroll: true,
        );
      case UserRole.superAdmin:
        return const DashboardPermissions(
          viewDashboard: true,
          manageTasks: true,
          manageUsers: true,
          manageDocuments: true,
          manageAssets: true,
          manageTraining: true,
          manageForms: true,
          approveReports: true,
          viewAnalytics: true,
          manageRoles: true,
          manageIncidents: true,
          assignTasks: true,
          viewTeam: true,
          manageProjects: true,
          systemAccess: true,
          techSupport: false,
          managePayroll: true,
        );
      case UserRole.techSupport:
        return const DashboardPermissions(
          viewDashboard: true,
          manageTasks: false,
          manageUsers: false,
          manageDocuments: true,
          manageAssets: true,
          manageTraining: false,
          manageForms: false,
          approveReports: false,
          viewAnalytics: true,
          manageRoles: false,
          manageIncidents: true,
          assignTasks: false,
          viewTeam: false,
          manageProjects: false,
          systemAccess: false,
          techSupport: true,
          managePayroll: false,
        );
      case UserRole.developer:
        return const DashboardPermissions(
          viewDashboard: true,
          manageTasks: true,
          manageUsers: true,
          manageDocuments: true,
          manageAssets: true,
          manageTraining: true,
          manageForms: true,
          approveReports: true,
          viewAnalytics: true,
          manageRoles: true,
          manageIncidents: true,
          assignTasks: true,
          viewTeam: true,
          manageProjects: true,
          systemAccess: true,
          techSupport: false,
          managePayroll: true,
        );
      case UserRole.client:
      case UserRole.vendor:
      case UserRole.viewer:
        return DashboardPermissions.none;
    }
  }
}

final dashboardPermissionsProvider = Provider<DashboardPermissions>((ref) {
  final role = ref.watch(activeRoleProvider);
  return DashboardPermissions.forRole(role);
});
