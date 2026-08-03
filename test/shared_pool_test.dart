import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prekta/core/models/app_user.dart';
import 'package:prekta/core/models/language_pair.dart';
import 'package:prekta/core/models/word.dart';
import 'package:prekta/core/models/word_progress.dart';
import 'package:prekta/providers.dart';

/// Hazır havuz kullanıcıya kopyalanmaz: içerik ortak koleksiyondan,
/// ilerleme `users/{uid}/progress`'ten gelir ve ekranda birleşir.
void main() {
  final now = DateTime(2026, 8, 1, 10);

  Word content(String term, {WordSource source = WordSource.prekta}) => Word(
        id: 'en_tr__$term',
        pairId: 'en_tr',
        term: term,
        translation: '$term-çeviri',
        source: source,
      );

  final pool = [content('run'), content('brave'), content('gentle')];
  final own = [content('kendi', source: WordSource.user)];

  ProviderContainer containerWith({
    Map<String, WordProgress> progress = const {},
    List<Word>? poolWords,
    List<Word>? ownWords,
  }) {
    final container = ProviderContainer(
      overrides: [
        nowProvider.overrideWith((ref) => now),
        appUserProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(uid: 'u1', pair: LanguagePair.enTr),
          ),
        ),
        poolWordsProvider.overrideWith((ref) => Stream.value(poolWords ?? pool)),
        ownWordsProvider.overrideWith((ref) => Stream.value(ownWords ?? own)),
        progressProvider.overrideWith((ref) => Stream.value(progress)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle(ProviderContainer c) async {
    c.listen(wordsProvider, (_, _) {});
    await c.read(appUserProvider.future);
    await c.read(poolWordsProvider.future);
    await c.read(ownWordsProvider.future);
    await c.read(progressProvider.future);
  }

  test('havuz ve kullanıcı kelimeleri tek listede birleşir', () async {
    final c = containerWith();
    await settle(c);

    final words = c.read(wordsProvider).value!;
    expect(words.length, 4);
    expect(words.where((w) => w.isCustom).length, 1);
  });

  test('ilerleme ayrı koleksiyondan gelip içeriğe uygulanır', () async {
    final c = containerWith(
      progress: {
        'en_tr__run': WordProgress(
          mastery: 3,
          correctCount: 4,
          wrongCount: 1,
          lastReviewedAt: now,
        ),
      },
    );
    await settle(c);

    final words = c.read(wordsProvider).value!;
    final run = words.firstWhere((w) => w.term == 'run');
    final brave = words.firstWhere((w) => w.term == 'brave');

    expect(run.mastery, 3);
    expect(run.correctCount, 4);
    expect(run.status, WordStatus.learning);
    expect(run.lastReviewedAt, now);

    // Hiç çalışılmamış kelimenin ilerleme kaydı yoktur — yeni sayılır.
    expect(brave.mastery, 0);
    expect(brave.status, WordStatus.isNew);
  });

  test('çalışılmamış kelimeler kayıt gerektirmez', () async {
    final c = containerWith(progress: const {});
    await settle(c);

    final words = c.read(wordsProvider).value!;
    expect(words.every((w) => w.progress.isUntouched), isTrue);
    expect(c.read(dueWordsProvider).length, 4); // hepsi tekrar sırasında
  });

  test('aynı kimlikte kullanıcı kelimesi havuzu ezer', () async {
    final c = containerWith(
      poolWords: [content('run')],
      ownWords: [content('run', source: WordSource.user)],
    );
    await settle(c);

    final words = c.read(wordsProvider).value!;
    expect(words.length, 1);
    expect(words.single.isCustom, isTrue);
  });

  test('havuz kapalıyken kullanıcının kelimeleri ilerlemesiyle kalır',
      () async {
    final c = containerWith(
      progress: {'en_tr__kendi': const WordProgress(mastery: 5)},
    );
    await settle(c);

    // Tercih varsayılan olarak açık; kapalı halini ayrıca doğruluyoruz.
    final visible = c.read(visibleWordsProvider).value!;
    expect(visible.length, 4);

    final own = c.read(customWordsProvider).value!;
    expect(own.single.mastery, 5);
    expect(own.single.isMastered, isTrue);
  });
}
