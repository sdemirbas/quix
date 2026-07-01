# Quix

Menü çubuğunda çalışan bir macOS aracı. Açık uygulamaları ikon, RAM ve CPU kullanımıyla
listeler; tek tek veya toptan **hızlıca kapatmanı** sağlar. (Quix = quick + quit)

## Özellikler

- 🖥️ Çalışan uygulamaları listeler — normal uygulamalar + menü çubuğu ajanları
- ❌ Tek tıkla uygulama kapat (üstüne gelince çıkar)
- ⚡ **Option** tuşuyla **zorla kapat** (force quit)
- 🧹 **Hepsini Kapat** — onaylı, kaydedilmemiş veriyi koruyan
- 🗂️ Kategori filtresi (Tümü / Uygulamalar / Menü Çubuğu) + isimle arama
- 📊 Hover'da RAM; yüksek CPU kullananlar turuncu nokta ile işaretli
- 🔄 Sparkle ile **otomatik güncelleme**
- 🚫 Dock ikonu yok (menü çubuğu uygulaması)

## Gereksinimler

- macOS 14+ (Sonoma ve üzeri)
- Swift 6 / Xcode 26 (derleme için)

## Çalıştırma

```bash
make debug   # en hızlı iterasyon (swift run)
make run     # .app oluştur ve aç
```

İkon menü çubuğunda (sağ üst) `rectangle.stack` sembolüyle belirir.

## Kullanım

1. Menü çubuğundaki ikona tıkla.
2. Bir uygulamanın üstüne gel → **✕** ile kapat.
3. **Option** basılı tut → butonlar kırmızı ⚡ olur, tıklayınca **zorla** kapatır.
4. Kategori sekmeleri ve arama ile filtrele.
5. Alttaki **Hepsini Kapat** → onaydan sonra görünen uygulamaları kapatır.

## Yayınlama

Dağıtım ve otomatik güncelleme için bkz. **[RELEASING.md](RELEASING.md)**.
Kısaca: `release.config`'de sürümü yükselt → `make release`.

## Mimari

- `main.swift` — AppKit bootstrap, `.accessory` (Dock ikonu yok)
- `AppDelegate.swift` — menü çubuğu `NSStatusItem` + `NSPopover`
- `RunningAppsModel.swift` — `NSWorkspace` ile uygulama listesi, quit/force/quitAll
- `ProcessStats.swift` — tek `ps` çağrısıyla RAM/CPU (imzalama/entitlement gerektirmez)
- `UpdaterController.swift` — Sparkle otomatik güncelleme
- `Views/` — SwiftUI arayüz (liste, arama, ayarlar, onboarding)
