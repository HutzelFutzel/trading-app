import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF3B82F6); // Electric Blue
  static const Color secondary = Color(0xFF8B5CF6); // Violet
  static const Color accent = Color(0xFF10B981); // Emerald
  
  // Backgrounds
  static const Color background = Color(0xFF0F172A); // Dark Slate 900
  static const Color surface = Color(0xFF1E293B); // Dark Slate 800
  static const Color surfaceHighlight = Color(0xFF334155); // Dark Slate 700
  
  // Status
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color info = Color(0xFF3B82F6); // Blue 500

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color textDisabled = Color(0xFF475569); // Slate 600

  // Trading Specific
  static const Color long = Color(0xFF22C55E); 
  static const Color short = Color(0xFFEF4444);
}

class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  
  static TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get headlineLarge => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  // Monospaced for financial data
  static TextStyle get monoLarge => GoogleFonts.robotoMono( // Changed from jetbrainsMono to robotoMono for safety
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static TextStyle get monoMedium => GoogleFonts.robotoMono( // Changed from jetbrainsMono to robotoMono for safety
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}

class AppTheme {
  // Legacy/Compatibility Getters
  static const Color brandPrimary = AppColors.primary;
  static const Color brandSecondary = AppColors.secondary;
  static const Color brandAccent = AppColors.accent;
  
  static const Color profit = AppColors.success;
  static const Color loss = AppColors.error;
  static const Color long = AppColors.long;
  static const Color short = AppColors.short;
  static const Color warning = AppColors.warning;
  
  static const Color live = AppColors.error;
  static const Color paper = AppColors.accent;

  static const Map<int, Color> threadColors = {
    1: Color(0xFFF87171), // Red 400
    2: Color(0xFF60A5FA), // Blue 400
    3: Color(0xFF4ADE80), // Green 400
    4: Color(0xFFFB923C), // Orange 400
    5: Color(0xFFA78BFA), // Purple 400
    6: Color(0xFFF472B6), // Pink 400
    7: Color(0xFF2DD4BF), // Teal 400
    8: Color(0xFFFACC15), // Yellow 400
    9: Color(0xFF94A3B8), // Slate 400
    10: Color(0xFF38BDF8), // Sky 400
  };

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        background: AppColors.background,
      ),

      // Typography
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        titleLarge: AppTextStyles.headlineLarge,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, // Fix: Make transparent for gradients to show through if handled by scaffold
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyles.headlineLarge,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(
            color: Color(0x0DFFFFFF), // Colors.white.withOpacity(0.05)
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHighlight.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: AppTextStyles.bodyMedium,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDisabled),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.textDisabled.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Misc
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.05),
        thickness: 1,
      ),
    );
  }

  static ThemeData get lightTheme {
    // We strictly prefer Dark Mode for professional trading apps, 
    // but providing a high-contrast light mode just in case.
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Slate 100
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: Colors.white,
        onSurface: Color(0xFF0F172A),
      ),
       textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge.copyWith(color: const Color(0xFF0F172A)),
        displayMedium: AppTextStyles.displayMedium.copyWith(color: const Color(0xFF0F172A)),
        titleLarge: AppTextStyles.headlineLarge.copyWith(color: const Color(0xFF0F172A)),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: const Color(0xFF334155)),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF475569)),
      ),
      // ... (simplified for light mode)
    );
  }
}
