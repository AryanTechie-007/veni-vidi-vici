import 'package:flutter/material.dart';
import '../../messages/mesh_message.dart';

/// Clean Functional Sans-Serif Design System for MeshSync.
/// Structured 3-tier dark surface system: #121212 (bg), #1E1E1E (card), #2E2E2E (subtle border).
class MeshTheme {
  // Structured 3-Tier Dark Elevation System
  static const Color darkBg = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF2E2E2E);
  static const Color darkText = Color(0xFFF9FAFB);
  static const Color darkTextMuted = Color(0xFF9CA3AF);

  // Clean Neutral Light Palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);

  // Primary Distress Action Color (Strictly for SOS / Broadcast)
  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color emergencyRedHover = Color(0xFFB91C1C);

  // Status & Utility Accents
  static const Color safeGreen = Color(0xFF16A34A);
  static const Color warningOrange = Color(0xFFEA580C);
  static const Color infoBlue = Color(0xFF2563EB);

  static Color getCategoryColor(Category? cat, {bool isDark = true}) {
    return switch (cat) {
      Category.medical => emergencyRed,
      Category.trapped => warningOrange,
      Category.fire => const Color(0xFFB91C1C),
      Category.supplies => infoBlue,
      Category.safe => safeGreen,
      null => isDark ? darkTextMuted : lightTextMuted,
    };
  }

  static IconData getCategoryIcon(Category? cat) {
    return switch (cat) {
      Category.medical => Icons.medical_services_outlined,
      Category.trapped => Icons.person_pin_circle_outlined,
      Category.fire => Icons.local_fire_department_outlined,
      Category.supplies => Icons.inventory_2_outlined,
      Category.safe => Icons.check_circle_outline,
      null => Icons.info_outline,
    };
  }

  static String getCategoryLabel(Category? cat) {
    return switch (cat) {
      Category.medical => 'Medical Emergency',
      Category.trapped => 'Trapped / Stranded',
      Category.fire => 'Fire Hazard',
      Category.supplies => 'Supplies Needed',
      Category.safe => 'Safe / Resolved',
      null => 'Emergency SOS',
    };
  }

  // --- DARK THEME ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: darkText,
        onPrimary: darkBg,
        surface: darkCard,
        onSurface: darkText,
        error: emergencyRed,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: darkBorder, width: 1)),
      ),
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) return darkText;
            return darkCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) return darkBg;
            return darkTextMuted;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: darkBorder, width: 1)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkText,
          foregroundColor: darkBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          side: const BorderSide(color: darkBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: darkText, width: 1.5),
        ),
        labelStyle: TextStyle(color: darkTextMuted, fontSize: 13),
        hintStyle: TextStyle(color: darkTextMuted, fontSize: 13),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: darkText,
        labelStyle: const TextStyle(color: darkText, fontSize: 12, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: darkBg, fontSize: 12, fontWeight: FontWeight.w600),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          side: BorderSide(color: darkBorder, width: 1),
        ),
      ),
    );
  }

  // --- LIGHT THEME ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: lightText,
        onPrimary: lightBg,
        surface: lightCard,
        onSurface: lightText,
        error: emergencyRed,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: lightBorder, width: 1)),
      ),
      cardTheme: CardTheme(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) return lightText;
            return lightCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) return lightBg;
            return lightTextMuted;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: lightBorder, width: 1)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightText,
          foregroundColor: lightBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightText,
          side: const BorderSide(color: lightBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: lightText, width: 1.5),
        ),
        labelStyle: TextStyle(color: lightTextMuted, fontSize: 13),
        hintStyle: TextStyle(color: lightTextMuted, fontSize: 13),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightCard,
        selectedColor: lightText,
        labelStyle: const TextStyle(color: lightText, fontSize: 12, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: lightBg, fontSize: 12, fontWeight: FontWeight.w600),
        side: const BorderSide(color: lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          side: BorderSide(color: lightBorder, width: 1),
        ),
      ),
    );
  }
}
