import 'package:flutter/material.dart';

/// Tasarım temasındaki renk token'ları. Widget içinde asla ham hex yazılmaz,
/// her renk buradan okunur.
abstract final class AppColors {
  // Marka / primary
  static const primary = Color(0xFF2C5F9E);
  static const primaryDark = Color(0xFF1E4A7D);
  static const primaryLight = Color(0xFF5B8FC7);
  static const primarySurface = Color(0xFFE8F0FA);

  // Nötr
  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6EAF0);
  static const textPrimary = Color(0xFF1A2A3D);
  static const textSecondary = Color(0xFF6B7A8D);
  static const textTertiary = Color(0xFF9AA7B6);
  static const trackNeutral = Color(0xFFE9EDF3);

  // Semantik
  static const success = Color(0xFF2E7D5B);
  static const successSurface = Color(0xFFE7F3EC);
  static const streak = Color(0xFFF08A3C);
  static const warning = streak;
  static const streakSurface = Color(0xFFFDEDE0);
  static const info = Color(0xFF3C8DBC);

  // Kelime durumu
  static const wordNew = primaryLight;
  static const wordLearning = Color(0xFFF0A63C);
  static const wordMastered = success;
  static const wordStruggling = Color(0xFFD9534F);
}
