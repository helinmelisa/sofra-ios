# NEXT

SwiftUI ile geliştirilen, sıcak ve sade bir yemek planlama iOS uygulaması.
İlk çalışan prototip; iOS 17 ve üzerini destekler, iPhone 15 Pro Max ile uyumludur.

## Özellikler

- **Bugün:** öğün zaman çizelgesi, tamamlandı işaretleri ve 250 ml adımlarla su kaydı.
- **Yarın:** Lamaces için evden hazırlık veya Lidl, Sequira için yemekhane planı.
- **Mutfak:** Buzdolabı, Kiler ve Dondurucu; malzeme ekleme, taşıma ve kaldırma.
- **Tarifler:** tüm saklama alanlarındaki malzemelere göre eşleşen sekiz başlangıç tarifi.
  Varsayılan görünüm yalnızca tüm malzemeleri bulunan tarifleri gösterir; eksik malzemeli tarifler isteğe bağlı açılır.
- **Fişten mutfağa:** Fotoğraflar’dan fiş seçimi, cihaz içi Vision OCR, Portekizce ürünler için
  sınırlı Türkçe çeviri sözlüğü, düzenlenebilir onay ekranı ve saklama alanı önerisi.
  Tanınmayan ürünler otomatik seçilmez; miktar okunamadığında tahmin edilmez.
- **Alışveriş:** tarif eksiklerini ekleme, alınanları işaretleme ve mutfağa taşıma.
- Yerel JSON kaydı ve saklama bölümü bulunmayan eski kayıtların otomatik geçişi.

## Xcode ile çalıştırma

1. `NEXT.xcodeproj` dosyasını aç.
2. `NEXT` şemasını ve bir iPhone simülatörünü seçip Run'a bas.
3. Kendi iPhone 15 Pro Max cihazında çalıştırmak için telefonu Mac'e bağla,
   cihazda geliştirici modunu etkinleştir ve Xcode cihaz listesinden telefonu seç.
4. NEXT target → Signing & Capabilities → Team bölümünde kendi Apple hesabını seç.
   Gerekirse bundle identifier değerini kendi benzersiz kimliğinle değiştir.

Bağımlılık veya API anahtarı gerekmez. Projede mevcut Xcode geliştirme takımı
korunmuştur; farklı bir hesapla çalıştırırken kendi takımını seç.
Xcode 26 veya sonrası önerilir; geliştirme ortamında Xcode'un iOS 27.1 SDK'sıyla derlendi.

## Kontroller

macOS ve Xcode komut satırı araçları gerekir:

```sh
sh scripts/check-models.sh
xcodebuild -project NEXT.xcodeproj -scheme NEXT -configuration Debug \
  -sdk iphonesimulator -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

Model kontrolleri tarif eşleştirme, alışveriş tekrarlarını önleme, JSON kayıt döngüsü,
eski veri geçişi, saklama bölümü kaydı, fiş ayrıştırma/çeviri, miktar okuma, gıda dışı
satırları eleme ve malzeme değişiminde tarif uygunluğunu kapsar. Bunlar komut satırı kontrolleridir;
Xcode Test action için henüz XCTest/UI test target eklenmedi.

## İlk sürümün sınırları

Yemek ve envanter başlangıç verileri örnektir. Lidl stoklarına veya Sequira menüsüne
canlı bağlantı, AI servisi, besin değeri hesabı, sağlık profili ve bulut senkronizasyonu yoktur.
Fiş çevirisi genel amaçlı bir çeviri servisi değildir; desteklenmeyen ürünlerin Türkçe adını
onay ekranında düzenlemek gerekir. Fotoğraflar sunucuya gönderilmez. Yalnızca görselde görünen
ürünler okunabilir; eksik sayfalar veya kırpılmış satırlar tamamlanmaz.
Tarifler malzeme adına göre eşleşir; miktarlar ve porsiyonlar değerlendirilmez.
Alışverişten mutfağa taşınan ürünlerde saklama alanı basit bir başlangıç kuralıyla
seçilir ve ürün menüsünden değiştirilebilir. Su ve tamamlanma kayıtları gün bazındadır.

Veriler cihazın Application Support/NEXT/data.json dosyasında saklanır.
Kayıt hataları uygulama içinde gösterilir; okunamayan kayıt dosyası otomatik ezilmez.
App Store/TestFlight dağıtımı için imzalama, uygulama ikonu, gizlilik bilgileri ve
cihaz testleri ayrıca tamamlanmalıdır.
