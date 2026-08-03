# Prekta

Flutter ile yazılmış, Türkçe arayüzlü **kelime öğrenme** uygulaması.
İngilizce ↔ Türkçe kelime çiftleriyle aralıklı tekrar (spaced repetition)
mantığında çalışır.

Uygulama kimliği: `com.prekta.app` · Dart paketi: `prekta`

## Özellikler

- **Ana Sayfa** — günlük hedef halkası, streak rozeti, o günün özeti
  (öğrenilen / tekrar / yeni), son çalışılan kelimeler şeridi ve duruma göre
  değişen teşvik kartı
- **Kelimelerim** — arama, duruma göre filtre (Yeni · Öğreniliyor ·
  Ustalaşıldı · Zorlanılan), sıralama, kelime detayı; kendi kelimeni ekleme
  ve silme. **Prekta kelimeleri** anahtarı hazır havuzu açıp kapatır;
  kapalıyken yalnızca kullanıcının eklediği kelimeler listelenir ve çalışılır.
  Eklenen kelimeler yalnızca ekleyen kullanıcıya görünür
- **İlerleme** — haftalık aktivite grafiği, cevap doğruluğu donut'u,
  30 günlük çalışma takvimi ve rozetler
- **Pratik** — çoktan seçmeli oturum; her doğru cevap ustalığı (`n/5`)
  artırır ve bir sonraki tekrar tarihini ileri atar
- Kelimelerin cihazın TTS motoruyla sesli okunması
- Google ile giriş, verilerin Firestore'da kullanıcıya özel saklanması;
  çevrimdışı önbellek açık

## Veri modeli

```
wordPool/{conceptId}                 ortak hazır havuz — dilden bağımsız kavram;
                                     her dil forms.<dil> altında (bkz. tool/README.md)
                                     herkese okuma açık, istemciden yazılamaz

users/{uid}                          profil, öğrenme yönü, günlük hedef, streak,
                                     usePrektaWords (hazır havuz açık mı)
  └── words/{wordId}                 YALNIZCA kullanıcının kendi eklediği kelimeler
                                     (içerik: kelime, çeviri, örnek, source: user)
  └── progress/{wordId}              kişisel ilerleme: ustalık, doğru/yanlış,
                                     son ve sonraki tekrar tarihi
  └── dailyStats/{yyyy-MM-dd}        answered, correct, learnedCount, reviewCount, newCount
```

**Hazır havuz kullanıcıya kopyalanmaz.** İçerik ortak koleksiyondan okunur,
kişi başına yalnızca *çalışılan* kelimenin ilerlemesi yazılır — hiç
dokunulmamış kelime yer kaplamaz. Böylece havuz binlerce kelimeye çıksa da
ilk açılış anında olur ve havuza kelime eklemek için uygulama sürümü çıkmak
ya da kullanıcı verisini taşımak gerekmez.

Şema dil çiftine değil **kavrama** dayanır: yeni bir dil eklemek yeni doküman
değil, var olan kavramlara yeni bir `forms.<dil>` anahtarı eklemek demektir.

Pratikteki her cevap tek bir batch'te kelimeyi ve o günün istatistiğini
günceller; streak ayrı bir transaction ile korunur. Ekranlardaki bütün sayılar
bu koleksiyonları dinleyen akışlardan gelir.

## Teknolojiler

Flutter · Riverpod · Firebase (Auth + Firestore) · fl_chart · flutter_tts ·
google_fonts

## Kurulum

Depoda **hiçbir Firebase kimliği veya anahtarı bulunmaz** (aşağıya bakın).
Bu yüzden çalıştırmadan önce kendi Firebase projeni bağlaman gerekir:

```bash
git clone <repo-url> && cd SmartLanguage

# 1) Firebase yapılandırmasını kendi projenle üret
dart pub global activate flutterfire_cli
flutterfire configure
#    -> lib/firebase_options.dart
#    -> android/app/google-services.json
#    -> ios/Runner/GoogleService-Info.plist  dosyalarını oluşturur

# 2) Şablonlardan kalan yerel dosyaları oluştur
cp lib/core/oauth_clients.dart.example lib/core/oauth_clients.dart
cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
cp firebase.json.example firebase.json          # gerekiyorsa

# 3) Değerleri doldur
#    oauth_clients.dart  -> google-services.json içindeki client_type 3 (web)
#                           ve GoogleService-Info.plist içindeki CLIENT_ID
#    Secrets.xcconfig    -> GoogleService-Info.plist içindeki REVERSED_CLIENT_ID

flutter pub get
flutter run
```

Firebase Console tarafında: **Authentication → Google** sağlayıcısını etkinleştir,
**Firestore**'u oluştur ve kuralları yayınla:

```bash
firebase deploy --only firestore:rules
```

## Güvenlik

Bu depo public. Bu yüzden:

- Firebase istemci yapılandırmaları, OAuth istemci kimlikleri, imzalama
  anahtarları ve ortam dosyaları `.gitignore` ile dışarıda tutulur; repoda
  yalnızca `.example` şablonları bulunur.
- Verinin asıl koruması `firestore.rules` dosyasındadır: her kullanıcı
  yalnızca kendi `users/{uid}` ağacını okuyup yazabilir, geri kalan her şey
  kapalıdır. Kullanıcının eklediği kelimeler de bu ağaçta durduğu için
  başka hiçbir hesap tarafından okunamaz.
- Kendi kopyanı yayına alırken API anahtarını paket adı / bundle id ile
  kısıtlaman ve App Check'i açman önerilir.

## Test

```bash
flutter analyze
flutter test
```

## Lisans

Henüz belirlenmedi.
