import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/language_pair.dart';
import '../core/models/word.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';
import 'icon_box.dart';
import 'stat_box.dart';

/// "Son Öğrenilenler" şeridindeki dikey kelime kartı: sol üstte durum ikonu,
/// sağ üstte seslendirme, altta kelime + çeviri ve ince ustalık çubuğu.
class WordCard extends ConsumerWidget {
  const WordCard({super.key, required this.word, this.onTap, this.width = 152});

  final Word word;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = word.status;

    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBox(
                  icon: _iconFor(status),
                  background: status.color.withValues(alpha: 0.12),
                  foreground: status.color,
                ),
                const Spacer(),
                _SpeakButton(word: word),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              word.term,
              style: AppTextStyles.word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              word.translation,
              style: AppTextStyles.translation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

/// Kelimeyi öğrenilen dilde seslendirir. Cihazda TTS yoksa kullanıcıya
/// kısa bir bilgi verilir — buton asla sessizce ölü kalmaz.
class _SpeakButton extends ConsumerWidget {
  const _SpeakButton({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkResponse(
      radius: 20,
      onTap: () async {
        final pair = ref.read(appUserProvider).value?.pair ??
            LanguagePair.fromId(word.pairId);
        final messenger = ScaffoldMessenger.of(context);
        final spoken = await ref.read(pronunciationProvider).speak(
              word.term,
              pair,
            );
        if (!spoken) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Bu cihazda seslendirme kullanılamıyor.'),
              ),
            );
        }
      },
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.xs),
        child: Icon(
          Icons.volume_up_outlined,
          size: 18,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
