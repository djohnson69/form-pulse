import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/theme_mode_provider.dart';
import 'app_navigator.dart';

/// Main app entry point
class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          final themeMode = ref.watch(themeModeProvider);
          return MaterialApp(
            title: 'Form Bridge',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: themeMode,
            home: const AppNavigator(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const background = Color(0xFFFFFFFF);
    const foreground = Color(0xFF030213);
    const primary = Color(0xFF030213);
    const secondary = Color(0xFFF3F3F5);
    const muted = Color(0xFFECECF0);
    const accent = Color(0xFFE9EBEF);
    const border = Color(0x1A000000); // rgba(0,0,0,0.1)
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        surface: background,
        onSurface: foreground,
        primary: primary,
        onPrimary: background,
        secondary: secondary,
        onSecondary: foreground,
        tertiary: accent,
        onTertiary: foreground,
        surfaceContainerHighest: muted,
        outline: border,
        error: const Color(0xFFD4183D),
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: const Color(0xFFF9FAFB), // bg-gray-50
      cardTheme: CardThemeData(
        elevation: 0,
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10), // 0.625rem
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F3F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    // Match React app dark theme colors
    const background = Color(0xFF030213); // oklch(0.145 0 0) ~ #030213
    const foreground = Color(0xFFFBFBFB); // oklch(0.985 0 0) ~ #FBFBFB
    const card = Color(0xFF1F2937); // gray-800
    const secondary = Color(0xFF374151); // gray-700
    const muted = Color(0xFF4B5563); // gray-600
    const accent = Color(0xFF374151); // gray-700
    const border = Color(0xFF374151); // gray-700
    const inputBg = Color(0xFF1F2937); // gray-800
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        surface: background,
        onSurface: foreground,
        surfaceContainerLowest: const Color(0xFF111827), // gray-900
        surfaceContainer: card,
        surfaceContainerHigh: secondary,
        surfaceContainerHighest: muted,
        primary: foreground,
        onPrimary: const Color(0xFF1F2937),
        secondary: secondary,
        onSecondary: foreground,
        tertiary: accent,
        onTertiary: foreground,
        outline: border,
        outlineVariant: const Color(0xFF4B5563),
        error: const Color(0xFFEF4444), // red-500
        onError: foreground,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: const Color(0xFF111827), // gray-900 like React app
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF1F2937), // gray-800
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: foreground, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: foreground,
          foregroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF3B82F6), // blue-500
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: border),
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
