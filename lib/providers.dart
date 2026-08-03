import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/app_user.dart';
import 'core/models/daily_stat.dart';
import 'core/models/word.dart';
import 'core/models/word_progress.dart';
import 'data/auth_repository.dart';
import 'data/progress_repository.dart';
import 'data/pronunciation_service.dart';
import 'data/stats_repository.dart';
import 'data/study_service.dart';
import 'data/user_repository.dart';
import 'data/word_pool_repository.dart';
import 'data/word_repository.dart';

final authRepositoryProvider = Provider((_) => AuthRepository());
final userRepositoryProvider = Provider((_) => UserRepository());
final wordRepositoryProvider = Provider((_) => WordRepository());
final wordPoolRepositoryProvider = Provider((_) => WordPoolRepository());
final progressRepositoryProvider = Provider((_) => ProgressRepository());
final statsRepositoryProvider = Provider((_) => StatsRepository());

final pronunciationProvider = Provider((ref) {
  final service = PronunciationService();
  ref.onDispose(service.stop);
  return service;
});

final studyServiceProvider = Provider(
  (ref) => StudyService(users: ref.watch(userRepositoryProvider)),
);

/// Uygulama açıldığında sabitlenen "şimdi". Gün geçişini yakalamak için
/// [refreshNow] ile tazelenir.
final nowProvider = StateProvider((_) => DateTime.now());

/// Firebase oturum durumu.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

String? _uidOf(Ref ref) => ref.watch(authStateProvider).value?.uid;

/// Giriş yapmış kullanıcının profil dokümanı.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = _uidOf(ref);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watch(uid);
});

/// Ortak hazır havuz (`wordPool`) — kullanıcıya kopyalanmaz, buradan okunur.
/// Havuza hiç erişilemezse (ilk açılış + internet yok) uygulamayla gelen
/// yedek listeye düşer; Firestore'a yazılmaz.
final poolWordsProvider = StreamProvider<List<Word>>((ref) {
  final pair = ref.watch(appUserProvider).value?.pair;
  if (pair == null) return Stream.value(const []);

  final pool = ref.watch(wordPoolRepositoryProvider);
  final fallback = ref.watch(wordRepositoryProvider).loadSeed(pair);

  return pool.watch(pair).asyncMap((words) async {
    if (words.isNotEmpty) return words;
    try {
      return await fallback;
    } catch (_) {
      return words;
    }
  }).handleError((_) {});
});

/// Kullanıcının kendi eklediği kelimeler (içerik).
final ownWordsProvider = StreamProvider<List<Word>>((ref) {
  final uid = _uidOf(ref);
  final pair = ref.watch(appUserProvider).value?.pair;
  if (uid == null || pair == null) return Stream.value(const []);
  return ref.watch(wordRepositoryProvider).watchCustom(uid, pair);
});

/// Kelime başına kişisel ilerleme: `users/{uid}/progress`.
final progressProvider = StreamProvider<Map<String, WordProgress>>((ref) {
  final uid = _uidOf(ref);
  if (uid == null) return Stream.value(const {});
  return ref.watch(progressRepositoryProvider).watchAll(uid);
});

/// Havuz + kullanıcının kelimeleri, üzerine ilerleme uygulanmış hali.
/// Ekranlar bunu doğrudan değil, [visibleWordsProvider] üzerinden kullanır.
final wordsProvider = Provider<AsyncValue<List<Word>>>((ref) {
  final pool = ref.watch(poolWordsProvider);
  final own = ref.watch(ownWordsProvider);
  final progress = ref.watch(progressProvider);

  // İçerik akışlarından biri hata verirse onu göster; ilerleme gecikirse
  // kelimeler yine de listelenir (ilerlemesiz).
  if (pool.hasError) return AsyncValue.error(pool.error!, pool.stackTrace!);
  if (own.hasError) return AsyncValue.error(own.error!, own.stackTrace!);
  if (pool.isLoading && own.isLoading) return const AsyncValue.loading();

  final byId = <String, Word>{
    for (final word in pool.valueOrNull ?? const <Word>[]) word.id: word,
    // Aynı kimlikte kullanıcı kelimesi varsa onunki kazanır.
    for (final word in own.valueOrNull ?? const <Word>[]) word.id: word,
  };

  final progressById = progress.valueOrNull ?? const <String, WordProgress>{};
  return AsyncValue.data([
    for (final word in byId.values) word.withProgress(progressById[word.id]),
  ]);
});

/// Hazır havuz tercihi. Profil yüklenene kadar açık kabul edilir.
final usePrektaWordsProvider = Provider<bool>(
  (ref) => ref.watch(appUserProvider).value?.usePrektaWords ?? true,
);

