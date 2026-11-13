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
    required this.accent,
    required this.surfaceAlt,
    required this.inkAlt,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
    required this.purple,
    required this.purpleSoft,
    required this.successSoft,
    required this.errorSoft,
    required this.accentSoft,
    required this.onAccent,
    required this.onAccentMuted,
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

  /// Second accent used by the gradient headers (`brand` → `accent`).
  final Color accent;

  /// Alternative surface: summary strips, read-only tiles, table headers.
  final Color surfaceAlt;

  /// Stronger secondary text: sub-headings, table cell labels.
  final Color inkAlt;

  /// Alert / caution accents and their tinted backgrounds.
  final Color warning;
  final Color warningSoft;

  /// Informational accents and their tinted backgrounds.
  final Color info;
  final Color infoSoft;

  /// Category accents (charts, tags) and their tinted backgrounds.
  final Color purple;
  final Color purpleSoft;

  /// Primary content drawn on a *coloured* surface: the brand gradient,
  /// the amber "layer" header, the market-rate header.
  ///
  /// Light = white. Dark = near-black, because those surfaces become light
  /// tints in dark mode and white content would disappear on them.
  final Color onAccent;

  /// Secondary content on a coloured surface (≈70% emphasis).
  final Color onAccentMuted;

  /// Fully transparent overlay, for `surfaceTintColor` / `Material.color`.
  static const Color transparent = Color(0x00000000);

  /// Tinted backgrounds for positive / negative states and the second accent.
  final Color successSoft;
  final Color errorSoft;
  final Color accentSoft;

  bool get isDark => brightness == Brightness.dark;

  /// Outline of an *interactive* boundary: text field, dropdown, checkbox.
  ///
  /// Deliberately stronger than [line]. WCAG 1.4.11 asks for 3:1 on the edge
  /// of a control; [line] is only 1.23:1 on white and 1.26:1 on dark card, so
  /// painting input borders with [line] is the classic "invisible input" bug.
  Color get controlBorder =>
      isDark ? const Color(0xFF566E5F) : const Color(0xFF89968D);

  /// Decorative edge for a warning / advisory surface; pairs with [warningSoft].
  /// Not an interactive boundary, so WCAG 1.4.11's 3:1 rule does not apply.
  Color get warningBorder =>
      isDark ? const Color(0xFF6B5726) : const Color(0xFFE9C46A);

  static const Color seed = Color(0xFF1B5E20);

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    brand: Color(0xFF1B5E20),
    brandSoft: Color(0xFFE8F2E9),
    onBrand: Color(0xFFFFFFFF),
    ink: Color(0xFF102A1F),
    muted: Color(0xFF6A717E),
    line: Color(0xFFE5E9E6),
    soft: Color(0xFFF4F7F5),
    card: Color(0xFFFFFFFF),
    shadow: Color(0x0A000000),
    hint: Color(0xFF757575),
    error: Color(0xFFD32F2F),
    errorBorder: Color(0xFFEF5350),
    errorText: Color(0xFFD32F2F),
    onError: Color(0xFFFFFFFF),
    noticeBg: Color(0xFFFFF8E8),
    noticeBorder: Color(0xFFF3E2B0),
    noticeText: Color(0xFF6E5718),
    noticeIcon: Color(0xFF8A6A1A),
    accent: Color(0xFF00897B),
    surfaceAlt: Color(0xFFF6F8FA),
    inkAlt: Color(0xFF1E293B),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFFF7ED),
    info: Color(0xFF0369A1),
    infoSoft: Color(0xFFEFF6FF),
    purple: Color(0xFF6A1B9A),
    purpleSoft: Color(0xFFFAF5FF),
    successSoft: Color(0xFFECFDF5),
    errorSoft: Color(0xFFFEF2F2),
    accentSoft: Color(0xFFE0F2F1),
    onAccent: Color(0xFFFFFFFF),
    onAccentMuted: Color(0xB3FFFFFF),
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
    error: Color(0xFFE12C32),
    errorBorder: Color(0xFFE05A56),
    errorText: Color(0xFFEE7B77),
    onError: Color(0xFFFFFFFF),
    noticeBg: Color(0xFF241E10),
    noticeBorder: Color(0xFF453A1B),
    noticeText: Color(0xFFD6BE82),
    noticeIcon: Color(0xFFC9A961),
    accent: Color(0xFF4FD1C5),
    surfaceAlt: Color(0xFF0F1A14),
    inkAlt: Color(0xFFC4D3CA),
    warning: Color(0xFFE0A85C),
    warningSoft: Color(0xFF2A2213),
    info: Color(0xFF64B5F6),
    infoSoft: Color(0xFF132430),
    purple: Color(0xFFCE93D8),
    purpleSoft: Color(0xFF241A2B),
    successSoft: Color(0xFF14251A),
    errorSoft: Color(0xFF2A1618),
    accentSoft: Color(0xFF10241F),
    onAccent: Color(0xFF08170E),
    onAccentMuted: Color(0xB308170E),
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
    Color? accent,
    Color? surfaceAlt,
    Color? inkAlt,
    Color? warning,
    Color? warningSoft,
    Color? info,
    Color? infoSoft,
    Color? purple,
    Color? purpleSoft,
    Color? successSoft,
    Color? errorSoft,
    Color? accentSoft,
    Color? onAccent,
    Color? onAccentMuted,
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
      accent: accent ?? this.accent,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      inkAlt: inkAlt ?? this.inkAlt,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      purple: purple ?? this.purple,
      purpleSoft: purpleSoft ?? this.purpleSoft,
      successSoft: successSoft ?? this.successSoft,
      errorSoft: errorSoft ?? this.errorSoft,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      onAccentMuted: onAccentMuted ?? this.onAccentMuted,
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
      accent: Color.lerp(accent, other.accent, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      inkAlt: Color.lerp(inkAlt, other.inkAlt, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      purpleSoft: Color.lerp(purpleSoft, other.purpleSoft, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      onAccentMuted: Color.lerp(onAccentMuted, other.onAccentMuted, t)!,
    );
  }
}

/// Convenient access to the registered AppColors extension.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
