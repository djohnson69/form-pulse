import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'app/app_navigator.dart';
import 'core/di/injection.dart';
import 'core/services/push_notifications_service.dart';
import 'core/utils/security_guard.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw StateError('Missing Supabase configuration. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.');
  }
  SecurityGuard.ensureHttps(_supabaseUrl);

  // Initialize Supabase
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  // Initialize dependency injection
  await configureDependencies();

  // Register push notifications (non-blocking if Firebase isn't configured).
  await PushNotificationsService().initialize();

  runApp(const ProviderScope(child: AppEntry()));
}

class FormBridgeApp extends ConsumerWidget {
  const FormBridgeApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Form Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Form Bridge theme
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const AppNavigator(), // Deprecated, now handled by AppEntry
    );
  }
}
