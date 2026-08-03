import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tipografi rolleri. Aile: Inter (gövde + başlık aynı aile).
abstract final class AppTextStyles {
  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// Ekran başlığı — "Kelimelerim"
  static TextStyle get screenTitle =>
      _inter(size: 26, weight: FontWeight.w800, color: AppColors.textPrimary);

  /// Selamlama — "Günaydın, Ahmet!"
  static TextStyle get greeting =>
      _inter(size: 24, weight: FontWeight.w800, color: AppColors.textPrimary);

  /// Bölüm başlığı — "Bugünkü özetin"
  static TextStyle get sectionTitle =>
      _inter(size: 17, weight: FontWeight.w700, color: AppColors.textPrimary);

  /// Kart başlığı — "Cevap doğruluğu"
  static TextStyle get cardTitle =>
      _inter(size: 17, weight: FontWeight.w700, color: AppColors.textPrimary);

  /// Büyük sayı — 340, %82, 12/20
  static TextStyle get statNumber =>
      _inter(size: 28, weight: FontWeight.w800, color: AppColors.textPrimary);

  static TextStyle get statNumberSm =>
      _inter(size: 26, weight: FontWeight.w800, color: AppColors.textPrimary);

  /// Kelime — "run", "brave"
  static TextStyle get word =>
      _inter(size: 16, weight: FontWeight.w700, color: AppColors.textPrimary);

  /// Çeviri — "koşmak", "cesur"
  static TextStyle get translation =>
      _inter(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary);

  /// Gövde / açıklama
  static TextStyle get body =>
      _inter(size: 14, weight: FontWeight.w500, color: AppColors.textSecondary);

  static TextStyle get bodyLight =>
      _inter(size: 14, weight: FontWeight.w400, color: AppColors.textSecondary);

  /// Etiket / caption
  static TextStyle get caption =>
      _inter(size: 12, weight: FontWeight.w500, color: AppColors.textSecondary);

  /// Bottom-nav etiketi
  static TextStyle get navLabel =>
      _inter(size: 11, weight: FontWeight.w600, color: AppColors.textTertiary);

  /// Buton metni
  static TextStyle get button =>
      _inter(size: 16, weight: FontWeight.w700, color: Colors.white);

  /// Kart sağ üstündeki metin-link — "Bu hafta", "Tümü"
  static TextStyle get link =>
      _inter(size: 13, weight: FontWeight.w600, color: AppColors.primary);

  /// `12/20` gibi kesirlerde bölen kısmı: küçük + gri.
  static TextStyle get fractionDenominator =>
      _inter(size: 15, weight: FontWeight.w600, color: AppColors.textSecondary);

  static TextStyle get chip =>
      _inter(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary);

  static TextStyle get placeholder =>
      _inter(size: 14, weight: FontWeight.w400, color: AppColors.textTertiary);

  /// Text theme — ThemeData'ya bağlanır.
  static TextTheme get textTheme => TextTheme(
        displayLarge: screenTitle,
        headlineLarge: greeting,
        headlineMedium: statNumber,
        titleLarge: sectionTitle,
        titleMedium: cardTitle,
        titleSmall: word,
        bodyLarge: body,
        bodyMedium: bodyLight,
        bodySmall: translation,
        labelLarge: button,
        labelMedium: caption,
        labelSmall: navLabel,
      );
}
