import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/word.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/stat_box.dart';

/// Bir oturumda sorulacak en fazla kelime sayısı.
const _sessionSize = 10;

/// Çoktan seçmeli pratik oturumu.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  final _random = Random();

  late final List<Word> _queue;
  late final List<List<String>> _options;

  int _index = 0;
  int _correct = 0;
  String? _picked;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final due = ref.read(dueWordsProvider);
    // Çeldiriciler de aktif havuzdan gelir: havuz kapalıysa kullanıcının
    // kendi kelimeleri dışından şık üretilmez.
    final all = ref.read(visibleWordsProvider).value ?? const <Word>[];
    _queue = due.take(_sessionSize).toList();
    _options = [
      for (final word in _queue) _buildOptions(word, all),
    ];
  }

  /// Doğru cevap + havuzdan 3 çeldirici, karışık sırada.
  List<String> _buildOptions(Word word, List<Word> pool) {
    final distractors = pool
        .where((w) => w.id != word.id && w.translation != word.translation)
        .map((w) => w.translation)
        .toSet()
        .toList()
      ..shuffle(_random);

    return [word.translation, ...distractors.take(3)]..shuffle(_random);
  }

  Word get _current => _queue[_index];

  Future<void> _answer(String option) async {
    if (_picked != null || _saving) return;

    final correct = option == _current.translation;
    setState(() {
      _picked = option;
      _saving = true;
      if (correct) _correct++;
    });

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      try {
        await ref.read(studyServiceProvider).submitAnswer(
              uid: uid,
              word: _current,
              correct: correct,
            );
      } catch (_) {
        // Firestore çevrimdışı kuyruğa alır; oturumu bölmeye gerek yok.
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() {
      _picked = null;
      _index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return _PracticeScaffold(
        onClose: () => Navigator.of(context).pop(),
        child: const _NothingDue(),
      );
    }

    if (_index >= _queue.length) {
      return _PracticeScaffold(
        onClose: () => Navigator.of(context).pop(),
        child: _SessionSummary(
          correct: _correct,
          total: _queue.length,
          onDone: () => Navigator.of(context).pop(),
        ),
      );
    }

    final word = _current;
    final options = _options[_index];

    return _PracticeScaffold(
      onClose: () => Navigator.of(context).pop(),
      progress: (_index + 1) / _queue.length,
      progressLabel: '${_index + 1}/${_queue.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Bu kelimenin anlamı ne?',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl + AppSpacing.sm,
            ),
            child: Column(
              children: [
                Text(
                  word.term,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.statNumber,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${word.mastery}/$kMaxMastery ustalık',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          for (final option in options) ...[
            _OptionTile(
              label: option,
              state: _stateFor(option, word),
              onTap: () => _answer(option),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_picked != null && _picked != word.translation) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Doğrusu: ${word.translation}',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.wordStruggling,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _OptionState _stateFor(String option, Word word) {
    if (_picked == null) return _OptionState.idle;
    if (option == word.translation) return _OptionState.correct;
    if (option == _picked) return _OptionState.wrong;
    return _OptionState.dimmed;
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _PracticeScaffold extends StatelessWidget {
  const _PracticeScaffold({
    required this.child,
    required this.onClose,
    this.progress,
    this.progressLabel,
  });

  final Widget child;
  final VoidCallback onClose;
  final double? progress;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.screenH,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    tooltip: 'Kapat',
                  ),
                  Expanded(
                    child: progress == null
                        ? const SizedBox.shrink()
                        : ThinProgressBar(
                            value: progress!,
                            color: AppColors.primary,
                            height: 6,
                          ),
                  ),
                  if (progressLabel != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Text(progressLabel!, style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  0,
                  AppSpacing.screenH,
                  AppSpacing.xxl,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, border, text) = switch (state) {
      _OptionState.idle => (
          AppColors.surface,
          AppColors.border,
          AppColors.textPrimary
        ),
      _OptionState.correct => (
          AppColors.successSurface,
          AppColors.success,
          AppColors.success
        ),
      _OptionState.wrong => (
          const Color(0xFFFBEBEA),
          AppColors.wordStruggling,
          AppColors.wordStruggling
        ),
      _OptionState.dimmed => (
          AppColors.surface,
          AppColors.border,
          AppColors.textTertiary
        ),
    };

    return Material(
      color: background,
      borderRadius: AppRadius.cardR,
      child: InkWell(
        borderRadius: AppRadius.cardR,
        onTap: state == _OptionState.idle ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardR,
            border: Border.all(
              color: border,
              width: state == _OptionState.idle ? 1 : 1.6,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.word.copyWith(color: text),
                ),
              ),
              if (state == _OptionState.correct)
                const Icon(Icons.check_circle_outline,
                    size: 20, color: AppColors.success),
              if (state == _OptionState.wrong)
                const Icon(Icons.highlight_off,
                    size: 20, color: AppColors.wordStruggling),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.correct,
    required this.total,
    required this.onDone,
  });

  final int correct;
  final int total;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (correct / total * 100).round();

    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text('Oturum tamam!', style: AppTextStyles.screenTitle),
        const SizedBox(height: AppSpacing.md),
        Text(
          '$total kelimeden $correct tanesini doğru bildin.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Text('%$percent', style: AppTextStyles.statNumber),
              const SizedBox(height: AppSpacing.xs),
              Text('bu oturumdaki doğruluk', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.lg),
              ThinProgressBar(value: total == 0 ? 0 : correct / total),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(onPressed: onDone, child: const Text('Bitir')),
      ],
    );
  }
}

class _NothingDue extends StatelessWidget {
  const _NothingDue();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxl * 2),
        const Icon(
          Icons.check_circle_outline,
          size: 34,
          color: AppColors.success,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Şimdilik tekrar yok', style: AppTextStyles.cardTitle),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Tüm kelimelerin tekrar sırasını bekliyor. Biraz sonra tekrar bak.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ],
    );
  }
}
