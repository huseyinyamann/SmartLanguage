import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prekta/core/models/app_user.dart';
import 'package:prekta/core/models/daily_stat.dart';
import 'package:prekta/core/models/language_pair.dart';
import 'package:prekta/core/models/word.dart';
import 'package:prekta/features/home/home_screen.dart';
import 'package:prekta/features/progress/progress_screen.dart';
import 'package:prekta/features/words/words_screen.dart';
import 'package:prekta/providers.dart';
import 'package:prekta/theme/app_theme.dart';

/// Taşma (overflow) regresyon testi.
///
/// Sabit yükseklikli şeritler dar ekranda ya da büyük yazı tipi ölçeğinde
/// "BOTTOM OVERFLOWED BY x PIXELS" hatası veriyordu. Flutter bu hatayı
/// testte istisna olarak fırlatır; aşağıdaki senaryolar hepsini yakalar.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime(2026, 8, 1, 10);

  const profile = AppUser(
    uid: 'u1',
    displayName: 'Hüseyin Yaman',
    pair: LanguagePair.enTr,
    dailyGoal: 20,
    currentStreak: 7,
    longestStreak: 9,
    lastStudyDay: '2026-08-01',
  );

  final words = [
    for (var i = 0; i < 12; i++)
      Word(
        id: 'en_tr__kelime$i',
        pairId: 'en_tr',
        term: 'kelime$i',
        translation: 'uzunca bir çeviri $i',
        mastery: i % 6,
        correctCount: i,
        wrongCount: i % 4,
        addedAt: now.subtract(Duration(days: i)),
        lastReviewedAt: now.subtract(Duration(hours: i)),
        nextReviewAt: now.subtract(Duration(minutes: i)),
      ),
  ];

  final stats = [
    for (var i = 29; i >= 0; i--)
      DailyStat(
        day: '2026-07-${(i + 1).toString().padLeft(2, '0')}',
        answered: i % 7 * 3,
        correct: i % 7 * 2,
        learnedCount: i % 3,
        reviewCount: i % 5,
        newCount: i % 2,
      ),
  ];

  /// [screen] ekranını verilen genişlik ve yazı ölçeğiyle çizer.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required double width,
    required double textScale,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 2600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWith((ref) => now),
          appUserProvider.overrideWith((ref) => Stream.value(profile)),
          todayStatProvider.overrideWith(
            (ref) => Stream.value(
              const DailyStat(
                day: '2026-08-01',
                answered: 12,
                correct: 9,
                learnedCount: 3,
                reviewCount: 7,
                newCount: 2,
              ),
            ),
          ),
          poolWordsProvider.overrideWith((ref) => Stream.value(words)),
          // Firebase'e uzanmasin diye kullanici tarafi da sahte.
          ownWordsProvider.overrideWith((ref) => Stream.value(const [])),
          progressProvider.overrideWith((ref) => Stream.value(const {})),
          recentStatsProvider.overrideWith((ref) => Stream.value(stats)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pump();
  }

  final screens = <String, Widget>{
    'Ana Sayfa': HomeScreen(onSeeAllWords: () {}, onSeeProgress: () {}),
    'Kelimelerim': const WordsScreen(),
    'Profil': const ProgressScreen(),
  };

  // 320: küçük telefonlar. 1.5: erişilebilirlik için büyütülmüş yazı.
  const widths = [320.0, 412.0];
  const scales = [1.0, 1.3, 1.5];

  for (final entry in screens.entries) {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets(
          '${entry.key} ${width.toInt()}px genişlik / ${scale}x yazıda taşmıyor',
          (tester) async {
            await pumpScreen(
              tester,
              entry.value,
              width: width,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
