import 'package:flutter_test/flutter_test.dart';
import 'package:prekta/core/date_key.dart';
import 'package:prekta/core/models/app_user.dart';
import 'package:prekta/core/models/language_pair.dart';
import 'package:prekta/core/models/word.dart';
import 'package:prekta/data/word_repository.dart';

Word _word({int mastery = 0, int correct = 0, int wrong = 0}) => Word(
      id: 'en_tr__run',
      pairId: 'en_tr',
      term: 'run',
      translation: 'koşmak',
      mastery: mastery,
      correctCount: correct,
      wrongCount: wrong,
    );

void main() {
  group('Word.status', () {
    test('hiç çalışılmamış kelime yenidir', () {
      expect(_word().status, WordStatus.isNew);
    });

    test('ustalık dolunca ustalaşıldı olur', () {
      expect(
        _word(mastery: kMaxMastery, correct: 5).status,
        WordStatus.mastered,
      );
    });

    test('doğrudan çok yanlış varsa zorlanılandır', () {
      expect(
        _word(mastery: 1, correct: 1, wrong: 4).status,
        WordStatus.struggling,
      );
    });

    test('arada kalan kelime öğreniliyordur', () {
      expect(
        _word(mastery: 2, correct: 2, wrong: 1).status,
        WordStatus.learning,
      );
    });

    test('ustalık oranı 0..1 arasında kalır', () {
      expect(_word().masteryRatio, 0);
      expect(_word(mastery: kMaxMastery).masteryRatio, 1);
    });
  });

  group('dateKey', () {
    test('gün anahtarı sıfır dolgulu yazılır', () {
      expect(dateKey(DateTime(2026, 7, 5)), '2026-07-05');
    });

    test('anahtar geri çözülebilir', () {
      expect(parseDateKey('2026-07-05'), DateTime(2026, 7, 5));
    });

    test('hafta günü kısaltması Türkçedir', () {
      // 2026-07-31 bir Cuma.
      expect(weekdayShort(DateTime(2026, 7, 31)), 'Cum');
    });
  });

  group('AppUser.streakAsOf', () {
    final now = DateTime(2026, 7, 31, 10);

    test('bugün çalışıldıysa seri korunur', () {
      const user = AppUser(
        uid: 'u1',
        currentStreak: 7,
        lastStudyDay: '2026-07-31',
      );
      expect(user.streakAsOf(now), 7);
    });

    test('dün çalışıldıysa seri hâlâ canlıdır', () {
      const user = AppUser(
        uid: 'u1',
        currentStreak: 7,
        lastStudyDay: '2026-07-30',
      );
      expect(user.streakAsOf(now), 7);
    });

    test('gün atlandıysa seri kopar', () {
      const user = AppUser(
        uid: 'u1',
        currentStreak: 7,
        lastStudyDay: '2026-07-28',
      );
      expect(user.streakAsOf(now), 0);
    });

    test('hiç çalışılmadıysa seri sıfırdır', () {
      const user = AppUser(uid: 'u1', currentStreak: 7);
      expect(user.streakAsOf(now), 0);
    });
  });

  group('WordRepository.wordIdFor', () {
    String id(LanguagePair pair, String term) =>
        WordRepository.wordIdFor(pair, term);

    test('kimlik dil yönü ve kelimeden türetilir', () {
      expect(id(LanguagePair.enTr, 'run'), 'en_tr__run');
    });

    test('aynı kelime büyük/küçük harften bağımsız aynı kimliği verir', () {
      expect(id(LanguagePair.enTr, '  Run '), id(LanguagePair.enTr, 'run'));
    });

    test('aynı kelime farklı dil yönünde farklı kimlik alır', () {
      expect(
        id(LanguagePair.enTr, 'run'),
        isNot(id(LanguagePair.trEn, 'run')),
      );
    });

    test('Türkçe harfler korunur, boşluk tireye döner', () {
      expect(id(LanguagePair.trEn, 'göz atmak'), 'tr_en__göz-atmak');
    });

    test('Türkçe büyük İ ve I doğru küçültülür', () {
      expect(id(LanguagePair.trEn, 'İzmir'), 'tr_en__izmir');
      expect(id(LanguagePair.trEn, 'Işık'), 'tr_en__ışık');
    });

    test('latin harf içermeyen kelimeler birbirine karışmaz', () {
      expect(
        id(LanguagePair.enTr, '書く'),
        isNot(id(LanguagePair.enTr, '読む')),
      );
    });
  });
}
