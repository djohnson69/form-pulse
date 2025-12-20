import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../dashboard/data/dashboard_provider.dart';
import 'assets_repository.dart';

final assetsRepositoryProvider = Provider<AssetsRepositoryBase>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SupabaseAssetsRepository(client);
});

final equipmentProvider =
    FutureProvider.autoDispose<List<Equipment>>((ref) async {
  final repo = ref.read(assetsRepositoryProvider);
  return repo.fetchEquipment();
});

final assetInspectionsProvider =
    FutureProvider.autoDispose.family<List<AssetInspection>, String>((
  ref,
  equipmentId,
) async {
  final repo = ref.read(assetsRepositoryProvider);
  return repo.fetchInspections(equipmentId);
});

final incidentReportsProvider =
    FutureProvider.autoDispose.family<List<IncidentReport>, String?>((
  ref,
  equipmentId,
) async {
  final repo = ref.read(assetsRepositoryProvider);
  return repo.fetchIncidents(equipmentId: equipmentId);
});
