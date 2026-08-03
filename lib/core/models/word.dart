import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'word_progress.dart';

/// Kelime durumu — filtre chip'leri ve satır ikon rengi bunu kullanır.
enum WordStatus {
  isNew('Yeni', AppColors.wordNew),
  learning('Öğreniliyor', AppColors.wordLearning),
  mastered('Ustalaşıldı', AppColors.wordMastered),
  struggling('Zorlanılan', AppColors.wordStruggling);

  const WordStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// Kelimenin nereden geldiği.
enum WordSource {
  /// Uygulamayla gelen hazır havuz.
  prekta('prekta'),

  /// Kullanıcının kendi eklediği kelime. Yalnızca o kullanıcıya görünür.
  user('user');

  const WordSource(this.id);

  final String id;

  static WordSource fromId(String? id) =>
      id == user.id ? WordSource.user : WordSource.prekta;
}

/// Ustalık üst sınırı — arayüzde `n/5` olarak gösterilir.
const kMaxMastery = 5;

/// Kullanıcının kelime dağarcığındaki tek bir kelime.
@immutable
class Word {
  const Word({
    required this.id,
    required this.pairId,
    required this.term,
    required this.translation,
    this.example,
    this.exampleTranslation,
    this.level,
    this.source = WordSource.prekta,
    this.mastery = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.addedAt,
    this.lastReviewedAt,
    this.nextReviewAt,
  });

  /// Öğrenilen dildeki kelime (ör. "run").
  final String term;

  /// Ana dildeki karşılığı (ör. "koşmak").
  final String translation;

  final String id;
  final String pairId;
  final String? example;
  final String? exampleTranslation;
  final String? level;

  /// Hazır havuzdan mı, kullanıcının kendi eklediği mi.
  final WordSource source;

  final int mastery;
  final int correctCount;
  final int wrongCount;
  final DateTime? addedAt;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;

  /// Durum saklanmaz, ustalık ve hata sayısından türetilir — böylece
  /// hiçbir zaman veriyle tutarsız kalmaz.
  WordStatus get status {
    if (mastery >= kMaxMastery) return WordStatus.mastered;
    if (wrongCount >= 3 && wrongCount > correctCount) {
      return WordStatus.struggling;
    }
    if (mastery == 0 && correctCount == 0 && wrongCount == 0) {
      return WordStatus.isNew;
    }
    return WordStatus.learning;
  }

  double get masteryRatio => (mastery / kMaxMastery).clamp(0.0, 1.0);

  bool get isMastered => mastery >= kMaxMastery;

  /// Kullanıcının kendi eklediği kelime mi?
  bool get isCustom => source == WordSource.user;

  /// Tekrar zamanı gelmiş mi?
  bool isDue(DateTime now) =>
      nextReviewAt == null || !nextReviewAt!.isAfter(now);

  Word copyWith({
    int? mastery,
    int? correctCount,
    int? wrongCount,
    DateTime? addedAt,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
  }) =>
      Word(
        id: id,
        pairId: pairId,
        term: term,
        translation: translation,
        example: example,
        exampleTranslation: exampleTranslation,
        level: level,
        source: source,
        mastery: mastery ?? this.mastery,
        correctCount: correctCount ?? this.correctCount,
        wrongCount: wrongCount ?? this.wrongCount,
        addedAt: addedAt ?? this.addedAt,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
        nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      );

  /// İçerik + kişisel ilerlemeyi birleştirir. İçerik ortak havuzdan ya da
  /// kullanıcının kendi kelimesinden, ilerleme `users/{uid}/progress`'ten gelir.
  Word withProgress(WordProgress? progress) {
    if (progress == null) return this;
    return copyWith(
      mastery: progress.mastery,
      correctCount: progress.correctCount,
      wrongCount: progress.wrongCount,
      lastReviewedAt: progress.lastReviewedAt,
      nextReviewAt: progress.nextReviewAt,
    );
  }

  WordProgress get progress => WordProgress(
        mastery: mastery,
        correctCount: correctCount,
        wrongCount: wrongCount,
        lastReviewedAt: lastReviewedAt,
        nextReviewAt: nextReviewAt,
      );

  factory Word.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Word(
      id: doc.id,
      pairId: data['pairId'] as String? ?? 'en_tr',
      term: data['term'] as String? ?? '',
      translation: data['translation'] as String? ?? '',
      example: data['example'] as String?,
      exampleTranslation: data['exampleTranslation'] as String?,
      level: data['level'] as String?,
      // Alanı olmayan eski kayıtlar hazır havuzdan gelmiştir.
      source: WordSource.fromId(data['source'] as String?),
      mastery: (data['mastery'] as num?)?.toInt() ?? 0,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      wrongCount: (data['wrongCount'] as num?)?.toInt() ?? 0,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
      lastReviewedAt: (data['lastReviewedAt'] as Timestamp?)?.toDate(),
      nextReviewAt: (data['nextReviewAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'pairId': pairId,
        'term': term,
        'translation': translation,
        if (example != null) 'example': example,
        if (exampleTranslation != null) 'exampleTranslation': exampleTranslation,
        if (level != null) 'level': level,
        'source': source.id,
        'mastery': mastery,
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'addedAt': addedAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(addedAt!),
        if (lastReviewedAt != null)
          'lastReviewedAt': Timestamp.fromDate(lastReviewedAt!),
        if (nextReviewAt != null)
          'nextReviewAt': Timestamp.fromDate(nextReviewAt!),
      };
}
