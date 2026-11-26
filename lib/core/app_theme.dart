import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'storage_service.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void initTheme() {
  final saved = StorageService.getThemeMode();
  themeModeNotifier.value = themeModeFromString(saved);
}

ThemeMode themeModeFromString(String mode) {
  switch (mode) {
    case 'Light':
      return ThemeMode.light;
    case 'Dark':
      return ThemeMode.dark;
    case 'System':
    default:
      return ThemeMode.system;
  }
}

String themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Light';
    case ThemeMode.dark:
      return 'Dark';
    case ThemeMode.system:
      return 'System';
  }
}

Future<void> updateAppTheme(String mode) async {
  await StorageService.saveThemeMode(mode);
  themeModeNotifier.value = themeModeFromString(mode);
}

class AppTheme {
  // Light Mode Color Palette
  static const Color primaryLight = Color(0xFF094943);
  static const Color backgroundLight = Color(0xFFF7F9F8);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceElevatedLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);
  static const Color cardSubtleLight = Color(0xFFF8FAFC);

  // Dark Mode Color Palette
  static const Color primaryDark = Color(0xFF0D9488);
  static const Color primaryDarkHeader = Color(0xFF094943);
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color surfaceElevatedDark = Color(0xFF334155); // Slate 700
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF334155);
  static const Color cardSubtleDark = Color(0xFF1E293B);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color background(BuildContext context) => isDark(context) ? backgroundDark : backgroundLight;
  static Color surface(BuildContext context) => isDark(context) ? surfaceDark : surfaceLight;
  static Color surfaceElevated(BuildContext context) => isDark(context) ? surfaceElevatedDark : surfaceElevatedLight;
  static Color textPrimary(BuildContext context) => isDark(context) ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(BuildContext context) => isDark(context) ? textSecondaryDark : textSecondaryLight;
  static Color border(BuildContext context) => isDark(context) ? borderDark : borderLight;
  static Color divider(BuildContext context) => isDark(context) ? dividerDark : dividerLight;
  static Color primary(BuildContext context) => isDark(context) ? primaryDark : primaryLight;
  static Color appBarBg(BuildContext context) => isDark(context) ? surfaceDark : primaryLight;
  static Color inputFill(BuildContext context) => isDark(context) ? const Color(0xFF0F172A) : Colors.white;
  static Color subtleBackground(BuildContext context) => isDark(context) ? surfaceElevatedDark : dividerLight;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: backgroundLight,
      cardColor: surfaceLight,
      dividerColor: dividerLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLight,
        brightness: Brightness.light,
        surface: surfaceLight,
        onSurface: textPrimaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceLight,
        modalBackgroundColor: surfaceLight,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: backgroundDark,
      cardColor: surfaceDark,
      dividerColor: dividerDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLight,
        brightness: Brightness.dark,
        surface: surfaceDark,
        onSurface: textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
        modalBackgroundColor: surfaceDark,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
