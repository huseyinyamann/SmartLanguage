import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/language_pair.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// İlk girişte gösterilen dil yönü seçimi. Seçimden sonra başlangıç kelime
/// listesi kullanıcının dağarcığına yüklenir.
class LanguageSelectScreen extends ConsumerStatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  ConsumerState<LanguageSelectScreen> createState() =>
      _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends ConsumerState<LanguageSelectScreen> {
  LanguagePair? _selected;
  bool _busy = false;

  Future<void> _continue() async {
    final pair = _selected;
    final uid = ref.read(authStateProvider).value?.uid;
    if (pair == null || uid == null) return;

    setState(() => _busy = true);
    try {
      // Kelime kopyalanmaz: havuz ortaktır, yalnızca tercih kaydedilir.
      // Profil güncellenince kök widget ana ekrana geçer.
      await ref.read(userRepositoryProvider).setPair(uid, pair);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Dil seçimi kaydedilemedi, tekrar dener misin?'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Text('Hangi dili öğreniyorsun?', style: AppTextStyles.screenTitle),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sonradan değiştirebilirsin. Kelimelerin ve ilerlemen '
                'her yön için ayrı tutulur.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xxl),
              for (final pair in LanguagePair.values) ...[
                _PairCard(
                  pair: pair,
                  selected: _selected == pair,
                  onTap: _busy ? null : () => setState(() => _selected = pair),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _selected == null || _busy ? null : _continue,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Devam et'),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard({
    required this.pair,
    required this.selected,
    required this.onTap,
  });

  final LanguagePair pair;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.cardR,
      child: InkWell(
        borderRadius: AppRadius.cardR,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : AppColors.surface,
            borderRadius: AppRadius.cardR,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.primarySurface,
                  borderRadius: AppRadius.iconBoxR,
                ),
                child: Text(
                  pair.shortLabel,
                  style: AppTextStyles.word.copyWith(
                    color: selected ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pair.title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Text(pair.subtitle, style: AppTextStyles.translation),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
