import 'package:flutter/material.dart';
import '../../messages/mesh_message.dart';

/// Cognitive / Exaggerated Minimalism Theme for MeshSync.
/// Editorial Serif display typography, warm muted organic palette (Obsidian, Linen, Terracotta, Sage).
class MeshTheme {
  // Warm Dark Palette (Obsidian & Warm Charcoal)
  static const Color darkBg = Color(0xFF0F0E0D);
  static const Color darkCard = Color(0xFF181715);
  static const Color darkBorder = Color(0xFF2E2C28);
  static const Color darkText = Color(0xFFF4F1EA);
  static const Color darkTextMuted = Color(0xFFA8A39A);

  // Warm Light Palette (Linen & Warm Parchment)
  static const Color lightBg = Color(0xFFF7F5F0);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE3DFD5);
  static const Color lightText = Color(0xFF1C1A17);
  static const Color lightTextMuted = Color(0xFF7A756D);

  // Editorial Warm Accents
  static const Color terracottaRed = Color(0xFFC93B2B);
  static const Color terracottaHover = Color(0xFFB53223);
  static const Color sageGreen = Color(0xFF4A6B53);
  static const Color warmSand = Color(0xFFD4A373);
  static const Color deepOchre = Color(0xFFD97706);

  static Color getCategoryColor(Category? cat, {bool isDark = true}) {
    return switch (cat) {
      Category.medical => terracottaRed,
      Category.trapped => deepOchre,
      Category.fire => const Color(0xFFB91C1C),
      Category.supplies => const Color(0xFF2563EB),
      Category.safe => sageGreen,
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
      fontFamily: 'Georgia',
      colorScheme: const ColorScheme.dark(
        primary: darkText,
        onPrimary: darkBg,
        surface: darkCard,
        onSurface: darkText,
        error: terracottaRed,
        onError: darkText,
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
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: darkText,
        unselectedLabelColor: darkTextMuted,
        indicatorColor: darkText,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: darkBorder,
        labelStyle: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 13),
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
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkText,
          foregroundColor: darkBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          side: const BorderSide(color: darkBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 13),
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
          borderSide: BorderSide(color: darkText, width: 1.5),
        ),
        labelStyle: TextStyle(fontFamily: 'Georgia', color: darkTextMuted),
        hintStyle: TextStyle(fontFamily: 'Georgia', color: darkTextMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: darkText,
        labelStyle: const TextStyle(fontFamily: 'Georgia', color: darkText, fontSize: 12),
        secondaryLabelStyle: const TextStyle(fontFamily: 'Georgia', color: darkBg, fontSize: 12, fontWeight: FontWeight.bold),
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
        backgroundColor: darkBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
      fontFamily: 'Georgia',
      colorScheme: const ColorScheme.light(
        primary: lightText,
        onPrimary: lightBg,
        surface: lightCard,
        onSurface: lightText,
        error: terracottaRed,
        onError: lightBg,
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
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: lightText,
        unselectedLabelColor: lightTextMuted,
        indicatorColor: lightText,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: lightBorder,
        labelStyle: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 13),
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
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightText,
          foregroundColor: lightBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightText,
          side: const BorderSide(color: lightBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 13),
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
          borderSide: BorderSide(color: lightText, width: 1.5),
        ),
        labelStyle: TextStyle(fontFamily: 'Georgia', color: lightTextMuted),
        hintStyle: TextStyle(fontFamily: 'Georgia', color: lightTextMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightCard,
        selectedColor: lightText,
        labelStyle: const TextStyle(fontFamily: 'Georgia', color: lightText, fontSize: 12),
        secondaryLabelStyle: const TextStyle(fontFamily: 'Georgia', color: lightBg, fontSize: 12, fontWeight: FontWeight.bold),
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
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: lightBorder, width: 1),
        ),
      ),
    );
  }
}
