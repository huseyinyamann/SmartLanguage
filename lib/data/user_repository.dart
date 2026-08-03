import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

import '../core/date_key.dart';
import '../core/models/app_user.dart';
import '../core/models/language_pair.dart';

/// `users/{uid}` dokümanını yönetir: profil, tercihler, streak.
class UserRepository {
  UserRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<AppUser?> watch(String uid) =>
      _doc(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<AppUser?> fetch(String uid) async {
    final d = await _doc(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  /// Girişten sonra profil dokümanını oluşturur ya da tazeler.
  /// Tercihler (pairId, dailyGoal, streak) korunur; `createdAt` yalnızca
  /// doküman ilk kez yazılırken konur.
  Future<void> upsertProfile(User user) async {
    final ref = _doc(user.uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      tx.set(ref, {
        'displayName': user.displayName,
        'email': user.email,
        'photoUrl': user.photoURL,
        'lastSeenAt': FieldValue.serverTimestamp(),
        if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> setPair(String uid, LanguagePair pair) =>
      _doc(uid).set({'pairId': pair.id}, SetOptions(merge: true));

  Future<void> setDailyGoal(String uid, int goal) =>
      _doc(uid).set({'dailyGoal': goal}, SetOptions(merge: true));

  /// Hazır kelime havuzu kullanılsın mı? Kapatılırsa liste ve pratik yalnızca
  /// kullanıcının kendi kelimelerinden oluşur.
  Future<void> setUsePrektaWords(String uid, bool value) =>
      _doc(uid).set({'usePrektaWords': value}, SetOptions(merge: true));

  /// Eski havuz kopyalarının temizlendiğini işaretler — göç bir kez çalışsın.
  Future<void> markPoolMigrated(String uid) => _doc(uid).set({
    'poolMigratedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  /// Günün ilk cevabında çağrılır. Streak'i bir işlemde günceller:
  /// dün çalışılmışsa artırır, aradan gün atlanmışsa 1'den başlatır.
  Future<void> markStudiedToday(String uid, DateTime now) async {
    final today = dateKey(now);
    final yesterday = dateKey(now.subtract(const Duration(days: 1)));

    await _db.runTransaction((tx) async {
      final ref = _doc(uid);
      final snap = await tx.get(ref);
      final data = snap.data() ?? const <String, dynamic>{};

      if (data['lastStudyDay'] == today) return;

      final current = (data['currentStreak'] as num?)?.toInt() ?? 0;
      final longest = (data['longestStreak'] as num?)?.toInt() ?? 0;
      final next = data['lastStudyDay'] == yesterday ? current + 1 : 1;

      tx.set(ref, {
        'lastStudyDay': today,
        'currentStreak': next,
        'longestStreak': next > longest ? next : longest,
      }, SetOptions(merge: true));
    });
  }

  /// Hesap silinirken çağrılır: kullanıcının tüm alt koleksiyonlarını ve
  /// profil dokümanını kalıcı olarak siler. Hazır kelime havuzu (`wordPool`)
  /// ortak olduğu için etkilenmez.
  Future<void> deleteAllData(String uid) async {
    final ref = _doc(uid);
    for (final sub in const ['words', 'progress', 'dailyStats']) {
      await _deleteCollection(ref.collection(sub));
    }
    await ref.delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const pageSize = 300;
    while (true) {
      final page = await collection.limit(pageSize).get();
      if (page.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (page.docs.length < pageSize) return;
    }
  }
}
