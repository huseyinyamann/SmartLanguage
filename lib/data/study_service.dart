import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/date_key.dart';
import '../core/models/word.dart';
import 'user_repository.dart';

/// Ustalık seviyesine göre bir sonraki tekrara kalan süre.
/// 0 → aynı oturumda tekrar sor, 5 → uzun aralık.
const _reviewIntervals = <Duration>[
  Duration(minutes: 10),
  Duration(days: 1),
  Duration(days: 2),
  Duration(days: 4),
  Duration(days: 7),
  Duration(days: 15),
];

/// Bir pratik cevabının tüm yan etkilerini tek yerde toplar:
/// kelimenin ustalığı, günlük istatistik ve streak.
class StudyService {
  StudyService({FirebaseFirestore? db, UserRepository? users})
      : _db = db ?? FirebaseFirestore.instance,
        _users = users ?? UserRepository();

  final FirebaseFirestore _db;
  final UserRepository _users;

  /// Cevabı kaydeder ve kelimenin güncellenmiş halini döndürür.
  Future<Word> submitAnswer({
    required String uid,
    required Word word,
    required bool correct,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final wasNew = word.status == WordStatus.isNew;
    final wasMastered = word.isMastered;

    final nextMastery = correct
        ? (word.mastery + 1).clamp(0, kMaxMastery)
        : (word.mastery - 1).clamp(0, kMaxMastery);
    final justMastered = !wasMastered && nextMastery >= kMaxMastery;

    final updated = word.copyWith(
      mastery: nextMastery,
      correctCount: correct ? word.correctCount + 1 : word.correctCount,
      wrongCount: correct ? word.wrongCount : word.wrongCount + 1,
      lastReviewedAt: now,
      nextReviewAt: now.add(_reviewIntervals[nextMastery]),
    );

    final userRef = _db.collection('users').doc(uid);
    final batch = _db.batch()
      // İlerleme kelimenin içeriğinden ayrı tutulur: hazır havuz ortaktır,
      // kullanıcı başına yalnızca çalıştığı kelime kadar kayıt oluşur.
      ..set(
        userRef.collection('progress').doc(word.id),
        updated.progress.toMap(),
        SetOptions(merge: true),
      )
      ..set(
        userRef.collection('dailyStats').doc(dateKey(now)),
        {
          'answered': FieldValue.increment(1),
          'correct': FieldValue.increment(correct ? 1 : 0),
          'newCount': FieldValue.increment(wasNew ? 1 : 0),
          'reviewCount': FieldValue.increment(wasNew ? 0 : 1),
          'learnedCount': FieldValue.increment(justMastered ? 1 : 0),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

    await batch.commit();
    await _users.markStudiedToday(uid, now);

    return updated;
  }
}
