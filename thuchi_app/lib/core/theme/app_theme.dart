import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application theme configuration using Material Design 3
class AppTheme {
  AppTheme._();

  // Brand colors
  // Premium Color Palette
  static const _primaryLight = Color(0xFF006C5B); // Emerald Green
  static const _primaryContainerLight = Color(0xFF6DF8DE); // Minty Fresh
  static const _secondaryLight = Color(0xFF4A635D); // Sage
  static const _tertiaryLight = Color(0xFF46617A); // Slate Blue
  static const _surfaceLight = Color(0xFFFBFDFA); // Off-white
  
  static const _primaryDark = Color(0xFF4CECC2); // Neon Mint
  static const _primaryContainerDark = Color(0xFF005143); // Deep Forest
  static const _secondaryDark = Color(0xFFB1CCC6); // Muted Sage
  static const _tertiaryDark = Color(0xFFAEC9E6); // Soft Blue
  static const _surfaceDark = Color(0xFF191C1B); // Deep Charcoal

  /// Light theme
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryLight,
      brightness: Brightness.light,
      primary: _primaryLight,
      primaryContainer: _primaryContainerLight,
      secondary: _secondaryLight,
      tertiary: _tertiaryLight,
      surface: _surfaceLight,
      error: const Color(0xFFBA1A1A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: const Color(0xFF191C1B),
        displayColor: const Color(0xFF191C1B),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent, // Glass-like effect usually handled by scroller
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // Softer curves
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        color: Colors.white, // Clean Look
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary, // Vibrant FAB
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        prefixIconColor: colorScheme.onSurfaceVariant,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _surfaceDark,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: MaterialStateProperty.all(
          GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        indicatorColor: colorScheme.secondaryContainer,
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryLight,
      brightness: Brightness.dark,
      primary: _primaryDark,
      primaryContainer: _primaryContainerDark,
      secondary: _secondaryDark,
      tertiary: _tertiaryDark,
      surface: _surfaceDark,
      error: const Color(0xFFFFB4AB),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: const Color(0xFFE1E3DF),
        displayColor: const Color(0xFFE1E3DF),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      scaffoldBackgroundColor: _surfaceDark,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        color: Color(0xFF202322), // Slightly lighter than bg
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF2A2D2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        prefixIconColor: colorScheme.onSurfaceVariant,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: MaterialStateProperty.all(
          GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        indicatorColor: colorScheme.primaryContainer, // Deep Forest for active tab
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(MaterialState.selected) 
              ? colorScheme.onPrimaryContainer 
              : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Extension for income/expense colors
extension TransactionColors on ColorScheme {
  Color get incomeColor => brightness == Brightness.light ? const Color(0xFF006C4C) : const Color(0xFF66DBB2); // Deep Green / Mint
  Color get expenseColor => brightness == Brightness.light ? const Color(0xFFBA1A1A) : const Color(0xFFFFB4AB); // Deep Red / Pastel Red
  Color get transferColor => primary;
}
