import 'package:flutter/material.dart';
import '../../messages/mesh_message.dart';

/// Design system and tactical emergency color palette for MeshSync.
class MeshTheme {
  // Brand & Mesh accents
  static const Color meshCyan = Color(0xFF00E5FF);
  static const Color meshTeal = Color(0xFF0D9488);
  static const Color meshTealGlow = Color(0xFF14B8A6);

  // Tactical Dark Palette
  static const Color darkBg = Color(0xFF0B1120);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardBorder = Color(0xFF334155);
  static const Color darkSurface = Color(0xFF131E32);
  static const Color darkMuted = Color(0xFF64748B);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextDim = Color(0xFF94A3B8);

  // Emergency Semantic Colors
  static const Color catMedical = Color(0xFFEF4444);
  static const Color catMedicalBg = Color(0x26EF4444);

  static const Color catTrapped = Color(0xFFF59E0B);
  static const Color catTrappedBg = Color(0x26F59E0B);

  static const Color catFire = Color(0xFFFF5722);
  static const Color catFireBg = Color(0x26FF5722);

  static const Color catSupplies = Color(0xFF0EA5E9);
  static const Color catSuppliesBg = Color(0x260EA5E9);

  static const Color catSafe = Color(0xFF10B981);
  static const Color catSafeBg = Color(0x2610B981);

  static const Color ackGreen = Color(0xFF22C55E);
  static const Color ackGreenGlow = Color(0x4022C55E);

  static Color getCategoryColor(Category? cat) {
    return switch (cat) {
      Category.medical => catMedical,
      Category.trapped => catTrapped,
      Category.fire => catFire,
      Category.supplies => catSupplies,
      Category.safe => catSafe,
      null => darkMuted,
    };
  }

  static Color getCategoryBg(Category? cat) {
    return switch (cat) {
      Category.medical => catMedicalBg,
      Category.trapped => catTrappedBg,
      Category.fire => catFireBg,
      Category.supplies => catSuppliesBg,
      Category.safe => catSafeBg,
      null => const Color(0x1F64748B),
    };
  }

  static IconData getCategoryIcon(Category? cat) {
    return switch (cat) {
      Category.medical => Icons.medical_services_rounded,
      Category.trapped => Icons.person_pin_circle_rounded,
      Category.fire => Icons.local_fire_department_rounded,
      Category.supplies => Icons.inventory_2_rounded,
      Category.safe => Icons.shield_rounded,
      null => Icons.help_outline_rounded,
    };
  }

  static String getCategoryLabel(Category? cat) {
    return switch (cat) {
      Category.medical => 'Medical Emergency',
      Category.trapped => 'Trapped / Stranded',
      Category.fire => 'Fire Hazard',
      Category.supplies => 'Needs Food / Water',
      Category.safe => 'Safe / Resolved',
      null => 'Emergency SOS',
    };
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: ColorScheme.dark(
        primary: meshCyan,
        onPrimary: Colors.black,
        primaryContainer: const Color(0xFF0E3A4B),
        onPrimaryContainer: meshCyan,
        secondary: meshTealGlow,
        surface: darkSurface,
        surfaceContainerHighest: darkCard,
        onSurface: darkText,
        onSurfaceVariant: darkTextDim,
        error: catMedical,
        onError: Colors.white,
        errorContainer: const Color(0xFF450A0A),
        onErrorContainer: const Color(0xFFFECACA),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkCardBorder, width: 1),
        ),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: meshCyan,
        unselectedLabelColor: darkTextDim,
        indicatorColor: meshCyan,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: darkCardBorder,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return meshCyan.withValues(alpha: 0.2);
            }
            return darkSurface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return meshCyan;
            }
            return darkTextDim;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: darkCardBorder, width: 1),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          side: const BorderSide(color: darkCardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: meshCyan, width: 1.5),
        ),
        labelStyle: const TextStyle(color: darkTextDim),
        hintStyle: const TextStyle(color: darkMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: meshCyan.withValues(alpha: 0.2),
        secondarySelectedColor: meshCyan.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: darkText, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: meshCyan, fontSize: 13, fontWeight: FontWeight.bold),
        side: const BorderSide(color: darkCardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(
        color: darkCardBorder,
        thickness: 1,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkCardBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: darkCardBorder),
        ),
      ),
    );
  }
}
