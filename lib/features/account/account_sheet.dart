import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/language_pair.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Hesap ve tercihler: profil, öğrenme yönü, günlük hedef, çıkış.
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet();

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  bool _busy = false;

  Future<void> _switchPair(LanguagePair pair) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      // Havuz ortak olduğu için yön değiştirmek kelime kopyalamaz.
      await ref.read(userRepositoryProvider).setPair(uid, pair);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Dil değiştirilemedi, tekrar dene.')),
        );
    }
  }

  Future<void> _setGoal(int goal) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref.read(userRepositoryProvider).setDailyGoal(uid, goal);
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(appUserProvider).value;
    final activePair = profile?.pair;

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
                _Avatar(
                  photoUrl: profile?.photoUrl,
                  initial: profile?.firstName.characters.first ?? '?',
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.displayName ?? 'Hesabım',
                        style: AppTextStyles.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile?.email ?? '',
                        style: AppTextStyles.translation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Öğrenme yönü', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<LanguagePair>(
              groupValue: activePair,
              onChanged: (p) {
                if (p != null && !_busy) _switchPair(p);
              },
              child: Column(
                children: [
                  for (final pair in LanguagePair.values)
                    RadioListTile<LanguagePair>(
                      value: pair,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: Text(pair.title, style: AppTextStyles.word),
                      subtitle:
                          Text(pair.subtitle, style: AppTextStyles.translation),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Günlük hedef', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final goal in const [10, 20, 30, 50])
                  _GoalChip(
                    goal: goal,
                    selected: profile?.dailyGoal == goal,
                    onTap: _busy ? null : () => _setGoal(goal),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            OutlinedButton(
              onPressed: _busy ? null : _signOut,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_outlined, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Çıkış yap',
                    style: AppTextStyles.button
                        .copyWith(color: AppColors.textPrimary),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.initial});

  final String? photoUrl;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.primarySurface,
        shape: BoxShape.circle,
      ),
      child: photoUrl == null
          ? Text(
              initial.toUpperCase(),
              style: AppTextStyles.cardTitle.copyWith(color: AppColors.primary),
            )
          : Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              width: 48,
              height: 48,
              errorBuilder: (_, _, _) => Text(
                initial.toUpperCase(),
                style:
                    AppTextStyles.cardTitle.copyWith(color: AppColors.primary),
              ),
            ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final int goal;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: AppRadius.chipR,
      child: InkWell(
        borderRadius: AppRadius.chipR,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.chipR,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            '$goal kelime',
            style: AppTextStyles.chip.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