/// Kullanıcının o an çalıştığı kelimeler: havuz kapalıysa yalnızca kendi
/// eklediği kelimeler. Liste, pratik ve istatistikler bunu kullanır.
final visibleWordsProvider = Provider<AsyncValue<List<Word>>>((ref) {
  final usePrekta = ref.watch(usePrektaWordsProvider);
  return ref.watch(wordsProvider).whenData(
        (words) =>
            usePrekta ? words : words.where((w) => w.isCustom).toList(),
      );
});

/// Kullanıcının kendi eklediği kelimeler — "Eklediklerin" sayacı için.
/// Havuz tercihi bunu etkilemez.
final customWordsProvider = Provider<AsyncValue<List<Word>>>(
  (ref) => ref.watch(wordsProvider).whenData(
        (words) => words.where((w) => w.isCustom).toList(),
      ),
);

/// Bugünün çalışma özeti.
final todayStatProvider = StreamProvider<DailyStat>((ref) {
  final uid = _uidOf(ref);
  final now = ref.watch(nowProvider);
  if (uid == null) return Stream.value(DailyStat.empty(''));
  return ref.watch(statsRepositoryProvider).watchToday(uid, now);
});

/// Son 30 günün istatistikleri (streak takvimi ve grafikler için).
final recentStatsProvider = StreamProvider<List<DailyStat>>((ref) {
  final uid = _uidOf(ref);
  final now = ref.watch(nowProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(statsRepositoryProvider).watchRecent(uid, now, 30);
});

/// Son çalışılan kelimeler, en yeniden eskiye — ana sayfadaki şerit.
/// Yükleniyor/hata durumu korunur ki arayüz boş listeyle karıştırmasın.
final recentlyStudiedWordsProvider = Provider<AsyncValue<List<Word>>>(
  (ref) => ref.watch(visibleWordsProvider).whenData((words) {
    final studied = words.where((w) => w.lastReviewedAt != null).toList()
      ..sort((a, b) => b.lastReviewedAt!.compareTo(a.lastReviewedAt!));
    return studied;
  }),
);

/// Kelime dağarcığının durum dağılımı — tüm ekranlar aynı sayıyı görsün diye
/// tek yerden türetilir.
typedef VocabSummary = ({
  int total,
  int mastered,
  int learning,
  int fresh,
  int struggling,
});

final vocabSummaryProvider = Provider<AsyncValue<VocabSummary>>(
  (ref) => ref.watch(visibleWordsProvider).whenData(
        (words) => (
          total: words.length,
          mastered: words.where((w) => w.status == WordStatus.mastered).length,
          learning: words.where((w) => w.status == WordStatus.learning).length,
          fresh: words.where((w) => w.status == WordStatus.isNew).length,
          struggling:
              words.where((w) => w.status == WordStatus.struggling).length,
        ),
      ),
);

/// Tekrar zamanı gelmiş, ustalaşılmamış kelimeler — pratik havuzu.
final dueWordsProvider = Provider<List<Word>>((ref) {
  final now = ref.watch(nowProvider);
  final words = ref.watch(visibleWordsProvider).value ?? const <Word>[];
  final due = words.where((w) => !w.isMastered && w.isDue(now)).toList()
    ..sort((a, b) {
      // Önce zorlanılanlar, sonra en eski tekrar tarihi.
      final byStatus = _priority(a).compareTo(_priority(b));
      if (byStatus != 0) return byStatus;
      final ad = a.nextReviewAt ?? DateTime(1970);
      final bd = b.nextReviewAt ?? DateTime(1970);
      return ad.compareTo(bd);
    });
  return due;
});

int _priority(Word w) => switch (w.status) {
      WordStatus.struggling => 0,
      WordStatus.learning => 1,
      WordStatus.isNew => 2,
      WordStatus.mastered => 3,
    };

/// Eski sürümde havuz her kullanıcıya kopyalanıyordu. Oturum açılınca bu
/// kopyalar bir kez temizlenir; çalışılmış kelimelerin ilerlemesi korunur.
final poolMigrationProvider = FutureProvider<int>((ref) async {
  final uid = _uidOf(ref);
  final profile = ref.watch(appUserProvider).value;
  if (uid == null || profile == null) return 0;
  if (profile.poolMigratedAt != null) return 0;

  final removed = await ref.read(wordRepositoryProvider).migrateLegacyCopies(uid);
  await ref.read(userRepositoryProvider).markPoolMigrated(uid);
  return removed;
});

/// Gün değişmiş olabilir — ekran ön plana geldiğinde çağrılır.
void refreshNow(WidgetRef ref) =>
    ref.read(nowProvider.notifier).state = DateTime.now();
