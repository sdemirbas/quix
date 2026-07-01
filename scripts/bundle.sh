#!/bin/bash
set -euo pipefail

# QuitAll'ı .app bundle'a sarar: Sparkle framework'ünü gömer, Info.plist yazar,
# rpath ekler ve imzalar (Developer ID varsa hardened runtime; yoksa ad-hoc).
#
# Ortam değişkenleri:
#   UNIVERSAL=1  → arm64 + x86_64 universal binary (dağıtım için)
#   SIGN_ID="Developer ID Application: ..."  → bu kimlikle imzala (release.sh geçirir)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source "$ROOT/release.config"

APP_DIR="$ROOT/$APP_NAME.app"
SPARKLE_FW="$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

echo "==> Derleniyor (release${UNIVERSAL:+, universal})…"
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    BUILD_BIN="$ROOT/.build/apple/Products/Release/$APP_NAME"
    [[ -f "$BUILD_BIN" ]] || BUILD_BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"
else
    swift build -c release
    BUILD_BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
fi

echo "==> Bundle oluşturuluyor: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"
cp "$BUILD_BIN" "$APP_DIR/Contents/MacOS/$APP_NAME"

# App icon
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Sparkle framework'ünü göm (symlink yapısını koruyarak)
echo "==> Sparkle gömülüyor"
ditto "$SPARKLE_FW" "$APP_DIR/Contents/Frameworks/Sparkle.framework"

# Framework'ü bulabilmesi için rpath ekle
install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "$APP_DIR/Contents/MacOS/$APP_NAME" 2>/dev/null || true

# Info.plist (sürüm + Sparkle anahtarları)
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 Sedat DEMİRBAŞ</string>
    <key>SUFeedURL</key><string>$SUFEED_URL</string>
    <key>SUPublicEDKey</key><string>$SU_PUBLIC_ED_KEY</string>
    <key>SUEnableAutomaticChecks</key><true/>
    <key>SUScheduledCheckInterval</key><integer>86400</integer>
</dict>
</plist>
PLIST

# İmzalama
SIGN_ID="${SIGN_ID:-}"
if [[ -n "$SIGN_ID" ]]; then
    echo "==> Developer ID ile imzalanıyor (hardened runtime): $SIGN_ID"
    FW="$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/B"
    # İçten dışa imzala; XPC servislerinin entitlement'larını koru
    codesign -f -o runtime --timestamp --preserve-metadata=entitlements \
        -s "$SIGN_ID" "$FW/XPCServices/Downloader.xpc"
    codesign -f -o runtime --timestamp --preserve-metadata=entitlements \
        -s "$SIGN_ID" "$FW/XPCServices/Installer.xpc"
    codesign -f -o runtime --timestamp -s "$SIGN_ID" "$FW/Updater.app"
    codesign -f -o runtime --timestamp -s "$SIGN_ID" "$FW/Autoupdate"
    codesign -f -o runtime --timestamp -s "$SIGN_ID" \
        "$APP_DIR/Contents/Frameworks/Sparkle.framework"
    codesign -f -o runtime --timestamp -s "$SIGN_ID" "$APP_DIR"
    echo "==> İmza doğrulanıyor"
    codesign --verify --deep --strict --verbose=2 "$APP_DIR"
else
    echo "==> Developer ID verilmedi → ad-hoc imza (yerel geliştirme)"
    codesign -f --deep -s - "$APP_DIR" 2>/dev/null || true
fi

echo "==> Tamam: $APP_DIR  (v$VERSION build $BUILD)"
