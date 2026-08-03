import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Bir kelimedeki kişisel ilerleme: `users/{uid}/progress/{wordId}`.
///
/// Kelimenin **içeriği** (yazımı, çevirisi, örneği) burada durmaz — o ya ortak
/// havuzdadır ya da kullanıcının kendi kelime dokümanındadır. Böylece havuz
/// her kullanıcıya kopyalanmaz; kişi başına yalnızca çalıştığı kelimeler
/// kadar kayıt oluşur.
@immutable
class WordProgress {
  const WordProgress({
    this.mastery = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lastReviewedAt,
    this.nextReviewAt,
  });

  final int mastery;
  final int correctCount;
  final int wrongCount;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;

  static const empty = WordProgress();

  bool get isUntouched =>
      mastery == 0 &&
      correctCount == 0 &&
      wrongCount == 0 &&
      lastReviewedAt == null;

  factory WordProgress.fromMap(Map<String, dynamic> data) => WordProgress(
        mastery: (data['mastery'] as num?)?.toInt() ?? 0,
        correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
        wrongCount: (data['wrongCount'] as num?)?.toInt() ?? 0,
        lastReviewedAt: (data['lastReviewedAt'] as Timestamp?)?.toDate(),
        nextReviewAt: (data['nextReviewAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'mastery': mastery,
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        if (lastReviewedAt != null)
          'lastReviewedAt': Timestamp.fromDate(lastReviewedAt!),
        if (nextReviewAt != null)
          'nextReviewAt': Timestamp.fromDate(nextReviewAt!),
      };
}
