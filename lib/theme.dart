import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF111111),
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF111111),
    onPrimary: Colors.white,
    secondary: const Color(0xFF2D2D2D),
    surface: Colors.white,
    onSurface: const Color(0xFF111111),
    surfaceContainerHighest: const Color(0xFFECEEF2),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
  );

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFFAFBFC),
    canvasColor: const Color(0xFFFAFBFC),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: const Color(0xFF111111),
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: const Color(0xFF101828),
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: const Color(0xFF101828),
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: const Color(0xFF101828),
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF344054),
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: const Color(0xFF667085),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF2F4F7),
      hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF111111), width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        side: const BorderSide(color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.black87,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFEEF1F6),
        foregroundColor: const Color(0xFF111111),
      ),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      borderRadius: BorderRadius.circular(12),
      selectedColor: Colors.white,
      color: const Color(0xFF475467),
      fillColor: const Color(0xFF111111),
      borderColor: const Color(0xFFD0D5DD),
      selectedBorderColor: const Color(0xFF111111),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: const Color(0xFFEEF1F6),
      selectedColor: const Color(0xFF111111),
      secondarySelectedColor: const Color(0xFF111111),
      labelStyle: const TextStyle(
        color: Color(0xFF344054),
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: Color(0xFFD0D5DD)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withAlpha(18),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF111111),
      textColor: Color(0xFF101828),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE4E7EC),
      space: 1,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF111111),
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: const Color(0xFF101828),
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF344054),
      ),
    ),
  );
}
