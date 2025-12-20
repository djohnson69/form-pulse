import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../dashboard/data/dashboard_provider.dart';
import 'tasks_repository.dart';

final tasksRepositoryProvider = Provider<TasksRepositoryBase>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SupabaseTasksRepository(client);
});

final tasksProvider = FutureProvider.autoDispose<List<Task>>((ref) async {
  final repo = ref.read(tasksRepositoryProvider);
  return repo.fetchTasks();
});

final taskAssigneesProvider =
    FutureProvider.autoDispose<List<TaskAssignee>>((ref) async {
  final repo = ref.read(tasksRepositoryProvider);
  return repo.fetchAssignees();
});
