import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marka logosu — "P" harfi. Kaynak PNG şeffaf zeminli ve tek renk olduğu
/// için istenen renge boyanabilir.
class PrektaLogo extends StatelessWidget {
  const PrektaLogo({super.key, this.size = 72, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/prekta_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color ?? AppColors.textPrimary,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Prekta',
      // Görsel yüklenemezse harf yedeği: splash asla boş kalmasın.
      errorBuilder: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: FittedBox(
          child: Text(
            'P',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
