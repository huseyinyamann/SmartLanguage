import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';
import 'icon_box.dart';

/// 3'lü sıradaki mini istatistik kartı: ikon kutusu → iri sayı → gri etiket.
class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(
            icon: icon,
            background: iconBackground,
            foreground: iconForeground,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTextStyles.statNumberSm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Üç istatistik kutusunu eşit genişlikte yan yana dizer.
class StatBoxRow extends StatelessWidget {
  const StatBoxRow({super.key, required this.boxes});

  final List<StatBox> boxes;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight, kutuları en uzun olanın boyuna eşitler. Row doğrudan
    // bir ListView içinde `stretch` ile kullanılamaz — dikey eksen sınırsız.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < boxes.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Expanded(child: boxes[i]),
          ],
        ],
      ),
    );
  }
}

/// Kelime satırının altındaki ince ilerleme çubuğu.
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.success,
    this.height = 3,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AppColors.trackNeutral,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}
