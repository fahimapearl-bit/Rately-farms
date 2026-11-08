import 'package:flutter/material.dart';

/// Centralized color tokens for the Rately Farms application.
///
/// Register [AppColors.light] and [AppColors.dark] in ThemeData.extensions,
/// then access them from widgets with `context.colors.brand`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.brand,
    required this.brandSoft,
    required this.onBrand,
    required this.ink,
    required this.muted,
    required this.line,
    required this.soft,
    required this.card,
    required this.shadow,
    required this.hint,
    required this.error,
    required this.errorBorder,
    required this.errorText,
    required this.onError,
    required this.noticeBg,
    required this.noticeBorder,
    required this.noticeText,
    required this.noticeIcon,
  });

  final Brightness brightness;
  final Color brand;
  final Color brandSoft;
  final Color onBrand;
  final Color ink;
  final Color muted;
  final Color line;
  final Color soft;
  final Color card;
  final Color shadow;
  final Color hint;
  final Color error;
  final Color errorBorder;
  final Color errorText;
  final Color onError;
  final Color noticeBg;
  final Color noticeBorder;
  final Color noticeText;
  final Color noticeIcon;

  bool get isDark => brightness == Brightness.dark;

  static const Color seed = Color(0xFF1B5E20);

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    brand: Color(0xFF1B5E20),
    brandSoft: Color(0xFFE8F2E9),
    onBrand: Color(0xFFFFFFFF),
    ink: Color(0xFF102A1F),
    muted: Color(0xFF6B7280),
    line: Color(0xFFE5E9E6),
    soft: Color(0xFFF4F7F5),
    card: Color(0xFFFFFFFF),
    shadow: Color(0x0A000000),
    hint: Color(0xFFBDBDBD),
    error: Color(0xFFD32F2F),
    errorBorder: Color(0xFFEF5350),
    errorText: Color(0xFFD32F2F),
    onError: Color(0xFFFFFFFF),
    noticeBg: Color(0xFFFFF8E8),
    noticeBorder: Color(0xFFF3E2B0),
    noticeText: Color(0xFF6E5718),
    noticeIcon: Color(0xFF8A6A1A),
  );

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    brand: Color(0xFF6FCB79),
    brandSoft: Color(0xFF17281D),
    onBrand: Color(0xFF08170E),
    ink: Color(0xFFE9F2EC),
    muted: Color(0xFF8E9E96),
    line: Color(0xFF243229),
    soft: Color(0xFF0B1310),
    card: Color(0xFF131F19),
    shadow: Color(0x8C000000),
    hint: Color(0xFF7C8E85),
    error: Color(0xFFE5484D),
    errorBorder: Color(0xFFE05A56),
    errorText: Color(0xFFEE7B77),
    onError: Color(0xFFFFFFFF),
    noticeBg: Color(0xFF241E10),
    noticeBorder: Color(0xFF453A1B),
    noticeText: Color(0xFFD6BE82),
    noticeIcon: Color(0xFFC9A961),
  );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? brand,
    Color? brandSoft,
    Color? onBrand,
    Color? ink,
    Color? muted,
    Color? line,
    Color? soft,
    Color? card,
    Color? shadow,
    Color? hint,
    Color? error,
    Color? errorBorder,
    Color? errorText,
    Color? onError,
    Color? noticeBg,
    Color? noticeBorder,
    Color? noticeText,
    Color? noticeIcon,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      onBrand: onBrand ?? this.onBrand,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      soft: soft ?? this.soft,
      card: card ?? this.card,
      shadow: shadow ?? this.shadow,
      hint: hint ?? this.hint,
      error: error ?? this.error,
      errorBorder: errorBorder ?? this.errorBorder,
      errorText: errorText ?? this.errorText,
      onError: onError ?? this.onError,
      noticeBg: noticeBg ?? this.noticeBg,
      noticeBorder: noticeBorder ?? this.noticeBorder,
      noticeText: noticeText ?? this.noticeText,
      noticeIcon: noticeIcon ?? this.noticeIcon,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;

    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      brand: Color.lerp(brand, other.brand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      card: Color.lerp(card, other.card, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      noticeBg: Color.lerp(noticeBg, other.noticeBg, t)!,
      noticeBorder: Color.lerp(noticeBorder, other.noticeBorder, t)!,
      noticeText: Color.lerp(noticeText, other.noticeText, t)!,
      noticeIcon: Color.lerp(noticeIcon, other.noticeIcon, t)!,
    );
  }
}

/// Convenient access to the registered AppColors extension.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
