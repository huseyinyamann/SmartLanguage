import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_user.dart';
import '../../core/models/daily_stat.dart';
import '../../core/models/word.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_section.dart';
import '../../widgets/motivation_card.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/stat_box.dart';
import '../../widgets/streak_badge.dart';
import '../../widgets/word_card.dart';
import '../practice/practice_screen.dart';
import '../words/word_detail_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onSeeAllWords,
    required this.onSeeProgress,
  });

  final VoidCallback onSeeAllWords;
  final VoidCallback onSeeProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final profile = ref.watch(appUserProvider).value;
    final todayAsync = ref.watch(todayStatProvider);
    final recentAsync = ref.watch(recentlyStudiedWordsProvider);
    final due = ref.watch(dueWordsProvider);

    final goal = profile?.dailyGoal ?? 20;
    final today = todayAsync.valueOrNull;
    final done = (today?.answered ?? 0).clamp(0, goal);
    final remaining = (goal - done).clamp(0, goal);
    final streak = profile?.streakAsOf(now) ?? 0;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            AppSpacing.xxl,
          ),
          children: [
            _GreetingRow(profile: profile, streak: streak, now: now),
            const SizedBox(height: AppSpacing.xl),
            _DailyGoalCard(
              done: done,
              goal: goal,
              remaining: remaining,
              canPractice: due.isNotEmpty,
              onPractice: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PracticeScreen()),
              ),
              onEditGoal: () => _showGoalSheet(context, ref, goal),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'Bugünkü özetin',
              actionLabel: 'Bu hafta',
              onAction: onSeeProgress,
            ),
            const SizedBox(height: AppSpacing.md),
            AsyncSection<DailyStat>(
              value: todayAsync,
              onRetry: () => _refresh(ref),
              skeleton: const SkeletonCard(height: 108),
              data: (stat) => _TodaySummary(stat: stat),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'Son Öğrenilenler',
              actionLabel: 'Tümü',
              onAction: onSeeAllWords,
            ),
            const SizedBox(height: AppSpacing.md),
            AsyncSection<List<Word>>(
              value: recentAsync,
              onRetry: () => _refresh(ref),
              skeleton: const _RecentWordsSkeleton(),
              data: (words) => _RecentWords(words: words),
            ),
            const SizedBox(height: AppSpacing.xl),
            const MotivationCard(
              title: 'Küçük adımlar büyük başarılar getirir',
              message: 'Bugün ayırdığın birkaç dakika fark yaratır.',
            ),
          ],
        ),
      ),
    );
  }

  /// Aşağı çekince günü tazele ve akışları yeniden bağla.
  void _refresh(WidgetRef ref) {
    refreshNow(ref);
    ref.invalidate(todayStatProvider);
    ref.invalidate(wordsProvider);
    ref.invalidate(appUserProvider);
  }

}

