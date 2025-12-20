import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

/// Configure dependency injection

/// Dependency injection is handled by Riverpod providers in this app.
/// No additional get_it registrations are required unless you add non-provider services.
Future<void> configureDependencies() async {
  // No-op: DI is managed by Riverpod.
  await Future.delayed(Duration.zero);
}
