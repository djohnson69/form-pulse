import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../dashboard/data/dashboard_provider.dart';
import 'projects_repository.dart';

final projectsRepositoryProvider = Provider<ProjectsRepositoryBase>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SupabaseProjectsRepository(client);
});

final projectsProvider = FutureProvider.autoDispose<List<Project>>((ref) async {
  final repo = ref.read(projectsRepositoryProvider);
  return repo.fetchProjects();
});

final projectUpdatesProvider =
    FutureProvider.autoDispose.family<List<ProjectUpdate>, String>((
  ref,
  projectId,
) async {
  final repo = ref.read(projectsRepositoryProvider);
  return repo.fetchUpdates(projectId);
});
