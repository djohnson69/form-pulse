import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'app/app_navigator.dart';
import 'core/di/injection.dart';
import 'core/services/push_notifications_service.dart';
import 'core/utils/security_guard.dart';

// Provide sane defaults so the app still boots if dart-defines aren't supplied.
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://xpcibptzncfmifaneoop.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwY2licHR6bmNmbWlmYW5lb29wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4NTE1ODcsImV4cCI6MjA4MTQyNzU4N30.sMzKoqj0GhLsD8tRd73j9NOjEa_ucz0dkh3TwoXD4Tg',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const _StartupErrorApp(
      title: 'Missing configuration',
      message:
          'SUPABASE_URL and SUPABASE_ANON_KEY are not set.\n\n'
          'Run the app with:\n'
          '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...\n\n'
          'Or use the provided scripts in the repo (run-mobile.sh / run-web.sh).\n\n'
          'Fallback defaults are embedded for local runs, but production should always pass defines.',
    ));
    return;
  }
  try {
    SecurityGuard.ensureHttps(_supabaseUrl);
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  } catch (e) {
    runApp(_StartupErrorApp(
      title: 'Startup failed',
      message: 'Could not initialize Supabase.\n\n$e',
    ));
    return;
  }

  // Initialize dependency injection
  await configureDependencies();

  // Register push notifications (non-blocking if Firebase isn't configured).
  await PushNotificationsService().initialize();

  runApp(const ProviderScope(child: AppEntry()));
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Form Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          surface: Color(0xFF111827),
          onSurface: Color(0xFFE5E7EB),
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
