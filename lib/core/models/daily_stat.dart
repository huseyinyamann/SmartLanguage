import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// `users/{uid}/dailyStats/{yyyy-MM-dd}` — bir günün çalışma özeti.
@immutable
class DailyStat {
  const DailyStat({
    required this.day,
    this.answered = 0,
    this.correct = 0,
    this.learnedCount = 0,
    this.reviewCount = 0,
    this.newCount = 0,
  });

  /// `yyyy-MM-dd`
  final String day;

  /// O gün cevaplanan toplam soru.
  final int answered;

  /// Doğru cevap sayısı.
  final int correct;

  /// O gün ustalığa erişen kelime sayısı.
  final int learnedCount;

  /// Tekrar edilen (daha önce görülmüş) kelime sayısı.
  final int reviewCount;

  /// İlk kez çalışılan kelime sayısı.
  final int newCount;

  int get wrong => answered - correct;

  double get accuracy => answered == 0 ? 0 : correct / answered;

  bool get studied => answered > 0;

  factory DailyStat.empty(String day) => DailyStat(day: day);

  factory DailyStat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return DailyStat(
      day: doc.id,
      answered: (data['answered'] as num?)?.toInt() ?? 0,
      correct: (data['correct'] as num?)?.toInt() ?? 0,
      learnedCount: (data['learnedCount'] as num?)?.toInt() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      newCount: (data['newCount'] as num?)?.toInt() ?? 0,
    );
  }
}
