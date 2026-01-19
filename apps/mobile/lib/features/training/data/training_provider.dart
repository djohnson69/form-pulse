import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../dashboard/data/dashboard_provider.dart';
import 'training_repository.dart';

final trainingRepositoryProvider = Provider<TrainingRepositoryBase>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SupabaseTrainingRepository(client);
});

final employeesProvider = FutureProvider.autoDispose<List<Employee>>((ref) async {
  final repo = ref.read(trainingRepositoryProvider);
  return repo.fetchEmployees();
});

final currentEmployeeIdProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return null;
  final res = await client
      .from('employees')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();
  return res?['id']?.toString();
});

final trainingRecordsProvider =
    FutureProvider.autoDispose.family<List<Training>, String?>((ref, employeeId) async {
  final repo = ref.read(trainingRepositoryProvider);
  return repo.fetchTrainingRecords(employeeId: employeeId);
});
