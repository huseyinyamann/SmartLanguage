import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

/// Renkli yuvarlatılmış ikon kutusu — istatistik kutularında ve kelime
/// satırlarında kullanılır.
class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 36,
    this.iconSize = 19,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.iconBoxR,
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}