/// Günlük hedefi 5-50 arasında ayarlamak için alt sayfa.
Future<void> _showGoalSheet(BuildContext context, WidgetRef ref, int currentGoal) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _GoalSheet(
      initialGoal: currentGoal,
      onChanged: (goal) {
        final uid = ref.read(authStateProvider).value?.uid;
        if (uid != null) ref.read(userRepositoryProvider).setDailyGoal(uid, goal);
      },
    ),
  );
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.initialGoal, required this.onChanged});

  final int initialGoal;
  final ValueChanged<int> onChanged;

  static const _min = 5;
  static const _max = 50;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late int _goal = widget.initialGoal.clamp(_GoalSheet._min, _GoalSheet._max);

  @override
  Widget build(BuildContext context) {
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
            Text('Günlük hedef', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            Text('$_goal kelime', style: AppTextStyles.greeting),
            Slider(
              value: _goal.toDouble(),
              min: _GoalSheet._min.toDouble(),
              max: _GoalSheet._max.toDouble(),
              divisions: _GoalSheet._max - _GoalSheet._min,
              activeColor: AppColors.primary,
              label: '$_goal',
              onChanged: (value) {
                final goal = value.round();
                if (goal == _goal) return;
                setState(() => _goal = goal);
                widget.onChanged(goal);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "Bugünkü özetin" — sayılar `users/{uid}/dailyStats/{bugün}` dokümanından
/// gelir; pratik sırasında StudyService tarafından artırılırlar.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.stat});

  final DailyStat stat;

  @override
  Widget build(BuildContext context) {
    return StatBoxRow(
      boxes: [
        StatBox(
          icon: Icons.check_circle_outline,
          iconBackground: AppColors.successSurface,
          iconForeground: AppColors.success,
          value: '${stat.learnedCount}',
          label: 'Öğrenilen',
        ),
        StatBox(
          icon: Icons.refresh_outlined,
          iconBackground: AppColors.streakSurface,
          iconForeground: AppColors.streak,
          value: '${stat.reviewCount}',
          label: 'Tekrar',
        ),
        StatBox(
          icon: Icons.auto_awesome_outlined,
          iconBackground: AppColors.primarySurface,
          iconForeground: AppColors.primary,
          value: '${stat.newCount}',
          label: 'Yeni',
        ),
      ],
    );
  }
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({
    required this.profile,
    required this.streak,
    required this.now,
  });

  final AppUser? profile;
  final int streak;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            '${_greeting(now)}, ${profile?.firstName ?? 'dostum'}!',
            style: AppTextStyles.greeting,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (streak > 0) ...[
          const SizedBox(width: AppSpacing.md),
          // Rozet, selamlama uzadığında ya da yazı büyüdüğünde daralabilsin.
          Flexible(child: StreakBadge(days: streak)),
        ],
      ],
    );
  }

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Günaydın';
    if (now.hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({
    required this.done,
    required this.goal,
    required this.remaining,
    required this.canPractice,
    required this.onPractice,
    required this.onEditGoal,
  });

  final int done;
  final int goal;
  final int remaining;
  final bool canPractice;
  final VoidCallback onPractice;
  final VoidCallback onEditGoal;

  @override
  Widget build(BuildContext context) {
    final ratio = goal == 0 ? 0.0 : done / goal;
    final percent = (ratio * 100).round();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.tune, size: 20),
                color: AppColors.textSecondary,
                tooltip: 'Günlük hedefi değiştir',
                onPressed: onEditGoal,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          ProgressRing(
            value: ratio,
            center: FractionLabel(
              numerator: done,
              denominator: goal,
              unit: 'kelime',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            remaining == 0
                ? 'Günlük hedefini tamamladın, harikasın!'
                : '$remaining kelime kaldı, hadi devam et!',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            remaining == 0
                ? 'İstersen fazladan tekrar yapabilirsin.'
                : 'Günlük hedefinin %$percent\'ını tamamladın.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: canPractice ? onPractice : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_outlined, size: 20),
                const SizedBox(width: AppSpacing.sm),
                // Dar ekranlarda metin taşmasın.
                Flexible(
                  child: Text(
                    canPractice ? 'Pratiğe Başla' : 'Şimdilik tekrar yok',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Yatay kaydırmalı kelime şeridi (mockup'taki görünüm).
class _RecentWords extends StatelessWidget {
  const _RecentWords({required this.words});

  final List<Word> words;

  static const _height = 150.0;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Henüz çalıştığın kelime yok.',
                style: AppTextStyles.cardTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'İlk pratiğini yaptığında burada son çalıştığın kelimeleri '
              'göreceksin.',
              style: AppTextStyles.body,
            ),
          ],
        ),
      );
    }

    final shown = words.take(10).toList();
    // Yükseklik kartların içeriğinden gelir; sabit yükseklik yazı tipi ölçeği
    // büyüdüğünde taşmaya yol açıyor.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              WordCard(
                word: shown[i],
                onTap: () => showWordDetail(context, shown[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentWordsSkeleton extends StatelessWidget {
  const _RecentWordsSkeleton();

  @override
  Widget build(BuildContext context) {
    // Kaydırılabilir liste: dar ekranda üçüncü kart taşmak yerine dışarıda kalır.
    return SizedBox(
      height: _RecentWords._height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, _) =>
            const SkeletonCard(height: _RecentWords._height, width: 152),
      ),
    );
  }
}
