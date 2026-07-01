# QuitAll — Yayınlama & Otomatik Güncelleme

Dağıtım: **doğrudan indirme** (Developer ID + notarization) + **Sparkle** ile otomatik güncelleme.
Mac App Store kullanılamaz (sandbox başka uygulamaları kapatmayı ve `/bin/ps`'i yasaklar).

## Tek seferlik kurulum (bir kez yapılır)

### 1. Developer ID Application sertifikası
Xcode → Settings (⌘,) → **Accounts** → hesabınla giriş → Team: *Sedat DEMİRBAŞ (BVCDHS9VW4)*
→ **Manage Certificates…** → **+** → **Developer ID Application**.

Doğrula:
```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

### 2. Notarization kimlik profili
appleid.apple.com → **App-Specific Passwords** → yeni parola oluştur. Sonra:
```bash
xcrun notarytool store-credentials "quitall-notary" \
  --apple-id "SENIN_APPLE_ID@ornek.com" \
  --team-id "BVCDHS9VW4" \
  --password "xxxx-xxxx-xxxx-xxxx"   # az önceki app-specific password
```

### 3. GitHub deposu
```bash
git init && git add -A && git commit -m "init: QuitAll"
gh repo create xsdemirbas/quitall --public --source=. --push
```
Depo adı farklıysa `release.config` içindeki `GITHUB_REPO` ve `SUFEED_URL`'i güncelle.

### 4. Sparkle özel anahtarını yedekle (KRİTİK)
Bu anahtar kaybolursa bir daha güncelleme imzalayamazsın:
```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x quitall_sparkle_private_key.txt
# Dosyayı GÜVENLİ bir yere sakla, repoya KOYMA.
```
Açık anahtar zaten `release.config` içinde: `SU_PUBLIC_ED_KEY`.

## Her yeni sürüm çıkarırken

1. `release.config` içinde **`VERSION`**'ı yükselt (ör. 1.0.1) ve **`BUILD`**'i artır (ör. 2).
2. Tek komut:
   ```bash
   make release
   ```
   Bu sırayla: universal derle → Developer ID imza (hardened runtime) → notarize → staple
   → DMG → EdDSA imzalı `appcast.xml` → GitHub Release + appcast push.
3. Bitti. Çalışan kullanıcıların uygulaması ~24 saatte bir (veya "Güncellemeleri Denetle")
   yeni sürümü **otomatik** bulup kurar.

## Nasıl çalışıyor
- Uygulama `Info.plist`'teki `SUFeedURL`'den `appcast.xml`'i okur (repo main dalı, raw).
- `appcast.xml` her sürümün DMG'sini, boyutunu ve **EdDSA imzasını** listeler.
- Sparkle imzayı `SUPublicEDKey` ile doğrular → sadece senin imzaladığın güncelleme kurulur.
- DMG'ler GitHub Release asset'i olarak sunulur.

## Yerel geliştirme
- `make run` → ad-hoc imzalı, notarize edilmemiş bundle (imza/güncelleme gerektirmez).
- `make debug` → `swift run` (en hızlı iterasyon).
