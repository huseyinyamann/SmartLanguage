import 'package:flutter_tts/flutter_tts.dart';

import '../core/models/language_pair.dart';

/// Kelimelerin sesli okunması (cihazın kendi TTS motoru).
///
/// Her çağrı savunmacı: TTS motoru kurulu değilse ya da dil paketi eksikse
/// sessizce vazgeçilir — telaffuz uygulamanın çalışması için gerekli değil.
class PronunciationService {
  PronunciationService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  String? _configuredFor;
  bool _available = true;

  static const _locales = <String, String>{'en': 'en-US', 'tr': 'tr-TR'};

  Future<void> _prepare(LanguagePair pair) async {
    if (_configuredFor == pair.learningCode) return;

    final locale = _locales[pair.learningCode] ?? 'en-US';
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(0.45); // varsayılan hız kelime için fazla hızlı
    await _tts.setVolume(1);
    await _tts.setPitch(1);
    _configuredFor = pair.learningCode;
  }

  /// Kelimeyi öğrenilen dilde seslendirir. Başarılı olursa `true` döner.
  Future<bool> speak(String text, LanguagePair pair) async {
    if (!_available || text.trim().isEmpty) return false;
    try {
      await _prepare(pair);
      await _tts.stop();
      await _tts.speak(text);
      return true;
    } catch (_) {
      // Motor yoksa bir daha denemeye çalışıp kullanıcıyı bekletmeyelim.
      _available = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Yoksayılır.
    }
  }
}
