import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models/language_pair.dart';
import '../core/models/word.dart';
import 'word_repository.dart' show WordRepository;

/// Hazır kelime havuzu: `wordPool/{conceptId}`.
///
/// Havuz dil çiftine göre değil **kavrama** göre saklanır; her dil kendi
/// biçimini `forms.<dil>` altında taşır. Yeni bir dil eklemek yeni doküman
/// değil, var olan kavramlara yeni bir anahtar eklemek demektir.
/// Şema ayrıntısı: `tool/README.md`.
class WordPoolRepository {
  WordPoolRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('wordPool');

  /// Verilen yön için havuzdaki kelimeler, önem sırasına göre.
  ///
  /// Sıralama bellekte yapılır: havuz birkaç bin kaydı geçmediği sürece
  /// bileşik indeks gerektirmez.
  Future<List<Word>> fetch(LanguagePair pair, {int limit = 5000}) async {
    final snap = await _col.where('pairs', arrayContains: pair.id).get();
    return _mapSnapshot(snap, pair, limit);
  }

  /// Havuzu canlı dinler. Firestore çevrimdışı önbelleği sayesinde ikinci
  /// açılıştan sonra ağ beklemeden gelir; havuza eklenen kelime uygulama
  /// güncellemesi olmadan görünür.
  Stream<List<Word>> watch(LanguagePair pair, {int limit = 5000}) => _col
      .where('pairs', arrayContains: pair.id)
      .snapshots()
      .map((snap) => _mapSnapshot(snap, pair, limit));

  List<Word> _mapSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
    LanguagePair pair,
    int limit,
  ) {
    final words = <(int, Word)>[];
    for (final doc in snap.docs) {
      final word = wordFrom(doc.data(), pair);
      if (word != null) words.add((_rankOf(doc.data(), pair), word));
    }
    words.sort((a, b) => a.$1.compareTo(b.$1));

    // "Son eklenen" sıralaması havuzdaki önem sırasını korusun diye
    // damgalar bir milisaniye arayla geriye kaydırılır.
    final base = DateTime.now();
    return [
      for (final (i, entry) in words.take(limit).indexed)
        entry.$2.copyWith(addedAt: base.subtract(Duration(milliseconds: i))),
    ];
  }

  static int _rankOf(Map<String, dynamic> data, LanguagePair pair) {
    final forms = data['forms'] as Map<String, dynamic>?;
    final form = forms?[pair.learningCode] as Map<String, dynamic>?;
    return (form?['rank'] as num?)?.toInt() ?? 1 << 30;
  }

  /// Kavram dokümanını, istenen yön için bir [Word]'e çevirir.
  ///
  /// Öğrenilen ya da ana dilin biçimi eksikse `null` döner — eksik çevirili
  /// bir kavram o yönde kullanılamaz.
  static Word? wordFrom(Map<String, dynamic> data, LanguagePair pair) {
    final forms = data['forms'] as Map<String, dynamic>?;
    if (forms == null) return null;

    final learning = forms[pair.learningCode] as Map<String, dynamic>?;
    final native = forms[pair.nativeCode] as Map<String, dynamic>?;

    final term = (learning?['text'] as String?)?.trim();
    final translation = (native?['text'] as String?)?.trim();
    if (term == null || term.isEmpty) return null;
    if (translation == null || translation.isEmpty) return null;

    return Word(
      // Kimlik yön + kelimeden türetilir; havuz kimliğinden bağımsızdır ki
      // mevcut kullanıcı kayıtlarıyla uyumlu kalsın.
      id: WordRepository.wordIdFor(pair, term),
      pairId: pair.id,
      term: term,
      translation: translation,
      example: _text(learning?['example']),
      exampleTranslation: _text(native?['example']),
      level: _text(learning?['level']),
      source: WordSource.prekta,
    );
  }

  static String? _text(Object? value) {
    final text = (value as String?)?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
