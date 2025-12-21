import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'templates_repository.dart';

final templatesRepositoryProvider = Provider<TemplatesRepositoryBase>((ref) {
  return SupabaseTemplatesRepository(Supabase.instance.client);
});

final templatesProvider =
    FutureProvider.family<List<AppTemplate>, String?>((ref, type) async {
  return ref.read(templatesRepositoryProvider).fetchTemplates(type: type);
});
