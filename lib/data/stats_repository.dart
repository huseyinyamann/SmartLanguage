import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/date_key.dart';
import '../core/models/daily_stat.dart';

/// `users/{uid}/dailyStats/{yyyy-MM-dd}` — günlük çalışma özetleri.
class StatsRepository {
  StatsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('dailyStats');

  /// Bugün dahil son [days] günün istatistikleri, eskiden yeniye sıralı.
  /// Kaydı olmayan günler boş istatistikle doldurulur.
  Stream<List<DailyStat>> watchRecent(String uid, DateTime now, int days) {
    final firstDay = dateKey(now.subtract(Duration(days: days - 1)));
    return _col(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: firstDay)
        .snapshots()
        .map((snap) {
      final byDay = {
        for (final d in snap.docs) d.id: DailyStat.fromDoc(d),
      };
      return [
        for (var i = days - 1; i >= 0; i--)
          () {
            final key = dateKey(now.subtract(Duration(days: i)));
            return byDay[key] ?? DailyStat.empty(key);
          }(),
      ];
    });
  }

  Stream<DailyStat> watchToday(String uid, DateTime now) {
    final key = dateKey(now);
    return _col(uid).doc(key).snapshots().map(
          (d) => d.exists ? DailyStat.fromDoc(d) : DailyStat.empty(key),
        );
  }
}
