import 'package:flutter/widgets.dart';

/// Köşe yuvarlatma değerleri.
abstract final class AppRadius {
  static const card = 16.0;
  static const button = 28.0;
  static const chip = 20.0;
  static const iconBox = 10.0;
  static const search = 12.0;
  static const calendarCell = 6.0;
  static const navPill = 18.0;

  static const cardR = BorderRadius.all(Radius.circular(card));
  static const buttonR = BorderRadius.all(Radius.circular(button));
  static const chipR = BorderRadius.all(Radius.circular(chip));
  static const iconBoxR = BorderRadius.all(Radius.circular(iconBox));
  static const searchR = BorderRadius.all(Radius.circular(search));
  static const calendarCellR = BorderRadius.all(Radius.circular(calendarCell));
  static const navPillR = BorderRadius.all(Radius.circular(navPill));
}
