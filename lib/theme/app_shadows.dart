import 'package:flutter/material.dart';

/// Neredeyse görünmez gölge — derinlik asıl olarak 1px kenarlıktan gelir.
abstract final class AppShadows {
  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A1A2A3D), // rgba(26,42,61,0.04)
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x081A2A3D), // rgba(26,42,61,0.03)
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];
}
