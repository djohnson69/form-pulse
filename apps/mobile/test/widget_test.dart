// Basic Flutter widget smoke test for Form Bridge

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/app/app.dart';
import 'package:mobile/app/app_navigator.dart';
import 'package:mobile/core/di/injection.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://xpcibptzncfmifaneoop.supabase.co',
);

const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Mirror main() bootstrap so navigation can access Supabase + DI
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
    await configureDependencies();
  });

  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AppEntry(),
      ),
    );
    await tester.pump();

    expect(find.byType(AppNavigator), findsOneWidget);
  });
}
