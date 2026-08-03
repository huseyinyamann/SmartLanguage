import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models/word_progress.dart';

/// `users/{uid}/progress/{wordId}` — kelime başına kişisel ilerleme.
///
/// Kayıt yalnızca kullanıcı o kelimeyi ilk kez cevapladığında oluşur;
/// hiç çalışılmamış kelime yer kaplamaz.
class ProgressRepository {
  ProgressRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> col(String uid) =>
      _db.collection('users').doc(uid).collection('progress');

  /// wordId -> ilerleme. Kelime kimliği dil yönünü içerdiği için
  /// (`en_tr__run`) yönler birbirine karışmaz.
  Stream<Map<String, WordProgress>> watchAll(String uid) =>
      col(uid).snapshots().map(
            (snap) => {
              for (final doc in snap.docs)
                doc.id: WordProgress.fromMap(doc.data()),
            },
          );

  Future<void> write(String uid, String wordId, WordProgress progress) =>
      col(uid).doc(wordId).set(progress.toMap(), SetOptions(merge: true));

  Future<void> remove(String uid, String wordId) => col(uid).doc(wordId).delete();
}
