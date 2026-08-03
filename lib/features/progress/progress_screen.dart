import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/daily_stat.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/accuracy_donut.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_section.dart';
import '../../widgets/icon_box.dart';
import '../../widgets/streak_badge.dart';
import '../../widgets/streak_grid.dart';
import '../../widgets/weekly_chart.dart';
import '../settings/settings_sheet.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final profile = ref.watch(appUserProvider).value;
    final statsAsync = ref.watch(recentStatsProvider);
    final summaryAsync = ref.watch(vocabSummaryProvider);

    final stats = statsAsync.valueOrNull ?? const <DailyStat>[];
    final week = stats.length <= 7 ? stats : stats.sublist(stats.length - 7);
    final answered = stats.fold<int>(0, (sum, d) => sum + d.answered);
    final correct = stats.fold<int>(0, (sum, d) => sum + d.correct);
    final accuracy = answered == 0 ? 0.0 : correct / answered;
    final streak = profile?.streakAsOf(now) ?? 0;
    final mastered = summaryAsync.valueOrNull?.mastered ?? 0;

    final badges = _badgesFor(
      streak: profile?.longestStreak ?? 0,
      mastered: mastered,
      totalAnswered: answered,
    );
    final unlocked = badges.where((b) => b.unlocked).length;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          refreshNow(ref);
          ref.invalidate(recentStatsProvider);
          ref.invalidate(wordsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            AppSpacing.xxl,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Profil', style: AppTextStyles.screenTitle),
                ),
                IconButton(
                  onPressed: () => showSettingsSheet(context),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Ayarlar',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AsyncSection<List<DailyStat>>(
              value: statsAsync,
              onRetry: () => ref.invalidate(recentStatsProvider),
              skeleton: const SkeletonCard(height: 214),
              data: (_) => AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Haftalık aktivite'),
                    Text(
                      'Son 7 günde cevapladığın kelime sayısı',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    WeeklyChart(days: week),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            AsyncSection<List<DailyStat>>(
              value: statsAsync,
              onRetry: () => ref.invalidate(recentStatsProvider),
              skeleton: const SkeletonCard(height: 168),
              data: (_) => AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cevap doğruluğu',
                            style: AppTextStyles.cardTitle,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Son pratiklerindeki doğru cevap oranı',
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _LegendDot(
                            color: AppColors.success,
                            label: '$correct doğru',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _LegendDot(
                            color: AppColors.trackNeutral,
                            label: '${answered - correct} yanlış',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    AccuracyDonut(value: accuracy),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            AsyncSection<List<DailyStat>>(
              value: statsAsync,
              onRetry: () => ref.invalidate(recentStatsProvider),
              skeleton: const SkeletonCard(height: 196),
              data: (days) => AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Çalışma serin',
                                style: AppTextStyles.cardTitle,
                              ),
                              const SizedBox(height: 2),
                              Text('Son 30 gün', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        StreakBadge(days: streak, compact: true),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    StreakGrid(days: days, today: now),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            SectionHeader(
              title: 'Rozetler',
              actionLabel: '$unlocked / ${badges.length} açıldı',
            ),
            Text(
              'Her küçük adımın bir karşılığı var.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.md),
            // Yükseklik içerikten gelir: sabit bir değer, yazı tipi ölçeği
            // büyüdüğünde kartların altını taşırıyordu.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < badges.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.md),
                      _BadgeCard(badge: badges[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<_Badge> _badgesFor({
    required int streak,
    required int mastered,
    required int totalAnswered,
  }) => [
    _Badge(
      icon: Icons.flag_outlined,
      title: 'İlk adım',
      detail: 'İlk pratiğini tamamla',
      unlocked: totalAnswered > 0,
    ),
    _Badge(
      icon: Icons.local_fire_department_outlined,
      title: '7 gün seri',
      detail: 'Bir hafta boyunca çalış',
      unlocked: streak >= 7,
    ),
    _Badge(
      icon: Icons.workspace_premium_outlined,
      title: '50 kelime',
      detail: '50 kelimede ustalaş',
      unlocked: mastered >= 50,
    ),
  ];
}

class _Badge {
  const _Badge({
    required this.icon,
    required this.title,
    required this.detail,
    required this.unlocked,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool unlocked;
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    final background = badge.unlocked
        ? AppColors.streakSurface
        : AppColors.trackNeutral;
    final foreground = badge.unlocked
        ? AppColors.streak
        : AppColors.textTertiary;

    return SizedBox(
      width: 148,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBox(
              icon: badge.unlocked ? badge.icon : Icons.lock_outline,
              background: background,
              foreground: foreground,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              badge.title,
              style: AppTextStyles.word.copyWith(
                color: badge.unlocked
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              badge.detail,
              style: AppTextStyles.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
