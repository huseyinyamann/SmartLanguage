import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/models/language_pair.dart';
import '../core/models/word.dart';
import 'word_pool_repository.dart';

/// Kullanıcının **kendi eklediği** kelimeler: `users/{uid}/words/{wordId}`.
///
/// Hazır havuz burada durmaz — o ortak `wordPool` koleksiyonundadır
/// ([WordPoolRepository]). Kullanıcı başına yalnızca kendi kelimeleri ve
/// çalıştığı kelimelerin ilerlemesi saklanır.
class WordRepository {
  WordRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('words');

  /// Kullanıcının bu yöndeki kendi kelimeleri (içerik; ilerleme ayrı gelir).
  Stream<List<Word>> watchCustom(String uid, LanguagePair pair) => _col(uid)
      .where('pairId', isEqualTo: pair.id)
      .snapshots()
      .map(
        (s) => s.docs
            .map(Word.fromDoc)
            .where((w) => w.isCustom)
            .toList(growable: false),
      );

  Future<void> add(String uid, Word word) =>
      _col(uid).doc(word.id).set(word.toMap());

  Future<void> remove(String uid, String wordId) => _col(uid).doc(wordId).delete();

  /// Eski sürümde hazır havuz her kullanıcıya kopyalanıyordu. Bu kopyaları
  /// temizler; varsa ilerlemelerini `users/{uid}/progress` altına taşır.
  ///
  /// Bir kez çalışır: bitince profile `poolMigratedAt` damgası yazılır.
  /// Kullanıcının kendi kelimelerine (`source: user`) dokunmaz.
  Future<int> migrateLegacyCopies(String uid) async {
    final snap = await _col(uid).get();
    final legacy = snap.docs.map(Word.fromDoc).where((w) => !w.isCustom).toList();
    if (legacy.isEmpty) return 0;

    final progressCol =
        _db.collection('users').doc(uid).collection('progress');

    var removed = 0;
    for (var i = 0; i < legacy.length; i += 200) {
      final chunk = legacy.skip(i).take(200);
      final batch = _db.batch();
      for (final word in chunk) {
        // Emeği kaybetme: yalnızca çalışılmış kelimelerin ilerlemesi taşınır.
        if (!word.progress.isUntouched) {
          batch.set(
            progressCol.doc(word.id),
            word.progress.toMap(),
            SetOptions(merge: true),
          );
        }
        batch.delete(_col(uid).doc(word.id));
      }
      await batch.commit();
      removed += chunk.length;
    }
    return removed;
  }

  /// Çevrimdışı yedek: `assets/words/<pairId>.json`.
  ///
  /// Yalnızca ortak havuza hiç erişilemediğinde (ilk açılış + internet yok)
  /// kullanılır; Firestore'a hiçbir şey yazılmaz.
  ///
  /// `addedAt` listedeki sıraya göre birer milisaniye geriye kaydırılır:
  /// böylece "Son eklenen" sıralaması dosyadaki düzeni korur, aksi halde
  /// tüm kelimeler aynı damgayı alıp rastgele sıralanırdı.
  Future<List<Word>> loadSeed(LanguagePair pair) async {
    final raw = await rootBundle.loadString('assets/words/${pair.id}.json');
    final list = jsonDecode(raw) as List<dynamic>;
    final base = DateTime.now();

    final words = <Word>[];
    for (final item in list.cast<Map<String, dynamic>>()) {
      final term = (item['term'] as String?)?.trim();
      if (term == null || term.isEmpty) continue;
      words.add(
        Word(
          id: wordIdFor(pair, term),
          pairId: pair.id,
          term: term,
          translation: (item['translation'] as String? ?? '').trim(),
          example: item['example'] as String?,
          exampleTranslation: item['exampleTranslation'] as String?,
          level: item['level'] as String?,
          source: WordSource.prekta,
          addedAt: base.subtract(Duration(milliseconds: words.length)),
        ),
      );
    }
    return words;
  }

  /// Aynı kelimenin iki kez eklenmesini engelleyen deterministik kimlik.
  ///
  /// Türkçe küçültme kuralı elle uygulanır: `toLowerCase()` "İ" için noktayı
  /// ayrı bir birleştirici karakter olarak bırakır ve "İzmir" → "i-zmir" gibi
  /// bozuk kimlikler üretirdi.
  static String wordIdFor(LanguagePair pair, String term) {
    final slug = term
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9çğıöşü]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    // Latin/Türkçe harf içermeyen bir girdide slug boş kalır; kelimeler
    // birbirine karışmasın diye kod noktalarından kimlik türetilir.
    final safe = slug.isEmpty
        ? term.runes.map((r) => r.toRadixString(16)).join('-')
        : slug;
    return '${pair.id}__$safe';
  }
}
