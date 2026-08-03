/// Öğrenme yönü. Şimdilik iki yön destekleniyor: TR→EN ve EN→TR.
enum LanguagePair {
  enTr(
    id: 'en_tr',
    learningCode: 'en',
    nativeCode: 'tr',
    title: 'İngilizce öğren',
    subtitle: 'Türkçeden İngilizceye',
    shortLabel: 'EN',
  ),
  trEn(
    id: 'tr_en',
    learningCode: 'tr',
    nativeCode: 'en',
    title: 'Türkçe öğren',
    subtitle: 'İngilizceden Türkçeye',
    shortLabel: 'TR',
  );

  const LanguagePair({
    required this.id,
    required this.learningCode,
    required this.nativeCode,
    required this.title,
    required this.subtitle,
    required this.shortLabel,
  });

  /// Firestore'da saklanan kimlik.
  final String id;

  /// Öğrenilen dilin kodu.
  final String learningCode;

  /// Kullanıcının bildiği dilin kodu.
  final String nativeCode;

  final String title;
  final String subtitle;

  /// Kart üzerindeki iki harfli rozet — "EN" / "TR".
  final String shortLabel;

  static LanguagePair fromId(String? id) => values.firstWhere(
        (p) => p.id == id,
        orElse: () => LanguagePair.enTr,
      );
}
