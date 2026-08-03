# Kelime havuzu betikleri

Prekta'nın hazır kelime havuzu Firestore'da **`wordPool`** koleksiyonunda
durur. Bu klasördeki betikler havuzu üretir ve yükler.

## Şema — neden böyle?

Havuz **dil çiftine göre değil, kavrama göre** saklanır. Bir kavram tek
dokümandır; her dil kendi biçimini `forms.<dil>` altında taşır:

```jsonc
// wordPool/run
{
  "conceptKey": "run",
  "languages": ["en", "tr"],
  "pairs": ["en_tr", "tr_en"],      // türetilmiş; sorgu için
  "forms": {
    "en": { "text": "run",    "example": "I run every morning.", "level": "A1", "rank": 1 },
    "tr": { "text": "koşmak", "example": "Her sabah koşarım.",   "level": "A1", "rank": 1 }
  },
  "pos": null,
  "tags": [],
  "version": 1
}
```

Yeni bir dil (örn. Almanca) eklemek **yeni doküman açmayı gerektirmez**:
her kavrama `forms.de` eklenir, `languages` ve `pairs` yeniden türetilir.
Dil çifti başına ayrı liste tutulsaydı 5 dilde 20 ayrı liste gerekirdi;
bu şemada doküman sayısı sabit kalır.

`rank` ve `level` dile özeldir (bir kelime İngilizcede A1, Türkçede B1
olabilir), bu yüzden `forms` içindedir. Sıralama sorgusu öğrenilen dilin
sıralamasını kullanır: `orderBy('forms.en.rank')`.

Uygulama, öğrenen için şunu okur:

```
term               = forms[öğrenilen].text
translation        = forms[ana dil].text
example            = forms[öğrenilen].example
exampleTranslation = forms[ana dil].example
```

## Kullanım

Betikler **bağımlılıksızdır** — `npm install` gerekmez, Firestore REST
API'sini doğrudan kullanırlar.

```bash
# 1) assets/words/*.json -> data/word_pool.json
node tool/build-pool.js

# 2) doğrula (Firestore'a yazmaz)
node tool/upload-pool.js --dry-run

# 3) yükle
node tool/upload-pool.js --project smartlanguage
#    --prune  : havuzda olmayan eski kayıtları siler
#    --key x.json : CLI oturumu yerine servis hesabı anahtarı kullan
```

**Kimlik:** varsayılan olarak `firebase login` ile açılmış CLI oturumu
kullanılır (OAuth istemci bilgileri kurulu `firebase-tools` paketinden
okunur; depoya hiçbir sır yazılmaz). Sunucu/CI ortamında servis hesabı
anahtarı ver: Firebase Console → Proje ayarları → Servis hesapları →
"Yeni özel anahtar oluştur". `*-firebase-adminsdk-*.json` ve
`*serviceAccount*.json` kalıpları `.gitignore`'da — **asla commit edilmez**.

## Kuralları ve indeksleri yayınlama

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Yükleme idempotenttir: kimlikler kavramdan türetildiği için betiği tekrar
çalıştırmak kayıtları günceller, kopya oluşturmaz.

## Güvenlik

`firestore.rules` içinde `wordPool` **giriş yapmış herkese okuma açık,
istemciden yazmaya kapalı**. Havuz yalnızca bu betikle (servis hesabı,
kuralları atlar) değiştirilir.
