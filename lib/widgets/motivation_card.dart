import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'icon_box.dart';

/// Ana sayfanın en altındaki şeftali renkli teşvik kartı.
///
/// Sağdaki manzara dış bir görsel değil, tema renkleriyle çizilir — böylece
/// depoya ikili dosya girmez ve renkler tema token'larıyla uyumlu kalır.
class MotivationCard extends StatelessWidget {
  const MotivationCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.self_improvement_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.streakSurface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: AppColors.streak.withValues(alpha: 0.22)),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardR,
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              top: 0,
              child: CustomPaint(
                painter: _ScenePainter(),
                size: const Size(150, double.infinity),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBox(
                    icon: icon,
                    background: AppColors.streak.withValues(alpha: 0.18),
                    foreground: AppColors.streak,
                    size: 40,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: 210,
                    child: Text(title, style: AppTextStyles.sectionTitle),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: 190,
                    child: Text(message, style: AppTextStyles.body),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gün batımı + tepeler + patika: yumuşak, düşük kontrastlı bir arka plan.
class _ScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..isAntiAlias = true;

    // Güneş
    paint.color = AppColors.streak.withValues(alpha: 0.28);
    canvas.drawCircle(Offset(w * 0.62, h * 0.34), w * 0.15, paint);

    // Arka tepe
    paint.color = AppColors.primaryLight.withValues(alpha: 0.30);
    final backHill = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.66)
      ..quadraticBezierTo(w * 0.28, h * 0.40, w * 0.55, h * 0.68)
      ..quadraticBezierTo(w * 0.78, h * 0.88, w, h * 0.62)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(backHill, paint);

    // Ön tepe
    paint.color = AppColors.primary.withValues(alpha: 0.22);
    final frontHill = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.86)
      ..quadraticBezierTo(w * 0.34, h * 0.68, w * 0.66, h * 0.88)
      ..quadraticBezierTo(w * 0.85, h * 0.99, w, h * 0.90)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(frontHill, paint);

    // Patika — yukarı doğru daralan bir yol
    paint.color = AppColors.surface.withValues(alpha: 0.55);
    final path = Path()
      ..moveTo(w * 0.34, h)
      ..quadraticBezierTo(w * 0.52, h * 0.90, w * 0.56, h * 0.78)
      ..quadraticBezierTo(w * 0.60, h * 0.90, w * 0.72, h)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => false;
}
