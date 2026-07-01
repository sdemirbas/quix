# QuitAll

Menü çubuğunda çalışan bir macOS aracı. Açık uygulamaları ikon, RAM ve CPU kullanımıyla
listeler; tek tek veya toptan kapatmanı sağlar.

## Özellikler

- 🖥️ Çalışan (Dock'ta görünen) uygulamaları listeler — Finder ve arka plan servisleri gizli
- ❌ Tek tıkla uygulama kapat
- ⚡ **Option** tuşuyla **zorla kapat** (force quit)
- 🧹 **Hepsini Kapat** butonu (Option ile hepsini zorla kapat)
- 🔍 İsimle arama / filtreleme
- 📊 Her uygulama için RAM ve CPU kullanımı (popover açıkken canlı güncellenir)
- 🚫 Dock ikonu yok (menü çubuğu uygulaması)

## Gereksinimler

- macOS 14+ (Sonoma ve üzeri)
- Swift 6 / Xcode 26 (derleme için)

## Çalıştırma

```bash
# Hızlı geliştirme (menü çubuğunda çalışır, terminale bağlı)
make debug

# .app oluştur ve aç
make run
```

`make run` → `QuitAll.app` üretir ve açar. İkon menü çubuğunda (sağ üst) belirir.

## Kullanım

1. Menü çubuğundaki ❌ ikonuna tıkla.
2. Açık uygulamalar listelenir. Bir uygulamanın yanındaki **✕** butonuna bas → kapanır.
3. **Option** tuşunu basılı tut → butonlar kırmızı ⚡ olur, tıklayınca **zorla** kapatır.
4. Alttaki **Hepsini Kapat** → QuitAll hariç tüm uygulamaları kapatır.
5. Üstteki arama kutusuyla filtreleyebilirsin.

## Notlar

- İlk açılışta macOS "geliştirici doğrulanamadı" uyarısı verirse: `QuitAll.app`'e
  **sağ tık → Aç** yap, bir kez onayla.
- CPU% değeri `ps` çıktısıdır (süreç ömrü boyunca ortalama), anlık değil.
- Kaydedilmemiş değişiklik içeren uygulamalar normal kapatmada onay diyaloğu gösterebilir.

## Mimari

- `main.swift` — AppKit bootstrap, `.accessory` (Dock ikonu yok)
- `AppDelegate.swift` — menü çubuğu `NSStatusItem` + `NSPopover`
- `RunningAppsModel.swift` — `NSWorkspace` ile uygulama listesi, quit/force/quitAll
- `ProcessStats.swift` — tek `ps` çağrısıyla RAM/CPU (imzalama/entitlement gerektirmez)
- `Views/` — SwiftUI arayüz (liste, arama, satırlar)
```
