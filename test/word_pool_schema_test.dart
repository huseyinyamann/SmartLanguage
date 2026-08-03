import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prekta/core/models/language_pair.dart';
import 'package:prekta/core/models/word.dart';
import 'package:prekta/data/word_pool_repository.dart';

/// Havuz şeması dilden bağımsız olmalı: aynı kavram dokümanı her yön için
/// doğru kelimeyi üretmeli ve yeni bir dil eklemek yeni doküman
/// gerektirmemeli.
void main() {
  // Almanca eklenmiş bir kavram: şemanın genişlemeye dayandığını gösterir.
  final concept = <String, dynamic>{
    'conceptKey': 'run',
    'languages': ['de', 'en', 'tr'],
    'pairs': ['de_en', 'de_tr', 'en_de', 'en_tr', 'tr_de', 'tr_en'],
    'forms': {
      'en': {
        'text': 'run',
        'example': 'I run every morning.',
        'level': 'A1',
        'rank': 1,
      },
      'tr': {
        'text': 'koşmak',
        'example': 'Her sabah koşarım.',
        'level': 'A2',
        'rank': 4,
      },
      'de': {'text': 'laufen', 'example': 'Ich laufe jeden Morgen.', 'rank': 7},
    },
  };

  group('WordPoolRepository.wordFrom', () {
    test('İngilizce öğrenen Türk için doğru yönü kurar', () {
      final word = WordPoolRepository.wordFrom(concept, LanguagePair.enTr)!;

      expect(word.term, 'run');
      expect(word.translation, 'koşmak');
      expect(word.example, 'I run every morning.');
      expect(word.exampleTranslation, 'Her sabah koşarım.');
      expect(word.level, 'A1'); // seviye öğrenilen dilden gelir
      expect(word.source, WordSource.prekta);
      expect(word.pairId, 'en_tr');
    });

    test('ters yönde aynı doküman tersine çevrilir', () {
      final word = WordPoolRepository.wordFrom(concept, LanguagePair.trEn)!;

      expect(word.term, 'koşmak');
      expect(word.translation, 'run');
      expect(word.example, 'Her sabah koşarım.');
      expect(word.exampleTranslation, 'I run every morning.');
      expect(word.level, 'A2');
    });

    test('iki yön farklı kimlik üretir, çakışmaz', () {
      final a = WordPoolRepository.wordFrom(concept, LanguagePair.enTr)!;
      final b = WordPoolRepository.wordFrom(concept, LanguagePair.trEn)!;
      expect(a.id, isNot(b.id));
    });

    test('eksik çevirisi olan kavram o yönde atlanır', () {
      final partial = <String, dynamic>{
        'forms': {
          'en': {'text': 'serendipity'},
        },
      };
      expect(WordPoolRepository.wordFrom(partial, LanguagePair.enTr), isNull);
    });

    test('bozuk doküman çökmez', () {
      expect(WordPoolRepository.wordFrom(<String, dynamic>{}, LanguagePair.enTr),
          isNull);
      expect(
        WordPoolRepository.wordFrom({'forms': <String, dynamic>{}},
            LanguagePair.enTr),
        isNull,
      );
    });
  });

  group('data/word_pool.json', () {
    late List<dynamic> pool;

    setUpAll(() {
      pool = jsonDecode(File('data/word_pool.json').readAsStringSync())
          as List<dynamic>;
    });

    test('her kavram en az iki dilde tanımlı ve metinleri dolu', () {
      for (final item in pool.cast<Map<String, dynamic>>()) {
        final forms = item['forms'] as Map<String, dynamic>;
        expect(forms.length, greaterThanOrEqualTo(2), reason: '${item['id']}');
        for (final entry in forms.entries) {
          final text = (entry.value as Map<String, dynamic>)['text'] as String?;
          expect(text, isNotNull, reason: '${item['id']}.${entry.key}');
          expect(text!.trim(), isNotEmpty, reason: '${item['id']}.${entry.key}');
        }
      }
    });

    test('kimlikler benzersiz', () {
      final ids = pool.map((e) => (e as Map<String, dynamic>)['id']).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('pairs alanı forms ile tutarlı', () {
      for (final item in pool.cast<Map<String, dynamic>>()) {
        final forms = item['forms'] as Map<String, dynamic>;
        for (final pair in (item['pairs'] as List<dynamic>).cast<String>()) {
          final parts = pair.split('_');
          expect(forms.containsKey(parts[0]), isTrue, reason: pair);
          expect(forms.containsKey(parts[1]), isTrue, reason: pair);
        }
      }
    });

    test('desteklenen her dil çifti havuzda karşılık buluyor', () {
      for (final pair in LanguagePair.values) {
        final usable = pool.cast<Map<String, dynamic>>().where((item) {
          final word = WordPoolRepository.wordFrom(item, pair);
          return word != null;
        }).length;
        expect(usable, greaterThan(0), reason: pair.id);
      }
    });
  });
}
