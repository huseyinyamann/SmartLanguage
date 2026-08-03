import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/language_pair.dart';
import '../../core/models/word.dart';
import '../../data/word_repository.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Kullanıcının kendi kelimesini eklediği form.
Future<void> showAddWordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _AddWordSheet(),
  );
}

class _AddWordSheet extends ConsumerStatefulWidget {
  const _AddWordSheet();

  @override
  ConsumerState<_AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends ConsumerState<_AddWordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _term = TextEditingController();
  final _translation = TextEditingController();
  final _example = TextEditingController();
  final _exampleTranslation = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _term.dispose();
    _translation.dispose();
    _example.dispose();
    _exampleTranslation.dispose();
    super.dispose();
  }

  String? _trimmed(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save(LanguagePair pair) async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final term = _term.text.trim();

    final word = Word(
      id: WordRepository.wordIdFor(pair, term),
      pairId: pair.id,
      term: term,
      translation: _translation.text.trim(),
      example: _trimmed(_example),
      exampleTranslation: _trimmed(_exampleTranslation),
      source: WordSource.user,
    );

    try {
      await ref.read(wordRepositoryProvider).add(uid, word);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('"$term" kelime listene eklendi.')),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Kelime eklenemedi, tekrar dene.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pair = ref.watch(appUserProvider).value?.pair ?? LanguagePair.enTr;
    final existing = ref.watch(wordsProvider).value ?? const <Word>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kelime ekle', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 2),
                Text(
                  'Kendi kelimeni ekle; pratikte diğerleriyle birlikte '
                  'karşına çıkar.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.xl),
                _Field(
                  controller: _term,
                  label: _termLabel(pair),
                  hint: pair == LanguagePair.enTr ? 'run' : 'koşmak',
                  autofocus: true,
                  textCapitalization: TextCapitalization.none,
                  validator: (value) => _validateTerm(value, pair, existing),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Field(
                  controller: _translation,
                  label: _translationLabel(pair),
                  hint: pair == LanguagePair.enTr ? 'koşmak' : 'run',
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Karşılığını yazman gerekiyor.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                _Field(
                  controller: _example,
                  label: 'Örnek cümle (opsiyonel)',
                  hint: pair == LanguagePair.enTr
                      ? 'I run every morning.'
                      : 'Her sabah koşarım.',
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),
                _Field(
                  controller: _exampleTranslation,
                  label: 'Örnek cümlenin çevirisi (opsiyonel)',
                  hint: pair == LanguagePair.enTr
                      ? 'Her sabah koşarım.'
                      : 'I run every morning.',
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: () => _save(pair),
                ),
                const SizedBox(height: AppSpacing.xxl),
                FilledButton(
                  onPressed: _saving ? null : () => _save(pair),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : const Text('Kelimeyi ekle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Aynı kelime iki kez eklenirse deterministik kimlik yüzünden eskisinin
  /// ustalık geçmişi silinirdi — bu yüzden baştan engelleniyor.
  static String? _validateTerm(
    String? value,
    LanguagePair pair,
    List<Word> existing,
  ) {
    final term = (value ?? '').trim();
    if (term.isEmpty) return 'Kelimeyi yazman gerekiyor.';

    final id = WordRepository.wordIdFor(pair, term);
    if (existing.any((w) => w.id == id)) {
      return 'Bu kelime listende zaten var.';
    }
    return null;
  }

  static String _termLabel(LanguagePair pair) => switch (pair) {
        LanguagePair.enTr => 'İngilizce kelime',
        LanguagePair.trEn => 'Türkçe kelime',
      };

  static String _translationLabel(LanguagePair pair) => switch (pair) {
        LanguagePair.enTr => 'Türkçe karşılığı',
        LanguagePair.trEn => 'İngilizce karşılığı',
      };
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          validator: validator,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          style: AppTextStyles.word,
          textInputAction:
              onSubmitted == null ? TextInputAction.next : TextInputAction.done,
          onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
