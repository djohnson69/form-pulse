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

final trainingRecordsProvider =
    FutureProvider.autoDispose.family<List<Training>, String?>((ref, employeeId) async {
  final repo = ref.read(trainingRepositoryProvider);
  return repo.fetchTrainingRecords(employeeId: employeeId);
});
