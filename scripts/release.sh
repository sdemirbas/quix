#!/bin/bash
set -euo pipefail

# QuitAll tam yayınlama hattı:
#   universal derle → imzala (Developer ID + hardened runtime) → notarize → staple
#   → DMG → EdDSA imzalı appcast → GitHub Release + appcast push
#
# Kullanım: release.config içindeki VERSION/BUILD'i güncelle, sonra:  ./scripts/release.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source "$ROOT/release.config"

APP_DIR="$ROOT/$APP_NAME.app"
DIST="$ROOT/dist"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
GEN_APPCAST="$ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"

# ---- Ön koşul kontrolleri ----
echo "==> Ön koşullar denetleniyor"
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "✗ 'Developer ID Application' sertifikası yok. Önce Xcode > Settings > Accounts'tan oluştur."
    exit 1
fi
command -v create-dmg >/dev/null || { echo "✗ create-dmg yok (brew install create-dmg)"; exit 1; }
command -v gh >/dev/null || { echo "✗ gh yok (brew install gh)"; exit 1; }
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || { echo "✗ notarytool profili '$NOTARY_PROFILE' yok. release.config içindeki store-credentials komutunu çalıştır."; exit 1; }

# ---- 1) İmzalı universal bundle ----
UNIVERSAL=1 SIGN_ID="$DEVELOPER_ID" "$ROOT/scripts/bundle.sh"

# ---- 2) DMG ----
echo "==> DMG oluşturuluyor"
rm -rf "$DIST"; mkdir -p "$DIST"
create-dmg \
    --volname "$APP_NAME" \
    --window-size 500 320 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 130 160 \
    --app-drop-link 370 160 \
    "$DMG" "$APP_DIR" || true   # create-dmg başarıda bile bazen != 0 döner
[[ -f "$DMG" ]] || { echo "✗ DMG oluşturulamadı"; exit 1; }

# ---- 3) Notarize + staple ----
echo "==> Notarize ediliyor (birkaç dakika sürebilir)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
echo "==> Staple"
xcrun stapler staple "$DMG"

# ---- 4) GitHub Release ----
echo "==> GitHub Release: v$VERSION"
gh release create "v$VERSION" "$DMG" \
    --repo "$GITHUB_REPO" \
    --title "$APP_NAME $VERSION" \
    --notes "QuitAll $VERSION — bkz. CHANGELOG."

# ---- 5) Appcast (EdDSA imzalı) ----
echo "==> Appcast üretiliyor"
"$GEN_APPCAST" \
    --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/" \
    "$DIST"
cp "$DIST/appcast.xml" "$ROOT/appcast.xml"

echo "==> appcast.xml repo'ya push ediliyor"
git add appcast.xml release.config
git commit -m "release: v$VERSION" || true
git push

echo "==> ✅ Yayınlandı: $APP_NAME $VERSION"
echo "    Kullanıcılar Sparkle ile otomatik güncelleme alacak."
