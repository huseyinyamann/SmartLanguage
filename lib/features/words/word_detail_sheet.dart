import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/word.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/icon_box.dart';
import '../../widgets/stat_box.dart';

/// Kelimeye dokununca açılan detay: örnek cümle, ustalık, doğru/yanlış sayısı.
Future<void> showWordDetail(BuildContext context, Word word) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _WordDetail(word: word),
  );
}

class _WordDetail extends ConsumerWidget {
  const _WordDetail({required this.word});

  final Word word;

  /// Silmeden önce onay ister; silindikten sonra tek dokunuşla geri alınabilir
  /// (kelime tüm ustalık geçmişiyle birlikte geri yazılır).
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Kelime silinsin mi?', style: AppTextStyles.cardTitle),
        content: Text(
          '"${word.term}" kelime listenden kaldırılacak.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Sil',
              style: AppTextStyles.link.copyWith(
                color: AppColors.wordStruggling,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final repository = ref.read(wordRepositoryProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repository.remove(uid, word.id);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('"${word.term}" silindi.'),
            action: SnackBarAction(
              label: 'Geri al',
              textColor: Colors.white,
              onPressed: () => repository.add(uid, word),
            ),
          ),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Kelime silinemedi, tekrar dene.')),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = word.status;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBox(
                  icon: Icons.translate_outlined,
                  background: status.color.withValues(alpha: 0.12),
                  foreground: status.color,
                  size: 44,
                  iconSize: 22,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(word.term, style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 2),
                      Text(word.translation, style: AppTextStyles.body),
                    ],
                  ),
                ),
                _StatusPill(status: status),
              ],
            ),
            if (word.example != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppRadius.searchR,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.example!, style: AppTextStyles.word),
                    if (word.exampleTranslation != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        word.exampleTranslation!,
                        style: AppTextStyles.translation,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Text('Ustalık', style: AppTextStyles.caption),
                const Spacer(),
                Text(
                  '${word.mastery}/$kMaxMastery',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ThinProgressBar(value: word.masteryRatio),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                _MiniStat(
                  label: 'Doğru',
                  value: '${word.correctCount}',
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.xxl),
                _MiniStat(
                  label: 'Yanlış',
                  value: '${word.wrongCount}',
                  color: AppColors.wordStruggling,
                ),
                if (word.level != null) ...[
                  const SizedBox(width: AppSpacing.xxl),
                  _MiniStat(
                    label: 'Seviye',
                    value: word.level!,
                    color: AppColors.primary,
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () => _delete(context, ref),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.wordStruggling,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Sil',
                        style: AppTextStyles.link.copyWith(
                          color: AppColors.wordStruggling,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final WordStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: AppRadius.chipR,
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(
          color: status.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.cardTitle.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
