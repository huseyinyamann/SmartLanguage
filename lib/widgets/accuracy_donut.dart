import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Doğruluk donut'ı — merkezde `%82`, altında küçük gri "doğruluk".
class AccuracyDonut extends StatelessWidget {
  const AccuracyDonut({
    super.key,
    required this.value,
    this.size = 108,
    this.strokeWidth = 10,
  });

  /// 0..1
  final double value;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final percent = (value.clamp(0.0, 1.0) * 100).round();

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          value: value.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
        ),
        // Halkanın çapı sabit; büyük yazı ölçeğinde metin taşmasın diye
        // içerik halkaya sığacak şekilde küçültülür.
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(strokeWidth + AppSpacing.xs),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('%$percent', style: AppTextStyles.statNumberSm),
                  Text('doğruluk', style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.value, required this.strokeWidth});

  final double value;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = AppColors.trackNeutral,
    );

    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = AppColors.success,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.value != value;
}
