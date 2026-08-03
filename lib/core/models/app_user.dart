import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../date_key.dart';
import 'language_pair.dart';

/// `users/{uid}` dokümanı — profil + tercihler + streak.
@immutable
class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    this.pair,
    this.usePrektaWords = true,
    this.dailyGoal = 20,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastStudyDay,
    this.createdAt,
    this.poolMigratedAt,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  /// Seçili öğrenme yönü. `null` ise dil seçimi henüz yapılmamış.
  final LanguagePair? pair;

  /// Hazır Prekta kelime havuzu listeye ve pratiğe dahil edilsin mi?
  /// Kapalıyken yalnızca kullanıcının kendi eklediği kelimeler kullanılır.
  final bool usePrektaWords;

  final int dailyGoal;
  final int currentStreak;
  final int longestStreak;

  /// Son çalışılan gün, `yyyy-MM-dd`.
  final String? lastStudyDay;
  final DateTime? createdAt;

  /// Eski sürümdeki havuz kopyaları temizlendiyse dolu olur.
  final DateTime? poolMigratedAt;

  bool get hasChosenLanguage => pair != null;

  /// Adın ilk kelimesi — "Günaydın, Ahmet!" için.
  String get firstName {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) return 'dostum';
    return name.split(RegExp(r'\s+')).first;
  }

  /// Streak bugün veya dün çalışılmışsa canlıdır; aksi halde kopmuştur.
  int streakAsOf(DateTime now) {
    if (lastStudyDay == null) return 0;
    final today = dateKey(now);
    final yesterday = dateKey(now.subtract(const Duration(days: 1)));
    if (lastStudyDay == today || lastStudyDay == yesterday) {
      return currentStreak;
    }
    return 0;
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final pairId = data['pairId'] as String?;
    return AppUser(
      uid: doc.id,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      pair: pairId == null ? null : LanguagePair.fromId(pairId),
      usePrektaWords: data['usePrektaWords'] as bool? ?? true,
      dailyGoal: (data['dailyGoal'] as num?)?.toInt() ?? 20,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      lastStudyDay: data['lastStudyDay'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      poolMigratedAt: (data['poolMigratedAt'] as Timestamp?)?.toDate(),
    );
  }
}
