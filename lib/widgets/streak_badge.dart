import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Şeftali arkaplanlı alev rozeti — "7 gün üst üste".
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days, this.compact = false});

  final int days;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.streakSurface,
        borderRadius: AppRadius.chipR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_outlined,
            size: 17,
            color: AppColors.streak,
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          // Dar ekranda / büyük yazıda rozet metni kısalır, satırı taşırmaz.
          Flexible(
            child: Text(
              compact ? '$days gün' : '$days gün üst üste',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.streak,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
