/// Gün anahtarı: `yyyy-MM-dd`. Firestore'da günlük istatistik dokümanlarının
/// kimliği ve streak karşılaştırmaları bunun üzerinden yürür.
String dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Saat/dakika bilgisi atılmış gün başlangıcı.
DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// `yyyy-MM-dd` → DateTime. Geçersizse null.
DateTime? parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Haftanın Türkçe kısaltmaları — grafik X ekseni (Pzt…Paz).
const kWeekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

String weekdayShort(DateTime d) => kWeekdayShort[d.weekday - 1];
