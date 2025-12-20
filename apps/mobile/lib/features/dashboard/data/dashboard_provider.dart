import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final dashboardRepositoryProvider = Provider<DashboardRepositoryBase>((ref) {
  final supabaseClient = ref.read(supabaseClientProvider);
  return SupabaseDashboardRepository(supabaseClient);
});

final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.loadDashboard();
});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    final data = await ref.watch(dashboardDataProvider.future);
    return data.notifications;
  },
);
