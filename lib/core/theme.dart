import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const macroProteinColor = Color(0xFFE8590C);
const macroCarbsColor = Color(0xFFE6A700);
const macroFatColor = Color(0xFF7C4DFF);

const primaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
);

LinearGradient primaryGradientFor(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
    );
  }
  return primaryGradient;
}

const morningColor = Color(0xFFF9A825);
const lunchColor = Color(0xFF43A047);
const dinnerColor = Color(0xFF8E24AA);
const nightColor = Color(0xFF546E7A);

class AppTheme {
  static const seed = Color(0xFF2E7D32);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.nunito(
        fontSize: 57,
        fontWeight: FontWeight.w900,
        color: scheme.onSurface,
      ),
      headlineMedium: GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: scheme.onSurface,
      ),
      headlineSmall: GoogleFonts.nunito(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      titleLarge: GoogleFonts.nunito(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      titleMedium: GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      bodyLarge: GoogleFonts.nunito(fontSize: 16, color: scheme.onSurface),
      bodyMedium: GoogleFonts.nunito(fontSize: 14, color: scheme.onSurface),
      bodySmall: GoogleFonts.nunito(
        fontSize: 12.5,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      labelMedium: GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    );

    final isDark = brightness == Brightness.dark;

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF0E120E) : const Color(0xFFF7F8F5),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: scheme.surfaceContainerLowest,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        backgroundColor: isDark ? const Color(0xFF141A14) : scheme.surface,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF141A14) : scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}