import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Dairesel ilerleme halkası. Kalınlık ~10, uçlar yuvarlak, boş kısım
/// `trackNeutral`. Merkeze serbest içerik konur.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 132,
    this.strokeWidth = 10,
    this.color = AppColors.primary,
    this.trackColor = AppColors.trackNeutral,
    this.center,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          color: color,
          trackColor: trackColor,
        ),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);

    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        progress,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// Halka merkezindeki `12/20` biçimi: pay iri + koyu, bölen küçük + gri.
class FractionLabel extends StatelessWidget {
  const FractionLabel({
    super.key,
    required this.numerator,
    required this.denominator,
    this.unit,
  });

  final int numerator;
  final int denominator;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$numerator', style: AppTextStyles.statNumber),
              TextSpan(
                text: '/$denominator',
                style: AppTextStyles.fractionDenominator,
              ),
            ],
          ),
        ),
        if (unit != null)
          Text(unit!, style: AppTextStyles.caption),
      ],
    );
  }
}
