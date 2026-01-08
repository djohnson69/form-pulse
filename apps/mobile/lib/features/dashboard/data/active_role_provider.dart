import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'role_override_provider.dart';

final dashboardRoleProvider = Provider<UserRole>((ref) => UserRole.employee);

final activeRoleProvider = Provider<UserRole>((ref) {
  final override = ref.watch(roleOverrideProvider);
  return override ?? ref.watch(dashboardRoleProvider);
});
