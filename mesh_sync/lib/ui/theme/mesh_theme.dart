import 'package:flutter/material.dart';
import '../../messages/mesh_message.dart';

/// Minimalist Design System and Theme for MeshSync.
/// Pure black dark mode & crisp light mode, Arial typography, and zero glassmorphism.
class MeshTheme {
  // Pure minimalist palette
  static const Color pureBlack = Color(0xFF000000);
  static const Color pureWhite = Color(0xFFFFFFFF);

  // Dark mode surfaces
  static const Color darkCard = Color(0xFF141414);
  static const Color darkBorder = Color(0xFF2E2E2E);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextDim = Color(0xFF9E9E9E);

  // Light mode surfaces
  static const Color lightBg = Color(0xFFF9F9F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightText = Color(0xFF111111);
  static const Color lightTextDim = Color(0xFF666666);

  // Core Emergency Red for SOS
  static const Color emergencyRed = Color(0xFFD32F2F);
  static const Color safeGreen = Color(0xFF2E7D32);

  static Color getCategoryColor(Category? cat, {bool isDark = true}) {
    return switch (cat) {
      Category.medical => emergencyRed,
      Category.trapped => const Color(0xFFE65100),
      Category.fire => const Color(0xFFC62828),
      Category.supplies => const Color(0xFF1565C0),
      Category.safe => safeGreen,
      null => isDark ? darkTextDim : lightTextDim,
    };
  }

  static IconData getCategoryIcon(Category? cat) {
    return switch (cat) {
      Category.medical => Icons.medical_services,
      Category.trapped => Icons.person_pin_circle,
      Category.fire => Icons.local_fire_department,
      Category.supplies => Icons.inventory_2,
      Category.safe => Icons.check_circle,
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

  // --- DARK THEME (Pure Black Minimalism) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: pureBlack,
      fontFamily: 'Arial',
      colorScheme: const ColorScheme.dark(
        primary: pureWhite,
        onPrimary: pureBlack,
        surface: darkCard,
        onSurface: darkText,
        error: emergencyRed,
        onError: pureWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        foregroundColor: pureWhite,
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
      tabBarTheme: const TabBarTheme(
        labelColor: pureWhite,
        unselectedLabelColor: darkTextDim,
        indicatorColor: pureWhite,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: darkBorder,
        labelStyle: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 13),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) return pureWhite;
            return darkCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) return pureBlack;
            return darkTextDim;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: darkBorder, width: 1)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pureWhite,
          foregroundColor: pureBlack,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pureWhite,
          side: const BorderSide(color: darkBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: pureWhite, width: 1.5),
        ),
        labelStyle: TextStyle(fontFamily: 'Arial', color: darkTextDim),
        hintStyle: TextStyle(fontFamily: 'Arial', color: darkTextDim),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: pureWhite,
        labelStyle: const TextStyle(fontFamily: 'Arial', color: darkText, fontSize: 12),
        secondaryLabelStyle: const TextStyle(fontFamily: 'Arial', color: pureBlack, fontSize: 12, fontWeight: FontWeight.bold),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: pureBlack,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: darkBorder, width: 1),
        ),
      ),
    );
  }

  // --- LIGHT THEME (Minimalist Clean White) ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      fontFamily: 'Arial',
      colorScheme: const ColorScheme.light(
        primary: pureBlack,
        onPrimary: pureWhite,
        surface: lightCard,
        onSurface: lightText,
        error: emergencyRed,
        onError: pureWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureWhite,
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
      tabBarTheme: const TabBarTheme(
        labelColor: pureBlack,
        unselectedLabelColor: lightTextDim,
        indicatorColor: pureBlack,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: lightBorder,
        labelStyle: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 13),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) return pureBlack;
            return lightCard;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) return pureWhite;
            return lightTextDim;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: lightBorder, width: 1)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pureBlack,
          foregroundColor: pureWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightText,
          side: const BorderSide(color: lightBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: pureBlack, width: 1.5),
        ),
        labelStyle: TextStyle(fontFamily: 'Arial', color: lightTextDim),
        hintStyle: TextStyle(fontFamily: 'Arial', color: lightTextDim),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightCard,
        selectedColor: pureBlack,
        labelStyle: const TextStyle(fontFamily: 'Arial', color: lightText, fontSize: 12),
        secondaryLabelStyle: const TextStyle(fontFamily: 'Arial', color: pureWhite, fontSize: 12, fontWeight: FontWeight.bold),
        side: const BorderSide(color: lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: pureWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: lightBorder, width: 1),
        ),
      ),
    );
  }
}
