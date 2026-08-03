import 'package:flutter/material.dart';

import '../core/models/word.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'icon_box.dart';
import 'stat_box.dart';

/// Kelime satırı: renkli ikon kutusu · kelime + çeviri · `3/5` + chevron,
/// altında ince ilerleme çubuğu.
class WordRow extends StatelessWidget {
  const WordRow({super.key, required this.word, this.onTap});

  final Word word;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = word.status;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBox(
                  icon: _iconFor(status),
                  background: status.color.withValues(alpha: 0.12),
                  foreground: status.color,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              word.term,
                              style: AppTextStyles.word,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Kullanıcının kendi eklediği kelime, hazır havuzun
                          // içinde kaybolmasın.
                          if (word.isCustom) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(
                              Icons.bookmark_added_outlined,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        word.translation,
                        style: AppTextStyles.translation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${word.mastery}/$kMaxMastery',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ThinProgressBar(
              value: word.masteryRatio,
              color: status == WordStatus.struggling
                  ? AppColors.wordStruggling
                  : AppColors.success,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(WordStatus status) => switch (status) {
        WordStatus.isNew => Icons.auto_awesome_outlined,
        WordStatus.learning => Icons.schedule_outlined,
        WordStatus.mastered => Icons.check_circle_outline,
        WordStatus.struggling => Icons.priority_high_rounded,
      };
}
