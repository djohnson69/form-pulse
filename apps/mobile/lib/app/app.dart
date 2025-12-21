import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_navigator.dart';
import '../core/theme/theme_mode_provider.dart';
import '../features/projects/presentation/pages/project_share_page.dart';

/// Main app entry point
class AppEntry extends ConsumerWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = _resolveHome();
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Form Bridge',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: themeMode,
      home: home,
    );
  }

  Widget _resolveHome() {
    final segments = Uri.base.pathSegments;
    if (segments.length >= 2 && segments.first == 'share') {
      return ProjectSharePage(shareToken: segments[1]);
    }
    return const AppNavigator();
  }

  ThemeData _buildLightTheme() {
    const seed = Color(0xFF2563EB);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFF7F9FC),
      surfaceContainerHighest: const Color(0xFFEAF0F7),
      primaryContainer: const Color(0xFFDCE8FF),
      secondaryContainer: const Color(0xFFE7EDF7),
      outline: const Color(0xFFD4DEEC),
      outlineVariant: const Color(0xFFE3E9F2),
    );
    final textTheme = GoogleFonts.manropeTextTheme();
    return ThemeData(
      colorScheme: scheme,
      textTheme: textTheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF3F6FB),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFFF3F6FB),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        elevation: 0.6,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelLarge,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(MaterialState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }

  ThemeData _buildDarkTheme() {
    const seed = Color(0xFF2563EB);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF111827),
      surfaceContainerHighest: const Color(0xFF1F2937),
      outline: const Color(0xFF334155),
      outlineVariant: const Color(0xFF1F2A3A),
    );
    final textTheme = GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      colorScheme: scheme,
      textTheme: textTheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF0B1220),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFF111C2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelLarge,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(MaterialState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
