import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prekta/core/models/app_user.dart';
import 'package:prekta/core/models/daily_stat.dart';
import 'package:prekta/core/models/language_pair.dart';
import 'package:prekta/core/models/word.dart';
import 'package:prekta/features/home/home_screen.dart';
import 'package:prekta/providers.dart';
import 'package:prekta/theme/app_theme.dart';

/// Ana sayfanın gösterdiği her sayı Firestore akışlarından gelmeli.
/// Testte akışlar sahte verilerle değiştirilir; ekranda o değerler beklenir.
void main() {
  setUpAll(() {
    // Testte ağdan font indirilmesin; yerel yedek font kullanılır.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final now = DateTime(2026, 7, 31, 9);

  const profile = AppUser(
    uid: 'u1',
    displayName: 'Hüseyin Yaman',
    pair: LanguagePair.enTr,
    dailyGoal: 20,
    currentStreak: 4,
    lastStudyDay: '2026-07-31',
  );

  Word word(String term, String translation, {int mastery = 2, DateTime? seen}) =>
      Word(
        id: 'en_tr__$term',
        pairId: 'en_tr',
        term: term,
        translation: translation,
        mastery: mastery,
        correctCount: mastery,
        lastReviewedAt: seen,
        nextReviewAt: seen,
      );

  Future<void> pumpHome(
    WidgetTester tester, {
    required DailyStat today,
    required List<Word> words,
    AppUser user = profile,
  }) async {
    // Varsayılan 800x600 test ekranında sayfanın altı çizilmez; uzun bir
    // yüzey verip tüm bölümlerin oluşmasını sağlıyoruz.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 2200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWith((ref) => now),
          appUserProvider.overrideWith((ref) => Stream.value(user)),
          todayStatProvider.overrideWith((ref) => Stream.value(today)),
          poolWordsProvider.overrideWith((ref) => Stream.value(words)),
          // Firebase'e uzanmasin diye kullanici tarafi da sahte.
          ownWordsProvider.overrideWith((ref) => Stream.value(const [])),
          progressProvider.overrideWith((ref) => Stream.value(const {})),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeScreen(onSeeAllWords: () {}, onSeeProgress: () {}),
          ),
        ),
      ),
    );
    await tester.pump(); // akışlardaki ilk değerler
  }

  testWidgets('bugünkü özet dailyStats dokümanındaki sayıları gösterir',
      (tester) async {
    await pumpHome(
      tester,
      today: const DailyStat(
        day: '2026-07-31',
        answered: 12,
        correct: 9,
        learnedCount: 3,
        reviewCount: 7,
        newCount: 2,
      ),
      words: [word('run', 'koşmak', seen: now)],
    );

    expect(find.text('Bugünkü özetin'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // öğrenilen
    expect(find.text('7'), findsOneWidget); // tekrar
    expect(find.text('2'), findsOneWidget); // yeni
    expect(find.text('Öğrenilen'), findsOneWidget);
  });

  testWidgets('günlük hedef halkası bugünün cevap sayısından beslenir',
      (tester) async {
    await pumpHome(
      tester,
      today: const DailyStat(day: '2026-07-31', answered: 12, correct: 10),
      words: [word('run', 'koşmak', seen: now)],
    );

    // Halka merkezi tek bir zengin metin: pay + bölen.
    expect(find.text('12/20', findRichText: true), findsOneWidget);
    expect(find.text('8 kelime kaldı, hadi devam et!'), findsOneWidget);
  });

  testWidgets('son öğrenilenler şeridi kelime akışından gelir',
      (tester) async {
    await pumpHome(
      tester,
      today: DailyStat.empty('2026-07-31'),
      words: [
        word('apple', 'elma', seen: now.subtract(const Duration(minutes: 5))),
        word('brave', 'cesur', seen: now.subtract(const Duration(hours: 2))),
        word('gentle', 'nazik'), // hiç çalışılmamış — şeritte olmamalı
      ],
    );

    expect(find.text('apple'), findsOneWidget);
    expect(find.text('elma'), findsOneWidget);
    expect(find.text('brave'), findsOneWidget);
    expect(find.text('gentle'), findsNothing);
  });

  testWidgets('motivasyon kartı her durumda mockup metnini gösterir',
      (tester) async {
    // Gün boş: metin sabit.
    await pumpHome(
      tester,
      user: const AppUser(uid: 'u2', pair: LanguagePair.enTr),
      today: DailyStat.empty('2026-07-31'),
      words: [word('run', 'koşmak')],
    );

    expect(find.text('Küçük adımlar büyük başarılar getirir'), findsOneWidget);
    expect(
      find.text('Bugün ayırdığın birkaç dakika fark yaratır.'),
      findsOneWidget,
    );
  });

  testWidgets('hedef tamamlansa da motivasyon metni değişmez', (tester) async {
    await pumpHome(
      tester,
      today: const DailyStat(day: '2026-07-31', answered: 20, correct: 18),
      words: [word('run', 'koşmak')],
    );

    expect(find.text('Küçük adımlar büyük başarılar getirir'), findsOneWidget);
    expect(
      find.text('Bugün ayırdığın birkaç dakika fark yaratır.'),
      findsOneWidget,
    );
  });
}
