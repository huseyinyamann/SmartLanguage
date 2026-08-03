import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prekta/core/models/app_user.dart';
import 'package:prekta/core/models/language_pair.dart';
import 'package:prekta/core/models/word.dart';
import 'package:prekta/providers.dart';

/// "Prekta kelimeleri" anahtarı kapalıyken listenin de pratiğin de yalnızca
/// kullanıcının kendi kelimelerinden oluşması gerekir.
void main() {
  final now = DateTime(2026, 8, 1, 10);

  Word word(
    String term, {
    required WordSource source,
    int mastery = 0,
    DateTime? next,
  }) =>
      Word(
        id: 'en_tr__$term',
        pairId: 'en_tr',
        term: term,
        translation: '$term-çeviri',
        source: source,
        mastery: mastery,
        nextReviewAt: next,
      );

  // Hazır havuz ortak koleksiyondan, kendi kelimeleri kullanıcıdan gelir.
  final pool = [
    word('run', source: WordSource.prekta),
    word('brave', source: WordSource.prekta, mastery: kMaxMastery),
  ];
  final own = [
    word('kendi1', source: WordSource.user),
    word('kendi2', source: WordSource.user, mastery: 2),
  ];

  ProviderContainer containerWith({required bool usePrekta}) {
    final container = ProviderContainer(
      overrides: [
        nowProvider.overrideWith((ref) => now),
        appUserProvider.overrideWith(
          (ref) => Stream.value(
            AppUser(
              uid: 'u1',
              pair: LanguagePair.enTr,
              usePrektaWords: usePrekta,
            ),
          ),
        ),
        poolWordsProvider.overrideWith((ref) => Stream.value(pool)),
        ownWordsProvider.overrideWith((ref) => Stream.value(own)),
        progressProvider.overrideWith((ref) => Stream.value(const {})),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Akışların ilk değerlerini yayması için bir tur bekle.
  Future<void> settle(ProviderContainer c) async {
    c.listen(appUserProvider, (_, _) {});
    c.listen(wordsProvider, (_, _) {});
    await c.read(appUserProvider.future);
    await c.read(poolWordsProvider.future);
    await c.read(ownWordsProvider.future);
    await c.read(progressProvider.future);
  }

  test('havuz açıkken tüm kelimeler görünür', () async {
    final c = containerWith(usePrekta: true);
    await settle(c);

    final visible = c.read(visibleWordsProvider).value!;
    expect(visible.length, 4);
    expect(c.read(vocabSummaryProvider).value!.total, 4);
  });

  test('havuz kapalıyken yalnızca kullanıcının kelimeleri kalır', () async {
    final c = containerWith(usePrekta: false);
    await settle(c);

    final visible = c.read(visibleWordsProvider).value!;
    expect(visible.map((w) => w.term), ['kendi1', 'kendi2']);
    expect(visible.every((w) => w.isCustom), isTrue);
  });

  test('pratik havuzu da tercihe uyar', () async {
    final open = containerWith(usePrekta: true);
    await settle(open);
    // brave ustalaşıldığı için havuzda değil: run + kendi1 + kendi2
    expect(open.read(dueWordsProvider).map((w) => w.term).toSet(),
        {'run', 'kendi1', 'kendi2'});

    final closed = containerWith(usePrekta: false);
    await settle(closed);
    expect(closed.read(dueWordsProvider).map((w) => w.term).toSet(),
        {'kendi1', 'kendi2'});
  });

  test('"Eklediklerin" sayacı havuz tercihinden etkilenmez', () async {
    for (final usePrekta in [true, false]) {
      final c = containerWith(usePrekta: usePrekta);
      await settle(c);
      expect(c.read(customWordsProvider).value!.length, 2);
    }
  });

  test('kaynak alanı olmayan eski kayıtlar hazır havuz sayılır', () {
    const raw = Word(id: 'x', pairId: 'en_tr', term: 'a', translation: 'b');
    expect(raw.source, WordSource.prekta);
    expect(raw.isCustom, isFalse);
    expect(WordSource.fromId(null), WordSource.prekta);
    expect(WordSource.fromId('user'), WordSource.user);
  });
}
