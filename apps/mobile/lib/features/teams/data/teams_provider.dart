import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

import 'teams_repository.dart';

final teamsRepositoryProvider = Provider<TeamsRepository>((ref) {
  return TeamsRepository(Supabase.instance.client);
});

final teamsProvider = FutureProvider.autoDispose<List<Team>>((ref) {
  return ref.read(teamsRepositoryProvider).fetchTeams();
});

final teamMembersProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, teamId) {
  return ref.read(teamsRepositoryProvider).fetchTeamMembers(teamId);
});
