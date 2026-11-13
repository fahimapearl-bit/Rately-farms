import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Single place that turns [AppColors] into a [ThemeData].
///
/// `main.dart` only needs:
/// ```dart
/// theme: AppTheme.light,
/// darkTheme: AppTheme.dark,
/// themeMode: ThemeMode.system,
/// ```
/// Screens then read `context.colors.xxx` and never define a colour.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(AppColors.light);

  static ThemeData get dark => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final bool isDark = c.isDark;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: c.brightness,
    ).copyWith(
      primary: c.brand,
      onPrimary: c.onBrand,
      secondary: c.accent,
      onSecondary: c.onBrand,
      tertiary: c.accent,
      surface: c.card,
      onSurface: c.ink,
      surfaceContainerHighest: c.surfaceAlt,
      error: c.error,
      onError: c.onError,
      // `outline` is what DropdownButton, Checkbox, Slider and TextField
      // borders fall back to. Pointing it at `line` is the reason controls
      // vanish in dark mode (line is only 1.26:1 there).
      outline: c.controlBorder,
      outlineVariant: c.line,
    );

    final TextTheme text = ThemeData(brightness: c.brightness)
        .textTheme
        .apply(bodyColor: c.ink, displayColor: c.ink);

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.soft,
      canvasColor: c.card,
      cardColor: c.card,
      dividerColor: c.line,
      shadowColor: c.shadow,
      textTheme: text,
      iconTheme: IconThemeData(color: c.ink),
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.card,
        foregroundColor: c.ink,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        isDense: true,
        hintStyle: TextStyle(fontSize: 14, color: c.hint),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: c.muted,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: c.brand,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _border(c.controlBorder),
        enabledBorder: _border(c.controlBorder),
        focusedBorder: _border(c.brand, width: 1.5),
        errorBorder: _border(c.errorBorder),
        focusedErrorBorder: _border(c.errorBorder, width: 1.5),
        errorStyle: TextStyle(fontSize: 12, color: c.errorText),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          disabledBackgroundColor: c.brand.withOpacity(0.55),
          disabledForegroundColor: c.onBrand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.brand),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.brand,
          side: BorderSide(color: c.controlBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.inkAlt,
        contentTextStyle: TextStyle(color: c.card, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: AppColors.transparent,
        titleTextStyle: TextStyle(
          color: c.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: c.ink, fontSize: 14),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.ink,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.card,
        surfaceTintColor: AppColors.transparent,
        headerBackgroundColor: c.card,
        headerForegroundColor: c.ink,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.brand,
        selectionColor: c.brand.withOpacity(isDark ? 0.30 : 0.18),
        selectionHandleColor: c.brand,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(c.card),
        trackColor: WidgetStatePropertyAll<Color>(c.brand),
        trackOutlineColor: WidgetStatePropertyAll<Color>(c.controlBorder),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStatePropertyAll<Color>(c.brand),
        checkColor: WidgetStatePropertyAll<Color>(c.onBrand),
        side: BorderSide(color: c.controlBorder, width: 1.4),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll<Color>(c.brand),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.brandSoft,
        labelStyle: TextStyle(
          color: c.brand,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: c.line),
        shape: const StadiumBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.card,
        selectedItemColor: c.brand,
        unselectedItemColor: c.muted,
        elevation: 0,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(c.controlBorder),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
